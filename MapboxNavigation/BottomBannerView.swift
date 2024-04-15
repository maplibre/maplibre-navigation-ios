import MapboxCoreNavigation
import MapboxDirections
import UIKit

protocol BottomBannerViewDelegate: AnyObject {
    func didCancel()
}

/// :nodoc:
@IBDesignable
@objc(MBBottomBannerView)
open class BottomBannerView: UIView {
    weak var timeRemainingLabel: TimeRemainingLabel!
    weak var distanceRemainingLabel: DistanceRemainingLabel!
    weak var arrivalTimeLabel: ArrivalTimeLabel!
    weak var cancelButton: CancelButton!
    // Vertical divider between cancel button and the labels
    weak var verticalDividerView: SeparatorView!
    // Horizontal divider between the map view and the bottom banner
    weak var horizontalDividerView: SeparatorView!
    weak var routeController: RouteController!
    weak var delegate: BottomBannerViewDelegate?
    
    let dateFormatter = DateFormatter()
    let dateComponentsFormatter = DateComponentsFormatter()
    let distanceFormatter = DistanceFormatter(approximate: true)
    
    var verticalCompactConstraints = [NSLayoutConstraint]()
    var verticalRegularConstraints = [NSLayoutConstraint]()
    
    var congestionLevel: CongestionLevel = .unknown {
        didSet {
            switch self.congestionLevel {
            case .unknown:
                self.timeRemainingLabel.textColor = self.timeRemainingLabel.trafficUnknownColor
            case .low:
                self.timeRemainingLabel.textColor = self.timeRemainingLabel.trafficLowColor
            case .moderate:
                self.timeRemainingLabel.textColor = self.timeRemainingLabel.trafficModerateColor
            case .heavy:
                self.timeRemainingLabel.textColor = self.timeRemainingLabel.trafficHeavyColor
            case .severe:
                self.timeRemainingLabel.textColor = self.timeRemainingLabel.trafficSevereColor
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    func commonInit() {
        self.dateFormatter.timeStyle = .short
        self.dateComponentsFormatter.allowedUnits = [.hour, .minute]
        self.dateComponentsFormatter.unitsStyle = .abbreviated
        
        setupViews()
        
        self.cancelButton.addTarget(self, action: #selector(BottomBannerView.cancel(_:)), for: .touchUpInside)
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.delegate?.didCancel()
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.timeRemainingLabel.text = "22 min"
        self.distanceRemainingLabel.text = "4 mi"
        self.arrivalTimeLabel.text = "10:09"
    }
    
    func updateETA(routeProgress: RouteProgress) {
        guard let arrivalDate = NSCalendar.current.date(byAdding: .second, value: Int(routeProgress.durationRemaining), to: Date()) else { return }
        self.arrivalTimeLabel.text = self.dateFormatter.string(from: arrivalDate)

        if routeProgress.durationRemaining < 5 {
            self.distanceRemainingLabel.text = nil
        } else {
            self.distanceRemainingLabel.text = self.distanceFormatter.string(from: routeProgress.distanceRemaining)
        }

        self.dateComponentsFormatter.unitsStyle = routeProgress.durationRemaining < 3600 ? .short : .abbreviated

        if let hardcodedTime = dateComponentsFormatter.string(from: 61), routeProgress.durationRemaining < 60 {
            self.timeRemainingLabel.text = String.localizedStringWithFormat(NSLocalizedString("LESS_THAN", bundle: .mapboxNavigation, value: "<%@", comment: "Format string for a short distance or time less than a minimum threshold; 1 = duration remaining"), hardcodedTime)
        } else {
            self.timeRemainingLabel.text = self.dateComponentsFormatter.string(from: routeProgress.durationRemaining)
        }
        
        guard let congestionForRemainingLeg = routeProgress.averageCongestionLevelRemainingOnLeg else { return }
        self.congestionLevel = congestionForRemainingLeg
    }
}
