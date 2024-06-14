import MapboxDirections
import MapLibre
import UIKit

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
        self.instructionsBannerView.topAnchor.constraint(equalTo: self.safeTopAnchor),
        self.instructionsBannerContentView.topAnchor.constraint(equalTo: self.topAnchor)
    ]
    
    lazy var bannerHideConstraints: [NSLayoutConstraint] = [
        self.informationStackView.bottomAnchor.constraint(equalTo: self.topAnchor),
        self.instructionsBannerContentView.topAnchor.constraint(equalTo: self.instructionsBannerView.topAnchor)
    ]
    
    lazy var endOfRouteShowConstraint: NSLayoutConstraint? = self.endOfRouteView?.bottomAnchor.constraint(equalTo: self.safeBottomAnchor)
    
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
    lazy var reportButton = FloatingButton.rounded(image: Images.feedback)
    
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
    
    weak var delegate: NavigationViewDelegate? {
        didSet {
            self.updateDelegates()
        }
    }
    
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
    
    // MARK: - Initializers
    
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
    
    func commonInit() {
        self.setupViews()
        setupConstraints()
    }
    
    func setupStackViews() {
        self.setupInformationStackView()
        self.floatingStackView.addArrangedSubviews([self.overviewButton, self.muteButton, self.reportButton])
    }
    
    func setupInformationStackView() {
        let informationChildren: [UIView] = [instructionsBannerView, lanesView, nextBannerView, statusView]
        self.informationStackView.addArrangedSubviews(informationChildren)
        
        for informationChild in informationChildren {
            informationChild.leadingAnchor.constraint(equalTo: self.informationStackView.leadingAnchor).isActive = true
            informationChild.trailingAnchor.constraint(equalTo: self.informationStackView.trailingAnchor).isActive = true
        }
    }
    
    func setupContainers() {
        let containers: [(UIView, UIView)] = [
            (instructionsBannerContentView, instructionsBannerView),
            (bottomBannerContentView, bottomBannerView)
        ]
        containers.forEach { $0.addSubview($1) }
    }
    
    func setupViews() {
        self.setupStackViews()
        self.setupContainers()
        
        let subviews: [UIView] = [
            mapView,
            informationStackView,
            floatingStackView,
            resumeButton,
            wayNameView,
            bottomBannerContentView,
            instructionsBannerContentView
        ]
        
        subviews.forEach(addSubview(_:))
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        DayStyle(demoStyle: ()).apply()
        [self.mapView, self.instructionsBannerView, self.lanesView, self.bottomBannerView, self.nextBannerView].forEach { $0.prepareForInterfaceBuilder() }
        self.wayNameView.text = "Street Label"
    }
    
    @objc func cancelButtonTapped(_ sender: CancelButton) {
        self.delegate?.navigationView(self, didTapCancelButton: self.bottomBannerView.cancelButton)
    }
    
    private func updateDelegates() {
        self.mapView.delegate = self.delegate
        self.mapView.navigationMapDelegate = self.delegate
        self.mapView.courseTrackingDelegate = self.delegate
        self.instructionsBannerView.delegate = self.delegate
        self.instructionsBannerView.instructionDelegate = self.delegate
        self.nextBannerView.instructionDelegate = self.delegate
        self.statusView.delegate = self.delegate
    }
}

protocol NavigationViewDelegate: NavigationMapViewDelegate, MLNMapViewDelegate, StatusViewDelegate, InstructionsBannerViewDelegate, NavigationMapViewCourseTrackingDelegate, VisualInstructionDelegate {
    func navigationView(_ view: NavigationView, didTapCancelButton: CancelButton)
}
