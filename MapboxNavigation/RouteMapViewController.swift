import AVFoundation
import MapboxCoreNavigation
import MapboxDirections
import MapLibre
import Turf
import UIKit

class ArrowFillPolyline: MLNPolylineFeature {}
class ArrowStrokePolyline: ArrowFillPolyline {}

@objc protocol RouteMapViewControllerDelegate: NavigationMapViewDelegate, MLNMapViewDelegate, VisualInstructionDelegate {
    func mapViewControllerDidFinish(_ mapViewController: RouteMapViewController, byCanceling canceled: Bool)
    func mapViewControllerShouldAnnotateSpokenInstructions(_ routeMapViewController: RouteMapViewController) -> Bool

    /**
     Called to allow the delegate to customize the contents of the road name label that is displayed towards the bottom of the map view.

     This method is called on each location update. By default, the label displays the name of the road the user is currently traveling on.

     - parameter mapViewController: The route map view controller that will display the road name.
     - parameter location: The user’s current location.
     - return: The road name to display in the label, or the empty string to hide the label, or nil to query the map’s vector tiles for the road name.
     */
    @objc func mapViewController(_ mapViewController: RouteMapViewController, roadNameAt location: CLLocation) -> String?
}

class RouteMapViewController: UIViewController {
    typealias LabelRoadNameCompletionHandler = (_ defaultRaodNameAssigned: Bool) -> Void
	
    private enum Actions {
        static let overview: Selector = #selector(RouteMapViewController.toggleOverview(_:))
        static let mute: Selector = #selector(RouteMapViewController.toggleMute(_:))
        static let recenter: Selector = #selector(RouteMapViewController.recenter(_:))
    }
	
    private lazy var geocoder: CLGeocoder = .init()
	
    // MARK: - Properties
	
    let distanceFormatter = DistanceFormatter(approximate: true)
    var navigationView: NavigationView { view as! NavigationView }
    var mapView: NavigationMapView { self.navigationView.mapView }
    var statusView: StatusView { self.navigationView.statusView }
    var lanesView: LanesView { self.navigationView.lanesView }
    var nextBannerView: NextBannerView { self.navigationView.nextBannerView }
    var instructionsBannerView: InstructionsBannerView { self.navigationView.instructionsBannerView }
    var instructionsBannerContentView: InstructionsBannerContentView { self.navigationView.instructionsBannerContentView }
    var route: Route? { self.routeController?.routeProgress.route }
    var updateETATimer: Timer?
    var previewInstructionsView: StepInstructionsView?
    var lastTimeUserRerouted: Date?
    var stepsViewController: StepsViewController?
    var destination: Waypoint?
    var showsEndOfRoute: Bool = true
    var arrowCurrentStep: RouteStep?
	
    var contentInsets: UIEdgeInsets {
        let top = self.navigationView.instructionsBannerContentView.bounds.height
        let bottom = self.navigationView.bottomBannerView.bounds.height
        return UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    }
	
    var isUsedInConjunctionWithCarPlayWindow = false {
        didSet {
            if self.isUsedInConjunctionWithCarPlayWindow {
                displayPreviewInstructions()
            } else {
                self.stepsViewController?.dismiss()
            }
        }
    }

    var pendingCamera: MLNMapCamera? {
        guard let parent = parent as? NavigationViewController else {
            return nil
        }
        return parent.pendingCamera
    }

    var tiltedCamera: MLNMapCamera {
        let camera = self.mapView.camera
        camera.altitude = 1000
        camera.pitch = 45
        return camera
    }

    var routeController: Router? {
        didSet {
            self.navigationView.statusView.canChangeValue = self.routeController?.locationManager is SimulatedLocationManager
            guard let destination = self.route?.legs.last?.destination else { return }
			
            self.populateName(for: destination, populated: { self.destination = $0 })
        }
    }
    
    var isInOverviewMode = false {
        didSet {
            if self.isInOverviewMode {
                self.navigationView.overviewButton.isHidden = true
                self.navigationView.resumeButton.isHidden = false
                self.navigationView.wayNameView.isHidden = true
                self.mapView.logoView.isHidden = true
            } else {
                self.navigationView.overviewButton.isHidden = false
                self.navigationView.resumeButton.isHidden = true
                self.mapView.logoView.isHidden = false
            }
        }
    }

    var currentLegIndexMapped = 0
    var currentStepIndexMapped = 0
    var labelRoadNameCompletionHandler: LabelRoadNameCompletionHandler?
   
