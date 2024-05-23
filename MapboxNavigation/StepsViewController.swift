import MapboxCoreNavigation
import MapboxDirections
import Turf
import UIKit

/// :nodoc:
@objc(MBStepsBackgroundView)
open class StepsBackgroundView: UIView {}

/**
 `StepsViewControllerDelegate` provides methods for user interactions in a `StepsViewController`.
 */
@objc public protocol StepsViewControllerDelegate: AnyObject {
    /**
     Called when the user selects a step in a `StepsViewController`.
     */
    @objc optional func stepsViewController(_ viewController: StepsViewController, didSelect legIndex: Int, stepIndex: Int, cell: StepTableViewCell)

    /**
     Called when the user dismisses the `StepsViewController`.
     */
    @objc func didDismissStepsViewController(_ viewController: StepsViewController)
}

/// :nodoc:
@objc(MBStepsViewController)
public class StepsViewController: UIViewController {
    weak var tableView: UITableView!
    weak var backgroundView: UIView!
    weak var bottomView: UIView!
    weak var separatorBottomView: SeparatorView!
    weak var dismissButton: DismissButton!
    public weak var delegate: StepsViewControllerDelegate?

    let cellId = "StepTableViewCellId"
    var routeProgress: RouteProgress!

    typealias StepSection = [RouteStep]
    var sections = [StepSection]()

    var previousLegIndex: Int = NSNotFound
    var previousStepIndex: Int = NSNotFound

    /**
     Initializes StepsViewController with a RouteProgress object.

     - parameter routeProgress: The user's current route progress.
     - SeeAlso: [RouteProgress](https://www.mapbox.com/mapbox-navigation-ios/navigation/0.14.1/Classes/RouteProgress.html)
     */
    public convenience init(routeProgress: RouteProgress) {
        self.init()
        self.routeProgress = routeProgress
    }

    @discardableResult
    func rebuildDataSourceIfNecessary() -> Bool {
        let legIndex = self.routeProgress.legIndex
        let stepIndex = self.routeProgress.currentLegProgress.stepIndex
        let didProcessCurrentStep = self.previousLegIndex == legIndex && self.previousStepIndex == stepIndex

        guard !didProcessCurrentStep else { return false }

        self.sections.removeAll()

        let currentLeg = self.routeProgress.currentLeg

        // Add remaining steps for current leg
        var section = [RouteStep]()
        for (index, step) in currentLeg.steps.enumerated() {
            guard index > stepIndex else { continue }
            // Don't include the last step, it includes nothing
            guard index < currentLeg.steps.count - 1 else { continue }
            section.append(step)
        }

        if !section.isEmpty {
            self.sections.append(section)
        }

        // Include all steps on any future legs
        if !self.routeProgress.isFinalLeg {
            for item in self.routeProgress.route.legs.suffix(from: self.routeProgress.legIndex + 1) {
                var steps = item.steps
                // Don't include the last step, it includes nothing
                _ = steps.popLast()
                self.sections.append(steps)
            }
        }

        self.previousStepIndex = stepIndex
        self.previousLegIndex = legIndex

        return true
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
        self.rebuildDataSourceIfNecessary()

        NotificationCenter.default.addObserver(self, selector: #selector(StepsViewController.progressDidChange(_:)), name: .routeControllerProgressDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
    }

    @objc func progressDidChange(_ notification: Notification) {
        if self.rebuildDataSourceIfNecessary() {
            self.tableView.reloadData()
        }
    }

    func setupViews() {
        self.view.translatesAutoresizingMaskIntoConstraints = false

        let backgroundView = StepsBackgroundView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(backgroundView)
        self.backgroundView = backgroundView

        backgroundView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        backgroundView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        backgroundView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true

        let tableView = UITableView(frame: self.view.bounds, style: .plain)
        tableView.separatorColor = .clear
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
        self.tableView = tableView

        let dismissButton = DismissButton(type: .custom)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        let title = NSLocalizedString("DISMISS_STEPS_TITLE", bundle: .mapboxNavigation, value: "Close", comment: "Dismiss button title on the steps view")
        dismissButton.setTitle(title, for: .normal)
        dismissButton.addTarget(self, action: #selector(StepsViewController.tappedDismiss(_:)), for: .touchUpInside)
        self.view.addSubview(dismissButton)
        self.dismissButton = dismissButton

        let bottomView = UIView()
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.backgroundColor = DismissButton.appearance().backgroundColor
        self.view.addSubview(bottomView)
        self.bottomView = bottomView

        let separatorBottomView = SeparatorView()
        separatorBottomView.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addSubview(separatorBottomView)
        self.separatorBottomView = separatorBottomView

        dismissButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        dismissButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        dismissButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        dismissButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true

        bottomView.topAnchor.constraint(equalTo: dismissButton.bottomAnchor).isActive = true
        bottomView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        bottomView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        bottomView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true

        separatorBottomView.topAnchor.constraint(equalTo: dismissButton.topAnchor).isActive = true
        separatorBottomView.leadingAnchor.constraint(equalTo: dismissButton.leadingAnchor).isActive = true
        separatorBottomView.trailingAnchor.constraint(equalTo: dismissButton.trailingAnchor).isActive = true
        separatorBottomView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true

        tableView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: dismissButton.topAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true

        tableView.register(StepTableViewCell.self, forCellReuseIdentifier: self.cellId)
    }

    /**
     Shows and animates the `StepsViewController` down.
     */
    public func dropDownAnimation() {
        var frame = view.frame
        frame.origin.y -= frame.height
        view.frame = frame

        UIView.animate(withDuration: 0.35, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            var frame = self.view.frame
            frame.origin.y += frame.height
            self.view.frame = frame
        }, completion: nil)
    }

    /**
     Dismisses and animates the `StepsViewController` up.
     */
    public func slideUpAnimation(completion: CompletionHandler? = nil) {
        UIView.animate(withDuration: 0.35, delay: 0, options: [.beginFromCurrentState, .curveEaseIn], animations: {
            var frame = self.view.frame
            frame.origin.y -= frame.height
            self.view.frame = frame
        }, completion: { _ in
            completion?()
        })
    }

    @IBAction func tappedDismiss(_ sender: Any) {
        self.delegate?.didDismissStepsViewController(self)
    }

    /**
     Dismisses the `StepsViewController`.
     */
    public func dismiss(completion: CompletionHandler? = nil) {
        self.slideUpAnimation {
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            completion?()
        }
    }
}

extension StepsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath) as! StepTableViewCell
        // Since as we progress, steps are removed from the list, we need to map the row the user tapped to the actual step on the leg.
        // If the user selects a step on future leg, all steps are going to be there.
        var stepIndex: Int
        if indexPath.section > 0 {
            stepIndex = indexPath.row
        } else {
            stepIndex = indexPath.row + self.routeProgress.currentLegProgress.stepIndex
            // For the current leg, we need to know the upcoming step.
            stepIndex += indexPath.row + 1 > self.sections[indexPath.section].count ? 0 : 1
        }
        self.delegate?.stepsViewController?(self, didSelect: indexPath.section, stepIndex: stepIndex, cell: cell)
    }
}

