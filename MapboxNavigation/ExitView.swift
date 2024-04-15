import UIKit

enum ExitSide: String {
    case left, right, other
    
    var exitImage: UIImage {
        self == .left ? ExitView.leftExitImage : ExitView.rightExitImage
    }
}

class ExitView: StylableView {
    static let leftExitImage = UIImage(named: "exit-left", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
    static let rightExitImage = UIImage(named: "exit-right", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
    
    static let labelFontSizeScaleFactor: CGFloat = 2.0 / 3.0
    
    @objc dynamic var foregroundColor: UIColor? {
        didSet {
            layer.borderColor = self.foregroundColor?.cgColor
            self.imageView.tintColor = self.foregroundColor
            self.exitNumberLabel.textColor = self.foregroundColor
            setNeedsDisplay()
        }
    }
    
    var side: ExitSide = .right {
        didSet {
            self.populateExitImage()
            self.rebuildConstraints()
        }
    }
    
    lazy var imageView: UIImageView = {
        let view = UIImageView(image: self.side.exitImage)
        view.tintColor = self.foregroundColor
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var exitNumberLabel: UILabel = {
        let label: UILabel = .forAutoLayout()
        label.text = self.exitText
        label.textColor = .black
        label.font = UIFont.boldSystemFont(ofSize: self.pointSize * ExitView.labelFontSizeScaleFactor)

        return label
    }()

    var exitText: String? {
        didSet {
            self.exitNumberLabel.text = self.exitText
            invalidateIntrinsicContentSize()
        }
    }
    
    var pointSize: CGFloat {
        didSet {
            self.exitNumberLabel.font = self.exitNumberLabel.font.withSize(self.pointSize * ExitView.labelFontSizeScaleFactor)
            self.rebuildConstraints()
        }
    }
    
    func spacing(for side: ExitSide, direction: UIUserInterfaceLayoutDirection = UIApplication.shared.userInterfaceLayoutDirection) -> CGFloat {
        let space: (less: CGFloat, more: CGFloat) = (4.0, 6.0)
        let lessSide: ExitSide = (direction == .rightToLeft) ? .left : .right
        return side == lessSide ? space.less : space.more
    }
    
    convenience init(pointSize: CGFloat, side: ExitSide = .right, text: String) {
        self.init(frame: .zero)
        self.pointSize = pointSize
        self.side = side
        self.exitText = text
        self.commonInit()
    }
    
    override init(frame: CGRect) {
        self.pointSize = 0.0
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
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
        [self.imageView, self.exitNumberLabel].forEach(addSubview(_:))
        self.buildConstraints()
        
        setNeedsLayout()
        invalidateIntrinsicContentSize()
        layoutIfNeeded()
    }
    
    func populateExitImage() {
        self.imageView.image = self.side.exitImage
    }
    
    func buildConstraints() {
        let height = heightAnchor.constraint(equalToConstant: self.pointSize * 1.2)

        let imageHeight = self.imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.4)
        let imageAspect = self.imageView.widthAnchor.constraint(equalTo: self.imageView.heightAnchor, multiplier: self.imageView.image?.size.aspectRatio ?? 1.0)

        let imageCenterY = self.imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        let labelCenterY = self.exitNumberLabel.centerYAnchor.constraint(equalTo: centerYAnchor)

        let sideConstraints = self.side != .left ? self.rightExitConstraints() : self.leftExitConstraints()
        
        let constraints = [height, imageHeight, imageAspect,
                           imageCenterY, labelCenterY] + sideConstraints
        
        addConstraints(constraints)
    }

    func rightExitConstraints() -> [NSLayoutConstraint] {
        let labelLeading = self.exitNumberLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        let spacing = spacing(for: .right)
        let imageLabelSpacing = self.exitNumberLabel.trailingAnchor.constraint(equalTo: self.imageView.leadingAnchor, constant: -1 * spacing)
        let imageTrailing = trailingAnchor.constraint(equalTo: self.imageView.trailingAnchor, constant: 8)
        return [labelLeading, imageLabelSpacing, imageTrailing]
    }
    
    func leftExitConstraints() -> [NSLayoutConstraint] {
        let imageLeading = self.imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        let spacing = spacing(for: .left)
        let imageLabelSpacing = self.imageView.trailingAnchor.constraint(equalTo: self.exitNumberLabel.leadingAnchor, constant: -1 * spacing)
        let labelTrailing = trailingAnchor.constraint(equalTo: self.exitNumberLabel.trailingAnchor, constant: 8)
        return [imageLeading, imageLabelSpacing, labelTrailing]
    }
    
    /**
     This generates the cache key needed to hold the `ExitView`'s `imageRepresentation` in the `ImageCache` caching engine.
     */
    static func criticalHash(side: ExitSide, dataSource: DataSource) -> String {
        let proxy = ExitView.appearance()
        let criticalProperties: [AnyHashable?] = [side, dataSource.font.pointSize, proxy.backgroundColor, proxy.foregroundColor, proxy.borderWidth, proxy.cornerRadius]
        return String(describing: criticalProperties.reduce(0) { $0 ^ ($1?.hashValue ?? 0) })
    }
}
