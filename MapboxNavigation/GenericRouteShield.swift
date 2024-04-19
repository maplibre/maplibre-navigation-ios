import Foundation
import UIKit

/**
 `GenericRouteShield` is a class to render routes that do not have route-shields.
 */
public class GenericRouteShield: StylableView {
    static let labelFontSizeScaleFactor: CGFloat = 2.0 / 3.0
    
    // The color to use for the text and border.
    @objc dynamic var foregroundColor: UIColor? {
        didSet {
            layer.borderColor = self.foregroundColor?.cgColor
            self.routeLabel.textColor = self.foregroundColor
            setNeedsDisplay()
        }
    }
     
    // The label that contains the route code.
    lazy var routeLabel: UILabel = {
        let label: UILabel = .forAutoLayout()
        label.text = self.routeText
        label.textColor = .black
        label.font = UIFont.boldSystemFont(ofSize: self.pointSize * ExitView.labelFontSizeScaleFactor)
        
        return label
    }()
    
    // The text to put in the label
    var routeText: String? {
        didSet {
            self.routeLabel.text = self.routeText
            invalidateIntrinsicContentSize()
        }
    }
    
    // The size of the text the view attachment is contained within.
    var pointSize: CGFloat {
        didSet {
            self.routeLabel.font = self.routeLabel.font.withSize(self.pointSize * ExitView.labelFontSizeScaleFactor)
            self.rebuildConstraints()
        }
    }
    
    convenience init(pointSize: CGFloat, text: String) {
        self.init(frame: .zero)
        self.pointSize = pointSize
        self.routeText = text
        self.commonInit()
    }
    
    override init(frame: CGRect) {
        self.pointSize = 0.0
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.pointSize = 0.0
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    func rebuildConstraints() {
        NSLayoutConstraint.deactivate(constraints)
        self.buildConstraints()
    }
    
    func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.masksToBounds = true
        
        // build view hierarchy
        addSubview(self.routeLabel)
        self.buildConstraints()
        
        setNeedsLayout()
        invalidateIntrinsicContentSize()
        layoutIfNeeded()
    }

    func buildConstraints() {
        let height = heightAnchor.constraint(equalToConstant: self.pointSize * 1.2)
        
        let labelCenterY = self.routeLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        
        let labelLeading = self.routeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        let labelTrailingSpacing = self.routeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        
        let constraints = [height, labelCenterY, labelLeading, labelTrailingSpacing]
        
        addConstraints(constraints)
    }
    
    /**
     This generates the cache key needed to hold the `GenericRouteShield`'s `imageRepresentation` in the `ImageCache` caching engine.
     */
    static func criticalHash(dataSource: DataSource) -> String {
        let proxy = GenericRouteShield.appearance()
        let criticalProperties: [AnyHashable?] = [dataSource.font.pointSize, proxy.backgroundColor, proxy.foregroundColor, proxy.borderWidth, proxy.cornerRadius]
        return String(describing: criticalProperties.reduce(0) { $0 ^ ($1?.hashValue ?? 0) })
    }
}
