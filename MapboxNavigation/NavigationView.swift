import MapboxDirections
import MapLibre
import UIKit

protocol NavigationViewDelegate: NavigationMapViewDelegate, MLNMapViewDelegate, StatusViewDelegate, InstructionsBannerViewDelegate, NavigationMapViewCourseTrackingDelegate, VisualInstructionDelegate {
    func navigationView(_ view: NavigationView, didTapCancelButton: CancelButton)
}

/**
 A view that represents the root view of the MapboxNavigation drop-in UI.
 
 ## Components
 
 1. InstructionsBannerView
 2. InformationStackView
 3. BottomBannerView
 4. ResumeButton
 5. WayNameLabel
 6. FloatingStackView
 7. NavigationMapView
 
 ```
 +--------------------+
 |         1          |
 +--------------------+
 |         2          |
 +----------------+---+
 |                |   |
 |                | 6 |
 |                |   |
 |         7      +---+
 |                    |
 |                    |
 |                    |
 +------------+       |
 |  4  ||  5  |       |
 +------------+-------+
 |         3          |
 +--------------------+
 ```
 */
@IBDesignable
@objc(MBNavigationView)
open class NavigationView: UIView {
    private enum Constants {
        static let endOfRouteHeight: CGFloat = 260.0
        static let feedbackTopConstraintPadding: CGFloat = 10.0
        static let buttonSize: CGSize = 50.0
        static let buttonSpacing: CGFloat = 8.0
    }
    
    lazy var bannerShowConstraints: [NSLayoutConstraint] = [
        self.instructionsBannerView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
        self.instructionsBannerContentView.topAnchor.constraint(equalTo: self.topAnchor)
    ]
    
    lazy var bannerHideConstraints: [NSLayoutConstraint] = [
        self.informationStackView.bottomAnchor.constraint(equalTo: self.topAnchor),
        self.instructionsBannerContentView.topAnchor.constraint(equalTo: self.instructionsBannerView.topAnchor)
    ]

    lazy var endOfRouteShowConstraint: NSLayoutConstraint? = self.endOfRouteView?.bottomAnchor.constraint(equalTo: self.bottomAnchor)

    lazy var endOfRouteHideConstraint: NSLayoutConstraint? = self.endOfRouteView?.topAnchor.constraint(equalTo: self.bottomAnchor)

    lazy var endOfRouteHeightConstraint: NSLayoutConstraint? = self.endOfRouteView?.heightAnchor.constraint(equalToConstant: Constants.endOfRouteHeight)

