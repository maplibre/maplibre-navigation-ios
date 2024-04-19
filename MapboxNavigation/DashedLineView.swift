import UIKit

/// :nodoc:
@IBDesignable
@objc(MBDashedLineView)
public class DashedLineView: LineView {
    @IBInspectable public var dashedLength: CGFloat = 4 { didSet { self.updateProperties() } }
    @IBInspectable public var dashedGap: CGFloat = 4 { didSet { self.updateProperties() } }

    let dashedLineLayer = CAShapeLayer()

    override public func layoutSubviews() {
        if self.dashedLineLayer.superlayer == nil {
            layer.addSublayer(self.dashedLineLayer)
        }
        self.updateProperties()
    }

    func updateProperties() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.height / 2))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height / 2))
        self.dashedLineLayer.path = path.cgPath

        self.dashedLineLayer.frame = bounds
        self.dashedLineLayer.fillColor = UIColor.clear.cgColor
        self.dashedLineLayer.strokeColor = lineColor.cgColor
        self.dashedLineLayer.lineWidth = bounds.height
        self.dashedLineLayer.lineDashPattern = [self.dashedLength as NSNumber, self.dashedGap as NSNumber]
    }
}
