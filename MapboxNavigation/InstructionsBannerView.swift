import CoreLocation
import MapboxCoreNavigation
import MapboxDirections
import UIKit

/**
 `InstructionsBannerViewDelegate` provides methods for reacting to user interactions in `InstructionsBannerView`.
 */
@objc(MBInstructionsBannerViewDelegate)
public protocol InstructionsBannerViewDelegate: AnyObject {
    /**
     Called when the user taps the `InstructionsBannerView`.
     */
    @objc(didTapInstructionsBanner:)
    optional func didTapInstructionsBanner(_ sender: BaseInstructionsBannerView)
    
    /**
     Called when the user drags either up or down on the `InstructionsBannerView`.
     */
    @objc(didDragInstructionsBanner:)
    optional func didDragInstructionsBanner(_ sender: BaseInstructionsBannerView)
}

/// :nodoc:
@IBDesignable
@objc(MBInstructionsBannerView)
open class InstructionsBannerView: BaseInstructionsBannerView {}

/// :nodoc:
open class BaseInstructionsBannerView: UIControl {
    weak var maneuverView: ManeuverView!
    weak var primaryLabel: PrimaryLabel!
    weak var secondaryLabel: SecondaryLabel!
    weak var distanceLabel: DistanceLabel!
    weak var dividerView: UIView!
    weak var _separatorView: UIView!
    weak var separatorView: SeparatorView!
    weak var stepListIndicatorView: StepListIndicatorView!
    public weak var delegate: InstructionsBannerViewDelegate? {
        didSet {
            self.stepListIndicatorView.isHidden = false
        }
    }
    
    weak var instructionDelegate: VisualInstructionDelegate? {
        didSet {
            self.primaryLabel.instructionDelegate = self.instructionDelegate
            self.secondaryLabel.instructionDelegate = self.instructionDelegate
        }
    }
    
    var centerYConstraints = [NSLayoutConstraint]()
    var baselineConstraints = [NSLayoutConstraint]()
    
    let distanceFormatter = DistanceFormatter(approximate: true)
    
    var distance: CLLocationDistance? {
        didSet {
            self.distanceLabel.attributedDistanceString = nil
            
            if let distance {
                self.distanceLabel.attributedDistanceString = self.distanceFormatter.attributedString(for: distance)
            } else {
                self.distanceLabel.text = nil
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
        setupViews()
        setupLayout()
        centerYAlignInstructions()
        setupAvailableBounds()
        self.stepListIndicatorView.isHidden = true
    }
    
    @objc func draggedInstructionsBanner(_ sender: Any) {
        if let gestureRecognizer = sender as? UIPanGestureRecognizer, gestureRecognizer.state == .ended, let delegate {
            self.stepListIndicatorView.isHidden = !self.stepListIndicatorView.isHidden
            delegate.didDragInstructionsBanner?(self)
        }
    }
    
    @objc func tappedInstructionsBanner(_ sender: Any) {
        if let delegate {
            self.stepListIndicatorView.isHidden = !self.stepListIndicatorView.isHidden
            delegate.didTapInstructionsBanner?(self)
        }
    }
    
    /**
     Updates the instructions banner info with a given `VisualInstructionBanner`.
     */
    @objc(updateForVisualInstructionBanner:)
    public func update(for instruction: VisualInstructionBanner?) {
        let secondaryInstruction = instruction?.secondaryInstruction
        self.primaryLabel.numberOfLines = secondaryInstruction == nil ? 2 : 1
        
        if secondaryInstruction == nil {
            centerYAlignInstructions()
        } else {
            baselineAlignInstructions()
        }
        
        self.primaryLabel.instruction = instruction?.primaryInstruction
        self.maneuverView.visualInstruction = instruction?.primaryInstruction
        self.maneuverView.drivingSide = instruction?.drivingSide ?? .right
        self.secondaryLabel.instruction = secondaryInstruction
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.maneuverView.isStart = true
        let component = VisualInstructionComponent(type: .text, text: "Primary text label", imageURL: nil, abbreviation: nil, abbreviationPriority: NSNotFound)
        let instruction = VisualInstruction(text: nil, maneuverType: .none, maneuverDirection: .none, components: [component])
        self.primaryLabel.instruction = instruction
        
        self.distance = 100
    }
    
    /**
     Updates the instructions banner distance info for a given `RouteStepProgress`.
     */
    public func updateDistance(for currentStepProgress: RouteStepProgress) {
        let distanceRemaining = currentStepProgress.distanceRemaining
        self.distance = distanceRemaining > 5 ? distanceRemaining : 0
    }
}
