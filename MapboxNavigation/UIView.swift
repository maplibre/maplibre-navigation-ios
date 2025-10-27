import UIKit

extension UIView {
    class func defaultAnimation(_ duration: TimeInterval, delay: TimeInterval = 0, animations: @escaping () -> Void, completion: ((_ completed: Bool) -> Void)?) {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseInOut, animations: animations, completion: completion)
    }
    
    class func defaultSpringAnimation(_ duration: TimeInterval, delay: TimeInterval = 0, animations: @escaping () -> Void, completion: ((_ completed: Bool) -> Void)?) {
        UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.6, options: [.beginFromCurrentState], animations: animations, completion: completion)
    }
    
    func roundCorners(_ corners: UIRectCorner = [.allCorners], radius: CGFloat = 5.0) {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        layer.mask = maskLayer
    }
    
    func applyDefaultCornerRadiusShadow(cornerRadius: CGFloat? = 4, shadowOpacity: CGFloat? = 0.1) {
        layer.cornerRadius = cornerRadius!
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 4
        layer.shadowOpacity = Float(shadowOpacity!)
    }
    
    func applyDefaultShadow(shadowOpacity: CGFloat? = 0.1) {
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 4
        layer.shadowOpacity = Float(shadowOpacity!)
    }
    
    func applyGradient(colors: [UIColor], locations: [NSNumber]? = nil) {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = colors.map(\.cgColor)
        gradient.locations = locations
        
        if let sublayers = layer.sublayers, !sublayers.isEmpty, let sublayer = sublayers.first {
            layer.replaceSublayer(sublayer, with: gradient)
        } else {
            layer.addSublayer(gradient)
        }
    }
    
    func startRippleAnimation() {
        layer.masksToBounds = true
        let rippleLayer = RippleLayer()
        rippleLayer.rippleRadius = bounds.midX
        rippleLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.addSublayer(rippleLayer)
        rippleLayer.startAnimation()
    }
    
    class func fromNib<ViewType: UIView>() -> ViewType? {
        let nibName = String(describing: ViewType.self)
        return Bundle.main.loadNibNamed(nibName, owner: nil, options: nil)?[0] as? ViewType
    }
    
    func constraints(affecting view: UIView?) -> [NSLayoutConstraint]? {
        guard let view else { return nil }
        return self.constraints.filter { constraint in
            if let first = constraint.firstItem as? UIView, first == view {
                return true
            }
            if let second = constraint.secondItem as? UIView, second == view {
                return true
            }
            return false
        }
    }
    
    func pinInSuperview(respectingMargins margins: Bool = false) {
        guard let superview else {
            assertionFailure("superview was unexpectedly nil")
            return
        }
        let guide: Anchorable = margins ? superview.layoutMarginsGuide : superview
        
        let constraints = [
            topAnchor.constraint(equalTo: guide.topAnchor),
            leftAnchor.constraint(equalTo: guide.leftAnchor),
            bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            rightAnchor.constraint(equalTo: guide.rightAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }
    
    class func forAutoLayout<ViewType: UIView>(frame: CGRect = .zero, hidden: Bool = false) -> ViewType {
        let view = ViewType(frame: frame)
        view.isHidden = hidden
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    var imageRepresentation: UIImage? {
        let size = CGSize(width: frame.size.width, height: frame.size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let currentContext = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: currentContext)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

class RippleLayer: CAReplicatorLayer {
    var animationGroup: CAAnimationGroup? {
        didSet {
            self.animationGroup?.delegate = self
        }
    }

    var rippleRadius: CGFloat = 100
    var rippleColor: UIColor = .red
    var rippleRepeatCount: Float = .greatestFiniteMagnitude
    var rippleWidth: CGFloat = 10
    
    fileprivate var rippleEffect: CALayer?
    
    override init() {
        super.init()
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    func commonInit() {
        self.setupRippleEffect()
        repeatCount = Float(self.rippleRepeatCount)
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        
        self.rippleEffect?.bounds = CGRect(x: 0, y: 0, width: self.rippleRadius * 2, height: self.rippleRadius * 2)
        self.rippleEffect?.cornerRadius = self.rippleRadius
        instanceCount = 3
        instanceDelay = 0.4
    }
    
    func setupRippleEffect() {
        self.rippleEffect = CALayer()
        self.rippleEffect?.borderWidth = CGFloat(self.rippleWidth)
        self.rippleEffect?.borderColor = self.rippleColor.cgColor
        self.rippleEffect?.opacity = 0
        
        addSublayer(self.rippleEffect!)
    }
    
    func startAnimation() {
        self.animationGroup = self.rippleAnimationGroup()
        self.rippleEffect?.add(self.animationGroup!, forKey: "ripple")
    }
    
    func stopAnimation() {
        self.rippleEffect?.removeAnimation(forKey: "ripple")
    }
    
    func rippleAnimationGroup() -> CAAnimationGroup {
        let duration: CFTimeInterval = 3
        
        let group = CAAnimationGroup()
        group.duration = duration
        group.repeatCount = repeatCount
        group.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.default)
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale.xy")
        scaleAnimation.fromValue = 0.0
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = duration
        
        let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnimation.duration = duration
        let fromAlpha = 1.0
        opacityAnimation.values = [fromAlpha, fromAlpha * 0.5, 0]
        opacityAnimation.keyTimes = [0, 0.2, 1]
        
        group.animations = [scaleAnimation, opacityAnimation]
        
        return group
    }
}

extension RippleLayer: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let count = rippleEffect?.animationKeys()?.count, count > 0 {
            self.rippleEffect?.removeAllAnimations()
        }
    }
}

protocol Anchorable {
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
    var leftAnchor: NSLayoutXAxisAnchor { get }
    var rightAnchor: NSLayoutXAxisAnchor { get }
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
}

extension UIView: Anchorable {}
extension UILayoutGuide: Anchorable {}
