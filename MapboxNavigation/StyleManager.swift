import CoreLocation
import Solar
import UIKit

/**
 The `StyleManagerDelegate` protocol defines a set of methods used for controlling the style.
 */
@objc(MBStyleManagerDelegate)
public protocol StyleManagerDelegate: NSObjectProtocol {
    /**
     Asks the delegate for a location to use when calculating sunset and sunrise.
     */
    @objc func locationFor(styleManager: StyleManager) -> CLLocation?
    
    /**
     Informs the delegate that a style was applied.
     */
    @objc optional func styleManager(_ styleManager: StyleManager, didApply style: Style)
    
    /**
     Informs the delegate that the manager forcefully refreshed UIAppearance.
     */
    @objc optional func styleManagerDidRefreshAppearance(_ styleManager: StyleManager)
}

/**
 A manager that handles `Style` objects. The manager listens for significant time changes
 and changes to the content size to apply an approriate style for the given condition.
 */
@objc(MBStyleManager)
open class StyleManager: NSObject {
    /**
     The receiver of the delegate. See `StyleManagerDelegate` for more information.
     */
    @objc public weak var delegate: StyleManagerDelegate?
    
    /**
     Determines whether the style manager should apply a new style given the time of day.
     
     - precondition: `nightStyle` must be provided for this property to have any effect.
     */
    @objc public var automaticallyAdjustsStyleForTimeOfDay = true {
        didSet {
            assert(!self.automaticallyAdjustsStyleForTimeOfDay || self.nightStyle != nil, "`nightStyle` must be specified in order to adjust style for time of day")
            self.resetTimeOfDayTimer()
        }
    }
   
    /// Useful for testing
    var stubbedDate: Date?

    var currentStyleAndSize: (Style, UIContentSizeCategory)?

    /// The style used from sunrise to sunset.
    ///
    /// If `nightStyle` is nil, `dayStyle` will be used for all times.
    @objc public var dayStyle: Style {
        didSet {
            self.ensureAppropriateStyle()
        }
    }

    /// The style used from sunset to sunrise.
    ///
    /// If `nightStyle` is nil, `dayStyle` will be used for all times.
    @objc public var nightStyle: Style? {
        didSet {
            self.resetTimeOfDayTimer()
            self.ensureAppropriateStyle()
        }
    }

    /**
     Initializes a new `StyleManager`.
     
     - parameter delegate: The receiver’s delegate
     */
    public required init(_ delegate: StyleManagerDelegate, dayStyle: Style, nightStyle: Style? = nil) {
        self.delegate = delegate
        self.dayStyle = dayStyle
        self.nightStyle = nightStyle
        super.init()
        self.resumeNotifications()
        self.resetTimeOfDayTimer()
    }
    
