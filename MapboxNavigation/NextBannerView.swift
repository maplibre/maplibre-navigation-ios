import MapboxCoreNavigation
import MapboxDirections
import UIKit

/// :nodoc:
@objc(MBNextInstructionLabel)
open class NextInstructionLabel: InstructionLabel {}

/// :nodoc:
@IBDesignable
@objc(MBNextBannerView)
open class NextBannerView: UIView {
    weak var maneuverView: ManeuverView!
    weak var instructionLabel: NextInstructionLabel!
    weak var bottomSeparatorView: SeparatorView!
    weak var instructionDelegate: VisualInstructionDelegate? {
        didSet {
            self.instructionLabel.instructionDelegate = self.instructionDelegate
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
        self.setupViews()
        self.setupLayout()
    }
    
    func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        
        let maneuverView = ManeuverView()
        maneuverView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(maneuverView)
        self.maneuverView = maneuverView
        
        let instructionLabel = NextInstructionLabel()
        instructionLabel.instructionDelegate = self.instructionDelegate
        instructionLabel.shieldHeight = instructionLabel.font.pointSize
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instructionLabel)
        self.instructionLabel = instructionLabel
        
        instructionLabel.availableBounds = { [unowned self] in
            // Available width H:|-padding-maneuverView-padding-availableWidth-padding-|
            let availableWidth = bounds.width - BaseInstructionsBannerView.maneuverViewSize.width - BaseInstructionsBannerView.padding * 3
            return CGRect(x: 0, y: 0, width: availableWidth, height: self.instructionLabel.font.lineHeight)
        }
        
        let bottomSeparatorView = SeparatorView()
        bottomSeparatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomSeparatorView)
        self.bottomSeparatorView = bottomSeparatorView
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.maneuverView.isEnd = true
        let component = VisualInstructionComponent(type: .text, text: "Next step", imageURL: nil, abbreviation: nil, abbreviationPriority: NSNotFound)
        let instruction = VisualInstruction(text: nil, maneuverType: .none, maneuverDirection: .none, components: [component])
        self.instructionLabel.instruction = instruction
    }
    
    func setupLayout() {
        let heightConstraint = heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.priority = UILayoutPriority(rawValue: 999)
        heightConstraint.isActive = true
        
        let midX = BaseInstructionsBannerView.padding + BaseInstructionsBannerView.maneuverViewSize.width / 2
        self.maneuverView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: midX).isActive = true
        self.maneuverView.heightAnchor.constraint(equalToConstant: 22).isActive = true
        self.maneuverView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        self.maneuverView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        self.instructionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 70).isActive = true
        self.instructionLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        self.instructionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
        
        self.bottomSeparatorView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        self.bottomSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        self.bottomSeparatorView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        self.bottomSeparatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
    }
    
    /**
     Updates the instructions banner info with a given `VisualInstructionBanner`.
     */
    @objc(updateForVisualInstructionBanner:)
    public func update(for visualInstruction: VisualInstructionBanner?) {
        guard let tertiaryInstruction = visualInstruction?.tertiaryInstruction, !tertiaryInstruction.containsLaneIndications else {
            self.hide()
            return
        }
        
        self.maneuverView.visualInstruction = tertiaryInstruction
        self.maneuverView.drivingSide = visualInstruction?.drivingSide ?? .right
        self.instructionLabel.instruction = tertiaryInstruction
        self.show()
    }
    
    public func show() {
        guard isHidden else { return }
        UIView.defaultAnimation(0.3, animations: {
            self.isHidden = false
        }, completion: nil)
    }
    
    public func hide() {
        guard !isHidden else { return }
        UIView.defaultAnimation(0.3, animations: {
            self.isHidden = true
        }, completion: nil)
    }
}
