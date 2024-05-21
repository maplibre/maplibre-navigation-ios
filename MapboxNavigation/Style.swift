import MapLibre
import UIKit

/**
 `Style` is a convenient wrapper for styling the appearance of various interface components throughout the Navigation UI.
 
 Styles are applied globally using `UIAppearance`. You should call `Style.apply()` to apply the style to the `NavigationViewController`.
 */
@objc(MBStyle)
open class Style: NSObject {
    ///  General styling
    
    /**
     Sets the tint color for guidance arrow, highlighted text, progress bar and more.
     */
    @objc public var tintColor: UIColor?
    
    /**
     Sets the status bar style.
     `UIViewControllerBasedStatusBarAppearance` must be set to NO for this property to have any effect.
     */
    public var statusBarStyle: UIStatusBarStyle?
    
    /**
     Sets the font family for all labels.
     */
    @objc public var fontFamily: String?
    
    /**
     Describes the situations in which the style should be used. By default, the style will be used during the daytime.
     */
    @objc public var styleType: StyleType = .day
    
    /**
     URL of the style to display on the map during turn-by-turn navigation.
     */
    @objc open var mapStyleURL: URL = MLNStyle.defaultStyle().url

    #if canImport(CarPlay)
    /**
     URL of the style to display on the map when previewing a route, for example on CarPlay.
     */
    @objc open var previewMapStyleURL = MLNStyle.defaultStyle().url
    #else
    /**
     URL of the style to display on the map when previewing a route.
     
     This property is currently unused by default, but you can use it to present your own route preview map.
     */
    @objc open var previewMapStyleURL = MLNStyle.defaultStyle().url
    #endif
    
    /**
     Applies the style for all changed properties.
     */
    @objc open func apply() {}
  
    @available(*, deprecated, message: "Use `init(mapStyleURL:)` to specify your map style. If you want to try the demo maplibre tiles, use init(demoStyle: ()).")
    @objc override public convenience init() {
        self.init(demoStyle: ())
    }

    @objc public required init(mapStyleURL: URL) {
        self.mapStyleURL = mapStyleURL
    }

    @objc public convenience init(demoStyle: ()) {
        self.init(mapStyleURL: MLNStyle.defaultStyle().url)
    }
}

extension Style: NSCopying {
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Self(mapStyleURL: self.mapStyleURL)
        copy.tintColor = self.tintColor
        copy.statusBarStyle = self.statusBarStyle
        copy.fontFamily = self.fontFamily
        copy.styleType = self.styleType
        copy.mapStyleURL = self.mapStyleURL
        copy.previewMapStyleURL = self.previewMapStyleURL
        return copy
    }
}

/**
 :nodoc:
 `MBButton` sets the tintColor according to the style.
 */
@objc(MBButton)
open class Button: StylableButton {}

/// :nodoc:
@objc(MBCancelButton)
open class CancelButton: Button {}

/// :nodoc:
@objc(MBDismissButton)
open class DismissButton: Button {}

/// :nodoc:
@objc(MBFloatingButton)
open class FloatingButton: Button {
    static let buttonSize = CGSize(width: 50, height: 50)
    static let sizeConstraintPriority = UILayoutPriority(999.0) // Don't fight with the stack view (superview) when it tries to hide buttons.
    
    lazy var widthConstraint: NSLayoutConstraint = {
        let constraint = self.widthAnchor.constraint(equalToConstant: FloatingButton.buttonSize.width)
        constraint.priority = FloatingButton.sizeConstraintPriority
        return constraint
    }()

    lazy var heightConstraint: NSLayoutConstraint = {
        let constraint = self.heightAnchor.constraint(equalToConstant: FloatingButton.buttonSize.height)
        constraint.priority = FloatingButton.sizeConstraintPriority
        return constraint
    }()
        
    var constrainedSize: CGSize? {
        didSet {
            guard let size = constrainedSize else {
                NSLayoutConstraint.deactivate([self.widthConstraint, self.heightConstraint])
                return
            }
            self.widthConstraint.constant = size.width
            self.heightConstraint.constant = size.height
            NSLayoutConstraint.activate([self.widthConstraint, self.heightConstraint])
        }
    }
    
    class func rounded<T: FloatingButton>(image: UIImage, selectedImage: UIImage? = nil, size: CGSize = FloatingButton.buttonSize) -> T {
        let button = T(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.constrainedSize = size
        button.setImage(image, for: .normal)
        if let selected = selectedImage { button.setImage(selected, for: .selected) }
        button.applyDefaultCornerRadiusShadow(cornerRadius: size.width / 2)
        return button
    }
}

/// :nodoc:
@objc(MBReportButton)
public class ReportButton: Button {
    static let padding: CGFloat = 10
    static let downConstant: CGFloat = 10
    static let defaultInsets: UIEdgeInsets = 10.0
    static let defaultCornerRadius: CGFloat = 4.0
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    private func commonInit() {
        contentEdgeInsets = ReportButton.defaultInsets
        applyDefaultCornerRadiusShadow(cornerRadius: ReportButton.defaultCornerRadius)
    }
    
