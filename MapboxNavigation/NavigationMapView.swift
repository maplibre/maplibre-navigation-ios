import Foundation
import MapboxCoreNavigation
import MapboxDirections
import MapLibre
import Turf

/**
 `NavigationMapView` is a subclass of `MLNMapView` with convenience functions for adding `Route` lines to a map.
 */
@objc(MLNavigationMapView)
open class NavigationMapView: MLNMapView, UIGestureRecognizerDelegate {
    // MARK: Class Constants
    
    enum FrameIntervalOptions {
        fileprivate static let durationUntilNextManeuver: TimeInterval = 7
        fileprivate static let durationSincePreviousManeuver: TimeInterval = 3
        fileprivate static let defaultFramesPerSecond = MLNMapViewPreferredFramesPerSecond.maximum
        fileprivate static let pluggedInFramesPerSecond = MLNMapViewPreferredFramesPerSecond.lowPower
        fileprivate static let decreasedFramesPerSecond = MLNMapViewPreferredFramesPerSecond(rawValue: 5)
    }
    
    /**
     Returns the altitude that the map camera initally defaults to.
     */
    @objc public var defaultAltitude: CLLocationDistance = 1000.0
    
    /**
      Returns the altitude the map conditionally zooms out to when user is on a motorway, and the maneuver length is sufficently long.
     */
    @objc public var zoomedOutMotorwayAltitude: CLLocationDistance = 2000.0
    
    /**
     Returns the threshold for what the map considers a "long-enough" maneuver distance to trigger a zoom-out when the user enters a motorway.
     */
    @objc public var longManeuverDistance: CLLocationDistance = 1000.0
    
    /**
     Maximum distance the user can tap for a selection to be valid when selecting an alternate route.
     */
    @objc public var tapGestureDistanceThreshold: CGFloat = 50
    
    /**
     The object that acts as the navigation delegate of the map view.
     */
    public weak var navigationMapDelegate: NavigationMapViewDelegate?
    
    /**
     The object that acts as the course tracking delegate of the map view.
     */
    public weak var courseTrackingDelegate: NavigationMapViewCourseTrackingDelegate?
    
    let sourceOptions: [MLNShapeSourceOption: Any] = [.maximumZoomLevel: 16]

    // MARK: - Instance Properties

    let sourceIdentifier = "routeSource"
    let sourceCasingIdentifier = "routeCasingSource"
    let routeLayerIdentifier = "routeLayer"
    let routeLayerCasingIdentifier = "routeLayerCasing"
    let waypointSourceIdentifier = "waypointsSource"
    let waypointCircleIdentifier = "waypointsCircle"
    let waypointSymbolIdentifier = "waypointsSymbol"
    let arrowSourceIdentifier = "arrowSource"
    let arrowSourceStrokeIdentifier = "arrowSourceStroke"
    let arrowLayerIdentifier = "arrowLayer"
    let arrowSymbolLayerIdentifier = "arrowSymbolLayer"
    let arrowLayerStrokeIdentifier = "arrowStrokeLayer"
    let arrowCasingSymbolLayerIdentifier = "arrowCasingSymbolLayer"
    let arrowSymbolSourceIdentifier = "arrowSymbolSource"
    let instructionSource = "instructionSource"
    let instructionLabel = "instructionLabel"
    let instructionCircle = "instructionCircle"
    
    @objc public dynamic var trafficUnknownColor: UIColor = .trafficUnknown
    @objc public dynamic var trafficLowColor: UIColor = .trafficLow
    @objc public dynamic var trafficModerateColor: UIColor = .trafficModerate
    @objc public dynamic var trafficHeavyColor: UIColor = .trafficHeavy
    @objc public dynamic var trafficSevereColor: UIColor = .trafficSevere
    @objc public dynamic var routeLineColor: UIColor = .defaultRouteLine
    @objc public dynamic var routeLineAlternativeColor: UIColor = .defaultRouteLineAlternative
    @objc public dynamic var routeLineCasingColor: UIColor = .defaultRouteLineCasing
    @objc public dynamic var routeLineCasingAlternativeColor: UIColor = .defaultRouteLineCasingAlternative
    @objc public dynamic var maneuverArrowColor: UIColor = .defaultManeuverArrow
    @objc public dynamic var maneuverArrowStrokeColor: UIColor = .defaultManeuverArrowStroke
    
    var userLocationForCourseTracking: CLLocation?
    var animatesUserLocation: Bool = false
    var altitude: CLLocationDistance
    var routes: [Route]?
    var isAnimatingToOverheadMode = false
    
    var shouldPositionCourseViewFrameByFrame = false {
        didSet {
            if self.shouldPositionCourseViewFrameByFrame {
                preferredFramesPerSecond = FrameIntervalOptions.defaultFramesPerSecond
            }
        }
    }
    
    var showsRoute: Bool {
        style?.layer(withIdentifier: self.routeLayerIdentifier) != nil
    }
    
    override open var showsUserLocation: Bool {
        get {
            if self.tracksUserCourse || self.userLocationForCourseTracking != nil {
                return !(self.userCourseView?.isHidden ?? true)
            }
            return super.showsUserLocation
        }
        set {
            if self.tracksUserCourse || self.userLocationForCourseTracking != nil {
                super.showsUserLocation = false
                
                if self.userCourseView == nil {
                    self.userCourseView = UserPuckCourseView(frame: CGRect(origin: .zero, size: CGSize(width: 75, height: 75)))
                }
                self.userCourseView?.isHidden = !newValue
            } else {
                self.userCourseView?.isHidden = true
                super.showsUserLocation = newValue
            }
        }
    }
    
    /**
     Center point of the user course view in screen coordinates relative to the map view.
     - seealso: NavigationMapViewDelegate.navigationMapViewUserAnchorPoint(_:)
     */
    var userAnchorPoint: CGPoint {
        if let anchorPoint = navigationMapDelegate?.navigationMapViewUserAnchorPoint?(self), anchorPoint != .zero {
            return anchorPoint
        }
        
        let contentFrame = bounds.inset(by: safeArea)
        let courseViewWidth = self.userCourseView?.frame.width ?? 0
        let courseViewHeight = self.userCourseView?.frame.height ?? 0
        let edgePadding = UIEdgeInsets(top: 50 + courseViewHeight / 2,
                                       left: 50 + courseViewWidth / 2,
                                       bottom: 50 + courseViewHeight / 2,
                                       right: 50 + courseViewWidth / 2)
        return CGPoint(x: max(min(contentFrame.midX,
                                  contentFrame.maxX - edgePadding.right),
                              contentFrame.minX + edgePadding.left),
                       y: max(max(min(contentFrame.minY + contentFrame.height * 0.8,
                                      contentFrame.maxY - edgePadding.bottom),
                                  contentFrame.minY + edgePadding.top),
                              contentFrame.minY + contentFrame.height * 0.5))
    }
    
    /**
     Determines whether the map should follow the user location and rotate when the course changes.
     - seealso: NavigationMapViewCourseTrackingDelegate
     */
    open var tracksUserCourse: Bool = false {
        didSet {
            if self.tracksUserCourse {
                self.enableFrameByFrameCourseViewTracking(for: 3)
                self.altitude = self.defaultAltitude
                self.showsUserLocation = true
                self.courseTrackingDelegate?.navigationMapViewDidStartTrackingCourse?(self)
            } else {
                self.courseTrackingDelegate?.navigationMapViewDidStopTrackingCourse?(self)
            }
            if let location = userLocationForCourseTracking {
                self.updateCourseTracking(location: location, animated: true)
            }
        }
    }

