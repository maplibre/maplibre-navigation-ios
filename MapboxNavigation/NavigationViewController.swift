import MapboxCoreNavigation
import MapboxDirections
import MapLibre
import UIKit
#if canImport(CarPlay)
import CarPlay
#endif

/**
 The `NavigationViewControllerDelegate` protocol provides methods for configuring the map view shown by a `NavigationViewController` and responding to the cancellation of a navigation session.
 */
@objc(MBNavigationViewControllerDelegate)
public protocol NavigationViewControllerDelegate: VisualInstructionDelegate {
    /**
     Called when user arrived at the destination of the trip.
	 
     - parameter navigationViewController: The navigation view controller that finished navigation.
     */
    @objc optional func navigationViewControllerDidFinishRouting(_ navigationViewController: NavigationViewController)
	
    /**
     Called when the underlaying mapView finished loading the style.
	 
     - parameter navigationViewController: The navigation view controller that finished navigation.
     - parameter style: The applied style
     */
    @objc optional func navigationViewController(_ navigationViewController: NavigationViewController, didFinishLoading style: MLNStyle)

    /**
     Called when the user arrives at the destination waypoint for a route leg.
     
     This method is called when the navigation view controller arrives at the waypoint. You can implement this method to prevent the navigation view controller from automatically advancing to the next leg. For example, you can and show an interstitial sheet upon arrival and pause navigation by returning `false`, then continue the route when the user dismisses the sheet. If this method is unimplemented, the navigation view controller automatically advances to the next leg when arriving at a waypoint.
     
     - postcondition: If you return `false` within this method, you must manually advance to the next leg: obtain the value of the `routeController` and its `RouteController.routeProgress` property, then increment the `RouteProgress.legIndex` property.
     - parameter navigationViewController: The navigation view controller that has arrived at a waypoint.
     - parameter waypoint: The waypoint that the user has arrived at.
     - returns: True to automatically advance to the next leg, or false to remain on the now completed leg.
     */
    @objc(navigationViewController:didArriveAtWaypoint:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool

    /**
      Returns whether the navigation view controller should be allowed to calculate a new route.
     
      If implemented, this method is called as soon as the navigation view controller detects that the user is off the predetermined route. Implement this method to conditionally prevent rerouting. If this method returns `true`, `navigationViewController(_:willRerouteFrom:)` will be called immediately afterwards.
     
      - parameter navigationViewController: The navigation view controller that has detected the need to calculate a new route.
      - parameter location: The user’s current location.
      - returns: True to allow the navigation view controller to calculate a new route; false to keep tracking the current route.
     */
    @objc(navigationViewController:shouldRerouteFromLocation:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, shouldRerouteFrom location: CLLocation) -> Bool
    
    /**
     Called immediately before the navigation view controller calculates a new route.
     
     This method is called after `navigationViewController(_:shouldRerouteFrom:)` is called, simultaneously with the `RouteControllerWillReroute` notification being posted, and before `navigationViewController(_:didRerouteAlong:)` is called.
     
     - parameter navigationViewController: The navigation view controller that will calculate a new route.
     - parameter location: The user’s current location.
     */
    @objc(navigationViewController:willRerouteFromLocation:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, willRerouteFrom location: CLLocation)
    
    /**
     Called immediately after the navigation view controller receives a new route.
     
     This method is called after `navigationViewController(_:willRerouteFrom:)` and simultaneously with the `RouteControllerDidReroute` notification being posted.
     
     - parameter navigationViewController: The navigation view controller that has calculated a new route.
     - parameter route: The new route.
     */
    @objc(navigationViewController:didRerouteAlongRoute:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, didRerouteAlong route: Route)
    
    /**
     Called when the navigation view controller fails to receive a new route.
     
     This method is called after `navigationViewController(_:willRerouteFrom:)` and simultaneously with the `RouteControllerDidFailToReroute` notification being posted.
     
     - parameter navigationViewController: The navigation view controller that has calculated a new route.
     - parameter error: An error raised during the process of obtaining a new route.
     */
    @objc(navigationViewController:didFailToRerouteWithError:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, didFailToRerouteWith error: Error)
    
    /**
     Returns an `MLNStyleLayer` that determines the appearance of the route line.
     
     If this method is unimplemented, the navigation view controller’s map view draws the route line using an `MLNLineStyleLayer`.
     */
    @objc optional func navigationViewController(_ navigationViewController: NavigationViewController, routeStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /**
     Returns an `MLNStyleLayer` that determines the appearance of the route line’s casing.
     
     If this method is unimplemented, the navigation view controller’s map view draws the route line’s casing using an `MLNLineStyleLayer` whose width is greater than that of the style layer returned by `navigationViewController(_:routeStyleLayerWithIdentifier:source:)`.
     */
    @objc optional func navigationViewController(_ navigationViewController: NavigationViewController, routeCasingStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /**
     Returns an `MLNShape` that represents the path of the route line.
     
     If this method is unimplemented, the navigation view controller’s map view represents the route line using an `MLNPolylineFeature` based on `route`’s `coordinates` property.
     */
    @objc(navigationViewController:shapeForRoutes:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, shapeFor routes: [Route]) -> MLNShape?
    
    /**
     Returns an `MLNShape` that represents the path of the route line’s casing.
     
     If this method is unimplemented, the navigation view controller’s map view represents the route line’s casing using an `MLNPolylineFeature` identical to the one returned by `navigationViewController(_:shapeFor:)`.
     */
    @objc(navigationViewController:simplifiedShapeForRoute:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, simplifiedShapeFor route: Route) -> MLNShape?
    
    /*
     Returns an `MLNStyleLayer` that marks the location of each destination along the route when there are multiple destinations. The returned layer is added to the map below the layer returned by `navigationViewController(_:waypointSymbolStyleLayerWithIdentifier:source:)`.
     
     If this method is unimplemented, the navigation view controller’s map view marks each destination waypoint with a circle.
     */
    @objc optional func navigationViewController(_ navigationViewController: NavigationViewController, waypointStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /*
     Returns an `MLNStyleLayer` that places an identifying symbol on each destination along the route when there are multiple destinations. The returned layer is added to the map above the layer returned by `navigationViewController(_:waypointStyleLayerWithIdentifier:source:)`.
     
     If this method is unimplemented, the navigation view controller’s map view labels each destination waypoint with a number, starting with 1 at the first destination, 2 at the second destination, and so on.
     */
    @objc optional func navigationViewController(_ navigationViewController: NavigationViewController, waypointSymbolStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /**
     Returns an `MLNShape` that represents the destination waypoints along the route (that is, excluding the origin).
     
     If this method is unimplemented, the navigation map view represents the route waypoints using `navigationViewController(_:shapeFor:legIndex:)`.
     */
    @objc(navigationViewController:shapeForWaypoints:legIndex:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, shapeFor waypoints: [Waypoint], legIndex: Int) -> MLNShape?
    
    /**
     Called when the user taps to select a route on the navigation view controller’s map view.
     - parameter navigationViewController: The navigation view controller presenting the route that the user selected.
     - parameter route: The route on the map that the user selected.
     */
    @objc(navigationViewController:didSelectRoute:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, didSelect route: Route)
	
    /**
     Called when the user taps to select an annotation on the navigation view controller’s map view.
     - parameter navigationViewController: The navigation view controller presenting the route that the user selected.
     - parameter annotation: The annotation on the map that the user selected.
     */
    @objc optional func navigationViewController(_ navigationViewController: NavigationViewController, didSelect annotation: MLNAnnotation)
    
    /**
     Return an `MLNAnnotationImage` that represents the destination marker.
     
     If this method is unimplemented, the navigation view controller’s map view will represent the destination annotation with the default marker.
     */
    @objc(navigationViewController:imageForAnnotation:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage?
    
    /**
     Returns a view object to mark the given point annotation object on the map.
     
     The user location annotation view can also be customized via this method. When annotation is an instance of `MLNUserLocation`, return an instance of `MLNUserLocationAnnotationView` (or a subclass thereof). Note that when `NavigationMapView.tracksUserCourse` is set to `true`, the navigation view controller’s map view uses a distinct user course view; to customize it, set the `NavigationMapView.userCourseView` property of the map view stored by the `NavigationViewController.mapView` property.
     */
    @objc(navigationViewController:viewForAnnotation:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, viewFor annotation: MLNAnnotation) -> MLNAnnotationView?
    
    /**
     Returns the center point of the user course view in screen coordinates relative to the map view.
     */
    @objc optional func navigationViewController(_ navigationViewController: NavigationViewController, mapViewUserAnchorPoint mapView: NavigationMapView) -> CGPoint
    
    /**
     Allows the delegate to decide whether to ignore a location update.
     
     This method is called on every location update. By default, the navigation view controller ignores certain location updates that appear to be unreliable, as determined by the `CLLocation.isQualified` property.
     
     - parameter navigationViewController: The navigation view controller that discarded the location.
     - parameter location: The location that will be discarded.
     - returns: If `true`, the location is discarded and the `NavigationViewController` will not consider it. If `false`, the location will not be thrown out.
     */
    @objc(navigationViewController:shouldDiscardLocation:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, shouldDiscard location: CLLocation) -> Bool
    
    /**
     Called to allow the delegate to customize the contents of the road name label that is displayed towards the bottom of the map view.
     
     This method is called on each location update. By default, the label displays the name of the road the user is currently traveling on.
     
     - parameter navigationViewController: The navigation view controller that will display the road name.
     - parameter location: The user’s current location.
     - returns: The road name to display in the label, or nil to hide the label.
     */
    @objc(navigationViewController:roadNameAtLocation:)
    optional func navigationViewController(_ navigationViewController: NavigationViewController, roadNameAt location: CLLocation) -> String?
}

/**
 `NavigationViewController` is a fully-featured turn-by-turn navigation UI.
 
 It provides step by step instructions, an overview of all steps for the given route and support for basic styling.
 
 - seealso: CarPlayNavigationViewController
 */
@objcMembers
@objc(MBNavigationViewController)
open class NavigationViewController: UIViewController {
    private var locationManager: NavigationLocationManager
	
    var mapViewController: RouteMapViewController
    var styleManager: StyleManager!
	
    var currentStatusBarStyle: UIStatusBarStyle = .default {
        didSet {
            guard oldValue != self.currentStatusBarStyle else { return }

            self.mapViewController.instructionsBannerView.backgroundColor = InstructionsBannerView.appearance().backgroundColor
            self.mapViewController.instructionsBannerContentView.backgroundColor = InstructionsBannerContentView.appearance().backgroundColor
        }
    }
	
    // MARK: - Properties
	
    /**
     A `Route` object constructed by [MapboxDirections](https://mapbox.github.io/mapbox-navigation-ios/directions/).
     
     In cases where you need to update the route after navigation has started you can set a new `route` here and `NavigationViewController` will update its UI accordingly.
     */
    public var route: Route? {
        didSet {
            guard oldValue != self.route else { return }
			
            if let route {
                if self.routeController == nil {
                    let routeController = RouteController(along: route, directions: self.directions, locationManager: self.locationManager)
                    routeController.delegate = self
                    self.routeController = routeController
                } else {
                    self.routeController?.routeProgress = RouteProgress(route: route)
                }
                NavigationSettings.shared.distanceUnit = route.routeOptions.locale.usesMetric ? .kilometer : .mile
                self.mapViewController.notifyDidReroute(route: route)
            } else {
                self.routeController = nil
            }
        }
    }
    
    /**
     An instance of `Directions` need for rerouting. See [Mapbox Directions](https://mapbox.github.io/mapbox-navigation-ios/directions/) for further information.
     */
    public var directions: Directions
    
    /**
     An optional `MLNMapCamera` you can use to improve the initial transition from a previous viewport and prevent a trigger from an excessive significant location update.
     */
    public var pendingCamera: MLNMapCamera?
    
    /**
     An instance of `MLNAnnotation` representing the origin of your route.
     */
    public var origin: MLNAnnotation?

    /**
     Shows End of route Feedback UI when the route controller arrives at the final destination. Defaults to `true.`
     */
    public var showsEndOfRouteFeedback: Bool = true

    /**
     The receiver’s delegate.
     */
    public weak var delegate: NavigationViewControllerDelegate?
    
    /**
     Provides access to various speech synthesizer options.
     
     See `RouteVoiceController` for more information.
     */
    public var voiceController: RouteVoiceController?
    
    /**
     Provides all routing logic for the user.

     See `RouteController` for more information.
     */
    public var routeController: RouteController? {
        didSet {
            guard oldValue != self.routeController else { return }
			
            self.mapViewController.routeController = self.routeController
        }
    }
    
    /**
     The main map view displayed inside the view controller.
     
     - note: Do not change this map view’s delegate.
     */
    public var mapView: NavigationMapView {
        self.mapViewController.mapView
    }
    
    /**
     Determines whether the user location annotation is moved from the raw user location reported by the device to the nearest location along the route.
     
     By default, this property is set to `true`, causing the user location annotation to be snapped to the route.
     */
    public var snapsUserLocationAnnotationToRoute = true
    
    /**
     Toggles sending of UILocalNotification upon upcoming steps when application is in the background. Defaults to `true`.
     */
    public var sendsNotifications: Bool = true
    
    /**
     If true, the map style and UI will automatically be updated given the time of day.
     */
    public var automaticallyAdjustsStyleForTimeOfDay = true {
        didSet {
            guard oldValue != self.automaticallyAdjustsStyleForTimeOfDay else { return }
			
            self.styleManager.automaticallyAdjustsStyleForTimeOfDay = self.automaticallyAdjustsStyleForTimeOfDay
        }
    }

    /**
     If `true`, `UIApplication.isIdleTimerDisabled` is set to `true` while a navigation is running. If your application manages the idle timer itself, set this property to `false`.
     */
    public var shouldManageApplicationIdleTimer = true
    
    /**
     Bool which should be set to true if a CarPlayNavigationView is also being used.
     */
    public var isUsedInConjunctionWithCarPlayWindow: Bool {
        get {
            self.mapViewController.isUsedInConjunctionWithCarPlayWindow
        }
        set {
            self.mapViewController.isUsedInConjunctionWithCarPlayWindow = newValue
        }
    }
    
    /**
     A Boolean value that determines whether the map annotates the locations at which instructions are spoken for debugging purposes.
     */
    public var annotatesSpokenInstructions = false
    
    // MARK: - Lifecycle
	
    /// Initializes a `NavigationViewController` that displays a map with a given style.
    /// - Parameters:
    ///   - dayStyleURL: URL for the style rules used to render the map during daylight hours.
    ///   - nightStyleURL: URL for the style rules used to render the map during nighttime hours. If nil, `dayStyleURL` will be used at night as well.
    ///   - directions: Used when recomputing a new route, for example if the user takes a wrong turn and needs re-routing. If unspecified, a default will be used.
    ///   - voiceController: Produces voice instructions for route navigation. If nil, a default will be used.
    @objc(initWithDayStyleURL:nightStyleURL:directions:voiceController:)
    public convenience init(dayStyleURL: URL,
                            nightStyleURL: URL? = nil,
                            directions: Directions = .shared,
                            voiceController: RouteVoiceController = RouteVoiceController()) {
        let dayStyle = DayStyle(mapStyleURL: dayStyleURL)
        let nightStyle = NightStyle(mapStyleURL: nightStyleURL ?? dayStyleURL)
        self.init(dayStyle: dayStyle, nightStyle: nightStyle, directions: directions, voiceController: voiceController)
    }

    /// Initializes a `NavigationViewController` that displays a map with a given style.
    /// - Parameters:
    ///   - dayStyle: Style used to render the map during daylight hours.
    ///   - nightStyle: Style used to render the map during nighttime hours. If nil, `dayStyle` will be used at night as well.
    ///   - directions: Used when recomputing a new route, for example if the user takes a wrong turn and needs re-routing. If unspecified, a default will be used.
    ///   - voiceController: Produces voice instructions for route navigation. If nil, a default will be used.
    @objc(initWithDayStyle:nightStyle:directions:voiceController:)
    public required init(dayStyle: Style,
                         nightStyle: Style? = nil,
                         directions: Directions = Directions.shared,
                         voiceController: RouteVoiceController = RouteVoiceController()) {
        let nightStyle = {
            if let nightStyle {
                return nightStyle
            }
			
            let dayCopy: Style = dayStyle.copy() as! Style
            dayCopy.styleType = .night
            return dayCopy
        }()
        assert(dayStyle.styleType == .day)
        assert(nightStyle.styleType == .night)
        
        self.directions = directions
        self.voiceController = voiceController
        self.mapViewController = RouteMapViewController(routeController: self.routeController)
        self.locationManager = NavigationLocationManager()
		
        super.init(nibName: nil, bundle: nil)
		
        self.mapViewController.delegate = self
        self.mapViewController.willMove(toParent: self)
        self.addChild(self.mapViewController)
        self.mapViewController.didMove(toParent: self)
        let mapSubview: UIView = self.mapViewController.view
        mapSubview.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(mapSubview)
        mapSubview.pinInSuperview()
        
        self.styleManager = StyleManager(self)
        self.styleManager.styles = [dayStyle, nightStyle]
        
        self.mapViewController.navigationView.hideUI(animated: false)
        self.mapView.tracksUserCourse = false
    }
	
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
	
    deinit {
        self.suspendNotifications()
    }
    
    // MARK: - UIViewController
	
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        self.currentStatusBarStyle
    }
	
    override open func viewDidLoad() {
        super.viewDidLoad()

        self.resumeNotifications()
        self.view.clipsToBounds = true
    }
    
    // MARK: - NavigationViewController
	
    public func startNavigation(with route: Route, animated: Bool, routeController: RouteController? = nil, locationManager: NavigationLocationManager? = nil) {
        if let locationManager {
            self.locationManager = locationManager
        }
        if let routeController {
            self.routeController = routeController
        }
        self.route = route
		
        self.mapViewController.navigationView.showUI(animated: animated)
        self.mapViewController.destination = route.legs.last?.destination

        self.routeController?.usesDefaultUserInterface = true
        self.routeController?.delegate = self
        self.routeController?.tunnelIntersectionManager.delegate = self
        self.routeController?.resume()
        self.mapViewController.prepareForNavigation()
		
        if !(route.routeOptions is NavigationRouteOptions) {
            print("`Route` was created using `RouteOptions` and not `NavigationRouteOptions`. Although not required, this may lead to a suboptimal navigation experience. Without `NavigationRouteOptions`, it is not guaranteed you will get congestion along the route line, better ETAs and ETA label color dependent on congestion.")
        }
		
        if self.shouldManageApplicationIdleTimer {
            UIApplication.shared.isIdleTimerDisabled = true
        }
		
        if let simulatedLocationManager = self.routeController?.locationManager as? SimulatedLocationManager {
            let localized = String.Localized.simulationStatus(speed: Int(simulatedLocationManager.speedMultiplier))
            self.mapViewController.statusView.show(localized, showSpinner: false, interactive: true)
        }
    }
	
    public func endNavigation(animated: Bool = true) {
        self.routeController?.endNavigation()
        self.mapView.removeRoutes()
        self.mapView.removeWaypoints()
        self.mapView.removeArrow()

        self.voiceController = nil
        self.route = nil
        self.locationManager = NavigationLocationManager()
		
        self.mapViewController.navigationView.hideUI(animated: animated)
        self.mapView.tracksUserCourse = false
        self.mapView.userLocationForCourseTracking = nil
        self.mapView.showsUserLocation = true
		
        let camera = self.mapView.camera
        camera.pitch = 0
        self.mapView.setCamera(camera, animated: false)
		
        if self.shouldManageApplicationIdleTimer {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
	
    #if canImport(CarPlay)
    /**
     Presents a `NavigationViewController` on the top most view controller in the window and opens up the `StepsViewController`.
     If the `NavigationViewController` is already in the stack, it will open the `StepsViewController` unless it is already open.
     */
    @available(iOS 12.0, *)
    public class func carPlayManager(_ carPlayManager: CarPlayManager, didBeginNavigationWith routeController: RouteController, window: UIWindow) {
        if let navigationViewController = window.viewControllerInStack(of: NavigationViewController.self) {
            // Open StepsViewController on iPhone if NavigationViewController is being presented
            navigationViewController.isUsedInConjunctionWithCarPlayWindow = true
        } else {
            // Start NavigationViewController and open StepsViewController if navigation has not started on iPhone yet.
            let navigationViewControllerExistsInStack = window.viewControllerInStack(of: NavigationViewController.self) != nil
            
            if !navigationViewControllerExistsInStack {
                let locationManager = routeController.locationManager.copy() as! NavigationLocationManager
                let directions = routeController.directions
                let route = routeController.routeProgress.route
                let navigationViewController = NavigationViewController(dayStyle: DayStyle(demoStyle: ()), nightStyle: NightStyle(demoStyle: ()), directions: directions)
                navigationViewController.startNavigation(with: route, animated: true, routeController: routeController, locationManager: locationManager)

                window.rootViewController?.topMostViewController()?.present(navigationViewController, animated: true, completion: {
                    navigationViewController.isUsedInConjunctionWithCarPlayWindow = true
                })
            }
        }
    }
    
    /**
     Dismisses a `NavigationViewController` if there is any in the navigation stack.
     */
    @available(iOS 12.0, *)
    public class func carPlayManagerDidEndNavigation(_ carPlayManager: CarPlayManager, window: UIWindow) {
        if let navigationViewController = window.viewControllerInStack(of: NavigationViewController.self) {
            navigationViewController.dismiss(animated: true, completion: nil)
        }
    }
    #endif
}

// MARK: - RouteMapViewControllerDelegate

extension NavigationViewController: RouteMapViewControllerDelegate {
    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        self.delegate?.navigationViewController?(self, didFinishLoading: style)
    }
	
    public func mapView(_ mapView: MLNMapView, didSelect annotation: any MLNAnnotation) {
        self.delegate?.navigationViewController?(self, didSelect: annotation)
    }
	
    public func navigationMapView(_ mapView: NavigationMapView, routeCasingStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationViewController?(self, routeCasingStyleLayerWithIdentifier: identifier, source: source)
    }
    
    public func navigationMapView(_ mapView: NavigationMapView, routeStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationViewController?(self, routeStyleLayerWithIdentifier: identifier, source: source)
    }
    
    public func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        self.delegate?.navigationViewController?(self, didSelect: route)
    }
    
    public func navigationMapView(_ mapView: NavigationMapView, shapeFor routes: [Route]) -> MLNShape? {
        self.delegate?.navigationViewController?(self, shapeFor: routes)
    }
    
    public func navigationMapView(_ mapView: NavigationMapView, simplifiedShapeFor route: Route) -> MLNShape? {
        self.delegate?.navigationViewController?(self, simplifiedShapeFor: route)
    }
    
    public func navigationMapView(_ mapView: NavigationMapView, waypointStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationViewController?(self, waypointStyleLayerWithIdentifier: identifier, source: source)
    }
    
    public func navigationMapView(_ mapView: NavigationMapView, waypointSymbolStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer? {
        self.delegate?.navigationViewController?(self, waypointSymbolStyleLayerWithIdentifier: identifier, source: source)
    }
    
    public func navigationMapView(_ mapView: NavigationMapView, shapeFor waypoints: [Waypoint], legIndex: Int) -> MLNShape? {
        self.delegate?.navigationViewController?(self, shapeFor: waypoints, legIndex: legIndex)
    }
    
    public func navigationMapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage? {
        self.delegate?.navigationViewController?(self, imageFor: annotation)
    }
    
    public func navigationMapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        self.delegate?.navigationViewController?(self, viewFor: annotation)
    }
    
    func mapViewControllerDidFinish(_ mapViewController: RouteMapViewController, byCanceling canceled: Bool) {
        self.endNavigation()
        self.delegate?.navigationViewControllerDidFinishRouting?(self)
    }
    
    public func navigationMapViewUserAnchorPoint(_ mapView: NavigationMapView) -> CGPoint {
        self.delegate?.navigationViewController?(self, mapViewUserAnchorPoint: mapView) ?? .zero
    }
    
    func mapViewControllerShouldAnnotateSpokenInstructions(_ routeMapViewController: RouteMapViewController) -> Bool {
        self.annotatesSpokenInstructions
    }
    
    func mapViewController(_ mapViewController: RouteMapViewController, roadNameAt location: CLLocation) -> String? {
        guard let roadName = delegate?.navigationViewController?(self, roadNameAt: location) else {
            return nil
        }
        return roadName
    }
    
    public func label(_ label: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString? {
        self.delegate?.label?(label, willPresent: instruction, as: presented)
    }
}

// MARK: - RouteControllerDelegate

extension NavigationViewController: RouteControllerDelegate {
    public func routeController(_ routeController: RouteController, shouldRerouteFrom location: CLLocation) -> Bool {
        self.delegate?.navigationViewController?(self, shouldRerouteFrom: location) ?? true
    }
    
    public func routeController(_ routeController: RouteController, willRerouteFrom location: CLLocation) {
        self.delegate?.navigationViewController?(self, willRerouteFrom: location)
    }
    
    @objc
    public func routeController(_ routeController: RouteController, didRerouteAlong route: Route, reason: RouteController.RerouteReason) {
        self.mapViewController.notifyDidReroute(route: route)
        self.delegate?.navigationViewController?(self, didRerouteAlong: route)
    }
    
    public func routeController(_ routeController: RouteController, didFailToRerouteWith error: Error) {
        self.delegate?.navigationViewController?(self, didFailToRerouteWith: error)
    }
    
    public func routeController(_ routeController: RouteController, shouldDiscard location: CLLocation) -> Bool {
        self.delegate?.navigationViewController?(self, shouldDiscard: location) ?? true
    }
    
    public func routeController(_ routeController: RouteController, didUpdate locations: [CLLocation]) {
        // If the user has arrived, don't snap the user puck.
        // In the case the user drives beyond the waypoint,
        // we should accurately depict this.
        let shouldPreventReroutesWhenArrivingAtWaypoint = routeController.delegate?.routeController?(routeController, shouldPreventReroutesWhenArrivingAt: routeController.routeProgress.currentLeg.destination) ?? true
        let userHasArrivedAndShouldPreventRerouting = shouldPreventReroutesWhenArrivingAtWaypoint && !routeController.routeProgress.currentLegProgress.userHasArrivedAtWaypoint
        
        if self.snapsUserLocationAnnotationToRoute,
           let snappedLocation = routeController.location ?? locations.last,
           let rawLocation = locations.last,
           userHasArrivedAndShouldPreventRerouting {
            self.mapViewController.labelCurrentRoad(at: rawLocation, for: snappedLocation)
        } else if let rawlocation = locations.last {
            self.mapViewController.labelCurrentRoad(at: rawlocation)
        }
    }
    
    public func routeController(_ routeController: RouteController, didArriveAt waypoint: Waypoint) -> Bool {
        let advancesToNextLeg = self.delegate?.navigationViewController?(self, didArriveAt: waypoint) ?? true
        
        if !self.isConnectedToCarPlay, // CarPlayManager shows rating on CarPlay if it's connected
           routeController.routeProgress.isFinalLeg, advancesToNextLeg {
            self.mapViewController.completeRoute(showArrivalUI: self.showsEndOfRouteFeedback, onDismiss: { [weak self] in
                guard let self else {
                    return
                }
                self.delegate?.navigationViewControllerDidFinishRouting?(self)
            })
        }
        return advancesToNextLeg
    }
}

// MARK: - TunnelIntersectionManagerDelegate

extension NavigationViewController: TunnelIntersectionManagerDelegate {
    public func tunnelIntersectionManager(_ manager: TunnelIntersectionManager, willEnableAnimationAt location: CLLocation) {
        self.routeController?.tunnelIntersectionManager(manager, willEnableAnimationAt: location)
        self.styleManager.applyStyle(type: .night)
    }
    
    public func tunnelIntersectionManager(_ manager: TunnelIntersectionManager, willDisableAnimationAt location: CLLocation) {
        self.routeController?.tunnelIntersectionManager(manager, willDisableAnimationAt: location)
        self.styleManager.timeOfDayChanged()
    }
}

// MARK: - StyleManagerDelegate

extension NavigationViewController: StyleManagerDelegate {
    public func locationFor(styleManager: StyleManager) -> CLLocation? {
        if let location = self.routeController?.location {
            location
        } else if let firstCoord = self.routeController?.routeProgress.route.coordinates?.first {
            CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
        } else {
            nil
        }
    }
    
    public func styleManager(_ styleManager: StyleManager, didApply style: Style) {
        if self.mapView.styleURL != style.mapStyleURL {
            self.mapView.style?.transition = MLNTransition(duration: 0.5, delay: 0)
            self.mapView.styleURL = style.mapStyleURL
        }
        
        self.currentStatusBarStyle = style.statusBarStyle ?? .default
        setNeedsStatusBarAppearanceUpdate()
    }
    
    public func styleManagerDidRefreshAppearance(_ styleManager: StyleManager) {
        self.mapView.reloadStyle(self)
    }
}

// MARK: - Private

private extension NavigationViewController {
    var isConnectedToCarPlay: Bool {
        CarPlayManager.shared.isConnectedToCarPlay
    }
	
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressDidChange(notification:)), name: .routeControllerProgressDidChange, object: self.routeController)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didPassInstructionPoint(notification:)), name: .routeControllerDidPassSpokenInstructionPoint, object: self.routeController)
    }
	
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: self.routeController)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassSpokenInstructionPoint, object: self.routeController)
    }

    @objc func progressDidChange(notification: NSNotification) {
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as! CLLocation
        let secondsRemaining = routeProgress.currentLegProgress.currentStepProgress.durationRemaining

        self.mapViewController.notifyDidChange(routeProgress: routeProgress, location: location, secondsRemaining: secondsRemaining)
        guard let routeController else { return }
		
        // If the user has arrived, don't snap the user puck.
        // In the case the user drives beyond the waypoint,
        // we should accurately depict this.
        let shouldPreventReroutesWhenArrivingAtWaypoint = routeController.delegate?.routeController?(routeController, shouldPreventReroutesWhenArrivingAt: routeController.routeProgress.currentLeg.destination) ?? true
        let userHasArrivedAndShouldPreventRerouting = shouldPreventReroutesWhenArrivingAtWaypoint && !routeController.routeProgress.currentLegProgress.userHasArrivedAtWaypoint
		
        if self.snapsUserLocationAnnotationToRoute,
           userHasArrivedAndShouldPreventRerouting {
            self.mapView.updateCourseTracking(location: location, animated: true)
        }
    }
	
    @objc func didPassInstructionPoint(notification: NSNotification) {
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
		
        self.mapViewController.updateCameraAltitude(for: routeProgress)
		
        self.clearStaleNotifications()
		
        if routeProgress.currentLegProgress.currentStepProgress.durationRemaining <= RouteControllerHighAlertInterval {
            self.scheduleLocalNotification(about: routeProgress.currentLegProgress.currentStep, legIndex: routeProgress.legIndex, numberOfLegs: routeProgress.route.legs.count)
        }
    }
	
    func scheduleLocalNotification(about step: RouteStep, legIndex: Int?, numberOfLegs: Int?) {
        guard self.sendsNotifications else { return }
        guard UIApplication.shared.applicationState == .background else { return }
        guard let text = step.instructionsSpokenAlongStep?.last?.text else { return }
		
        let notification = UILocalNotification()
        notification.alertBody = text
        notification.fireDate = Date()
		
        self.clearStaleNotifications()
		
        UIApplication.shared.cancelAllLocalNotifications()
        UIApplication.shared.scheduleLocalNotification(notification)
    }
	
    func clearStaleNotifications() {
        guard self.sendsNotifications else { return }
        // Remove all outstanding notifications from notification center.
        // This will only work if it's set to 1 and then back to 0.
        // This way, there is always just one notification.
        UIApplication.shared.applicationIconBadgeNumber = 1
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