    var upConstant: CGFloat {
        -bounds.height - (ReportButton.padding * 2)
    }
    
    func slideDown(constraint: NSLayoutConstraint, interval: TimeInterval) {
        guard isHidden == true else { return }
        
        isHidden = false
        constraint.constant = ReportButton.downConstant
        setNeedsUpdateConstraints()
        UIView.defaultAnimation(0.5, animations: {
            self.superview?.layoutIfNeeded()
        }, completion: { _ in
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ReportButton.slideUp(constraint:)), object: nil)
            self.perform(#selector(ReportButton.slideUp(constraint:)), with: constraint, afterDelay: interval)
        })
    }
    
    @objc func slideUp(constraint: NSLayoutConstraint) {
        constraint.constant = self.upConstant
        setNeedsUpdateConstraints()
        UIView.defaultSpringAnimation(0.5, animations: {
            self.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.isHidden = true
        })
    }
}

/**
 :nodoc:
 `HighlightedButton` sets the button’s titleColor for normal control state according to the style in addition to the styling behavior inherited from
 `Button`.
 */
@objc(MBHighlightedButton)
public class HighlightedButton: Button {}

/// :nodoc:
@IBDesignable
@objc(MBResumeButton)
public class ResumeButton: UIControl {
    override public dynamic var tintColor: UIColor! {
        didSet {
            self.imageView.tintColor = self.tintColor
            self.titleLabel.textColor = self.tintColor
        }
    }
    
    let imageView = UIImageView(image: UIImage(named: "location", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate))
    let titleLabel = UILabel()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.commonInit()
    }
    
    func commonInit() {
        self.titleLabel.text = NSLocalizedString("RESUME", bundle: .mapboxNavigation, value: "Resume", comment: "Button title for resume tracking")
        self.titleLabel.sizeToFit()
        addSubview(self.imageView)
        addSubview(self.titleLabel)
        
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["label": titleLabel, "imageView": imageView]
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-8-[imageView]-8-[label]-8-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|->=12-[imageView]->=12-|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|->=12-[label]->=12-|", options: [], metrics: nil, views: views))
        setNeedsUpdateConstraints()
        
        applyDefaultCornerRadiusShadow()
    }
}

/// :nodoc:
@objc(MBDraggableView)
open class StepListIndicatorView: UIView {
    // Workaround the fact that UIView properties are not marked with UI_APPEARANCE_SELECTOR
    @objc open dynamic var gradientColors: [UIColor] = [.gray, .lightGray, .gray] {
        didSet {
            setNeedsLayout()
        }
    }
    
    fileprivate lazy var blurredEffectView: UIVisualEffectView = .init(effect: UIBlurEffect(style: .extraLight))

    override open func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.midY
        layer.masksToBounds = true
        layer.opacity = 0.25
        applyGradient(colors: self.gradientColors)
        self.addBlurredEffect(view: self.blurredEffectView, to: self)
    }
    
    fileprivate func addBlurredEffect(view: UIView, to parentView: UIView) {
        guard !view.isDescendant(of: parentView) else { return }
        view.frame = parentView.bounds
        parentView.addSubview(view)
    }
}

/// :nodoc:
@objc(MBStylableLabel)
open class StylableLabel: UILabel {
    // Workaround the fact that UILabel properties are not marked with UI_APPEARANCE_SELECTOR
    @objc open dynamic var normalTextColor: UIColor = .black {
        didSet {
            textColor = self.normalTextColor
        }
    }
    
    @objc open dynamic var normalFont: UIFont = .systemFont(ofSize: 16) {
        didSet {
            font = self.normalFont
        }
    }
}

/// :nodoc
@objc(MBStylableView)
open class StylableView: UIView {
    @objc dynamic var borderWidth: CGFloat = 0.0 {
        didSet {
            layer.borderWidth = self.borderWidth
        }
    }

    @objc dynamic var cornerRadius: CGFloat = 0.0 {
        didSet {
            layer.cornerRadius = self.cornerRadius
        }
    }
}

/// :nodoc:
@objc(MBStylableTextView)
open class StylableTextView: UITextView {
    // Workaround the fact that UITextView properties are not marked with UI_APPEARANCE_SELECTOR
    @objc open dynamic var normalTextColor: UIColor = .black {
        didSet {
            textColor = self.normalTextColor
        }
    }
}