    /**
     A Boolean value that determines whether the map annotates the locations at which instructions are spoken for debugging purposes.
     */
    var annotatesSpokenInstructions = false

    var overheadInsets: UIEdgeInsets {
        UIEdgeInsets(top: self.navigationView.instructionsBannerView.bounds.height,
                     left: 20,
                     bottom: self.navigationView.bottomBannerView.bounds.height,
                     right: 20)
    }
    
    lazy var endOfRouteViewController: EndOfRouteViewController = {
        let storyboard = UIStoryboard(name: "Navigation", bundle: .mapboxNavigation)
        let viewController = storyboard.instantiateViewController(withIdentifier: "EndOfRouteViewController") as! EndOfRouteViewController
        return viewController
    }()

    weak var delegate: RouteMapViewControllerDelegate?
	
    // MARK: - Lifecycle
	
    convenience init(routeController: RouteController?, delegate: RouteMapViewControllerDelegate? = nil) {
        self.init()
        self.routeController = routeController
        self.delegate = delegate
        self.automaticallyAdjustsScrollViewInsets = false
    }

    deinit {
        self.suspendNotifications()
        self.removeTimer()
    }

    // MARK: - UIViewController
	
    override func loadView() {
        self.view = NavigationView(delegate: self)
        self.view.frame = self.parent?.view.bounds ?? UIScreen.main.bounds
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.mapView.contentInset = self.contentInsets
        self.view.layoutIfNeeded()

        self.mapView.tracksUserCourse = self.route != nil

        self.distanceFormatter.numberFormatter.locale = .nationalizedCurrent

        self.navigationView.overviewButton.addTarget(self, action: Actions.overview, for: .touchUpInside)
        self.navigationView.muteButton.addTarget(self, action: Actions.mute, for: .touchUpInside)
        self.navigationView.resumeButton.addTarget(self, action: Actions.recenter, for: .touchUpInside)
        self.resumeNotifications()
        self.notifyUserAboutLowVolume()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.prepareForNavigation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.prepareForMap()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.removeTimer()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.mapView.enableFrameByFrameCourseViewTracking(for: 3)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.mapView.setContentInset(self.contentInsets, animated: true, completionHandler: nil)
        self.mapView.setNeedsUpdateConstraints()
    }
	