extension StepsViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        self.sections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let steps = self.sections[section]
        return steps.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        96
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellId, for: indexPath) as! StepTableViewCell
        return cell
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        self.updateCell(cell as! StepTableViewCell, at: indexPath)
    }

    func updateCell(_ cell: StepTableViewCell, at indexPath: IndexPath) {
        cell.instructionsView.primaryLabel.viewForAvailableBoundsCalculation = cell
        cell.instructionsView.secondaryLabel.viewForAvailableBoundsCalculation = cell

        let step = self.sections[indexPath.section][indexPath.row]

        if let instructions = step.instructionsDisplayedAlongStep?.last {
            cell.instructionsView.update(for: instructions)
            cell.instructionsView.secondaryLabel.instruction = instructions.secondaryInstruction
        }
        cell.instructionsView.distance = step.distance

        cell.instructionsView.stepListIndicatorView.isHidden = true

        // Hide cell separator if it’s the last row in a section
        let isLastRowInSection = indexPath.row == self.sections[indexPath.section].count - 1
        cell.separatorView.isHidden = isLastRowInSection
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }

        let leg = self.routeProgress.route.legs[section]
        let sourceName = leg.source.name
        let destinationName = leg.destination.name
        let majorWays = leg.name.components(separatedBy: ", ")

        if let destinationName = destinationName?.nonEmptyString, majorWays.count > 1 {
            let summary = String.localizedStringWithFormat(NSLocalizedString("LEG_MAJOR_WAYS_FORMAT", bundle: .mapboxNavigation, value: "%@ and %@", comment: "Format for displaying the first two major ways"), majorWays[0], majorWays[1])
            return String.localizedStringWithFormat(NSLocalizedString("WAYPOINT_DESTINATION_VIA_WAYPOINTS_FORMAT", bundle: .mapboxNavigation, value: "%@, via %@", comment: "Format for displaying destination and intermediate waypoints; 1 = source ; 2 = destinations"), destinationName, summary)
        } else if let sourceName = sourceName?.nonEmptyString, let destinationName = destinationName?.nonEmptyString {
            return String.localizedStringWithFormat(NSLocalizedString("WAYPOINT_SOURCE_DESTINATION_FORMAT", bundle: .mapboxNavigation, value: "%@ and %@", comment: "Format for displaying start and endpoint for leg; 1 = source ; 2 = destination"), sourceName, destinationName)
        } else {
            return leg.name
        }
    }
}

/// :nodoc:
@objc(MBStepInstructionsView)
open class StepInstructionsView: BaseInstructionsBannerView {}

/// :nodoc:
@objc(MBStepTableViewCell)
open class StepTableViewCell: UITableViewCell {
    weak var instructionsView: StepInstructionsView!
    weak var separatorView: SeparatorView!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    func commonInit() {
        selectionStyle = .none

        let instructionsView = StepInstructionsView()
        instructionsView.translatesAutoresizingMaskIntoConstraints = false
        instructionsView.separatorView.isHidden = true
        instructionsView.isUserInteractionEnabled = false
        addSubview(instructionsView)
        self.instructionsView = instructionsView

        instructionsView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        instructionsView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        instructionsView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        instructionsView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

        let separatorView = SeparatorView()
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)
        self.separatorView = separatorView

        separatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        separatorView.leadingAnchor.constraint(equalTo: instructionsView.primaryLabel.leadingAnchor).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: instructionsView.bottomAnchor).isActive = true
        separatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18).isActive = true
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        self.instructionsView.update(for: nil)
    }
}

private extension [RouteStep] {
    func stepBefore(_ step: RouteStep) -> RouteStep? {
        guard let index = firstIndex(of: step) else {
            return nil
        }

        if index > 0 {
            return self[index - 1]
        }

        return nil
    }
}