/// :nodoc:
@objc(MBDistanceLabel)
open class DistanceLabel: StylableLabel {
    @objc public dynamic var valueTextColor: UIColor = #colorLiteral(red: 0.431372549, green: 0.431372549, blue: 0.431372549, alpha: 1) {
        didSet { update() }
    }

    @objc public dynamic var unitTextColor: UIColor = #colorLiteral(red: 0.6274509804, green: 0.6274509804, blue: 0.6274509804, alpha: 1) {
        didSet { update() }
    }

    @objc public dynamic var valueFont: UIFont = .systemFont(ofSize: 16, weight: .medium) {
        didSet { self.update() }
    }

    @objc public dynamic var unitFont: UIFont = .systemFont(ofSize: 11, weight: .medium) {
        didSet { self.update() }
    }
    
    /**
     An attributed string indicating the distance along with a unit.
     
     - precondition: `NSAttributedStringKey.quantity` should be applied to the
        numeric quantity.
     */
    var attributedDistanceString: NSAttributedString? {
        didSet {
            self.update()
        }
    }
    
    fileprivate func update() {
        guard let attributedDistanceString else {
            return
        }
        
        // Create a copy of the attributed string that emphasizes the quantity.
        let emphasizedDistanceString = NSMutableAttributedString(attributedString: attributedDistanceString)
        let wholeRange = NSRange(location: 0, length: emphasizedDistanceString.length)
        var hasQuantity = false
        emphasizedDistanceString.enumerateAttribute(.quantity, in: wholeRange, options: .longestEffectiveRangeNotRequired) { _, range, _ in
            let foregroundColor: UIColor
            let font: UIFont
            if emphasizedDistanceString.attribute(NSAttributedString.Key.quantity, at: range.location, effectiveRange: nil) != nil {
                foregroundColor = self.valueTextColor
                font = self.valueFont
                hasQuantity = true
            } else {
                foregroundColor = self.unitTextColor
                font = self.unitFont
            }
            emphasizedDistanceString.addAttributes([.foregroundColor: foregroundColor, .font: font], range: range)
        }
        
        // As a failsafe, if no quantity was found, emphasize the entire string.
        if !hasQuantity {
            emphasizedDistanceString.addAttributes([.foregroundColor: self.valueTextColor, .font: self.valueFont], range: wholeRange)
        }
        
        // Replace spaces with hair spaces to economize on horizontal screen
        // real estate. Formatting the distance with a short style would remove
        // spaces, but in English it would also denote feet with a prime
        // mark (′), which is typically used for heights, not distances.
        emphasizedDistanceString.mutableString.replaceOccurrences(of: " ", with: "\u{200A}", options: [], range: wholeRange)
        
        attributedText = emphasizedDistanceString
    }
}

/// :nodoc:
@objc(MBPrimaryLabel)
open class PrimaryLabel: InstructionLabel {}

/// :nodoc:
@objc(MBSecondaryLabel)
open class SecondaryLabel: InstructionLabel {}

/// :nodoc:
@objc(MBTimeRemainingLabel)
open class TimeRemainingLabel: StylableLabel {
    // Sets the text color for no or unknown traffic
    @objc public dynamic var trafficUnknownColor: UIColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1) {
        didSet {
            textColor = trafficUnknownColor
        }
    }

    // Sets the text color for low traffic
    @objc public dynamic var trafficLowColor: UIColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
    // Sets the text color for moderate traffic
    @objc public dynamic var trafficModerateColor: UIColor = #colorLiteral(red: 0.95, green: 0.65, blue: 0.31, alpha: 1.0)
    // Sets the text color for heavy traffic
    @objc public dynamic var trafficHeavyColor: UIColor = #colorLiteral(red: 0.91, green: 0.20, blue: 0.25, alpha: 1.0)
    // Sets the text color for severe traffic
    @objc public dynamic var trafficSevereColor: UIColor = #colorLiteral(red: 0.54, green: 0.06, blue: 0.22, alpha: 1.0)
}

/// :nodoc:
@objc(MBDistanceRemainingLabel)
open class DistanceRemainingLabel: StylableLabel {}

/// :nodoc:
@objc(MBArrivalTimeLabel)
open class ArrivalTimeLabel: StylableLabel {}

/// :nodoc:
@objc(MBTitleLabel)
open class TitleLabel: StylableLabel {}

/// :nodoc:
@objc(MBSubtitleLabel)
open class SubtitleLabel: StylableLabel {}

/// :nodoc:
@objc(MBWayNameView)
open class WayNameView: UIView {
    private static let textInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
    