    // MARK: - UIContentContainer
	
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        UIView.animate(withDuration: 0.3, animations: self.view.layoutIfNeeded)
    }

    // MARK: - RouteMapViewController
	
    func prepareForNavigation() {
        guard let routeController else { return }
		
        self.resetETATimer()
        self.navigationView.muteButton.isSelected = NavigationSettings.shared.voiceMuted
        self.mapView.compassView.isHidden = true
        self.mapView.tracksUserCourse = true

        if let camera = self.pendingCamera {
            self.mapView.camera = camera
            return
        }
		
        if let location = routeController.location,
           location.course > 0 {
            self.mapView.updateCourseTracking(location: location, animated: false)
        } else if let coordinates = routeController.routeProgress.currentLegProgress.currentStep.coordinates,
                  let firstCoordinate = coordinates.first,
                  coordinates.count > 1 {
            let secondCoordinate = coordinates[1]
            let course = firstCoordinate.direction(to: secondCoordinate)
            let newLocation = CLLocation(coordinate: routeController.location?.coordinate ?? firstCoordinate,
                                         altitude: 0,
                                         horizontalAccuracy: 0,
                                         verticalAccuracy: 0,
                                         course: course,
                                         speed: 0,
                                         timestamp: Date())
            self.mapView.updateCourseTracking(location: newLocation, animated: false)
        }
    }
	
    func prepareForMap() {
        self.annotatesSpokenInstructions = self.delegate?.mapViewControllerShouldAnnotateSpokenInstructions(self) ?? false
        self.showRouteIfNeeded()
        self.currentLegIndexMapped = self.routeController?.routeProgress.legIndex ?? 0
        self.currentStepIndexMapped = self.routeController?.routeProgress.currentLegProgress.stepIndex ?? 0
    }
	
    func notifyDidReroute(route: Route) {
        guard let routeController else {
            assertionFailure("routeController needs to be set before calling this method")
            return
        }
		
        self.updateETA()
        self.currentStepIndexMapped = 0
        self.instructionsBannerView.updateDistance(for: routeController.routeProgress.currentLegProgress.currentStepProgress)

        self.mapView.addArrow(route: routeController.routeProgress.route, legIndex: routeController.routeProgress.legIndex, stepIndex: routeController.routeProgress.currentLegProgress.stepIndex + 1)
        self.mapView.showRoutes([routeController.routeProgress.route], legIndex: routeController.routeProgress.legIndex)
        self.mapView.showWaypoints(routeController.routeProgress.route)

        if self.annotatesSpokenInstructions {
            self.mapView.showVoiceInstructionsOnMap(route: routeController.routeProgress.route)
        }

        if self.isInOverviewMode {
            if let coordinates = routeController.routeProgress.route.coordinates, let userLocation = routeController.locationManager.location?.coordinate {
                self.mapView.setOverheadCameraView(from: userLocation, along: coordinates, for: self.overheadInsets)
            }
        } else {
            self.mapView.tracksUserCourse = true
            self.navigationView.wayNameView.isHidden = true
        }

        self.stepsViewController?.dismiss {
            self.removePreviewInstructions()
            self.stepsViewController = nil
            self.navigationView.instructionsBannerView.stepListIndicatorView.isHidden = false
        }
    }

    func notifyUserAboutLowVolume() {
        guard !(self.routeController?.locationManager is SimulatedLocationManager) else { return }
        guard !NavigationSettings.shared.voiceMuted else { return }
        guard AVAudioSession.sharedInstance().outputVolume <= NavigationViewMinimumVolumeForWarning else { return }

        let title = String.localizedStringWithFormat(NSLocalizedString("DEVICE_VOLUME_LOW", bundle: .mapboxNavigation, value: "%@ Volume Low", comment: "Format string for indicating the device volume is low; 1 = device model"), UIDevice.current.model)
        self.statusView.show(title, showSpinner: false)
        self.statusView.hide(delay: 3, animated: true)
    }

    func updateMapOverlays(for routeProgress: RouteProgress) {
        guard let routeController else {
            assertionFailure("routeController needs to be set during navigation")
            return
        }
		
        if routeProgress.currentLegProgress.followOnStep != nil {
            self.mapView.addArrow(route: routeController.routeProgress.route,
                                  legIndex: routeController.routeProgress.legIndex,
                                  stepIndex: routeController.routeProgress.currentLegProgress.stepIndex + 1)
        } else {
            self.mapView.removeArrow()
        }
    }

    func updateCameraAltitude(for routeProgress: RouteProgress) {
        guard self.mapView.tracksUserCourse else { return } // only adjust when we are actively tracking user course

        let zoomOutAltitude = self.mapView.zoomedOutMotorwayAltitude
        let defaultAltitude = self.mapView.defaultAltitude
        let isLongRoad = routeProgress.distanceRemaining >= self.mapView.longManeuverDistance
        let currentStep = routeProgress.currentLegProgress.currentStep
        let upComingStep = routeProgress.currentLegProgress.upComingStep

        // If the user is at the last turn maneuver, the map should zoom in to the default altitude.
        let currentInstruction = routeProgress.currentLegProgress.currentStepProgress.currentSpokenInstruction

        // If the user is on a motorway, not exiting, and their segment is sufficently long, the map should zoom out to the motorway altitude.
        // otherwise, zoom in if it's the last instruction on the step.
        let currentStepIsMotorway = currentStep.isMotorway
        let nextStepIsMotorway = upComingStep?.isMotorway ?? false
        if currentStepIsMotorway, nextStepIsMotorway, isLongRoad {
            self.setCamera(altitude: zoomOutAltitude)
        } else if currentInstruction == currentStep.lastInstruction {
            self.setCamera(altitude: defaultAltitude)
        }
    }

    func notifyDidChange(routeProgress: RouteProgress, location: CLLocation, secondsRemaining: TimeInterval) {
        guard let routeController else {
            assertionFailure("routeController needs to be set during navigation")
            return
        }
		
        self.resetETATimer()
        self.updateETA()

        self.instructionsBannerView.updateDistance(for: routeProgress.currentLegProgress.currentStepProgress)

        if self.currentLegIndexMapped != routeProgress.legIndex {
            self.mapView.showWaypoints(routeProgress.route, legIndex: routeProgress.legIndex)
            self.mapView.showRoutes([routeProgress.route], legIndex: routeProgress.legIndex)

            self.currentLegIndexMapped = routeProgress.legIndex
        }

        if self.currentStepIndexMapped != routeProgress.currentLegProgress.stepIndex {
            self.updateMapOverlays(for: routeProgress)
            self.currentStepIndexMapped = routeProgress.currentLegProgress.stepIndex
        }

        if self.annotatesSpokenInstructions {
            self.mapView.showVoiceInstructionsOnMap(route: routeController.routeProgress.route)
        }
    }

    /**
     Updates the current road name label to reflect the road on which the user is currently traveling.

     - parameter location: The user’s current location.
     */
    func labelCurrentRoad(at rawLocation: CLLocation, for snappedLoction: CLLocation? = nil) {
        guard self.navigationView.resumeButton.isHidden else {
            return
        }

        let roadName = self.delegate?.mapViewController(self, roadNameAt: rawLocation)
        guard roadName == nil else {
            if let roadName {
                self.navigationView.wayNameView.text = roadName
                self.navigationView.wayNameView.isHidden = roadName.isEmpty
            }
            return
        }

        let location = snappedLoction ?? rawLocation

        self.labelCurrentRoadFeature(at: location)

        if let labelRoadNameCompletionHandler {
            labelRoadNameCompletionHandler(true)
        }
    }

    func labelCurrentRoadFeature(at location: CLLocation) {
        guard let stepCoordinates = self.routeController?.routeProgress.currentLegProgress.currentStep.coordinates else {
            return
        }

        let closestCoordinate = location.coordinate
        let roadLabelLayerIdentifier = "roadLabelLayer"

        let userPuck = self.mapView.convert(closestCoordinate, toPointTo: self.mapView)
        let features = self.mapView.visibleFeatures(at: userPuck, styleLayerIdentifiers: Set([roadLabelLayerIdentifier]))
        var smallestLabelDistance = Double.infinity
        var currentName: String?
        var currentShieldName: NSAttributedString?

        for feature in features {
            var allLines: [MLNPolyline] = []

            if let line = feature as? MLNPolylineFeature {
                allLines.append(line)
            } else if let lines = feature as? MLNMultiPolylineFeature {
                allLines = lines.polylines
            }

            for line in allLines {
                let featureCoordinates = Array(UnsafeBufferPointer(start: line.coordinates, count: Int(line.pointCount)))
                let featurePolyline = Polyline(featureCoordinates)
                let slicedLine = Polyline(stepCoordinates).sliced(from: closestCoordinate)

                let lookAheadDistance: CLLocationDistance = 10
                guard let pointAheadFeature = featurePolyline.sliced(from: closestCoordinate).coordinateFromStart(distance: lookAheadDistance) else { continue }
                guard let pointAheadUser = slicedLine.coordinateFromStart(distance: lookAheadDistance) else { continue }
                guard let reversedPoint = Polyline(featureCoordinates.reversed()).sliced(from: closestCoordinate).coordinateFromStart(distance: lookAheadDistance) else { continue }

                let distanceBetweenPointsAhead = pointAheadFeature.distance(to: pointAheadUser)
                let distanceBetweenReversedPoint = reversedPoint.distance(to: pointAheadUser)
                let minDistanceBetweenPoints = min(distanceBetweenPointsAhead, distanceBetweenReversedPoint)

                if minDistanceBetweenPoints < smallestLabelDistance {
                    smallestLabelDistance = minDistanceBetweenPoints

                    if let line = feature as? MLNPolylineFeature {
                        let roadNameRecord = self.roadFeature(for: line)
                        currentShieldName = roadNameRecord.shieldName
                        currentName = roadNameRecord.roadName
                    } else if let line = feature as? MLNMultiPolylineFeature {
                        let roadNameRecord = self.roadFeature(for: line)
                        currentShieldName = roadNameRecord.shieldName
                        currentName = roadNameRecord.roadName
                    }
                }
            }
        }

        let hasWayName = currentName != nil || currentShieldName != nil
        if smallestLabelDistance < 5, hasWayName {
            if let currentShieldName {
                self.navigationView.wayNameView.attributedText = currentShieldName
            } else if let currentName {
                self.navigationView.wayNameView.text = currentName
            }
            self.navigationView.wayNameView.isHidden = false
        } else {
            self.navigationView.wayNameView.isHidden = true
        }
    }
	
    // MARK: End Of Route
	
    func transitionToEndNavigation(with duration: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        self.view.layoutIfNeeded() // flush layout queue
        NSLayoutConstraint.deactivate(self.navigationView.bannerShowConstraints)
        NSLayoutConstraint.activate(self.navigationView.bannerHideConstraints)

        self.mapView.enableFrameByFrameCourseViewTracking(for: duration)
        self.mapView.setNeedsUpdateConstraints()

        let animate = {
            self.view.layoutIfNeeded()
            self.navigationView.floatingStackView.alpha = 0.0
        }

        let noAnimation = { animate(); completion?(true) }

        guard duration > 0.0 else { return noAnimation() }

        self.navigationView.mapView.tracksUserCourse = false
        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveLinear], animations: animate, completion: completion)
    }

    func hideEndOfRoute(duration: TimeInterval = 0.3, completion: ((Bool) -> Void)? = nil) {
        self.view.layoutIfNeeded() // flush layout queue
        self.view.clipsToBounds = true

        self.mapView.enableFrameByFrameCourseViewTracking(for: duration)
        self.mapView.setNeedsUpdateConstraints()

        let animate = {
            self.view.layoutIfNeeded()
            self.navigationView.floatingStackView.alpha = 1.0
        }

        let noAnimation = {
            animate()
            completion?(true)
        }

        guard duration > 0.0 else { return noAnimation() }
		
        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveLinear], animations: animate, completion: completion)
    }
}