    private enum Images {
        static let overview = UIImage(named: "overview", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
        static let volumeUp = UIImage(named: "volume_up", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
        static let volumeOff = UIImage(named: "volume_off", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
        static let feedback = UIImage(named: "feedback", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
    }
    
    private enum Actions {
        static let cancelButton: Selector = #selector(NavigationView.cancelButtonTapped(_:))
    }
    
    lazy var mapView: NavigationMapView = {
        let map: NavigationMapView = .forAutoLayout(frame: self.bounds)
        map.delegate = self.delegate
        map.navigationMapDelegate = self.delegate
        map.courseTrackingDelegate = self.delegate
        map.showsUserLocation = true
        return map
    }()
    
    lazy var instructionsBannerContentView: InstructionsBannerContentView = .forAutoLayout()
    
    lazy var instructionsBannerView: InstructionsBannerView = {
        let banner: InstructionsBannerView = .forAutoLayout()
        banner.delegate = self.delegate
        return banner
    }()
    
    lazy var informationStackView = UIStackView(orientation: .vertical, autoLayout: true)
    
    lazy var floatingStackView: UIStackView = {
        let stackView = UIStackView(orientation: .vertical, autoLayout: true)
        stackView.distribution = .equalSpacing
        stackView.spacing = Constants.buttonSpacing
        return stackView
    }()
    
    lazy var overviewButton = FloatingButton.rounded(image: Images.overview)
    lazy var muteButton = FloatingButton.rounded(image: Images.volumeUp, selectedImage: Images.volumeOff)
    
    lazy var lanesView: LanesView = .forAutoLayout(hidden: true)
    lazy var nextBannerView: NextBannerView = .forAutoLayout(hidden: true)
    lazy var statusView: StatusView = {
        let view: StatusView = .forAutoLayout()
        view.delegate = self.delegate
        view.isHidden = true
        return view
    }()
    
    lazy var resumeButton: ResumeButton = .forAutoLayout()
    
    lazy var wayNameView: WayNameView = {
        let view: WayNameView = .forAutoLayout(hidden: true)
        view.clipsToBounds = true
        view.layer.borderWidth = 1.0 / UIScreen.main.scale
        return view
    }()
    
    lazy var bottomBannerContentView: BottomBannerContentView = .forAutoLayout()
    lazy var bottomBannerView: BottomBannerView = {
        let view: BottomBannerView = .forAutoLayout()
        view.cancelButton.addTarget(self, action: Actions.cancelButton, for: .touchUpInside)
        return view
    }()

    var endOfRouteView: UIView? {
        didSet {
            if let active: [NSLayoutConstraint] = constraints(affecting: oldValue) {
                NSLayoutConstraint.deactivate(active)
            }

            oldValue?.removeFromSuperview()
            if let endOfRouteView {
                endOfRouteView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(endOfRouteView)
            }
        }
    }

    weak var delegate: NavigationViewDelegate? {
        didSet {
            self.updateDelegates()
        }
    }
    
    // MARK: - Lifecycle
    
    convenience init(delegate: NavigationViewDelegate) {
        self.init(frame: .zero)
        self.delegate = delegate
        self.updateDelegates() // this needs to be called because didSet's do not fire in init contexts.
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    // MARK: - NavigationView
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        DayStyle(demoStyle: ()).apply()
        [self.mapView, self.instructionsBannerView, self.lanesView, self.bottomBannerView, self.nextBannerView].forEach { $0.prepareForInterfaceBuilder() }
        self.wayNameView.text = "Street Label"
    }
	
    func showUI(animated: Bool = true) {
        let views: [UIView] = [
            self.instructionsBannerContentView,
            self.lanesView,
            self.bottomBannerContentView,
            self.floatingStackView
        ]
		
        NSLayoutConstraint.activate(self.bannerShowConstraints)
        NSLayoutConstraint.deactivate(self.bannerHideConstraints)
		
        UIView.animate(withDuration: animated ? CATransaction.animationDuration() : 0) {
            views.forEach { $0.alpha = 1 }
        } completion: { _ in
            views.forEach { $0.isHidden = false }
            self.bottomBannerView.traitCollectionDidChange(self.traitCollection)
        }
    }
	
    func hideUI(animated: Bool = true) {
        let views: [UIView] = [
            self.instructionsBannerContentView,
            self.lanesView,
            self.bottomBannerContentView,
            self.floatingStackView,
            self.resumeButton
        ]
		
        NSLayoutConstraint.deactivate(self.bannerShowConstraints)
        NSLayoutConstraint.activate(self.bannerHideConstraints)
		
        UIView.animate(withDuration: animated ? CATransaction.animationDuration() : 0) {
            views.forEach { $0.alpha = 0 }
        } completion: { _ in
            views.forEach { $0.isHidden = true }
            self.bottomBannerView.traitCollectionDidChange(self.traitCollection)
        }
    }
}

// MARK: - Private

private extension NavigationView {
    @objc
    func cancelButtonTapped(_ sender: CancelButton) {
        self.delegate?.navigationView(self, didTapCancelButton: self.bottomBannerView.cancelButton)
    }
	
    func commonInit() {
        self.setupViews()
        self.setupConstraints()
    }
    
    func setupStackViews() {
        self.setupInformationStackView()
        self.floatingStackView.addArrangedSubviews([self.overviewButton, self.muteButton])
    }
    
    func setupInformationStackView() {
        let informationChildren: [UIView] = [self.instructionsBannerView, self.lanesView, self.nextBannerView, self.statusView]
        self.informationStackView.addArrangedSubviews(informationChildren)
        
        for informationChild in informationChildren {
            informationChild.leadingAnchor.constraint(equalTo: self.informationStackView.leadingAnchor).isActive = true
            informationChild.trailingAnchor.constraint(equalTo: self.informationStackView.trailingAnchor).isActive = true
        }
    }
    
    func setupContainers() {
        let containers: [(UIView, UIView)] = [
            (self.instructionsBannerContentView, self.instructionsBannerView),
            (self.bottomBannerContentView, self.bottomBannerView)
        ]
        containers.forEach { $0.addSubview($1) }
    }
    
    func setupViews() {
        self.setupStackViews()
        self.setupContainers()
		
        let subviews: [UIView] = [
            self.mapView,
            self.informationStackView,
            self.floatingStackView,
            self.resumeButton,
            self.wayNameView,
            self.bottomBannerContentView,
            self.instructionsBannerContentView
        ]
        
        subviews.forEach(addSubview(_:))
    }
    
    func updateDelegates() {
        self.mapView.delegate = self.delegate
        self.mapView.navigationMapDelegate = self.delegate
        self.mapView.courseTrackingDelegate = self.delegate
        self.instructionsBannerView.delegate = self.delegate
        self.instructionsBannerView.instructionDelegate = self.delegate
        self.nextBannerView.instructionDelegate = self.delegate
        self.statusView.delegate = self.delegate
    }
}
