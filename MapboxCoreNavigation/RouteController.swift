import CoreLocation
import Foundation
import MapboxDirections
import Polyline
import Turf
import UIKit

/**
 A `RouteController` tracks the user’s progress along a route, posting notifications as the user reaches significant points along the route. On every location update, the route controller evaluates the user’s location, determining whether the user remains on the route. If not, the route controller calculates a new route.

 `RouteController` is responsible for the core navigation logic whereas
 `NavigationViewController` is responsible for displaying a default drop-in navigation UI.
 */
@objc(MBRouteController)
open class RouteController: NSObject, Router {
    /**
     The number of seconds between attempts to automatically calculate a more optimal route while traveling.
     */
    public var routeControllerProactiveReroutingInterval: TimeInterval = 120
    
    /// With this property you can enable test-routes to be returned when rerouting for an ETA update. It will randomly choose a route between two that differ a lot by ETA when rerouting
    /// These will only get returned when that route is _slower_ than the current route, as that forces an ETA update reroute.
    /// To pass the rerouting checks, simulate or drive a route from coordinate `52.02224357,5.78149084` to `52.03924958,5.55054131`
    public var shouldReturnTestingETAUpdateReroutes = false
    
    /// Determines if we should check for a faster/more updated route in the last 10 minutes of the user's route. By default, we don't check this before doing the reroute call.
    public var shouldCheckForRerouteInLastMinutes = false

    /**
     The route controller’s delegate.
     */
    @objc public weak var delegate: RouteControllerDelegate?

    /**
     The route controller’s associated location manager.
     */
    @objc public var locationManager: NavigationLocationManager! {
        didSet {
            oldValue.delegate = nil
            self.locationManager.delegate = self
        }
    }
    
    /**
     The Directions object used to create the route.
     */
    @objc public var directions: Directions

    /**
     If true, location updates will be simulated when driving through tunnels or other areas where there is none or bad GPS reception.
     */
    @objc public var isDeadReckoningEnabled = false

    /**
     If true, the `RouteController` attempts to calculate a more optimal route for the user on an interval defined by `routeControllerProactiveReroutingInterval`.
     */
    @objc public var reroutesProactively = false

    /**
     A `TunnelIntersectionManager` used for animating the use user puck when and if a user enters a tunnel.
     
     Will only be enabled if `tunnelSimulationEnabled` is true.
     */
    public var tunnelIntersectionManager: TunnelIntersectionManager = .init()

    /**
     If true, the first voice announcement is always triggered when beginning a leg.
     */
    public var speakFirstInstructionOnFirstStep = true

    var didFindFasterRoute = false

    /**
     Details about the user’s progress along the current route, leg, and step.
     */
    @objc public var routeProgress: RouteProgress {
        didSet {
            var userInfo = [RouteControllerNotificationUserInfoKey: Any]()
            if let location = locationManager.location {
                userInfo[.locationKey] = location
            }
            userInfo[.isProactiveKey] = self.didFindFasterRoute
            NotificationCenter.default.post(name: .routeControllerDidReroute, object: self, userInfo: userInfo)
            self.movementsAwayFromRoute = 0
        }
    }

    var isRerouting = false
    var lastRerouteLocation: CLLocation?
    
    var isFindingFasterRoute = false

    var routeTask: URLSessionDataTask?
    var lastLocationDate: Date?

    /// :nodoc: This is used internally when the navigation UI is being used
    public var usesDefaultUserInterface = false

    var hasFoundOneQualifiedLocation = false

    var movementsAwayFromRoute = 0

    var previousArrivalWaypoint: Waypoint?

    var userSnapToStepDistanceFromManeuver: CLLocationDistance?
    
    /// Describes a reason for rerouting and applying a new route
    @objc public enum RerouteReason: Int, CustomStringConvertible {
        /// When we check for a faster route we can also reroute the user when we just want to update the ETA. For example when the user is driving on a route where a Trafficjam appears, it should update the ETA
        case ETAUpdate
        
        /// When the user diverts from the route, we reroute to take the new diversion into account
        case divertedFromRoute
        
        /// When the route is faster than the current route, we can also reroute the user
        case fasterRoute
        
        // Needed to expose real case name to Swift when using @obj-c enum
        public var description: String {
            switch self {
            case .ETAUpdate:
                "ETAUpdate"
            case .fasterRoute:
                "fasterRoute"
            case .divertedFromRoute:
                "divertedFromRoute"
            }
        }
    }
    