// MARK: - NavigationViewDelegate

extension RouteMapViewController: NavigationViewDelegate {
    // MARK: NavigationViewDelegate

    func navigationView(_ view: NavigationView, didTapCancelButton: CancelButton) {
        self.delegate?.mapViewControllerDidFinish(self, byCanceling: true)
    }

    // MARK: MLNMapViewDelegate

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        var userTrackingMode = mapView.userTrackingMode
        if let mapView = mapView as? NavigationMapView, mapView.tracksUserCourse {
            userTrackingMode = .followWithCourse
        }
        if userTrackingMode == .none, !self.isInOverviewMode {
            self.navigationView.wayNameView.isHidden = true
        }
    }

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        // This method is called before the view is added to a window
        // (if the style is cached) preventing UIAppearance to apply the style.
        self.showRouteIfNeeded()
        self.mapView.localizeLabels()
        self.delegate?.mapView?(mapView, didFinishLoading: style)
    }

    func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
        self.delegate?.mapViewDidFinishLoadingMap?(mapView)
    }

    // MARK: - VisualInstructionDelegate
	
    func label(_ label: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString? {
        self.delegate?.label?(label, willPresent: instruction, as: presented)
    }

    // MARK: NavigationMapViewCourseTrackingDelegate

    func navigationMapViewDidStartTrackingCourse(_ mapView: NavigationMapView) {
        // Important, this look redundant but it needed.
        // In NavigationView.showUI(animated:) we animate using alpha and then set isHidden
        // To keep this in sync we also need to adjust alpha here as well.
        self.navigationView.resumeButton.isHidden = true
        self.navigationView.resumeButton.alpha = 0
        mapView.logoView.isHidden = false
    }

    func navigationMapViewDidStopTrackingCourse(_ mapView: NavigationMapView) {
        // Important, this look redundant but it needed.
        // In NavigationView.hideUI(animated:) we animate using alpha and then set isHidden
        // To keep this in sync we also need to adjust alpha here as well.
        self.navigationView.resumeButton.isHidden = false
        self.navigationView.resumeButton.alpha = 1
        self.navigationView.wayNameView.isHidden = true
        mapView.logoView.isHidden = true
    }

    // MARK: InstructionsBannerViewDelegate

    func didDragInstructionsBanner(_ sender: BaseInstructionsBannerView) {
        self.displayPreviewInstructions()
    }

    func didTapInstructionsBanner(_ sender: BaseInstructionsBannerView) {
        self.displayPreviewInstructions()
    }

    // MARK: NavigationMapViewDelegate

    func navigationMapView(_ mapView: NavigationMapView, routeStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationMapView?(mapView, routeStyleLayerWithIdentifier: identifier, source: source)
    }

    func navigationMapView(_ mapView: NavigationMapView, routeCasingStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationMapView?(mapView, routeCasingStyleLayerWithIdentifier: identifier, source: source)
    }

    func navigationMapView(_ mapView: NavigationMapView, waypointStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationMapView?(mapView, waypointStyleLayerWithIdentifier: identifier, source: source)
    }

    func navigationMapView(_ mapView: NavigationMapView, waypointSymbolStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationMapView?(mapView, waypointSymbolStyleLayerWithIdentifier: identifier, source: source)
    }

    func navigationMapView(_ mapView: NavigationMapView, shapeFor waypoints: [Waypoint], legIndex: Int) -> MLNShape? {
        self.delegate?.navigationMapView?(mapView, shapeFor: waypoints, legIndex: legIndex)
    }

    func navigationMapView(_ mapView: NavigationMapView, shapeFor routes: [Route]) -> MLNShape? {
        self.delegate?.navigationMapView?(mapView, shapeFor: routes)
    }

    func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        self.delegate?.navigationMapView?(mapView, didSelect: route)
    }

    func navigationMapView(_ mapView: NavigationMapView, simplifiedShapeFor route: Route) -> MLNShape? {
        self.delegate?.navigationMapView?(mapView, simplifiedShapeFor: route)
    }

    func navigationMapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage? {
        self.delegate?.navigationMapView?(mapView, imageFor: annotation)
    }

    func navigationMapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        self.delegate?.navigationMapView?(mapView, viewFor: annotation)
    }

    func navigationMapViewUserAnchorPoint(_ mapView: NavigationMapView) -> CGPoint {
        self.delegate?.navigationMapViewUserAnchorPoint?(mapView) ?? .zero
    }
}