    deinit {
        suspendNotifications()
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(timeOfDayChanged), object: nil)
    }
    
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.timeOfDayChanged), name: UIApplication.significantTimeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.preferredContentSizeChanged(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIContentSizeCategory.didChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.significantTimeChangeNotification, object: nil)
    }
    
    func resetTimeOfDayTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.timeOfDayChanged), object: nil)
        
        guard self.automaticallyAdjustsStyleForTimeOfDay, self.nightStyle != nil else { return }
        guard let location = delegate?.locationFor(styleManager: self) else { return }
        
        guard let solar = Solar(date: stubbedDate, coordinate: location.coordinate),
              let sunrise = solar.sunrise,
              let sunset = solar.sunset else {
            return
        }
        
        guard let interval = solar.date.intervalUntilTimeOfDayChanges(sunrise: sunrise, sunset: sunset) else {
            print("Unable to get sunrise or sunset. Automatic style switching has been disabled.")
            return
        }
        
        perform(#selector(self.timeOfDayChanged), with: nil, afterDelay: interval + 1)
    }
   
    @objc func preferredContentSizeChanged(_ notification: Notification) {
        self.ensureAppropriateStyle()
    }
  
    /// Useful when you don't want the time of day to change the style. For example if you're in a tunnel.
    @objc func cancelTimeOfDayTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.timeOfDayChanged), object: nil)
    }

    @objc func timeOfDayChanged() {
        self.ensureAppropriateStyle()
        self.resetTimeOfDayTimer()
    }
    
    func ensureAppropriateStyle() {
        guard self.nightStyle != nil else {
            self.ensureStyle(style: self.dayStyle)
            return
        }

        guard let location = delegate?.locationFor(styleManager: self) else {
            // We can't calculate sunset or sunrise w/o a location so just apply the first style
            self.ensureStyle(style: self.dayStyle)
            return
        }

        self.ensureStyle(type: self.styleType(for: location))
    }

    func ensureStyle(type: StyleType) {
        switch type {
        case .day:
            self.ensureStyle(style: self.dayStyle)
        case .night:
            self.ensureStyle(style: self.nightStyle ?? self.dayStyle)
        }
    }

    func ensureStyle(style: Style) {
        let preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory

        if let currentStyleAndSize, currentStyleAndSize == (style, preferredContentSizeCategory) {
            return
        }
        self.currentStyleAndSize = (style, preferredContentSizeCategory)
        style.apply()
        self.delegate?.styleManager?(self, didApply: style)
        self.refreshAppearance()
    }

    func styleType(for location: CLLocation) -> StyleType {
        guard let solar = Solar(date: stubbedDate, coordinate: location.coordinate),
              let sunrise = solar.sunrise,
              let sunset = solar.sunset else {
            return .day
        }
        
        return solar.date.isNighttime(sunrise: sunrise, sunset: sunset) ? .night : .day
    }
    
    func refreshAppearance() {
        for window in UIApplication.shared.windows {
            for view in window.subviews {
                view.removeFromSuperview()
                window.addSubview(view)
            }
        }
        
        self.delegate?.styleManagerDidRefreshAppearance?(self)
    }
}

extension Date {
    func intervalUntilTimeOfDayChanges(sunrise: Date, sunset: Date) -> TimeInterval? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: self)
        guard let date = calendar.date(from: components) else {
            return nil
        }
        
        if self.isNighttime(sunrise: sunrise, sunset: sunset) {
            let sunriseComponents = calendar.dateComponents([.hour, .minute, .second], from: sunrise)
            guard let sunriseDate = calendar.date(from: sunriseComponents) else {
                return nil
            }
            let interval = sunriseDate.timeIntervalSince(date)
            return interval >= 0 ? interval : (interval + 24 * 3600)
        } else {
            let sunsetComponents = calendar.dateComponents([.hour, .minute, .second], from: sunset)
            guard let sunsetDate = calendar.date(from: sunsetComponents) else {
                return nil
            }
            return sunsetDate.timeIntervalSince(date)
        }
    }
    
    fileprivate func isNighttime(sunrise: Date, sunset: Date) -> Bool {
        let calendar = Calendar.current
        let currentSecondsFromMidnight = calendar.component(.hour, from: self) * 3600 + calendar.component(.minute, from: self) * 60 + calendar.component(.second, from: self)
        let sunriseSecondsFromMidnight = calendar.component(.hour, from: sunrise) * 3600 + calendar.component(.minute, from: sunrise) * 60 + calendar.component(.second, from: sunrise)
        let sunsetSecondsFromMidnight = calendar.component(.hour, from: sunset) * 3600 + calendar.component(.minute, from: sunset) * 60 + calendar.component(.second, from: sunset)
        return currentSecondsFromMidnight < sunriseSecondsFromMidnight || currentSecondsFromMidnight > sunsetSecondsFromMidnight
    }
}

extension Solar {
    init?(date: Date?, coordinate: CLLocationCoordinate2D) {
        if let date {
            self.init(for: date, coordinate: coordinate)
        } else {
            self.init(coordinate: coordinate)
        }
    }
}
