import MapboxCoreNavigation
import MapboxDirections
import Turf
import UIKit

/// :nodoc:
@IBDesignable
@objc(MBManeuverView)
open class ManeuverView: UIView {
    @objc public dynamic var primaryColor: UIColor = .defaultTurnArrowPrimary {
        didSet {
            setNeedsDisplay()
        }
    }

    @objc public dynamic var secondaryColor: UIColor = .defaultTurnArrowSecondary {
        didSet {
            setNeedsDisplay()
        }
    }

    @objc public var isStart = false {
        didSet {
            setNeedsDisplay()
        }
    }

    @objc public var isEnd = false {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable
    var scale: CGFloat = 1 {
        didSet {
            setNeedsDisplay()
        }
    }

    /**
     The current instruction displayed in the maneuver view.
     */
    @objc public var visualInstruction: VisualInstruction? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /**
     This indicates the side of the road currently driven on.
     */
    @objc public var drivingSide: DrivingSide = .right {
        didSet {
            setNeedsDisplay()
        }
    }

    override open func draw(_ rect: CGRect) {
        super.draw(rect)

        transform = .identity
        let resizing: ManeuversStyleKit.ResizingBehavior = .aspectFit

        #if TARGET_INTERFACE_BUILDER
        ManeuversStyleKit.drawFork(frame: bounds, resizing: resizing, primaryColor: self.primaryColor, secondaryColor: self.secondaryColor)
        return
        #endif

        guard let visualInstruction else {
            if self.isStart {
                ManeuversStyleKit.drawStarting(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
            } else if self.isEnd {
                ManeuversStyleKit.drawDestination(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
            }
            return
        }

        var flip = false
        let maneuverType = visualInstruction.maneuverType
        let maneuverDirection = visualInstruction.maneuverDirection
        
        let type = maneuverType != .none ? maneuverType : .turn
        let direction = maneuverDirection != .none ? maneuverDirection : .straightAhead

        switch type {
        case .merge:
            ManeuversStyleKit.drawMerge(frame: bounds, resizing: resizing, primaryColor: self.primaryColor, secondaryColor: self.secondaryColor)
            flip = [.left, .slightLeft, .sharpLeft].contains(direction)
        case .takeOffRamp:
            ManeuversStyleKit.drawOfframp(frame: bounds, resizing: resizing, primaryColor: self.primaryColor, secondaryColor: self.secondaryColor)
            flip = [.left, .slightLeft, .sharpLeft].contains(direction)
        case .reachFork:
            ManeuversStyleKit.drawFork(frame: bounds, resizing: resizing, primaryColor: self.primaryColor, secondaryColor: self.secondaryColor)
            flip = [.left, .slightLeft, .sharpLeft].contains(direction)
        case .takeRoundabout, .turnAtRoundabout, .takeRotary:
            ManeuversStyleKit.drawRoundabout(frame: bounds, resizing: resizing, primaryColor: self.primaryColor, secondaryColor: self.secondaryColor, roundabout_angle: CGFloat(visualInstruction.finalHeading))
            flip = self.drivingSide == .left
            
        case .arrive:
            switch direction {
            case .right:
                ManeuversStyleKit.drawArriveright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
            case .left:
                ManeuversStyleKit.drawArriveright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = true
            default:
                ManeuversStyleKit.drawArrive(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
            }
        default:
            switch direction {
            case .right:
                ManeuversStyleKit.drawArrowright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = false
            case .slightRight:
                ManeuversStyleKit.drawArrowslightright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = false
            case .sharpRight:
                ManeuversStyleKit.drawArrowsharpright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = false
            case .left:
                ManeuversStyleKit.drawArrowright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = true
            case .slightLeft:
                ManeuversStyleKit.drawArrowslightright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = true
            case .sharpLeft:
                ManeuversStyleKit.drawArrowsharpright(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = true
            case .uTurn:
                ManeuversStyleKit.drawArrow180right(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
                flip = self.drivingSide == .left
            default:
                ManeuversStyleKit.drawArrowstraight(frame: bounds, resizing: resizing, primaryColor: self.primaryColor)
            }
        }

        transform = CGAffineTransform(scaleX: flip ? -1 : 1, y: 1)
    }
}