// MARK: StepsViewControllerDelegate

extension RouteMapViewController: StepsViewControllerDelegate {
    func stepsViewController(_ viewController: StepsViewController, didSelect legIndex: Int, stepIndex: Int, cell: StepTableViewCell) {
        guard let routeController else {
            assertionFailure("routeController is needed during navigation")
            return
        }
		
        let legProgress = RouteLegProgress(leg: routeController.routeProgress.route.legs[legIndex], stepIndex: stepIndex)
        let step = legProgress.currentStep
        guard let upcomingStep = legProgress.upComingStep else { return }

        viewController.dismiss {
            self.addPreviewInstructions(step: step, maneuverStep: upcomingStep, distance: cell.instructionsView.distance)
            self.stepsViewController = nil
        }

        self.mapView.enableFrameByFrameCourseViewTracking(for: 1)
        self.mapView.tracksUserCourse = false
        self.mapView.setCenter(upcomingStep.maneuverLocation, zoomLevel: self.mapView.zoomLevel, direction: upcomingStep.initialHeading!, animated: true, completionHandler: nil)

        guard isViewLoaded, view.window != nil else { return }
        self.mapView.addArrow(route: routeController.routeProgress.route, legIndex: legIndex, stepIndex: stepIndex + 1)
    }

    func addPreviewInstructions(step: RouteStep, maneuverStep: RouteStep, distance: CLLocationDistance?) {
        self.removePreviewInstructions()

        guard let instructions = step.instructionsDisplayedAlongStep?.last else { return }

        let instructionsView = StepInstructionsView(frame: navigationView.instructionsBannerView.frame)
        instructionsView.backgroundColor = StepInstructionsView.appearance().backgroundColor
        instructionsView.delegate = self
        instructionsView.distance = distance

        self.navigationView.instructionsBannerContentView.backgroundColor = instructionsView.backgroundColor

        view.addSubview(instructionsView)
        instructionsView.update(for: instructions)
        self.previewInstructionsView = instructionsView
    }