    /**
     Intializes a new `RouteController`.

     - parameter route: The route to follow.
     - parameter directions: The Directions object that created `route`.
     - parameter locationManager: The associated location manager.
     */
    @objc(initWithRoute:directions:locationManager:)
    public init(along route: Route, directions: Directions = Directions.shared, locationManager: NavigationLocationManager = NavigationLocationManager()) {
        self.directions = directions
        self.routeProgress = RouteProgress(route: route)
        self.locationManager = locationManager
        self.locationManager.activityType = route.routeOptions.activityType
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        super.init()

        self.locationManager.delegate = self
        self.resumeNotifications()

        checkForUpdates()
        checkForLocationUsageDescription()
        
        self.tunnelIntersectionManager.delegate = self
    }

    deinit {
        endNavigation()
        
        guard let shouldDisable = delegate?.routeControllerShouldDisableBatteryMonitoring?(self) else {
            UIDevice.current.isBatteryMonitoringEnabled = false
            return
        }
        
        if shouldDisable {
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
    }

    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
    }

    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applicationWillTerminate(_ notification: NSNotification) {
        self.endNavigation()
    }
    
    /**
     Starts monitoring the user’s location along the route.

     Will continue monitoring until `suspendLocationUpdates()` is called.
     */
    @objc public func resume() {
        self.locationManager.delegate = self
        self.locationManager.startUpdatingLocation()
        self.locationManager.startUpdatingHeading()
    }

    /**
     Stops monitoring the user’s location along the route.
     */
    @objc public func suspendLocationUpdates() {
        self.locationManager.stopUpdatingLocation()
        self.locationManager.stopUpdatingHeading()
        self.locationManager.delegate = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(interpolateLocation), object: nil)
    }
    
    /**
     Ends the current navigation session.
     */
    @objc public func endNavigation() {
        self.suspendLocationUpdates()
        self.suspendNotifications()
    }

    /**
     The idealized user location. Snapped to the route line, if applicable, otherwise raw.
     - seeAlso: snappedLocation, rawLocation
     */
    @objc public var location: CLLocation? {
        // If there is no snapped location, and the rawLocation course is unqualified, use the user's heading as long as it is accurate.
        if self.snappedLocation == nil,
           let heading,
           let loc = rawLocation,
           !loc.course.isQualified,
           heading.trueHeading.isQualified {
            return CLLocation(coordinate: loc.coordinate, altitude: loc.altitude, horizontalAccuracy: loc.horizontalAccuracy, verticalAccuracy: loc.verticalAccuracy, course: heading.trueHeading, speed: loc.speed, timestamp: loc.timestamp)
        }

        return self.snappedLocation ?? self.rawLocation
    }

    /**
     The raw location, snapped to the current route.
     - important: If the rawLocation is outside of the route snapping tolerances, this value is nil.
     */
    var snappedLocation: CLLocation? {
        self.rawLocation?.snapped(to: self.routeProgress.currentLegProgress)
    }

    var heading: CLHeading?

    /**
     The most recently received user location.
     - note: This is a raw location received from `locationManager`. To obtain an idealized location, use the `location` property.
     */
    var rawLocation: CLLocation? {
        didSet {
            self.updateDistanceToManeuver()
        }
    }

    func updateDistanceToManeuver() {
        guard let coordinates = routeProgress.currentLegProgress.currentStep.coordinates, let coordinate = rawLocation?.coordinate else {
            self.userSnapToStepDistanceFromManeuver = nil
            return
        }
        self.userSnapToStepDistanceFromManeuver = Polyline(coordinates).distance(from: coordinate)
    }

    /**
     If the user is close to an intersection, the tolerance will be lower, otherwise it will be RouteControllerMaximumDistanceBeforeRecalculating
     */
    @objc public var reroutingTolerance: CLLocationDistance {
        guard let intersections = routeProgress.currentLegProgress.currentStepProgress.intersectionsIncludingUpcomingManeuverIntersection else { return RouteControllerMaximumDistanceBeforeRecalculating }
        guard let userLocation = rawLocation else { return RouteControllerMaximumDistanceBeforeRecalculating }

        for intersection in intersections {
            let absoluteDistanceToIntersection = userLocation.coordinate.distance(to: intersection.location)

            if absoluteDistanceToIntersection <= RouteControllerManeuverZoneRadius {
                return RouteControllerMaximumDistanceBeforeRecalculating / 2
            }
        }
        return RouteControllerMaximumDistanceBeforeRecalculating
    }
    
    // MARK: - Pre-defined routes for testing

    private lazy var testA12ToVeenendaalNormalWithTraffic = Route(
        jsonFileName: "A12-To-Veenendaal-Normal-With-Big-Trafficjam",
        waypoints: [
            CLLocationCoordinate2D(latitude: 52.02224357, longitude: 5.78149084),
            CLLocationCoordinate2D(latitude: 52.03924958, longitude: 5.55054131)
        ],
        bundle: .mapboxCoreNavigation,
        accessToken: "nonsense"
    )
    
    private lazy var testA12ToVeenendaalNormal = Route(
        jsonFileName: "A12-To-Veenendaal-Normal",
        waypoints: [
            CLLocationCoordinate2D(latitude: 52.02224357, longitude: 5.78149084),
            CLLocationCoordinate2D(latitude: 52.03924958, longitude: 5.55054131)
        ],
        bundle: .mapboxCoreNavigation,
        accessToken: "nonsense"
    )
}

