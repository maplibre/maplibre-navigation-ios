import MapboxDirections
import UIKit

/// :nodoc:
@objc(MBLaneView)
open class LaneView: UIView {
    @IBInspectable
    var scale: CGFloat = 1
    let invalidAlpha: CGFloat = 0.4
    
    var lane: Lane?
    var maneuverDirection: ManeuverDirection?
    var isValid: Bool = false
    
    override open var intrinsicContentSize: CGSize {
        bounds.size
    }
    
    @objc public dynamic var primaryColor: UIColor = .defaultLaneArrowPrimary {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @objc public dynamic var secondaryColor: UIColor = .defaultLaneArrowSecondary {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var appropriatePrimaryColor: UIColor {
        self.isValid ? self.primaryColor : self.secondaryColor
    }
    
    static let defaultFrame: CGRect = .init(origin: .zero, size: 30.0)
    
    convenience init(component: LaneIndicationComponent) {
        self.init(frame: LaneView.defaultFrame)
        backgroundColor = .clear
        self.lane = Lane(indications: component.indications)
        self.maneuverDirection = ManeuverDirection(description: component.indications.description)
        self.isValid = component.isUsable
    }
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        if let lane {
            var flipLane: Bool
            if lane.indications.isSuperset(of: [.straightAhead, .sharpRight]) || lane.indications.isSuperset(of: [.straightAhead, .right]) || lane.indications.isSuperset(of: [.straightAhead, .slightRight]) {
                flipLane = false
                if !self.isValid {
                    if lane.indications == .slightRight {
                        LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                    } else {
                        LanesStyleKit.drawLane_straight_right(primaryColor: self.appropriatePrimaryColor)
                    }
                    alpha = self.invalidAlpha
                } else if self.maneuverDirection == .straightAhead {
                    LanesStyleKit.drawLane_straight_only(primaryColor: self.appropriatePrimaryColor, secondaryColor: self.secondaryColor)
                } else if self.maneuverDirection == .sharpLeft || self.maneuverDirection == .left || self.maneuverDirection == .slightLeft {
                    if lane.indications == .slightLeft {
                        LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                    } else {
                        LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                    }
                    flipLane = true
                } else {
                    LanesStyleKit.drawLane_right_only(primaryColor: self.appropriatePrimaryColor, secondaryColor: self.secondaryColor)
                }
            } else if lane.indications.isSuperset(of: [.straightAhead, .sharpLeft]) || lane.indications.isSuperset(of: [.straightAhead, .left]) || lane.indications.isSuperset(of: [.straightAhead, .slightLeft]) {
                flipLane = true
                if !self.isValid {
                    if lane.indications == .slightLeft {
                        LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                    } else {
                        LanesStyleKit.drawLane_straight_right(primaryColor: self.appropriatePrimaryColor)
                    }
                    
                    alpha = self.invalidAlpha
                } else if self.maneuverDirection == .straightAhead {
                    LanesStyleKit.drawLane_straight_only(primaryColor: self.appropriatePrimaryColor, secondaryColor: self.secondaryColor)
                } else if self.maneuverDirection == .sharpRight || self.maneuverDirection == .right {
                    LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                    flipLane = false
                } else if self.maneuverDirection == .slightRight {
                    LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                    flipLane = false
                } else {
                    LanesStyleKit.drawLane_right_only(primaryColor: self.appropriatePrimaryColor, secondaryColor: self.secondaryColor)
                }
            } else if lane.indications.description.components(separatedBy: ",").count >= 2 {
                // Hack:
                // Account for a configuation where there is no straight lane
                // but there are at least 2 indications.
                // In this situation, just draw a left/right arrow
                if self.maneuverDirection == .sharpRight || self.maneuverDirection == .right {
                    LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                    flipLane = false
                } else if self.maneuverDirection == .slightRight {
                    LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                    flipLane = false
                } else {
                    LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                    flipLane = true
                }
                alpha = self.isValid ? 1 : self.invalidAlpha
            } else if lane.indications.isSuperset(of: [.sharpRight]) || lane.indications.isSuperset(of: [.right]) || lane.indications.isSuperset(of: [.slightRight]) {
                if lane.indications == .slightRight {
                    LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                } else {
                    LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                }
                flipLane = false
                alpha = self.isValid ? 1 : self.invalidAlpha
            } else if lane.indications.isSuperset(of: [.sharpLeft]) || lane.indications.isSuperset(of: [.left]) || lane.indications.isSuperset(of: [.slightLeft]) {
                if lane.indications == .slightLeft {
                    LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                } else {
                    LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                }
                flipLane = true
                alpha = self.isValid ? 1 : self.invalidAlpha
            } else if lane.indications.isSuperset(of: [.straightAhead]) {
                LanesStyleKit.drawLane_straight(primaryColor: self.appropriatePrimaryColor)
                flipLane = false
                alpha = self.isValid ? 1 : self.invalidAlpha
            } else if lane.indications.isSuperset(of: [.uTurn]) {
                LanesStyleKit.drawLane_uturn(primaryColor: self.appropriatePrimaryColor)
                flipLane = false
                alpha = self.isValid ? 1 : self.invalidAlpha
            } else if lane.indications.isEmpty, self.isValid {
                // If the lane indication is `none` and the maneuver modifier has a turn in it,
                // show the turn in the lane image.
                if self.maneuverDirection == .sharpRight || self.maneuverDirection == .right || self.maneuverDirection == .slightRight {
                    if self.maneuverDirection == .slightRight {
                        LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                    } else {
                        LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                    }
                    flipLane = false
                } else if self.maneuverDirection == .sharpLeft || self.maneuverDirection == .left || self.maneuverDirection == .slightLeft {
                    if self.maneuverDirection == .slightLeft {
                        LanesStyleKit.drawLane_slight_right(primaryColor: self.appropriatePrimaryColor)
                    } else {
                        LanesStyleKit.drawLane_right_h(primaryColor: self.appropriatePrimaryColor)
                    }
                    flipLane = true
                } else {
                    LanesStyleKit.drawLane_straight(primaryColor: self.appropriatePrimaryColor)
                    flipLane = false
                }
            } else {
                LanesStyleKit.drawLane_straight(primaryColor: self.appropriatePrimaryColor)
                flipLane = false
                alpha = self.isValid ? 1 : self.invalidAlpha
            }
            
            transform = CGAffineTransform(scaleX: flipLane ? -1 : 1, y: 1)
        }
        
        #if TARGET_INTERFACE_BUILDER
        self.isValid = true
        LanesStyleKit.drawLane_right_only(primaryColor: self.appropriatePrimaryColor, secondaryColor: self.secondaryColor)
        #endif
    }
}