    func didDismissStepsViewController(_ viewController: StepsViewController) {
        viewController.dismiss {
            self.stepsViewController = nil
            self.navigationView.instructionsBannerView.stepListIndicatorView.isHidden = false
        }
    }

    func statusView(_ statusView: StatusView, valueChangedTo value: Double) {
        let displayValue = 1 + min(Int(9 * value), 8)
        let title = String.Localized.simulationStatus(speed: displayValue)
        self.showStatus(title: title, for: .infinity, interactive: true)

        if let locationManager = self.routeController?.locationManager as? SimulatedLocationManager {
            locationManager.speedMultiplier = Double(displayValue)
        }
    }
}

private extension RouteMapViewController {
    @objc
    func recenter(_ sender: AnyObject) {
        self.mapView.tracksUserCourse = true
        self.mapView.enableFrameByFrameCourseViewTracking(for: 3)
        self.isInOverviewMode = false
        guard let routeController else { return }
		
        self.updateCameraAltitude(for: routeController.routeProgress)

        self.mapView.addArrow(route: routeController.routeProgress.route,
                              legIndex: routeController.routeProgress.legIndex,
                              stepIndex: routeController.routeProgress.currentLegProgress.stepIndex + 1)

        self.removePreviewInstructions()
    }

    @objc
    func removeTimer() {
        self.updateETATimer?.invalidate()
        self.updateETATimer = nil
    }
	