    lazy var label: WayNameLabel = .forAutoLayout()
    
    var text: String? {
        get {
            self.label.text
        }
        set {
            self.label.text = newValue
        }
    }
    
    var attributedText: NSAttributedString? {
        get {
            self.label.attributedText
        }
        set {
            self.label.attributedText = newValue
        }
    }
    
    @objc public dynamic var borderColor: UIColor? {
        get {
            guard let color = layer.borderColor else { return nil }
            return UIColor(cgColor: color)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    func commonInit() {
        addSubview(self.label)
        layoutMargins = WayNameView.textInsets
        self.label.pinInSuperview(respectingMargins: true)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.midY
    }
}

/// :nodoc:
@objc(MBWayNameLabel)
open class WayNameLabel: StylableLabel {}

/// :nodoc:
@objc(MBProgressBar)
public class ProgressBar: UIView {
    let bar = UIView()
    
    var barHeight: CGFloat = 3
    
    // Sets the color of the progress bar.
    @objc public dynamic var barColor: UIColor = #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1) {
        didSet {
            bar.backgroundColor = barColor
        }
    }
    
    // Set the progress between 0.0-1.0
    var progress: CGFloat = 0 {
        didSet {
            self.updateProgressBar()
            layoutIfNeeded()
        }
    }
    
    override open var description: String {
        super.description + "; progress = \(self.progress)"
    }
    
    func setProgress(_ progress: CGFloat, animated: Bool) {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: {
            self.progress = progress
        }, completion: nil)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if self.bar.superview == nil {
            addSubview(self.bar)
        }
        
        self.updateProgressBar()
    }
    
    func updateProgressBar() {
        if let superview {
            let origin: CGPoint
            switch UIApplication.shared.userInterfaceLayoutDirection {
            case .leftToRight:
                origin = .zero
            case .rightToLeft:
                origin = CGPoint(x: superview.bounds.width * (1 - self.progress), y: 0)
            @unknown default:
                fatalError("Unknown userInterfaceLayoutDirection")
            }
            self.bar.frame = CGRect(origin: origin, size: CGSize(width: superview.bounds.width * self.progress, height: bounds.height))
        }
    }
}

/// :nodoc:
@objc(MBLineView)
public class LineView: UIView {
    // Set the line color on all line views.
    @objc public dynamic var lineColor: UIColor = .black {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }
}

/// :nodoc:
@objc(MBSeparatorView)
public class SeparatorView: UIView {}

/// :nodoc:
@objc(MBStylableButton)
open class StylableButton: UIButton {
    // Sets the font on the button’s titleLabel
    @objc open dynamic var textFont: UIFont = .systemFont(ofSize: 20, weight: .medium) {
        didSet {
            titleLabel?.font = self.textFont
        }
    }
    
    // Sets the text color for normal state
    @objc open dynamic var textColor: UIColor = .black {
        didSet {
            setTitleColor(self.textColor, for: .normal)
        }
    }
    
    // Sets the border color
    @objc open dynamic var borderColor: UIColor = .clear {
        didSet {
            layer.borderColor = self.borderColor.cgColor
        }
    }
    
    // Sets the border width
    @objc open dynamic var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = self.borderWidth
        }
    }
    
    // Sets the corner radius
    @objc open dynamic var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = self.cornerRadius
        }
    }
}

/// :nodoc:
@objc(MBManeuverContainerView)
open class ManeuverContainerView: UIView {
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    @objc dynamic var height: CGFloat = 100 {
        didSet {
            self.heightConstraint.constant = self.height
            setNeedsUpdateConstraints()
        }
    }
}

/// :nodoc:
@objc(MBInstructionsBannerContentView)
open class InstructionsBannerContentView: UIView {}

/// :nodoc:
@objc(MBBottomBannerContentView)
open class BottomBannerContentView: UIView {}

/// :nodoc:
@objc(MBMarkerView)
public class MarkerView: UIView {
    // Sets the inner color on the pin.
    @objc public dynamic var innerColor: UIColor = .white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Sets the shadow color under the marker view.
    @objc public dynamic var shadowColor: UIColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.1) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Sets the color on the marker view.
    @objc public dynamic var pinColor: UIColor = #colorLiteral(red: 0.1493228376, green: 0.2374534607, blue: 0.333029449, alpha: 1) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Sets the stroke color on the marker view.
    @objc public dynamic var strokeColor: UIColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override public var intrinsicContentSize: CGSize {
        CGSize(width: 39, height: 51)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .clear
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        StyleKitMarker.drawMarker(innerColor: self.innerColor, shadowColor: self.shadowColor, pinColor: self.pinColor, strokeColor: self.strokeColor)
    }
}