    /**
     A `UIView` used to indicate the user’s location and course on the map.
     
     If the view conforms to `UserCourseView`, its `UserCourseView.update(location:pitch:direction:animated:)` method is frequently called to ensure that its visual appearance matches the map’s camera.
     */
    @objc public var userCourseView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let userCourseView {
                if let location = userLocationForCourseTracking {
                    self.updateCourseTracking(location: location, animated: false)
                } else {
                    userCourseView.center = self.userAnchorPoint
                }
                addSubview(userCourseView)
            }
        }
    }
    
    private lazy var mapTapGesture = UITapGestureRecognizer(target: self, action: #selector(didRecieveTap(sender:)))
    
    // MARK: - Initalizers
    
    override public init(frame: CGRect) {
        self.altitude = self.defaultAltitude
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder decoder: NSCoder) {
        self.altitude = self.defaultAltitude
        super.init(coder: decoder)
        self.commonInit()
    }
    
    override public init(frame: CGRect, styleURL: URL?) {
        self.altitude = self.defaultAltitude
        super.init(frame: frame, styleURL: styleURL)
        self.commonInit()
    }
    
    public convenience init(frame: CGRect, styleURL: URL?, config: MNConfig? = nil) {
        if let config {
            ConfigManager.shared.config = config
        }
        
        self.init(frame: frame, styleURL: styleURL)
    }
    
    fileprivate func commonInit() {
        self.makeGestureRecognizersRespectCourseTracking()
        self.makeGestureRecognizersUpdateCourseView()
        
        self.resumeNotifications()
    }
    
    deinit {
        suspendNotifications()
    }
    
    // MARK: - Overrides
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
        let image = UIImage(named: "feedback-map-error", in: .mapboxNavigation, compatibleWith: nil)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .center
        imageView.backgroundColor = .gray
        imageView.frame = bounds
        addSubview(imageView)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        // If the map is in tracking mode, make sure we update the camera after the layout pass.
        if self.tracksUserCourse {
            self.updateCourseTracking(location: self.userLocationForCourseTracking, camera: camera, animated: false)
        }
    }
    
    override open func anchorPoint(forGesture gesture: UIGestureRecognizer) -> CGPoint {
        if self.tracksUserCourse {
            self.userAnchorPoint
        } else {
            super.anchorPoint(forGesture: gesture)
        }
    }
   
    override open func mapViewDidFinishRenderingFrameFullyRendered(_ fullyRendered: Bool, frameEncodingTime: Double, frameRenderingTime: Double) {
        super.mapViewDidFinishRenderingFrameFullyRendered(fullyRendered, frameEncodingTime: frameEncodingTime, frameRenderingTime: frameRenderingTime)
        
        guard self.shouldPositionCourseViewFrameByFrame else { return }
        guard let location = userLocationForCourseTracking else { return }
        
        self.userCourseView?.center = convert(location.coordinate, toPointTo: self)
    }
    
    // MARK: - Notifications
    
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressDidChange(_:)), name: .routeControllerProgressDidChange, object: nil)
        
        let gestures = gestureRecognizers ?? []
        let mapTapGesture = mapTapGesture
        mapTapGesture.requireFailure(of: gestures)
        addGestureRecognizer(mapTapGesture)
    }
    
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
    }
    
    @objc func progressDidChange(_ notification: Notification) {
        guard self.tracksUserCourse else { return }
        
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        
        if let location = userLocationForCourseTracking {
            let cameraUpdated = self.courseTrackingDelegate?.updateCamera?(self, location: location, routeProgress: routeProgress) ?? false
            
            if !cameraUpdated {
                let newCamera = MLNMapCamera(lookingAtCenter: location.coordinate, acrossDistance: self.altitude, pitch: 45, heading: location.course)
                let function = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                setCamera(newCamera, withDuration: 1, animationTimingFunction: function, edgePadding: UIEdgeInsets.zero, completionHandler: nil)
            }
        }
        
        let stepProgress = routeProgress.currentLegProgress.currentStepProgress
        let expectedTravelTime = stepProgress.step.expectedTravelTime
        let durationUntilNextManeuver = stepProgress.durationRemaining
        let durationSincePreviousManeuver = expectedTravelTime - durationUntilNextManeuver
        guard !UIDevice.current.isPluggedIn else {
            preferredFramesPerSecond = FrameIntervalOptions.pluggedInFramesPerSecond
            return
        }
    
        if let upcomingStep = routeProgress.currentLegProgress.upComingStep,
           upcomingStep.maneuverDirection == .straightAhead || upcomingStep.maneuverDirection == .slightLeft || upcomingStep.maneuverDirection == .slightRight {
            preferredFramesPerSecond = self.shouldPositionCourseViewFrameByFrame ? FrameIntervalOptions.defaultFramesPerSecond : FrameIntervalOptions.decreasedFramesPerSecond
        } else if durationUntilNextManeuver > FrameIntervalOptions.durationUntilNextManeuver,
                  durationSincePreviousManeuver > FrameIntervalOptions.durationSincePreviousManeuver {
            preferredFramesPerSecond = self.shouldPositionCourseViewFrameByFrame ? FrameIntervalOptions.defaultFramesPerSecond : FrameIntervalOptions.decreasedFramesPerSecond
        } else {
            preferredFramesPerSecond = FrameIntervalOptions.pluggedInFramesPerSecond
        }
    }
    
    // MARK: - User Tracking
    
    /**
     Track position on a frame by frame basis. Used for first location update and when resuming tracking mode.
     Call this method when you are doing custom zoom animations, this will make sure the puck stays on the route during these animations.
     */
    @objc public func enableFrameByFrameCourseViewTracking(for duration: TimeInterval) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.disableFrameByFramePositioning), object: nil)
        perform(#selector(self.disableFrameByFramePositioning), with: nil, afterDelay: duration)
        self.shouldPositionCourseViewFrameByFrame = true
    }
    
    @objc fileprivate func disableFrameByFramePositioning() {
        self.shouldPositionCourseViewFrameByFrame = false
    }
    
    @objc private func disableUserCourseTracking() {
        guard self.tracksUserCourse else { return }
        self.tracksUserCourse = false
    }
    
    @objc public func updateCourseTracking(location: CLLocation?, camera: MLNMapCamera? = nil, animated: Bool = false) {
        // While animating to overhead mode, don't animate the puck.
        let duration: TimeInterval = animated && !self.isAnimatingToOverheadMode ? 1 : 0
        self.animatesUserLocation = animated
        self.userLocationForCourseTracking = location
        guard let location, CLLocationCoordinate2DIsValid(location.coordinate) else {
            return
        }
        
        if !self.tracksUserCourse || self.userAnchorPoint != userCourseView?.center ?? self.userAnchorPoint {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear, .beginFromCurrentState], animations: {
                self.userCourseView?.center = self.convert(location.coordinate, toPointTo: self)
            })
        }
        
        if let userCourseView = userCourseView as? UserCourseView {
            if let customTransformation = userCourseView.update?(location: location, pitch: self.camera.pitch, direction: direction, animated: animated, tracksUserCourse: tracksUserCourse) {
                customTransformation
            } else {
                self.userCourseView?.applyDefaultUserPuckTransformation(location: location, pitch: self.camera.pitch, direction: direction, animated: animated, tracksUserCourse: self.tracksUserCourse)
            }
        } else {
            userCourseView?.applyDefaultUserPuckTransformation(location: location, pitch: self.camera.pitch, direction: direction, animated: animated, tracksUserCourse: self.tracksUserCourse)
        }
    }
    
    // MARK: - Gesture Recognizers
    
    /**
     Fired when NavigationMapView detects a tap not handled elsewhere by other gesture recognizers.
     */
    @objc func didRecieveTap(sender: UITapGestureRecognizer) {
        guard let routes, let tapPoint = sender.point else { return }
        
        let waypointTest = self.waypoints(on: routes, closeTo: tapPoint) // are there waypoints near the tapped location?
        if let selected = waypointTest?.first { // test passes
            self.navigationMapDelegate?.navigationMapView?(self, didSelect: selected)
            return
        } else if let routes = self.routes(closeTo: tapPoint) {
            guard let selectedRoute = routes.first else { return }
            self.navigationMapDelegate?.navigationMapView?(self, didSelect: selectedRoute)
        }
    }
    
    @objc func updateCourseView(_ sender: UIGestureRecognizer) {
        preferredFramesPerSecond = FrameIntervalOptions.defaultFramesPerSecond
        
        if sender.state == .ended {
            self.altitude = camera.altitude
            self.enableFrameByFrameCourseViewTracking(for: 2)
        }
        
        // Capture altitude for double tap and two finger tap after animation finishes
        if sender is UITapGestureRecognizer, sender.state == .ended {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.altitude = self.camera.altitude
            }
        }
        
        if let pan = sender as? UIPanGestureRecognizer {
            if sender.state == .ended || sender.state == .cancelled {
                let velocity = pan.velocity(in: self)
                let didFling = sqrt(velocity.x * velocity.x + velocity.y * velocity.y) > 100
                if didFling {
                    self.enableFrameByFrameCourseViewTracking(for: 1)
                }
            }
        }
        
        if sender.state == .changed {
            guard let location = userLocationForCourseTracking else { return }
            self.userCourseView?.layer.removeAllAnimations()
            self.userCourseView?.center = convert(location.coordinate, toPointTo: self)
        }
    }
    
    // MARK: Feature Addition/Removal

    /**
      Showcases route array. Adds routes and waypoints to map, and sets camera to point encompassing the route.
     */
    public static let defaultPadding: UIEdgeInsets = .init(top: 10, left: 20, bottom: 10, right: 20)
    
    @objc public func showcase(_ routes: [Route], padding: UIEdgeInsets = NavigationMapView.defaultPadding, animated: Bool = false) {
        guard let active = routes.first,
              let coords = active.coordinates,
              !coords.isEmpty else { return } // empty array
        
        self.removeArrow()
        self.removeRoutes()
        self.removeWaypoints()
        
        self.showRoutes(routes)
        self.showWaypoints(active)
        
        self.fit(to: active, facing: 0, padding: padding, animated: animated)
    }
    
    func fit(to route: Route, facing direction: CLLocationDirection = 0, padding: UIEdgeInsets = NavigationMapView.defaultPadding, animated: Bool = false) {
        guard let coords = route.coordinates, !coords.isEmpty else { return }
      
        setUserTrackingMode(.none, animated: false, completionHandler: nil)
        let line = MLNPolyline(coordinates: coords, count: UInt(coords.count))
        let camera = cameraThatFitsShape(line, direction: direction, edgePadding: padding)
        
        setCamera(camera, animated: false)
    }
    
    /**
     Adds or updates both the route line and the route line casing
     */
    @objc public func showRoutes(_ routes: [Route], legIndex: Int = 0) {
        guard let style else { return }
        guard let mainRoute = routes.first else { return }
        self.routes = routes
        
        let polylines = self.navigationMapDelegate?.navigationMapView?(self, shapeFor: routes) ?? self.shape(for: routes, legIndex: legIndex)
        let mainPolylineSimplified = self.navigationMapDelegate?.navigationMapView?(self, simplifiedShapeFor: mainRoute) ?? self.shape(forCasingOf: mainRoute, legIndex: legIndex)
        
        if let source = style.source(withIdentifier: sourceIdentifier) as? MLNShapeSource,
           let sourceSimplified = style.source(withIdentifier: sourceCasingIdentifier) as? MLNShapeSource {
            source.shape = polylines
            sourceSimplified.shape = mainPolylineSimplified
        } else {
            let lineSource = MLNShapeSource(identifier: sourceIdentifier, shape: polylines, options: nil)
            let lineCasingSource = MLNShapeSource(identifier: sourceCasingIdentifier, shape: mainPolylineSimplified, options: nil)
            style.addSource(lineSource)
            style.addSource(lineCasingSource)
            
            let line = self.navigationMapDelegate?.navigationMapView?(self, routeStyleLayerWithIdentifier: self.routeLayerIdentifier, source: lineSource) ?? self.routeStyleLayer(identifier: self.routeLayerIdentifier, source: lineSource)
            let lineCasing = self.navigationMapDelegate?.navigationMapView?(self, routeCasingStyleLayerWithIdentifier: self.routeLayerCasingIdentifier, source: lineCasingSource) ?? self.routeCasingStyleLayer(identifier: self.routeLayerCasingIdentifier, source: lineSource)
            
            for layer in style.layers.reversed() {
                if !(layer is MLNSymbolStyleLayer),
                   layer.identifier != self.arrowLayerIdentifier, layer.identifier != self.arrowSymbolLayerIdentifier, layer.identifier != self.arrowCasingSymbolLayerIdentifier, layer.identifier != self.arrowLayerStrokeIdentifier, layer.identifier != self.waypointCircleIdentifier {
                    style.insertLayer(line, below: layer)
                    style.insertLayer(lineCasing, below: line)
                    break
                }
            }
        }
    }
    
    /**
     Removes route line and route line casing from map
     */
    @objc public func removeRoutes() {
        guard let style else {
            return
        }
        
        if let line = style.layer(withIdentifier: routeLayerIdentifier) {
            style.removeLayer(line)
        }
        
        if let lineCasing = style.layer(withIdentifier: routeLayerCasingIdentifier) {
            style.removeLayer(lineCasing)
        }
        
        if let lineSource = style.source(withIdentifier: sourceIdentifier) {
            style.removeSource(lineSource)
        }
        
        if let lineCasingSource = style.source(withIdentifier: sourceCasingIdentifier) {
            style.removeSource(lineCasingSource)
        }
    }
    
    /**
     Adds the route waypoints to the map given the current leg index. Previous waypoints for completed legs will be omitted.
     */
    @objc public func showWaypoints(_ route: Route, legIndex: Int = 0) {
        guard let style else {
            return
        }

        let waypoints: [Waypoint] = Array(route.legs.map(\.destination).dropLast())
        
        let source = self.navigationMapDelegate?.navigationMapView?(self, shapeFor: waypoints, legIndex: legIndex) ?? self.shape(for: waypoints, legIndex: legIndex)
        if route.routeOptions.waypoints.count > 2 { // are we on a multipoint route?
            self.routes = [route] // update the model
            if let waypointSource = style.source(withIdentifier: waypointSourceIdentifier) as? MLNShapeSource {
                waypointSource.shape = source
            } else {
                let sourceShape = MLNShapeSource(identifier: waypointSourceIdentifier, shape: source, options: sourceOptions)
                style.addSource(sourceShape)
                
                let circles = self.navigationMapDelegate?.navigationMapView?(self, waypointStyleLayerWithIdentifier: self.waypointCircleIdentifier, source: sourceShape) ?? self.routeWaypointCircleStyleLayer(identifier: self.waypointCircleIdentifier, source: sourceShape)
                let symbols = self.navigationMapDelegate?.navigationMapView?(self, waypointSymbolStyleLayerWithIdentifier: self.waypointSymbolIdentifier, source: sourceShape) ?? self.routeWaypointSymbolStyleLayer(identifier: self.waypointSymbolIdentifier, source: sourceShape)
                
                if let arrowLayer = style.layer(withIdentifier: arrowCasingSymbolLayerIdentifier) {
                    style.insertLayer(circles, below: arrowLayer)
                } else {
                    style.addLayer(circles)
                }
                
                style.insertLayer(symbols, above: circles)
            }
        }
        
        if let lastLeg = route.legs.last {
            removeAnnotations(annotations ?? [])
            let destination = MLNPointAnnotation()
            destination.coordinate = lastLeg.destination.coordinate
            addAnnotation(destination)
        }
    }

    /**
     Removes all waypoints from the map.
     */
    @objc public func removeWaypoints() {
        guard let style else { return }
        
        removeAnnotations(annotations ?? [])
        
        if let circleLayer = style.layer(withIdentifier: waypointCircleIdentifier) {
            style.removeLayer(circleLayer)
        }
        if let symbolLayer = style.layer(withIdentifier: waypointSymbolIdentifier) {
            style.removeLayer(symbolLayer)
        }
        if let waypointSource = style.source(withIdentifier: waypointSourceIdentifier) {
            style.removeSource(waypointSource)
        }
        if let circleSource = style.source(withIdentifier: waypointCircleIdentifier) {
            style.removeSource(circleSource)
        }
        if let symbolSource = style.source(withIdentifier: waypointSymbolIdentifier) {
            style.removeSource(symbolSource)
        }
    }
    
    /**
     Shows the step arrow given the current `RouteProgress`.
     */
    @objc public func addArrow(route: Route, legIndex: Int, stepIndex: Int) {
        guard route.legs.indices.contains(legIndex),
              route.legs[legIndex].steps.indices.contains(stepIndex) else { return }
        
        let step = route.legs[legIndex].steps[stepIndex]
        let maneuverCoordinate = step.maneuverLocation
        guard let routeCoordinates = route.coordinates else { return }
        
        guard let style else {
            return
        }

        guard let triangleImage = Bundle.mapboxNavigation.image(named: "triangle")?.withRenderingMode(.alwaysTemplate) else { return }
        
        style.setImage(triangleImage, forName: "triangle-tip-navigation")
        
        guard step.maneuverType != .arrive else { return }
        
        let minimumZoomLevel: Float = 14.5
        
        let shaftLength = max(min(30 * metersPerPoint(atLatitude: maneuverCoordinate.latitude), 30), 10)
        let polyline = Polyline(routeCoordinates)
        let shaftCoordinates = Array(polyline.trimmed(from: maneuverCoordinate, distance: -shaftLength).coordinates.reversed()
            + polyline.trimmed(from: maneuverCoordinate, distance: shaftLength).coordinates.suffix(from: 1))
        if shaftCoordinates.count > 1 {
            var shaftStrokeCoordinates = shaftCoordinates
            let shaftStrokePolyline = ArrowStrokePolyline(coordinates: &shaftStrokeCoordinates, count: UInt(shaftStrokeCoordinates.count))
            let shaftDirection = shaftStrokeCoordinates[shaftStrokeCoordinates.count - 2].direction(to: shaftStrokeCoordinates.last!)
            let maneuverArrowStrokePolylines = [shaftStrokePolyline]
            let shaftPolyline = ArrowFillPolyline(coordinates: shaftCoordinates, count: UInt(shaftCoordinates.count))
            
            let arrowShape = MLNShapeCollection(shapes: [shaftPolyline])
            let arrowStrokeShape = MLNShapeCollection(shapes: maneuverArrowStrokePolylines)
            
            let arrowSourceStroke = MLNShapeSource(identifier: arrowSourceStrokeIdentifier, shape: arrowStrokeShape, options: sourceOptions)
            let arrowStroke = MLNLineStyleLayer(identifier: arrowLayerStrokeIdentifier, source: arrowSourceStroke)
            let arrowSource = MLNShapeSource(identifier: arrowSourceIdentifier, shape: arrowShape, options: sourceOptions)
            let arrow = MLNLineStyleLayer(identifier: arrowLayerIdentifier, source: arrowSource)
            
            if let source = style.source(withIdentifier: arrowSourceIdentifier) as? MLNShapeSource {
                source.shape = arrowShape
            } else {
                arrow.minimumZoomLevel = minimumZoomLevel
                arrow.lineCap = NSExpression(forConstantValue: "butt")
                arrow.lineJoin = NSExpression(forConstantValue: "round")
                arrow.lineWidth = NSExpression(forMLNInterpolating: .zoomLevelVariable,
                                               curveType: .linear,
                                               parameters: nil,
                                               stops: NSExpression(forConstantValue: MLNRouteLineWidthByZoomLevel.multiplied(by: 0.7)))
                arrow.lineColor = NSExpression(forConstantValue: self.maneuverArrowColor)
                
                style.addSource(arrowSource)
                style.addLayer(arrow)
            }
            
            if let source = style.source(withIdentifier: arrowSourceStrokeIdentifier) as? MLNShapeSource {
                source.shape = arrowStrokeShape
            } else {
                arrowStroke.minimumZoomLevel = arrow.minimumZoomLevel
                arrowStroke.lineCap = arrow.lineCap
                arrowStroke.lineJoin = arrow.lineJoin
                arrow.lineWidth = NSExpression(forMLNInterpolating: .zoomLevelVariable,
                                               curveType: .linear,
                                               parameters: nil,
                                               stops: NSExpression(forConstantValue: MLNRouteLineWidthByZoomLevel.multiplied(by: 0.8)))
                arrowStroke.lineColor = NSExpression(forConstantValue: self.maneuverArrowStrokeColor)
                
                style.addSource(arrowSourceStroke)
                style.insertLayer(arrowStroke, below: arrow)
            }
            
            // Arrow symbol
            let point = MLNPointFeature()
            point.coordinate = shaftStrokeCoordinates.last!
            let arrowSymbolSource = MLNShapeSource(identifier: arrowSymbolSourceIdentifier, features: [point], options: sourceOptions)
            
            if let source = style.source(withIdentifier: arrowSymbolSourceIdentifier) as? MLNShapeSource {
                source.shape = arrowSymbolSource.shape
                if let arrowSymbolLayer = style.layer(withIdentifier: arrowSymbolLayerIdentifier) as? MLNSymbolStyleLayer {
                    arrowSymbolLayer.iconRotation = NSExpression(forConstantValue: shaftDirection as NSNumber)
                }
                if let arrowSymbolLayerCasing = style.layer(withIdentifier: arrowCasingSymbolLayerIdentifier) as? MLNSymbolStyleLayer {
                    arrowSymbolLayerCasing.iconRotation = NSExpression(forConstantValue: shaftDirection as NSNumber)
                }
            } else {
                let arrowSymbolLayer = MLNSymbolStyleLayer(identifier: arrowSymbolLayerIdentifier, source: arrowSymbolSource)
                arrowSymbolLayer.minimumZoomLevel = minimumZoomLevel
                arrowSymbolLayer.iconImageName = NSExpression(forConstantValue: "triangle-tip-navigation")
                arrowSymbolLayer.iconColor = NSExpression(forConstantValue: self.maneuverArrowColor)
                arrowSymbolLayer.iconRotationAlignment = NSExpression(forConstantValue: "map")
                arrowSymbolLayer.iconRotation = NSExpression(forConstantValue: shaftDirection as NSNumber)
                arrowSymbolLayer.iconScale = NSExpression(forMLNInterpolating: .zoomLevelVariable,
                                                          curveType: .linear,
                                                          parameters: nil,
                                                          stops: NSExpression(forConstantValue: MLNRouteLineWidthByZoomLevel.multiplied(by: 0.12)))
                arrowSymbolLayer.iconAllowsOverlap = NSExpression(forConstantValue: true)
                
                let arrowSymbolLayerCasing = MLNSymbolStyleLayer(identifier: arrowCasingSymbolLayerIdentifier, source: arrowSymbolSource)
                arrowSymbolLayerCasing.minimumZoomLevel = arrowSymbolLayer.minimumZoomLevel
                arrowSymbolLayerCasing.iconImageName = arrowSymbolLayer.iconImageName
                arrowSymbolLayerCasing.iconColor = NSExpression(forConstantValue: self.maneuverArrowStrokeColor)
                arrowSymbolLayerCasing.iconRotationAlignment = arrowSymbolLayer.iconRotationAlignment
                arrowSymbolLayerCasing.iconRotation = arrowSymbolLayer.iconRotation
                arrowSymbolLayerCasing.iconScale = NSExpression(forMLNInterpolating: .zoomLevelVariable,
                                                                curveType: .linear,
                                                                parameters: nil,
                                                                stops: NSExpression(forConstantValue: MLNRouteLineWidthByZoomLevel.multiplied(by: 0.14)))
                arrowSymbolLayerCasing.iconAllowsOverlap = arrowSymbolLayer.iconAllowsOverlap
                
                style.addSource(arrowSymbolSource)
                style.insertLayer(arrowSymbolLayer, above: arrow)
                style.insertLayer(arrowSymbolLayerCasing, below: arrow)
            }
        }
    }
    
    /**
     Removes the step arrow from the map.
     */
    @objc public func removeArrow() {
        guard let style else {
            return
        }
        
        if let arrowLayer = style.layer(withIdentifier: arrowLayerIdentifier) {
            style.removeLayer(arrowLayer)
        }
        
        if let arrowLayerStroke = style.layer(withIdentifier: arrowLayerStrokeIdentifier) {
            style.removeLayer(arrowLayerStroke)
        }
        
        if let arrowSymbolLayer = style.layer(withIdentifier: arrowSymbolLayerIdentifier) {
            style.removeLayer(arrowSymbolLayer)
        }
        
        if let arrowCasingSymbolLayer = style.layer(withIdentifier: arrowCasingSymbolLayerIdentifier) {
            style.removeLayer(arrowCasingSymbolLayer)
        }
        
        if let arrowSource = style.source(withIdentifier: arrowSourceIdentifier) {
            style.removeSource(arrowSource)
        }
        
        if let arrowStrokeSource = style.source(withIdentifier: arrowSourceStrokeIdentifier) {
            style.removeSource(arrowStrokeSource)
        }
        
        if let arrowSymboleSource = style.source(withIdentifier: arrowSymbolSourceIdentifier) {
            style.removeSource(arrowSymboleSource)
        }
    }
    
    // MARK: Utility Methods
    
    /** Modifies the gesture recognizers to also disable course tracking. */
    func makeGestureRecognizersRespectCourseTracking() {
        for gestureRecognizer in gestureRecognizers ?? []
            where gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer {
            gestureRecognizer.addTarget(self, action: #selector(disableUserCourseTracking))
        }
    }
    
    func makeGestureRecognizersUpdateCourseView() {
        for gestureRecognizer in gestureRecognizers ?? [] {
            gestureRecognizer.addTarget(self, action: #selector(self.updateCourseView(_:)))
        }
    }
    
    // TODO: Change to point-based distance calculation
    private func waypoints(on routes: [Route], closeTo point: CGPoint) -> [Waypoint]? {
        let tapCoordinate = convert(point, toCoordinateFrom: self)
        let multipointRoutes = routes.filter { $0.routeOptions.waypoints.count >= 3 }
        guard multipointRoutes.count > 0 else { return nil }
        let waypoints = multipointRoutes.flatMap(\.routeOptions.waypoints)
        
        // lets sort the array in order of closest to tap
        let closest = waypoints.sorted { left, right -> Bool in
            let leftDistance = left.coordinate.distance(to: tapCoordinate)
            let rightDistance = right.coordinate.distance(to: tapCoordinate)
            return leftDistance < rightDistance
        }
        
        // lets filter to see which ones are under threshold
        let candidates = closest.filter {
            let coordinatePoint = self.convert($0.coordinate, toPointTo: self)
            return coordinatePoint.distance(to: point) < self.tapGestureDistanceThreshold
        }
        
        return candidates
    }
    
    private func routes(closeTo point: CGPoint) -> [Route]? {
        let tapCoordinate = convert(point, toCoordinateFrom: self)
        
        // do we have routes? If so, filter routes with at least 2 coordinates.
        guard let routes = routes?.filter({ $0.coordinates?.count ?? 0 > 1 }) else { return nil }
        
        // Sort routes by closest distance to tap gesture.
        let closest = routes.sorted { left, right -> Bool in
            
            // existance has been assured through use of filter.
            let leftLine = Polyline(left.coordinates!)
            let rightLine = Polyline(right.coordinates!)
            let leftDistance = leftLine.closestCoordinate(to: tapCoordinate)!.distance
            let rightDistance = rightLine.closestCoordinate(to: tapCoordinate)!.distance
            
            return leftDistance < rightDistance
        }
        
        // filter closest coordinates by which ones are under threshold.
        let candidates = closest.filter {
            let closestCoordinate = Polyline($0.coordinates!).closestCoordinate(to: tapCoordinate)!.coordinate
            let closestPoint = self.convert(closestCoordinate, toPointTo: self)
            
            return closestPoint.distance(to: point) < self.tapGestureDistanceThreshold
        }
        return candidates
    }

    func shape(for routes: [Route], legIndex: Int?) -> MLNShape? {
        guard let firstRoute = routes.first else { return nil }
        guard let congestedRoute = addCongestion(to: firstRoute, legIndex: legIndex) else { return nil }
        
        var altRoutes: [MLNPolylineFeature] = []
        
        for route in routes.suffix(from: 1) {
            let polyline = MLNPolylineFeature(coordinates: route.coordinates!, count: UInt(route.coordinates!.count))
            polyline.attributes["isAlternateRoute"] = true
            altRoutes.append(polyline)
        }
        
        return MLNShapeCollectionFeature(shapes: altRoutes + congestedRoute)
    }
    
    func addCongestion(to route: Route, legIndex: Int?) -> [MLNPolylineFeature]? {
        guard let coordinates = route.coordinates else { return nil }
        
        var linesPerLeg: [MLNPolylineFeature] = []
        
        for (index, leg) in route.legs.enumerated() {
            // If there is no congestion, don't try and add it
            guard let legCongestion = leg.segmentCongestionLevels, legCongestion.count < coordinates.count else {
                return [MLNPolylineFeature(coordinates: route.coordinates!, count: UInt(route.coordinates!.count))]
            }
            
            // The last coord of the preceding step, is shared with the first coord of the next step, we don't need both.
            let legCoordinates: [CLLocationCoordinate2D] = leg.steps.enumerated().reduce([]) { allCoordinates, current in
                let index = current.offset
                let step = current.element
                let stepCoordinates = step.coordinates!
                
                return index == 0 ? stepCoordinates : allCoordinates + stepCoordinates.suffix(from: 1)
            }
            
            let mergedCongestionSegments = self.combine(legCoordinates, with: legCongestion)
            
            let lines: [MLNPolylineFeature] = mergedCongestionSegments.map { (congestionSegment: CongestionSegment) -> MLNPolylineFeature in
                let polyline = MLNPolylineFeature(coordinates: congestionSegment.0, count: UInt(congestionSegment.0.count))
                polyline.attributes[MBCongestionAttribute] = String(describing: congestionSegment.1)
                polyline.attributes["isAlternateRoute"] = false
                if let legIndex {
                    polyline.attributes[MBCurrentLegAttribute] = index == legIndex
                } else {
                    polyline.attributes[MBCurrentLegAttribute] = index == 0
                }
                return polyline
            }
            
            linesPerLeg.append(contentsOf: lines)
        }
        
        return linesPerLeg
    }
    
    func combine(_ coordinates: [CLLocationCoordinate2D], with congestions: [CongestionLevel]) -> [CongestionSegment] {
        var segments: [CongestionSegment] = []
        segments.reserveCapacity(congestions.count)
        for (index, congestion) in congestions.enumerated() {
            let congestionSegment: ([CLLocationCoordinate2D], CongestionLevel) = ([coordinates[index], coordinates[index + 1]], congestion)
            let coordinates = congestionSegment.0
            let congestionLevel = congestionSegment.1
            
            if segments.last?.1 == congestionLevel {
                segments[segments.count - 1].0 += coordinates
            } else {
                segments.append(congestionSegment)
            }
        }
        return segments
    }
    
    func shape(forCasingOf route: Route, legIndex: Int?) -> MLNShape? {
        var linesPerLeg: [MLNPolylineFeature] = []
        
        for (index, leg) in route.legs.enumerated() {
            let legCoordinates: [CLLocationCoordinate2D] = Array(leg.steps.compactMap(\.coordinates).joined())
            
            let polyline = MLNPolylineFeature(coordinates: legCoordinates, count: UInt(legCoordinates.count))
            if let legIndex {
                polyline.attributes[MBCurrentLegAttribute] = index == legIndex
            } else {
                polyline.attributes[MBCurrentLegAttribute] = index == 0
            }
            linesPerLeg.append(polyline)
        }
        
        return MLNShapeCollectionFeature(shapes: linesPerLeg)
    }
    
    func shape(for waypoints: [Waypoint], legIndex: Int) -> MLNShape? {
        var features = [MLNPointFeature]()
        
        for (waypointIndex, waypoint) in waypoints.enumerated() {
            let feature = MLNPointFeature()
            feature.coordinate = waypoint.coordinate
            feature.attributes = [
                "waypointCompleted": waypointIndex < legIndex,
                "name": waypointIndex + 1
            ]
            features.append(feature)
        }
        
        return MLNShapeCollectionFeature(shapes: features)
    }
    
    func routeWaypointCircleStyleLayer(identifier: String, source: MLNSource) -> MLNStyleLayer {
        let circles = MLNCircleStyleLayer(identifier: waypointCircleIdentifier, source: source)
        let opacity = NSExpression(forConditional: NSPredicate(format: "waypointCompleted == true"), trueExpression: NSExpression(forConstantValue: 0.5), falseExpression: NSExpression(forConstantValue: 1))
        
        circles.circleColor = NSExpression(forConstantValue: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
        circles.circleOpacity = opacity
        circles.circleRadius = NSExpression(forConstantValue: 10)
        circles.circleStrokeColor = NSExpression(forConstantValue: UIColor.black)
        circles.circleStrokeWidth = NSExpression(forConstantValue: 1)
        circles.circleStrokeOpacity = opacity
        
        return circles
    }
    
    func routeWaypointSymbolStyleLayer(identifier: String, source: MLNSource) -> MLNStyleLayer {
        let symbol = MLNSymbolStyleLayer(identifier: identifier, source: source)
        
        symbol.text = NSExpression(format: "CAST(name, 'NSString')")
        symbol.textOpacity = NSExpression(forConditional: NSPredicate(format: "waypointCompleted == true"), trueExpression: NSExpression(forConstantValue: 0.5), falseExpression: NSExpression(forConstantValue: 1))
        symbol.textFontSize = NSExpression(forConstantValue: 10)
        symbol.textHaloWidth = NSExpression(forConstantValue: 0.25)
        symbol.textHaloColor = NSExpression(forConstantValue: UIColor.black)
        
        return symbol
    }
    
    func routeStyleLayer(identifier: String, source: MLNSource) -> MLNStyleLayer {
        let line = MLNLineStyleLayer(identifier: identifier, source: source)
        line.lineWidth = NSExpression(forMLNInterpolating: .zoomLevelVariable,
                                      curveType: .linear,
                                      parameters: nil,
                                      stops: NSExpression(forConstantValue: MLNRouteLineWidthByZoomLevel))
        line.lineColor = NSExpression(
            forConditional: NSPredicate(format: "isAlternateRoute == true"),
            trueExpression: NSExpression(forConstantValue: self.routeLineAlternativeColor),
            falseExpression: NSExpression(forConstantValue: self.routeLineColor))
        
        line.lineOpacity = NSExpression(
            forConditional: NSPredicate(format: "isAlternateRoute == true"),
            trueExpression: NSExpression(forConstantValue: ConfigManager.shared.config.routeLineAlternativeAlpha),
            falseExpression: NSExpression(forConstantValue: ConfigManager.shared.config.routeLineAlpha))
        
        line.lineCap = NSExpression(forConstantValue: "round")
        line.lineJoin = NSExpression(forConstantValue: "round")
        
        return line
    }
    
    func routeCasingStyleLayer(identifier: String, source: MLNSource) -> MLNStyleLayer {
        let lineCasing = MLNLineStyleLayer(identifier: identifier, source: source)
        
        // Take the default line width and make it wider for the casing
        lineCasing.lineWidth = NSExpression(forMLNInterpolating: .zoomLevelVariable,
                                            curveType: .linear,
                                            parameters: nil,
                                            stops: NSExpression(forConstantValue: MLNRouteLineWidthByZoomLevel.multiplied(by: 1.5)))
        
        lineCasing.lineColor = NSExpression(
            forConditional: NSPredicate(format: "isAlternateRoute == true"),
            trueExpression: NSExpression(forConstantValue: self.routeLineCasingAlternativeColor),
            falseExpression: NSExpression(forConstantValue: self.routeLineCasingColor))
        
        lineCasing.lineOpacity = NSExpression(
            forConditional: NSPredicate(format: "isAlternateRoute == true"),
            trueExpression: NSExpression(forConstantValue: ConfigManager.shared.config.routeLineCasingAlternativeAlpha),
            falseExpression: NSExpression(forConstantValue: ConfigManager.shared.config.routeLineCasingAlpha))
        
        lineCasing.lineCap = NSExpression(forConstantValue: "round")
        lineCasing.lineJoin = NSExpression(forConstantValue: "round")
        
        return lineCasing
    }
    
    /**
     Attempts to localize road labels into the local language and other labels
     into the system’s preferred language.
     
     When this property is enabled, the style automatically modifies the `text`
     property of any symbol style layer whose source is the
     <a href="https://www.mapbox.com/vector-tiles/mapbox-streets-v7/#overview">Mapbox
     Streets source</a>. On iOS, the user can set the system’s preferred
     language in Settings, General Settings, Language & Region.
     
     Unlike the `MLNStyle.localizeLabels(into:)` method, this method localizes
     road labels into the local language, regardless of the system’s preferred
     language, in an effort to match road signage. The turn banner always
     displays road names and exit destinations in the local language, so you
     should call this method in the
     `MLNMapViewDelegate.mapView(_:didFinishLoading:)` method of any delegate of
     a standalone `NavigationMapView`. The map view embedded in
     `NavigationViewController` is localized automatically, so you do not need
     to call this method on the value of `NavigationViewController.mapView`.
     */
    @objc public func localizeLabels() {
        guard let style else {
            return
        }
        
        let streetsSourceIdentifiers: [String] = style.sources.compactMap {
            $0 as? MLNVectorTileSource
        }.filter(\.isMapboxStreets).map(\.identifier)
        
        for layer in style.layers where layer is MLNSymbolStyleLayer {
            let layer = layer as! MLNSymbolStyleLayer
            guard let sourceIdentifier = layer.sourceIdentifier,
                  streetsSourceIdentifiers.contains(sourceIdentifier) else {
                continue
            }
            guard let text = layer.text else {
                continue
            }
            
            // Road labels should match road signage.
            let locale = layer.sourceLayerIdentifier == "road_label" ? Locale(identifier: "mul") : nil
            
            let localizedText = text.mgl_expressionLocalized(into: locale)
            if localizedText != text {
                layer.text = localizedText
            }
        }
    }
    
    @objc public func showVoiceInstructionsOnMap(route: Route) {
        guard let style else {
            return
        }
        
        var features = [MLNPointFeature]()
        for (legIndex, leg) in route.legs.enumerated() {
            for (stepIndex, step) in leg.steps.enumerated() {
                for instruction in step.instructionsSpokenAlongStep! {
                    let feature = MLNPointFeature()
                    feature.coordinate = Polyline(route.legs[legIndex].steps[stepIndex].coordinates!.reversed()).coordinateFromStart(distance: instruction.distanceAlongStep)!
                    feature.attributes = ["instruction": instruction.text]
                    features.append(feature)
                }
            }
        }
        
        let instructionPointSource = MLNShapeCollectionFeature(shapes: features)
        
        if let instructionSource = style.source(withIdentifier: instructionSource) as? MLNShapeSource {
            instructionSource.shape = instructionPointSource
        } else {
            let sourceShape = MLNShapeSource(identifier: instructionSource, shape: instructionPointSource, options: nil)
            style.addSource(sourceShape)
            
            let symbol = MLNSymbolStyleLayer(identifier: instructionLabel, source: sourceShape)
            symbol.text = NSExpression(format: "instruction")
            symbol.textFontSize = NSExpression(forConstantValue: 14)
            symbol.textHaloWidth = NSExpression(forConstantValue: 1)
            symbol.textHaloColor = NSExpression(forConstantValue: UIColor.white)
            symbol.textOpacity = NSExpression(forConstantValue: 0.75)
            symbol.textAnchor = NSExpression(forConstantValue: "bottom-left")
            symbol.textJustification = NSExpression(forConstantValue: "left")
            
            let circle = MLNCircleStyleLayer(identifier: instructionCircle, source: sourceShape)
            circle.circleRadius = NSExpression(forConstantValue: 5)
            circle.circleOpacity = NSExpression(forConstantValue: 0.75)
            circle.circleColor = NSExpression(forConstantValue: UIColor.white)
            
            style.addLayer(circle)
            style.addLayer(symbol)
        }
    }
    
    /**
     Sets the camera directly over a series of coordinates.
     */
    @objc public func setOverheadCameraView(from userLocation: CLLocationCoordinate2D, along coordinates: [CLLocationCoordinate2D], for bounds: UIEdgeInsets) {
        self.isAnimatingToOverheadMode = true
        let slicedLine = Polyline(coordinates).sliced(from: userLocation).coordinates
        let line = MLNPolyline(coordinates: slicedLine, count: UInt(slicedLine.count))
        
        self.tracksUserCourse = false
        
        // If the user has a short distance left on the route, prevent the camera from zooming all the way.
        // `MLNMapView.setVisibleCoordinateBounds(:edgePadding:animated:)` will go beyond what is convenient for the driver.
        guard line.overlayBounds.ne.distance(to: line.overlayBounds.sw) > NavigationMapViewMinimumDistanceForOverheadZooming else {
            let camera = camera
            camera.pitch = 0
            camera.heading = 0
            camera.centerCoordinate = userLocation
            camera.altitude = self.defaultAltitude
            setCamera(camera, withDuration: 1, animationTimingFunction: nil) { [weak self] in
                self?.isAnimatingToOverheadMode = false
            }
            return
        }
        
        let cam = camera
        cam.pitch = 0
        cam.heading = 0
        
        let cameraForLine = camera(cam, fitting: line, edgePadding: bounds)
        setCamera(cameraForLine, withDuration: 1, animationTimingFunction: nil) { [weak self] in
            self?.isAnimatingToOverheadMode = false
        }
    }
    
    /**
     Recenters the camera and begins tracking the user's location.
     */
    @objc public func recenterMap() {
        self.tracksUserCourse = true
        self.enableFrameByFrameCourseViewTracking(for: 3)
    }
}

/**
 The `NavigationMapViewDelegate` provides methods for configuring the NavigationMapView, as well as responding to events triggered by the NavigationMapView.
 */
@objc(MBNavigationMapViewDelegate)
public protocol NavigationMapViewDelegate: AnyObject {
    /**
     Asks the receiver to return an MLNStyleLayer for routes, given an identifier and source.
     This method is invoked when the map view loads and any time routes are added.
     - parameter mapView: The NavigationMapView.
     - parameter identifier: The style identifier.
     - parameter source: The Layer source containing the route data that this method would style.
     - returns: An MLNStyleLayer that the map applies to all routes.
     */
    @objc optional func navigationMapView(_ mapView: NavigationMapView, routeStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /**
     Asks the receiver to return an MLNStyleLayer for waypoints, given an identifier and source.
     This method is invoked when the map view loads and any time waypoints are added.
     - parameter mapView: The NavigationMapView.
     - parameter identifier: The style identifier.
     - parameter source: The Layer source containing the waypoint data that this method would style.
     - returns: An MLNStyleLayer that the map applies to all waypoints.
     */
    @objc optional func navigationMapView(_ mapView: NavigationMapView, waypointStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /**
     Asks the receiver to return an MLNStyleLayer for waypoint symbols, given an identifier and source.
     This method is invoked when the map view loads and any time waypoints are added.
     - parameter mapView: The NavigationMapView.
     - parameter identifier: The style identifier.
     - parameter source: The Layer source containing the waypoint data that this method would style.
     - returns: An MLNStyleLayer that the map applies to all waypoint symbols.
     */
    @objc optional func navigationMapView(_ mapView: NavigationMapView, waypointSymbolStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /**
     Asks the receiver to return an MLNStyleLayer for route casings, given an identifier and source.
     This method is invoked when the map view loads and anytime routes are added.
     - note: Specify a casing to ensure good contrast between the route line and the underlying map layers.
     - parameter mapView: The NavigationMapView.
     - parameter identifier: The style identifier.
     - parameter source: The Layer source containing the route data that this method would style.
     - returns: An MLNStyleLayer that the map applies to the route.
     */
    @objc optional func navigationMapView(_ mapView: NavigationMapView, routeCasingStyleLayerWithIdentifier identifier: String, source: MLNSource) -> MLNStyleLayer?
    
    /**
      Tells the receiver that the user has selected a route by interacting with the map view.
      - parameter mapView: The NavigationMapView.
      - parameter route: The route that was selected.
     */
    @objc(navigationMapView:didSelectRoute:)
    optional func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route)
    
    /**
     Tells the receiver that a waypoint was selected.
     - parameter mapView: The NavigationMapView.
     - parameter waypoint: The waypoint that was selected.
     */
    @objc(navigationMapView:didSelectWaypoint:)
    optional func navigationMapView(_ mapView: NavigationMapView, didSelect waypoint: Waypoint)
    
    /**
     Asks the receiver to return an MLNShape that describes the geometry of the route.
     - note: The returned value represents the route in full detail. For example, individual `MLNPolyline` objects in an `MLNShapeCollectionFeature` object can represent traffic congestion segments. For improved performance, you should also implement `navigationMapView(_:simplifiedShapeFor:)`, which defines the overall route as a single feature.
     - parameter mapView: The NavigationMapView.
     - parameter routes: The routes that the sender is asking about. The first route will always be rendered as the main route, while all subsequent routes will be rendered as alternate routes.
     - returns: Optionally, a `MLNShape` that defines the shape of the route, or `nil` to use default behavior.
     */
    @objc(navigationMapView:shapeForRoutes:)
    optional func navigationMapView(_ mapView: NavigationMapView, shapeFor routes: [Route]) -> MLNShape?
    
    /**
     Asks the receiver to return an MLNShape that describes the geometry of the route at lower zoomlevels.
     - note: The returned value represents the simplfied route. It is designed to be used with `navigationMapView(_:shapeFor:), and if used without its parent method, can cause unexpected behavior.
     - parameter mapView: The NavigationMapView.
     - parameter route: The route that the sender is asking about.
     - returns: Optionally, a `MLNShape` that defines the shape of the route at lower zoomlevels, or `nil` to use default behavior.
     */
    @objc(navigationMapView:simplifiedShapeForRoute:)
    optional func navigationMapView(_ mapView: NavigationMapView, simplifiedShapeFor route: Route) -> MLNShape?
    
    /**
     Asks the receiver to return an MLNShape that describes the geometry of the waypoint.
     - parameter mapView: The NavigationMapView.
     - parameter waypoints: The waypoints to be displayed on the map.
     - returns: Optionally, a `MLNShape` that defines the shape of the waypoint, or `nil` to use default behavior.
     */
    @objc(navigationMapView:shapeForWaypoints:legIndex:)
    optional func navigationMapView(_ mapView: NavigationMapView, shapeFor waypoints: [Waypoint], legIndex: Int) -> MLNShape?
    
    /**
     Asks the receiver to return an MLNAnnotationImage that describes the image used an annotation.
     - parameter mapView: The MLNMapView.
     - parameter annotation: The annotation to be styled.
     - returns: Optionally, a `MLNAnnotationImage` that defines the image used for the annotation.
     */
    @objc(navigationMapView:imageForAnnotation:)
    optional func navigationMapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage?
    
    /**
     Asks the receiver to return an MLNAnnotationView that describes the image used an annotation.
     - parameter mapView: The MLNMapView.
     - parameter annotation: The annotation to be styled.
     - returns: Optionally, a `MLNAnnotationView` that defines the view used for the annotation.
     */
    @objc(navigationMapView:viewForAnnotation:)
    optional func navigationMapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView?
    
    /**
      Asks the receiver to return a CGPoint to serve as the anchor for the user icon.
      - important: The return value should be returned in the normal UIKit coordinate-space, NOT CoreAnimation's unit coordinate-space.
      - parameter mapView: The NavigationMapView.
      - returns: A CGPoint (in regular coordinate-space) that represents the point on-screen where the user location icon should be drawn.
     */
    @objc(navigationMapViewUserAnchorPoint:)
    optional func navigationMapViewUserAnchorPoint(_ mapView: NavigationMapView) -> CGPoint
}

// MARK: NavigationMapViewCourseTrackingDelegate

/**
 The `NavigationMapViewCourseTrackingDelegate` provides methods for responding to the `NavigationMapView` starting or stopping course tracking.
 */
@objc(MBNavigationMapViewCourseTrackingDelegate)
public protocol NavigationMapViewCourseTrackingDelegate: AnyObject {
    /**
     Tells the receiver that the map is now tracking the user course.
     - seealso: NavigationMapView.tracksUserCourse
     - parameter mapView: The NavigationMapView.
     */
    @objc(navigationMapViewDidStartTrackingCourse:)
    optional func navigationMapViewDidStartTrackingCourse(_ mapView: NavigationMapView)
    
    /**
     Tells the receiver that `tracksUserCourse` was set to false, signifying that the map is no longer tracking the user course.
     - seealso: NavigationMapView.tracksUserCourse
     - parameter mapView: The NavigationMapView.
     */
    @objc(navigationMapViewDidStopTrackingCourse:)
    optional func navigationMapViewDidStopTrackingCourse(_ mapView: NavigationMapView)
    
    /**
     Allows to pass a custom camera location given the current route progress. If you return true, the camera won't be updated by the NavigationMapView.
     - parameter mapView: The NavigationMapView.
     - parameter location: The current user location
     - parameter routeProgress: The current route progress
     */
    @objc(navigationMapView:location:routeProgress:)
    optional func updateCamera(_ mapView: NavigationMapView, location: CLLocation, routeProgress: RouteProgress) -> Bool
}