    @objc
    func toggleOverview(_ sender: Any) {
        self.mapView.enableFrameByFrameCourseViewTracking(for: 3)
        if let coordinates = self.routeController?.routeProgress.route.coordinates,
           let userLocation = self.routeController?.locationManager.location?.coordinate {
            self.mapView.setOverheadCameraView(from: userLocation, along: coordinates, for: self.overheadInsets)
        }
        self.isInOverviewMode = true
    }

    @objc
    func toggleMute(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected

        let muted = sender.isSelected
        NavigationSettings.shared.voiceMuted = muted
    }
	
    @objc
    func applicationWillEnterForeground(notification: NSNotification) {
        self.mapView.updateCourseTracking(location: self.routeController?.location, animated: false)
        self.resetETATimer()
    }

    @objc
    func willReroute(notification: NSNotification) {
        let title = NSLocalizedString("REROUTING", bundle: .mapboxNavigation, value: "Rerouting…", comment: "Indicates that rerouting is in progress")
        self.lanesView.hide()
        self.statusView.show(title, showSpinner: true)
    }

    @objc
    func rerouteDidFail(notification: NSNotification) {
        self.statusView.hide()
    }
	
    @objc
    func didReroute(notification: NSNotification) {
        guard isViewLoaded else { return }

        if let locationManager = self.routeController?.locationManager as? SimulatedLocationManager {
            let localized = String.Localized.simulationStatus(speed: Int(locationManager.speedMultiplier))
            self.showStatus(title: localized, for: .infinity, interactive: true)
        } else {
            self.statusView.hide(delay: 2, animated: true)
        }

        if notification.userInfo![RouteControllerNotificationUserInfoKey.isProactiveKey] as! Bool {
            let title = NSLocalizedString("FASTER_ROUTE_FOUND", bundle: .mapboxNavigation, value: "Faster Route Found", comment: "Indicates a faster route was found")
            self.showStatus(title: title, withSpinner: true, for: 3)
        }
    }

    @objc
    func updateInstructionsBanner(notification: NSNotification) {
        guard let routeProgress = notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress else { return }
        self.instructionsBannerView.update(for: routeProgress.currentLegProgress.currentStepProgress.currentVisualInstruction)
        self.lanesView.update(for: routeProgress.currentLegProgress.currentStepProgress.currentVisualInstruction)
        self.nextBannerView.update(for: routeProgress.currentLegProgress.currentStepProgress.currentVisualInstruction)
    }
	