// MARK: - CLLocationManagerDelegate

extension RouteController: CLLocationManagerDelegate {
    @objc func interpolateLocation() {
        guard let location = locationManager.lastKnownLocation else { return }
        guard let coordinates = routeProgress.route.coordinates else { return }
        let polyline = Polyline(coordinates)

        let distance = location.speed as CLLocationDistance

        guard let interpolatedCoordinate = polyline.coordinateFromStart(distance: routeProgress.distanceTraveled + distance) else {
            return
        }

        var course = location.course
        if let upcomingCoordinate = polyline.coordinateFromStart(distance: routeProgress.distanceTraveled + (distance * 2)) {
            course = interpolatedCoordinate.direction(to: upcomingCoordinate)
        }

        let interpolatedLocation = CLLocation(coordinate: interpolatedCoordinate,
                                              altitude: location.altitude,
                                              horizontalAccuracy: location.horizontalAccuracy,
                                              verticalAccuracy: location.verticalAccuracy,
                                              course: course,
                                              speed: location.speed,
                                              timestamp: Date())

        self.locationManager(self.locationManager, didUpdateLocations: [interpolatedLocation])
    }

    @objc public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = newHeading
    }

    @objc public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let filteredLocations = locations.filter(\.isQualified)

        if !filteredLocations.isEmpty, self.hasFoundOneQualifiedLocation == false {
            self.hasFoundOneQualifiedLocation = true
        }

        let currentStepProgress = self.routeProgress.currentLegProgress.currentStepProgress
        
        var potentialLocation: CLLocation?

        // `filteredLocations` contains qualified locations
        if let lastFiltered = filteredLocations.last {
            potentialLocation = lastFiltered
            // `filteredLocations` does not contain good locations and we have found at least one good location previously.
        } else if self.hasFoundOneQualifiedLocation {
            if let lastLocation = locations.last, delegate?.routeController?(self, shouldDiscard: lastLocation) ?? true {
                // Allow the user puck to advance. A stationary puck is not great.
                self.rawLocation = lastLocation
                
                // Check for a tunnel intersection at the current step we found the bad location update.
                self.tunnelIntersectionManager.checkForTunnelIntersection(at: lastLocation, routeProgress: self.routeProgress)
                
                return
            }
            // This case handles the first location.
            // This location is not a good location, but we need the rest of the UI to update and at least show something.
        } else if let lastLocation = locations.last {
            potentialLocation = lastLocation
        }

        guard let location = potentialLocation else {
            return
        }

        self.rawLocation = location

        self.delegate?.routeController?(self, didUpdate: [location])

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.interpolateLocation), object: nil)

        if self.isDeadReckoningEnabled {
            perform(#selector(self.interpolateLocation), with: nil, afterDelay: 1.1)
        }

        let currentStep = currentStepProgress.step

        self.updateIntersectionIndex(for: currentStepProgress)
        // Notify observers if the step’s remaining distance has changed.
        let polyline = Polyline(routeProgress.currentLegProgress.currentStep.coordinates!)
        if let closestCoordinate = polyline.closestCoordinate(to: location.coordinate) {
            let remainingDistance = polyline.distance(from: closestCoordinate.coordinate)
            let distanceTraveled = currentStep.distance - remainingDistance
            currentStepProgress.distanceTraveled = distanceTraveled
            NotificationCenter.default.post(name: .routeControllerProgressDidChange, object: self, userInfo: [
                RouteControllerNotificationUserInfoKey.routeProgressKey: self.routeProgress,
                RouteControllerNotificationUserInfoKey.locationKey: self.location!, // guaranteed value
                RouteControllerNotificationUserInfoKey.rawLocationKey: location // raw
            ])
            
            // Check for a tunnel intersection whenever the current route step progresses.
            self.tunnelIntersectionManager.checkForTunnelIntersection(at: location, routeProgress: self.routeProgress)
        }

        self.updateDistanceToIntersection(from: location)
        self.updateRouteStepProgress(for: location)
        self.updateRouteLegProgress(for: location)
        self.updateVisualInstructionProgress()

        guard self.userIsOnRoute(location) || !(self.delegate?.routeController?(self, shouldRerouteFrom: location) ?? true) else {
            self.rerouteForDiversion(from: location, along: self.routeProgress)
            return
        }

        self.updateSpokenInstructionProgress()

        // Check for faster route given users current location
        guard self.reroutesProactively else { return }
        
        // Only check for faster routes or ETA updates if the user has plenty of time left on the route (10+min)
        // Except when configured in the SDK that we may
        guard self.routeProgress.durationRemaining > 600 || !self.shouldCheckForRerouteInLastMinutes else { return }
        
        // If the user is approaching a maneuver (within 70secs of the maneuver), don't check for a faster routes or ETA updates
        guard self.routeProgress.currentLegProgress.currentStepProgress.durationRemaining > RouteControllerMediumAlertInterval else { return }
        
        self.checkForNewRoute(from: location)
    }
        
    func updateIntersectionIndex(for currentStepProgress: RouteStepProgress) {
        guard let intersectionDistances = currentStepProgress.intersectionDistances else { return }
        let upcomingIntersectionIndex = intersectionDistances.firstIndex { $0 > currentStepProgress.distanceTraveled } ?? intersectionDistances.endIndex
        currentStepProgress.intersectionIndex = upcomingIntersectionIndex > 0 ? intersectionDistances.index(before: upcomingIntersectionIndex) : 0
    }

    func updateRouteLegProgress(for location: CLLocation) {
        let currentDestination = self.routeProgress.currentLeg.destination
        guard let remainingVoiceInstructions = routeProgress.currentLegProgress.currentStepProgress.remainingSpokenInstructions else { return }

        if self.routeProgress.currentLegProgress.remainingSteps.count <= 1, remainingVoiceInstructions.count == 0, currentDestination != self.previousArrivalWaypoint {
            self.previousArrivalWaypoint = currentDestination

            self.routeProgress.currentLegProgress.userHasArrivedAtWaypoint = true

            let advancesToNextLeg = self.delegate?.routeController?(self, didArriveAt: currentDestination) ?? true

            if !self.routeProgress.isFinalLeg, advancesToNextLeg {
                self.routeProgress.legIndex += 1
                self.updateDistanceToManeuver()
            }
        }
    }

    /**
     Monitors the user's course to see if it is consistently moving away from what we expect the course to be at a given point.
     */
    func userCourseIsOnRoute(_ location: CLLocation) -> Bool {
        let nearByCoordinates = self.routeProgress.currentLegProgress.nearbyCoordinates
        guard let calculatedCourseForLocationOnStep = location.interpolatedCourse(along: nearByCoordinates) else { return true }

        let maxUpdatesAwayFromRouteGivenAccuracy = Int(location.horizontalAccuracy / Double(RouteControllerIncorrectCourseMultiplier))

        if self.movementsAwayFromRoute >= max(RouteControllerMinNumberOfInCorrectCourses, maxUpdatesAwayFromRouteGivenAccuracy) {
            return false
        } else if location.shouldSnapCourse(toRouteWith: calculatedCourseForLocationOnStep) {
            self.movementsAwayFromRoute = 0
        } else {
            self.movementsAwayFromRoute += 1
        }

        return true
    }

    /**
     Given a users current location, returns a Boolean whether they are currently on the route.

     If the user is not on the route, they should be rerouted.
     */
    @objc public func userIsOnRoute(_ location: CLLocation) -> Bool {
        // If the user has arrived, do not continue monitor reroutes, step progress, etc
        guard !self.routeProgress.currentLegProgress.userHasArrivedAtWaypoint && (self.delegate?.routeController?(self, shouldPreventReroutesWhenArrivingAt: self.routeProgress.currentLeg.destination) ?? true) else {
            return true
        }

        // If user is close to an intersection, the radius will be lower, so reroutes will fire easier.
        let radius = max(reroutingTolerance, RouteControllerManeuverZoneRadius)
        
        // This checks all coordinates of the step, if user is close to the step, they on the route
        let isCloseToCurrentStep = location.isWithin(radius, of: self.routeProgress.currentLegProgress.currentStep)

        // If the user is either close to the current step or at least driving in the right direction, we assume the user is on route
        guard !isCloseToCurrentStep || !self.userCourseIsOnRoute(location) else { return true }
        
        // Check and see if the user is near a future step.
        guard let nearestStep = routeProgress.currentLegProgress.closestStep(to: location.coordinate) else {
            return false
        }

        if nearestStep.distance < RouteControllerUserLocationSnappingDistance {
            // Only advance the stepIndex to a future step if the step is new. Otherwise, the user is still on the current step.
            if nearestStep.index != self.routeProgress.currentLegProgress.stepIndex {
                self.advanceStepIndex(to: nearestStep.index)
            }
            return true
        }

        return false
    }
    
    func checkForNewRoute(from location: CLLocation) {
        guard !self.isFindingFasterRoute else {
            return
        }
        
        guard let currentUpcomingManeuver = routeProgress.currentLegProgress.upComingStep else {
            return
        }

        guard let lastLocationDate else {
            self.lastLocationDate = location.timestamp
            return
        }

        // Only check every so often for a faster route.
        guard location.timestamp.timeIntervalSince(lastLocationDate) >= self.routeControllerProactiveReroutingInterval else {
            return
        }
        
        let durationRemaining = self.routeProgress.durationRemaining
        
        self.isFindingFasterRoute = true
        
        print("[RouteController] Checking for faster/updated route...")

        self.getDirections(from: location, along: self.routeProgress) { [weak self] mostSimilarRoute, routes, _ in
            guard let self else { return }
            
            // Every request should reset the lastLocationDate, else we spam the server by calling this method every location update.
            // If the call fails, tough luck buddy! Then wait until the next interval before retrying
            self.lastLocationDate = nil
            
            // Also only do one 'findFasterRoute' call per time
            self.isFindingFasterRoute = false
            
            guard let route = mostSimilarRoute, let routes else {
                return
            }
            
            self.applyNewRerouteIfNeeded(mostSimilarRoute: route, allRoutes: routes, currentUpcomingManeuver: currentUpcomingManeuver, durationRemaining: durationRemaining)
        }
    }
    
    func applyNewRerouteIfNeeded(mostSimilarRoute: Route, allRoutes: [Route], currentUpcomingManeuver: RouteStep, durationRemaining: TimeInterval) {
        guard let firstLeg = mostSimilarRoute.legs.first, let firstStep = firstLeg.steps.first else {
            return
        }
        
        // Current and First step of old and new route should be significant enough of a maneuver before applying a faster route, so we don't apply the route just before a maneuver will occur
        let isFirstStepSignificant = firstStep.expectedTravelTime >= RouteControllerMediumAlertInterval && self.routeProgress.currentLegProgress.currentStepProgress.durationRemaining > RouteControllerMediumAlertInterval
        
        // Current maneuver should correspond to the next maneuver in the new route
        let hasSameUpcomingManeuver = firstLeg.steps.indices.contains(1) ? currentUpcomingManeuver == firstLeg.steps[1] : false
        
        // Check if the new route is faster by comparing the ETA to the current ETA. Should be 10% faster or more
        let isRouteFaster = mostSimilarRoute.expectedTravelTime <= 0.9 * durationRemaining
        
        // Only check for alternatives if the user has plenty of time left on the route (10min+)
        let userHasEnoughTimeOnRoute = self.routeProgress.durationRemaining > 600
        
        print("[RouteController] applyNewRerouteIfNeeded called -> Significant first step: \(isFirstStepSignificant), Same upcoming maneuver: \(hasSameUpcomingManeuver), Route is faster: \(isRouteFaster)")
        
        // Check if we should apply faster route
        let shouldApplyFasterRoute = isFirstStepSignificant && hasSameUpcomingManeuver && isRouteFaster && userHasEnoughTimeOnRoute
        
        // Check if we should apply slower route
        let shouldApplySlowerRoute = isFirstStepSignificant && hasSameUpcomingManeuver
        
        if shouldApplyFasterRoute {
            print("[RouteController] Found faster route")
            
            // Need to set this for notifications being sent
            self.didFindFasterRoute = true
            
            // If the upcoming maneuver in the new route is the same as the current upcoming maneuver, don't announce it again, just set new progress
            self.routeProgress = RouteProgress(route: mostSimilarRoute, legIndex: 0, spokenInstructionIndex: self.routeProgress.currentLegProgress.currentStepProgress.spokenInstructionIndex)
            
            // Let delegate know
            self.delegate?.routeController?(self, didRerouteAlong: mostSimilarRoute, reason: .fasterRoute)
            
            // Reset flag for notification
            self.didFindFasterRoute = false
        }
        
        // If route is not faster, but matches criteria and we get a match that is similar enough (so we don't apply a route alternative that the user doesn't want), we will apply the route too
        else if shouldApplySlowerRoute, let matchingRoute = Self.bestMatch(for: routeProgress.route, and: allRoutes) {
            // Check if the time difference is more than 30 seconds between best match and current ETA for extra measure
            let isExpectedTravelTimeChangedSignificantly = abs(routeProgress.durationRemaining - matchingRoute.route.expectedTravelTime) > 30
            print("[RouteController] New ETA differs more than 30s from current ETA: \(isExpectedTravelTimeChangedSignificantly)")
            
            var routeToApply = matchingRoute.route
            
            // When testing flag is flipped, return instead one of the testing routes
            if self.shouldReturnTestingETAUpdateReroutes {
                let rightOrLeft = Bool.random()
                routeToApply = rightOrLeft ? self.testA12ToVeenendaalNormal : self.testA12ToVeenendaalNormalWithTraffic
                print("[RouteController] Testing route: ON")
            }
                
            if isExpectedTravelTimeChangedSignificantly || self.shouldReturnTestingETAUpdateReroutes {
                // Set new route and inform delegates
                print("[RouteController] Found matching route \(matchingRoute.matchPercentage)%, updating ETA...")
                print("[RouteController] Duration remaining CURRENT: \(self.routeProgress.durationRemaining)")
                print("[RouteController] Expected travel time: \(matchingRoute.route.expectedTravelTime)")
                print("[RouteController] Set the new route")
                
                // Don't announce new route
                self.routeProgress = RouteProgress(route: routeToApply, legIndex: 0, spokenInstructionIndex: self.routeProgress.currentLegProgress.currentStepProgress.spokenInstructionIndex)
                
                // Inform delegate
                self.delegate?.routeController?(self, didRerouteAlong: routeToApply, reason: .ETAUpdate)
            }
        }
    }

    /// Reroutes the user when the user isn't on the route anymore
    func rerouteForDiversion(from location: CLLocation, along progress: RouteProgress) {
        if let lastRerouteLocation {
            guard location.distance(from: lastRerouteLocation) >= RouteControllerMaximumDistanceBeforeRecalculating else {
                return
            }
        }

        if self.isRerouting {
            return
        }

        self.isRerouting = true

        self.delegate?.routeController?(self, willRerouteFrom: location)
        NotificationCenter.default.post(name: .routeControllerWillReroute, object: self, userInfo: [
            RouteControllerNotificationUserInfoKey.locationKey: location
        ])

        lastRerouteLocation = location

        self.getDirections(from: location, along: progress) { [weak self] route, _, error in
            guard let strongSelf = self else {
                return
            }
            
            // Update the rerouting state
            strongSelf.isRerouting = false

            if let error {
                strongSelf.delegate?.routeController?(strongSelf, didFailToRerouteWith: error)
                NotificationCenter.default.post(name: .routeControllerDidFailToReroute, object: self, userInfo: [
                    RouteControllerNotificationUserInfoKey.routingErrorKey: error
                ])
                return
            }

            guard let route else { return }

            strongSelf.routeProgress = RouteProgress(route: route, legIndex: 0)
            strongSelf.routeProgress.currentLegProgress.stepIndex = 0
            strongSelf.delegate?.routeController?(strongSelf, didRerouteAlong: route, reason: .divertedFromRoute)
        }
    }

    private func checkForUpdates() {
        #if TARGET_IPHONE_SIMULATOR
        guard let version = Bundle(for: RouteController.self).object(forInfoDictionaryKey: "CFBundleShortVersionString") else { return }
        let latestVersion = String(describing: version)
        _ = URLSession.shared.dataTask(with: URL(string: "https://www.mapbox.com/mapbox-navigation-ios/latest_version")!, completionHandler: { data, response, error in
            if let _ = error { return }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

            guard let data, let currentVersion = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) else { return }

            if latestVersion != currentVersion {
                let updateString = NSLocalizedString("UPDATE_AVAILABLE", bundle: .mapboxCoreNavigation, value: "Mapbox Navigation SDK for iOS version %@ is now available.", comment: "Inform developer an update is available")
                print(String.localizedStringWithFormat(updateString, latestVersion), "https://github.com/mapbox/mapbox-navigation-ios/releases/tag/v\(latestVersion)")
            }
        }).resume()
        #endif
    }

    private func checkForLocationUsageDescription() {
        guard let _ = Bundle.main.bundleIdentifier else {
            return
        }
        if Bundle.main.locationAlwaysUsageDescription == nil, Bundle.main.locationWhenInUseUsageDescription == nil, Bundle.main.locationAlwaysAndWhenInUseUsageDescription == nil {
            preconditionFailure("This application’s Info.plist file must include a NSLocationWhenInUseUsageDescription. See https://developer.apple.com/documentation/corelocation for more information.")
        }
    }

    func getDirections(from location: CLLocation, along progress: RouteProgress, completion: @escaping (_ mostSimilarRoute: Route?, _ routes: [Route]?, _ error: Error?) -> Void) {
        if self.delegate?.routeControllerGetDirections?(from: location, along: progress, completion: completion) != true {
            // Run the default route calculation if the delegate method is not defined or does not return true
            self.routeTask?.cancel()
            let options = progress.reroutingOptions(with: location)
            
            self.lastRerouteLocation = location
            
            let complete = { (mostSimilarRoute: Route?, routes: [Route]?, error: NSError?) in
                completion(mostSimilarRoute, routes, error)
            }
            
            self.routeTask = self.directions.calculate(options) { _, potentialRoutes, potentialError in
                
                guard let routes = potentialRoutes else {
                    return complete(nil, nil, potentialError)
                }
                
                // Checks by comparing leg `name` properties and see if the edit distance is within threshold
                let mostSimilar = routes.mostSimilar(to: progress.route)
                return complete(mostSimilar ?? routes.first, routes, potentialError)
            }
        }
    }

    func updateDistanceToIntersection(from location: CLLocation) {
        guard var intersections = routeProgress.currentLegProgress.currentStepProgress.step.intersections else { return }
        let currentStepProgress = self.routeProgress.currentLegProgress.currentStepProgress

        // The intersections array does not include the upcoming maneuver intersection.
        if let upcomingStep = routeProgress.currentLegProgress.upComingStep, let upcomingIntersection = upcomingStep.intersections, let firstUpcomingIntersection = upcomingIntersection.first {
            intersections += [firstUpcomingIntersection]
        }

        self.routeProgress.currentLegProgress.currentStepProgress.intersectionsIncludingUpcomingManeuverIntersection = intersections

        if let upcomingIntersection = routeProgress.currentLegProgress.currentStepProgress.upcomingIntersection {
            self.routeProgress.currentLegProgress.currentStepProgress.userDistanceToUpcomingIntersection = Polyline(currentStepProgress.step.coordinates!).distance(from: location.coordinate, to: upcomingIntersection.location)
        }
        
        if self.routeProgress.currentLegProgress.currentStepProgress.intersectionDistances == nil {
            self.routeProgress.currentLegProgress.currentStepProgress.intersectionDistances = [CLLocationDistance]()
            self.updateIntersectionDistances()
        }
    }

    func updateRouteStepProgress(for location: CLLocation) {
        guard self.routeProgress.currentLegProgress.remainingSteps.count > 0 else { return }

        guard let userSnapToStepDistanceFromManeuver else { return }
        var courseMatchesManeuverFinalHeading = false

        // Bearings need to normalized so when the `finalHeading` is 359 and the user heading is 1,
        // we count this as within the `RouteControllerMaximumAllowedDegreeOffsetForTurnCompletion`
        if let upcomingStep = routeProgress.currentLegProgress.upComingStep, let finalHeading = upcomingStep.finalHeading, let initialHeading = upcomingStep.initialHeading {
            let initialHeadingNormalized = initialHeading.wrap(min: 0, max: 360)
            let finalHeadingNormalized = finalHeading.wrap(min: 0, max: 360)
            let userHeadingNormalized = location.course.wrap(min: 0, max: 360)
            let expectedTurningAngle = initialHeadingNormalized.difference(from: finalHeadingNormalized)

            // If the upcoming maneuver is fairly straight,
            // do not check if the user is within x degrees of the exit heading.
            // For ramps, their current heading will very close to the exit heading.
            // We need to wait until their moving away from the maneuver location instead.
            // We can do this by looking at their snapped distance from the maneuver.
            // Once this distance is zero, they are at more moving away from the maneuver location
            if expectedTurningAngle <= RouteControllerMaximumAllowedDegreeOffsetForTurnCompletion {
                courseMatchesManeuverFinalHeading = userSnapToStepDistanceFromManeuver == 0
            } else {
                courseMatchesManeuverFinalHeading = finalHeadingNormalized.difference(from: userHeadingNormalized) <= RouteControllerMaximumAllowedDegreeOffsetForTurnCompletion
            }
        }

        let step = self.routeProgress.currentLegProgress.upComingStep?.maneuverLocation ?? self.routeProgress.currentLegProgress.currentStep.maneuverLocation
        let userAbsoluteDistance = step.distance(to: location.coordinate)
        let lastKnownUserAbsoluteDistance = self.routeProgress.currentLegProgress.currentStepProgress.userDistanceToManeuverLocation

        if userSnapToStepDistanceFromManeuver <= RouteControllerManeuverZoneRadius,
           courseMatchesManeuverFinalHeading || (userAbsoluteDistance > lastKnownUserAbsoluteDistance && lastKnownUserAbsoluteDistance > RouteControllerManeuverZoneRadius) {
            self.advanceStepIndex()
        }

        self.routeProgress.currentLegProgress.currentStepProgress.userDistanceToManeuverLocation = userAbsoluteDistance
    }

    func updateSpokenInstructionProgress() {
        guard let userSnapToStepDistanceFromManeuver else { return }
        guard let spokenInstructions = routeProgress.currentLegProgress.currentStepProgress.remainingSpokenInstructions else { return }

        let firstInstructionOnFirstStep = self.speakFirstInstructionOnFirstStep
            // Always give the first voice announcement when beginning a leg.
            ? self.routeProgress.currentLegProgress.stepIndex == 0 && self.routeProgress.currentLegProgress.currentStepProgress.spokenInstructionIndex == 0
            : false

        for voiceInstruction in spokenInstructions {
            if userSnapToStepDistanceFromManeuver <= voiceInstruction.distanceAlongStep || firstInstructionOnFirstStep {
                NotificationCenter.default.post(name: .routeControllerDidPassSpokenInstructionPoint, object: self, userInfo: [
                    RouteControllerNotificationUserInfoKey.routeProgressKey: self.routeProgress
                ])

                self.routeProgress.currentLegProgress.currentStepProgress.spokenInstructionIndex += 1
                return
            }
        }
    }
    
    func updateVisualInstructionProgress() {
        guard let userSnapToStepDistanceFromManeuver else { return }
        guard let visualInstructions = routeProgress.currentLegProgress.currentStepProgress.remainingVisualInstructions else { return }
        
        let firstInstructionOnFirstStep = self.routeProgress.currentLegProgress.stepIndex == 0 && self.routeProgress.currentLegProgress.currentStepProgress.visualInstructionIndex == 0
        
        for visualInstruction in visualInstructions {
            if userSnapToStepDistanceFromManeuver <= visualInstruction.distanceAlongStep || firstInstructionOnFirstStep {
                NotificationCenter.default.post(name: .routeControllerDidPassVisualInstructionPoint, object: self, userInfo: [
                    RouteControllerNotificationUserInfoKey.routeProgressKey: self.routeProgress
                ])
                
                self.routeProgress.currentLegProgress.currentStepProgress.visualInstructionIndex += 1
                return
            }
        }
    }

    func advanceStepIndex(to: Array<RouteStep>.Index? = nil) {
        if let forcedStepIndex = to {
            guard forcedStepIndex < self.routeProgress.currentLeg.steps.count else { return }
            self.routeProgress.currentLegProgress.stepIndex = forcedStepIndex
        } else {
            self.routeProgress.currentLegProgress.stepIndex += 1
        }

        self.updateIntersectionDistances()
        self.updateDistanceToManeuver()
    }

    func updateIntersectionDistances() {
        if let coordinates = routeProgress.currentLegProgress.currentStep.coordinates, let intersections = routeProgress.currentLegProgress.currentStep.intersections {
            let polyline = Polyline(coordinates)
            let distances: [CLLocationDistance] = intersections.map { polyline.distance(from: coordinates.first, to: $0.location) }
            self.routeProgress.currentLegProgress.currentStepProgress.intersectionDistances = distances
        }
    }
    
    /// Calculates a match percentage between the geometry of a route and another route. Uses exact coordinate checking (using 4 decimals) for performance reasons, so it assumes the geometry is stable between routes.
    /// - Parameters:
    ///   - route: First route to compare
    ///   - route2: Second route to compare
    /// - Returns: A percentage of the match. Can return `nil` if one of the route's geometry cannot be found.
    static func matchPercentage(between route: Route, and route2: Route) -> Double? {
        guard let currentRouteCoordinates = route.coordinates else { return nil }
        guard let otherRouteCoordinates = route2.coordinates else { return nil }
        
        // Convert to strings, only taking 4 decimals
        let currentRouteCoordinatesStrings = currentRouteCoordinates.map { String(format: "%.4f,%.4f", $0.latitude, $0.longitude) }
        let otherRouteCoordinatesString = otherRouteCoordinates.map { String(format: "%.4f,%.4f", $0.latitude, $0.longitude) }
        
        // Check how many coords match
        let matchCount = Double(otherRouteCoordinatesString.filter { currentRouteCoordinatesStrings.contains($0) }.count)
        
        // Make it a percentage
        let matchPercentage = 100.0 / Double(otherRouteCoordinatesString.count) * matchCount
        
        return matchPercentage
    }
    
    /// Checks for a best match to a route within an array of routes. It is a match when the route's geometry is 90% or higher.
    /// - Parameters:
    ///   - route: Route to compare to the others
    ///   - routes: The other routes to compare to
    /// - Returns: The best matched route with the highest match factor above 90% and the match percentage.
    static func bestMatch(for route: Route, and routes: [Route]) -> (route: Route, matchPercentage: Double)? {
        let bestMatch = routes.compactMap { newRoute -> (route: Route, matchPercentage: Double)? in
            guard let matchPercentage = matchPercentage(between: route, and: newRoute) else { return nil }
            return (newRoute, matchPercentage)
        }
        .filter { $0.matchPercentage >= 90.0 }
        .sorted { $0.matchPercentage > $1.matchPercentage }
        .first
        
        return bestMatch
    }
}

// MARK: - TunnelIntersectionManagerDelegate

extension RouteController: TunnelIntersectionManagerDelegate {
    public func tunnelIntersectionManager(_ manager: TunnelIntersectionManager, willEnableAnimationAt location: CLLocation) {
        self.tunnelIntersectionManager.enableTunnelAnimation(routeController: self, routeProgress: self.routeProgress)
    }
    
    public func tunnelIntersectionManager(_ manager: TunnelIntersectionManager, willDisableAnimationAt location: CLLocation) {
        self.tunnelIntersectionManager.suspendTunnelAnimation(at: location, routeController: self)
    }
}
