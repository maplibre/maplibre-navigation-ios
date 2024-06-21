import MapboxDirections
import UIKit

private enum ConstraintSpacing: CGFloat {
    case closer = 8.0
    case further = 65.0
}

private enum ContainerHeight: CGFloat {
    case normal = 200
    case commentShowing = 260
}

/// :nodoc:
@objc(MBEndOfRouteContentView)
open class EndOfRouteContentView: UIView {}

/// :nodoc:
@objc(MBEndOfRouteTitleLabel)
open class EndOfRouteTitleLabel: StylableLabel {}

/// :nodoc:
@objc(MBEndOfRouteStaticLabel)
open class EndOfRouteStaticLabel: StylableLabel {}

/// :nodoc:
@objc(MBEndOfRouteButton)
open class EndOfRouteButton: StylableButton {}

@objc(MBEndOfRouteViewController)
class EndOfRouteViewController: UIViewController {
    // MARK: - Properties

    lazy var column: UIStackView = {
        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        let column = UIStackView(arrangedSubviews: [self.staticYouHaveArrived, self.primaryLabel, spacerView, self.endNavigationButton])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        return column
    }()

    lazy var staticYouHaveArrived: EndOfRouteStaticLabel = {
        let label = EndOfRouteStaticLabel()
        label.text = self.endOfRouteArrivedText
        return label
    }()

    lazy var primaryLabel: EndOfRouteTitleLabel = {
        let label = EndOfRouteTitleLabel()
        label.numberOfLines = 3
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    lazy var endNavigationButton: EndOfRouteButton = {
        let button = EndOfRouteButton(type: .system)
        button.setTitle(self.endNavigationText, for: .normal)
        button.addTarget(self, action: #selector(self.endNavigationPressed(_:)), for: .touchUpInside)
        return button
    }()

    lazy var endOfRouteArrivedText: String = NSLocalizedString("END_OF_ROUTE_ARRIVED", bundle: .mapboxNavigation, value: "You have arrived", comment: "Title used for arrival")
    lazy var endNavigationText: String = NSLocalizedString("END_NAVIGATION", bundle: .mapboxNavigation, value: "End Navigation", comment: "End Navigation Button Text")

    var dismissHandler: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
    }
  
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
    open var destination: Waypoint? {
        didSet {
            guard isViewLoaded else { return }
            self.updateInterface()
        }
    }

    // MARK: - Lifecycle Methods

    override func loadView() {
        self.view = EndOfRouteContentView()
        self.view.addSubview(self.column)
        self.activateLayoutConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        preferredContentSize.height = self.height(for: .normal)
        self.updateInterface()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // roundCorners needs to be called whenever the bounds change
        view.roundCorners([.topLeft, .topRight])
    }

    // MARK: - Actions

    @objc func endNavigationPressed(_ sender: Any) {
        assert(self.dismissHandler != nil)
        self.dismissHandler?()
    }
    
    // MARK: - Private Functions

    private func height(for height: ContainerHeight) -> CGFloat {
        let window = UIApplication.shared.keyWindow
        let bottomMargin = window!.safeAreaInsets.bottom
        return height.rawValue + bottomMargin
    }
    
    private func updateInterface() {
        guard let name = destination?.name?.nonEmptyString else {
            self.staticYouHaveArrived.alpha = 0.0
            self.primaryLabel.text = self.endOfRouteArrivedText
            return
        }
        self.staticYouHaveArrived.alpha = 1.0
        self.primaryLabel.text = name
    }

    private func activateLayoutConstraints() {
        NSLayoutConstraint.activate([
            self.column.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.column.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            self.column.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            self.column.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            self.endNavigationButton.heightAnchor.constraint(equalToConstant: 60),
            self.endNavigationButton.leadingAnchor.constraint(equalTo: self.column.leadingAnchor),
            self.endNavigationButton.trailingAnchor.constraint(equalTo: self.column.trailingAnchor)
        ])
    }
}