    @objc
    func updateETA() {
        guard isViewLoaded, let routeController else { return }
		
        self.navigationView.bottomBannerView.updateETA(routeProgress: routeController.routeProgress)
    }
	
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.willReroute(notification:)), name: .routeControllerWillReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didReroute(notification:)), name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.rerouteDidFail(notification:)), name: .routeControllerDidFailToReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillEnterForeground(notification:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.removeTimer), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInstructionsBanner(notification:)), name: .routeControllerDidPassVisualInstructionPoint, object: self.routeController)
    }

    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerWillReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidFailToReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassVisualInstructionPoint, object: nil)
    }

    func showStatus(title: String, withSpinner spin: Bool = false, for time: TimeInterval, animated: Bool = true, interactive: Bool = false) {
        self.statusView.show(title, showSpinner: spin, interactive: interactive)
        guard time < .infinity else { return }
        self.statusView.hide(delay: time, animated: animated)
    }

    func setCamera(altitude: Double) {
        guard self.mapView.altitude != altitude else { return }
        self.mapView.altitude = altitude
    }

    func populateName(for waypoint: Waypoint, populated: @escaping (Waypoint) -> Void) {
        guard waypoint.name == nil else { return populated(waypoint) }
        CLGeocoder().reverseGeocodeLocation(waypoint.location) { places, error in
            guard let place = places?.first, let placeName = place.name, error == nil else { return }
            let named = Waypoint(coordinate: waypoint.coordinate, name: placeName)
            return populated(named)
        }
    }
	
    func removePreviewInstructions() {
        if let view = previewInstructionsView {
            view.removeFromSuperview()
            self.navigationView.instructionsBannerContentView.backgroundColor = InstructionsBannerView.appearance().backgroundColor
            self.navigationView.instructionsBannerView.delegate = self
            self.previewInstructionsView = nil
        }
    }
	
    func displayPreviewInstructions() {
        self.removePreviewInstructions()

        if let controller = stepsViewController {
            self.stepsViewController = nil
            controller.dismiss()
        } else if let routeController {
            let controller = StepsViewController(routeProgress: routeController.routeProgress)
            controller.delegate = self
            addChild(controller)
            view.insertSubview(controller.view, belowSubview: self.navigationView.instructionsBannerContentView)

            controller.view.topAnchor.constraint(equalTo: self.navigationView.instructionsBannerContentView.bottomAnchor).isActive = true
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

            controller.didMove(toParent: self)
            controller.dropDownAnimation()

            self.stepsViewController = controller
            return
        }
    }
	
    func roadFeature(for line: MLNPolylineFeature) -> (roadName: String?, shieldName: NSAttributedString?) {
        let roadNameRecord = self.roadFeatureHelper(ref: line.attribute(forKey: "ref"),
                                                    shield: line.attribute(forKey: "shield"),
                                                    reflen: line.attribute(forKey: "reflen"),
                                                    name: line.attribute(forKey: "name"))

        return (roadName: roadNameRecord.roadName, shieldName: roadNameRecord.shieldName)
    }

    func roadFeature(for line: MLNMultiPolylineFeature) -> (roadName: String?, shieldName: NSAttributedString?) {
        let roadNameRecord = self.roadFeatureHelper(ref: line.attribute(forKey: "ref"),
                                                    shield: line.attribute(forKey: "shield"),
                                                    reflen: line.attribute(forKey: "reflen"),
                                                    name: line.attribute(forKey: "name"))

        return (roadName: roadNameRecord.roadName, shieldName: roadNameRecord.shieldName)
    }

    func roadFeatureHelper(ref: Any?, shield: Any?, reflen: Any?, name: Any?) -> (roadName: String?, shieldName: NSAttributedString?) {
        var currentShieldName: NSAttributedString?, currentRoadName: String?

        if let text = ref as? String, let shieldID = shield as? String, let reflenDigit = reflen as? Int {
            currentShieldName = self.roadShieldName(for: text, shield: shieldID, reflen: reflenDigit)
        }

        if let roadName = name as? String {
            currentRoadName = roadName
        }

        if let compositeShieldImage = currentShieldName, let roadName = currentRoadName {
            let compositeShield = NSMutableAttributedString(string: " \(roadName)")
            compositeShield.insert(compositeShieldImage, at: 0)
            currentShieldName = compositeShield
        }

        return (roadName: currentRoadName, shieldName: currentShieldName)
    }

    func roadShieldName(for text: String?, shield: String?, reflen: Int?) -> NSAttributedString? {
        guard let text, let shield, let reflen else { return nil }

        let currentShield = HighwayShield.RoadType(rawValue: shield)
        let textColor = currentShield?.textColor ?? .black
        let imageName = "\(shield)-\(reflen)"

        guard let image = mapView.style?.image(forName: imageName) else {
            return nil
        }

        let attachment = RoadNameLabelAttachment(image: image, text: text, color: textColor, font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize), scale: UIScreen.main.scale)
        return NSAttributedString(attachment: attachment)
    }

    func resetETATimer() {
        self.removeTimer()
        self.updateETATimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.updateETA), userInfo: nil, repeats: true)
    }

    func showRouteIfNeeded() {
        guard self.isViewLoaded, self.view.window != nil else { return }
        guard !self.mapView.showsRoute else { return }
        guard let routeController else { return }
		
        self.mapView.showRoutes([routeController.routeProgress.route], legIndex: routeController.routeProgress.legIndex)
        self.mapView.showWaypoints(routeController.routeProgress.route, legIndex: routeController.routeProgress.legIndex)

        if routeController.routeProgress.currentLegProgress.stepIndex + 1 <= routeController.routeProgress.currentLegProgress.leg.steps.count {
            self.mapView.addArrow(route: routeController.routeProgress.route, legIndex: routeController.routeProgress.legIndex, stepIndex: routeController.routeProgress.currentLegProgress.stepIndex + 1)
        }

        if self.annotatesSpokenInstructions {
            self.mapView.showVoiceInstructionsOnMap(route: routeController.routeProgress.route)
        }
    }
}
