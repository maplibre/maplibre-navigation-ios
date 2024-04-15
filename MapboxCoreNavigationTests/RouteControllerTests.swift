import CoreLocation
@testable import MapboxCoreNavigation
import MapboxDirections
import Turf
import XCTest

private let mbTestHeading: CLLocationDirection = 50

class RouteControllerTests: XCTestCase {
    enum Constants {
        static let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String: Any]
        static let accessToken = "nonsense"
    }

    let directionsClientSpy = DirectionsSpy(accessToken: "garbage", host: nil)
    let delegate = RouteControllerDelegateSpy()

    typealias RouteLocations = (firstLocation: CLLocation, penultimateLocation: CLLocation, lastLocation: CLLocation)

    lazy var dependencies: (routeController: RouteController, routeLocations: RouteLocations) = {
        let routeController = RouteController(along: initialRoute, directions: directionsClientSpy, locationManager: NavigationLocationManager())
        routeController.delegate = self.delegate

        let legProgress: RouteLegProgress = routeController.routeProgress.currentLegProgress

        let firstCoord = legProgress.nearbyCoordinates.first!
        let firstLocation = CLLocation(coordinate: firstCoord, altitude: 5, horizontalAccuracy: 10, verticalAccuracy: 5, course: 20, speed: 4, timestamp: Date())

        let remainingStepCount = legProgress.remainingSteps.count
        let penultimateCoord = legProgress.remainingSteps[remainingStepCount - 2].coordinates!.first!
        let penultimateLocation = CLLocation(coordinate: penultimateCoord, altitude: 5, horizontalAccuracy: 10, verticalAccuracy: 5, course: 20, speed: 4, timestamp: Date())

        let lastCoord = legProgress.remainingSteps.last!.coordinates!.first!
        let lastLocation = CLLocation(coordinate: lastCoord, altitude: 5, horizontalAccuracy: 10, verticalAccuracy: 5, course: 20, speed: 4, timestamp: Date())

        let routeLocations = RouteLocations(firstLocation, penultimateLocation, lastLocation)

        return (routeController: routeController, routeLocations: routeLocations)
    }()

    lazy var initialRoute: Route = {
        let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165))
        let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))
        let route = Route(json: Constants.jsonRoute, waypoints: [waypoint1, waypoint2], options: NavigationRouteOptions(waypoints: [waypoint1, waypoint2]))
        route.accessToken = Constants.accessToken
        return route
    }()

    lazy var alternateRoute: Route = {
        let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.893922, longitude: -77.023900))
        let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.880727, longitude: -77.024888))
        let route = Route(json: Constants.jsonRoute, waypoints: [waypoint1, waypoint2], options: NavigationRouteOptions(waypoints: [waypoint1, waypoint2]))
        route.accessToken = Constants.accessToken
        return route
    }()

    override func setUp() {
        super.setUp()

        self.directionsClientSpy.reset()
        self.delegate.reset()
    }

    func testUserIsOnRoute() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation

        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertTrue(navigation.userIsOnRoute(firstLocation), "User should be on route")
    }

    func testUserIsOffRoute() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation

        let coordinateOffRoute = firstLocation.coordinate.coordinate(at: 100, facing: 90)
        let locationOffRoute = CLLocation(latitude: coordinateOffRoute.latitude, longitude: coordinateOffRoute.longitude)
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [locationOffRoute])
        XCTAssertFalse(navigation.userIsOnRoute(locationOffRoute), "User should be off route")
    }

    func testAdvancingToFutureStepAndNotRerouting() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertTrue(navigation.userIsOnRoute(firstLocation), "User should be on route")
        XCTAssertEqual(navigation.routeProgress.currentLegProgress.stepIndex, 0, "User is on first step")

        let futureCoordinate = navigation.routeProgress.currentLegProgress.leg.steps[2].coordinates![10]
        let futureLocation = CLLocation(latitude: futureCoordinate.latitude, longitude: futureCoordinate.longitude)

        navigation.locationManager(navigation.locationManager, didUpdateLocations: [futureLocation])
        XCTAssertTrue(navigation.userIsOnRoute(futureLocation), "User should be on route")
        XCTAssertEqual(navigation.routeProgress.currentLegProgress.stepIndex, 2, "User should be on route and we should increment all the way to the 4th step")
    }

    func testSnappedLocation() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertEqual(navigation.location!.coordinate, firstLocation.coordinate, "Check snapped location is working")
    }
    
    func testSnappedAtEndOfStepLocationWhenMovingSlowly() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertEqual(navigation.location!.coordinate, firstLocation.coordinate, "Check snapped location is working")
        
        let firstCoordinateOnUpcomingStep = navigation.routeProgress.currentLegProgress.upComingStep!.coordinates!.first!
        let firstLocationOnNextStepWithNoSpeed = CLLocation(coordinate: firstCoordinateOnUpcomingStep, altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, course: 10, speed: 0, timestamp: Date())
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocationOnNextStepWithNoSpeed])
        XCTAssertEqual(navigation.location!.coordinate, navigation.routeProgress.currentLegProgress.currentStep.coordinates!.last!, "When user is not moving, snap to current leg only")
        
        let firstLocationOnNextStepWithSpeed = CLLocation(coordinate: firstCoordinateOnUpcomingStep, altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, course: 10, speed: 5, timestamp: Date())
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocationOnNextStepWithSpeed])
        XCTAssertEqual(navigation.location!.coordinate, firstCoordinateOnUpcomingStep, "User is snapped to upcoming step when moving")
    }
    
    func testSnappedAtEndOfStepLocationWhenCourseIsSimilar() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertEqual(navigation.location!.coordinate, firstLocation.coordinate, "Check snapped location is working")
        
        let firstCoordinateOnUpcomingStep = navigation.routeProgress.currentLegProgress.upComingStep!.coordinates!.first!
        
        let finalHeading = navigation.routeProgress.currentLegProgress.upComingStep!.finalHeading!
        let firstLocationOnNextStepWithDifferentCourse = CLLocation(coordinate: firstCoordinateOnUpcomingStep, altitude: 0, horizontalAccuracy: 30, verticalAccuracy: 10, course: -finalHeading, speed: 5, timestamp: Date())
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocationOnNextStepWithDifferentCourse])
        XCTAssertEqual(navigation.location!.coordinate, navigation.routeProgress.currentLegProgress.currentStep.coordinates!.last!, "When user's course is dissimilar from the finalHeading, they should not snap to upcoming step")
        
        let firstLocationOnNextStepWithCorrectCourse = CLLocation(coordinate: firstCoordinateOnUpcomingStep, altitude: 0, horizontalAccuracy: 30, verticalAccuracy: 10, course: finalHeading, speed: 5, timestamp: Date())
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocationOnNextStepWithCorrectCourse])
        XCTAssertEqual(navigation.location!.coordinate, firstCoordinateOnUpcomingStep, "User is snapped to upcoming step when their course is similar to the final heading")
    }

    func testSnappedLocationForUnqualifiedLocation() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertEqual(navigation.location!.coordinate, firstLocation.coordinate, "Check snapped location is working")

        let futureCoord = Polyline(navigation.routeProgress.currentLegProgress.nearbyCoordinates).coordinateFromStart(distance: 100)!
        let futureInaccurateLocation = CLLocation(coordinate: futureCoord, altitude: 0, horizontalAccuracy: 1, verticalAccuracy: 200, course: 0, speed: 5, timestamp: Date())

        navigation.locationManager(navigation.locationManager, didUpdateLocations: [futureInaccurateLocation])
        XCTAssertEqual(navigation.location!.coordinate, futureInaccurateLocation.coordinate, "Inaccurate location is still snapped")
    }

    func testUserPuckShouldFaceBackwards() {
        // This route is a simple straight line: http://geojson.io/#id=gist:anonymous/64cfb27881afba26e3969d06bacc707c&map=17/37.77717/-122.46484
        let response = Fixture.JSONFromFileNamed(name: "straight-line", bundle: .module)
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String: Any]
        let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165))
        let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))
        let directions = Directions(accessToken: "pk.feedCafeDeadBeefBadeBede")
        let route = Route(json: jsonRoute, waypoints: [waypoint1, waypoint2], options: NavigationRouteOptions(waypoints: [waypoint1, waypoint2]))

        route.accessToken = "foo"
        let navigation = RouteController(along: route, directions: directions)
        let firstCoord = navigation.routeProgress.currentLegProgress.nearbyCoordinates.first!
        let firstLocation = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
        let coordNearStart = Polyline(navigation.routeProgress.currentLegProgress.nearbyCoordinates).coordinateFromStart(distance: 10)!

        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])

        // We're now 10 meters away from the last coord, looking at the start.
        // Basically, simulating moving backwards.
        let directionToStart = coordNearStart.direction(to: firstCoord)
        let facingTowardsStartLocation = CLLocation(coordinate: coordNearStart, altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: directionToStart, speed: 0, timestamp: Date())

        navigation.locationManager(navigation.locationManager, didUpdateLocations: [facingTowardsStartLocation])

        // The course should not be the interpolated course, rather the raw course.
        XCTAssertEqual(directionToStart, navigation.location!.course, "The course should be the raw course and not an interpolated course")
        XCTAssertFalse(facingTowardsStartLocation.shouldSnapCourse(toRouteWith: facingTowardsStartLocation.interpolatedCourse(along: navigation.routeProgress.currentLegProgress.nearbyCoordinates)!, distanceToFirstCoordinateOnLeg: facingTowardsStartLocation.distance(from: firstLocation)), "Should not snap")
    }

    func testLocationShouldUseHeading() {
        let navigation = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])

        XCTAssertEqual(navigation.location!.course, firstLocation.course, "Course should be using course")

        let invalidCourseLocation = CLLocation(coordinate: firstLocation.coordinate, altitude: firstLocation.altitude, horizontalAccuracy: firstLocation.horizontalAccuracy, verticalAccuracy: firstLocation.verticalAccuracy, course: -1, speed: firstLocation.speed, timestamp: firstLocation.timestamp)

        let heading = Heading(heading: mbTestHeading, accuracy: 1)

        navigation.locationManager(navigation.locationManager, didUpdateLocations: [invalidCourseLocation])
        navigation.locationManager(navigation.locationManager, didUpdateHeading: heading)

        XCTAssertEqual(navigation.location!.course, mbTestHeading, "Course should be using bearing")
    }

    // MARK: - Events & Delegation

    func testReroutingFromALocationSendsEvents() {
        let routeController = self.dependencies.routeController
        let testLocation = self.dependencies.routeLocations.firstLocation

        let willRerouteNotificationExpectation = expectation(forNotification: .routeControllerWillReroute, object: routeController) { notification -> Bool in
            let fromLocation = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as? CLLocation
            return fromLocation == testLocation
        }

        let didRerouteNotificationExpectation = expectation(forNotification: .routeControllerDidReroute, object: routeController, handler: nil)

        let routeProgressDidChangeNotificationExpectation = expectation(forNotification: .routeControllerProgressDidChange, object: routeController) { notification -> Bool in
            let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as? CLLocation
            let rawLocation = notification.userInfo![RouteControllerNotificationUserInfoKey.rawLocationKey] as? CLLocation
            let _ = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress

            return location == rawLocation
        }

        // MARK: When told to re-route from location -- `reroute(from:)`

        routeController.rerouteForDiversion(from: testLocation, along: routeController.routeProgress)

        // MARK: it tells the delegate & posts a willReroute notification

        XCTAssertTrue(self.delegate.recentMessages.contains("routeController(_:willRerouteFrom:)"))
        wait(for: [willRerouteNotificationExpectation], timeout: 0.1)

        // MARK: Upon rerouting successfully...

        self.directionsClientSpy.fireLastCalculateCompletion(with: nil, routes: [self.alternateRoute], error: nil)

        // MARK: It tells the delegate & posts a didReroute notification

        XCTAssertTrue(self.delegate.recentMessages.contains("routeController(_:didRerouteAlong:reason:)"))
        wait(for: [didRerouteNotificationExpectation], timeout: 0.1)

        // MARK: On the next call to `locationManager(_, didUpdateLocations:)`

        routeController.locationManager(routeController.locationManager, didUpdateLocations: [testLocation])

        // MARK: It tells the delegate & posts a routeProgressDidChange notification

        XCTAssertTrue(self.delegate.recentMessages.contains("routeController(_:didUpdate:)"))
        wait(for: [routeProgressDidChangeNotificationExpectation], timeout: 0.1)
    }

    func testGeneratingAnArrivalEvent() {
        let routeController = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        let penultimateLocation = self.dependencies.routeLocations.penultimateLocation
        let lastLocation = self.dependencies.routeLocations.lastLocation

        // MARK: When navigation begins with a location update

        routeController.locationManager(routeController.locationManager, didUpdateLocations: [firstLocation])

        // MARK: When at a valid location just before the last location (should this really be necessary?)

        routeController.locationManager(routeController.locationManager, didUpdateLocations: [penultimateLocation])

        // MARK: When navigation continues with a location update to the last location

        routeController.locationManager(routeController.locationManager, didUpdateLocations: [lastLocation])

        // MARK: And then navigation continues with another location update at the last location

        let currentLocation = routeController.location!
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [currentLocation])

        // MARK: It tells the delegate that the user did arrive

        XCTAssertTrue(self.delegate.recentMessages.contains("routeController(_:didArriveAt:)"))
    }
    
    func testNoReroutesAfterArriving() {
        let routeController = self.dependencies.routeController
        let firstLocation = self.dependencies.routeLocations.firstLocation
        let penultimateLocation = self.dependencies.routeLocations.penultimateLocation
        let lastLocation = self.dependencies.routeLocations.lastLocation

        // MARK: When navigation begins with a location update

        routeController.locationManager(routeController.locationManager, didUpdateLocations: [firstLocation])
        
        // MARK: When at a valid location just before the last location (should this really be necessary?)

        routeController.locationManager(routeController.locationManager, didUpdateLocations: [penultimateLocation])

        // MARK: When navigation continues with a location update to the last location

        routeController.locationManager(routeController.locationManager, didUpdateLocations: [lastLocation])
        
        // MARK: And then navigation continues with another location update at the last location

        let currentLocation = routeController.location!
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [currentLocation])
        
        // MARK: It tells the delegate that the user did arrive

        XCTAssertTrue(self.delegate.recentMessages.contains("routeController(_:didArriveAt:)"))
        
        // Find a location that is very far off route
        let locationBeyondRoute = routeController.location!.coordinate.coordinate(at: 2000, facing: 0)
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [CLLocation(latitude: locationBeyondRoute.latitude, longitude: locationBeyondRoute.latitude)])
        
        // Make sure configurable delegate is called
        XCTAssertTrue(self.delegate.recentMessages.contains("routeController(_:shouldPreventReroutesWhenArrivingAt:)"))
        
        // We should not reroute here because the user has arrived.
        XCTAssertFalse(self.delegate.recentMessages.contains("routeController(_:didRerouteAlong:)"))
    }

    func testRouteControllerDoesNotHaveRetainCycle() {
        weak var subject: RouteController? = nil
        
        autoreleasepool {
            let locationManager = NavigationLocationManager()
            let routeController: RouteController? = RouteController(along: initialRoute, directions: directionsClientSpy, locationManager: locationManager)
            subject = routeController
        }

        XCTAssertNil(subject, "Expected RouteController not to live beyond autorelease pool")
    }

    func testRouteControllerNilsOutLocationDelegateOnDeinit() {
        weak var subject: CLLocationManagerDelegate? = nil
        autoreleasepool {
            let locationManager = NavigationLocationManager()
            _ = RouteController(along: self.initialRoute, directions: self.directionsClientSpy, locationManager: locationManager)
            subject = locationManager.delegate
        }
        
        XCTAssertNil(subject, "Expected LocationManager's Delegate to be nil after RouteController Deinit")
    }
    
    // MARK: - Matching route geometries

    lazy var nijmegenArnhemVeenendaal = Route(
        jsonFileName: "Nijmegen-Arnhem-Veenendaal",
        waypoints: [
            CLLocationCoordinate2D(latitude: 51.83116792, longitude: 5.83897820),
            CLLocationCoordinate2D(latitude: 52.03920380, longitude: 5.55133121)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    lazy var nijmegenBemmelVeenendaal = Route(
        jsonFileName: "Nijmegen-Bemmel-Veenendaal",
        waypoints: [
            CLLocationCoordinate2D(latitude: 51.83116792, longitude: 5.83897820),
            CLLocationCoordinate2D(latitude: 52.03920380, longitude: 5.55133121)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    // Same route, routed on a different day
    lazy var nijmegenBemmelVeenendaal2 = Route(
        jsonFileName: "Nijmegen-Bemmel-Veenendaal2",
        waypoints: [
            CLLocationCoordinate2D(latitude: 51.83116792, longitude: 5.83897820),
            CLLocationCoordinate2D(latitude: 52.03920380, longitude: 5.55133121)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    lazy var wolfhezeVeenendaalNormal = Route(
        jsonFileName: "Wolfheze-Veenendaal-Normal",
        waypoints: [
            CLLocationCoordinate2D(latitude: 51.99711882858318, longitude: 5.7932572786103265),
            CLLocationCoordinate2D(latitude: 52.0392038, longitude: 5.55133121)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    lazy var wolfhezeVeenendaalSmallDetourAtEnd = Route(
        jsonFileName: "Wolfheze-Veenendaal-Small-Detour-At-End",
        waypoints: [
            CLLocationCoordinate2D(latitude: 51.99711882858318, longitude: 5.7932572786103265),
            CLLocationCoordinate2D(latitude: 52.04451273, longitude: 5.57902714),
            CLLocationCoordinate2D(latitude: 52.0392038, longitude: 5.55133121)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    lazy var a12ToVeenendaalNormal = Route(
        jsonFileName: "A12-To-Veenendaal-Normal",
        waypoints: [
            CLLocationCoordinate2D(latitude: 52.02224357, longitude: 5.78149084),
            CLLocationCoordinate2D(latitude: 52.03924958, longitude: 5.55054131)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    lazy var a12ToVeenendaalSlightDifference = Route(
        jsonFileName: "A12-To-Veenendaal-Slight-Difference",
        waypoints: [
            CLLocationCoordinate2D(latitude: 52.02224357, longitude: 5.78149084),
            CLLocationCoordinate2D(latitude: 52.03917716, longitude: 5.55201356),
            CLLocationCoordinate2D(latitude: 52.03924958, longitude: 5.55054131)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    lazy var a12ToVeenendaalBiggerDetour = Route(
        jsonFileName: "A12-To-Veenendaal-Bigger-Detour",
        waypoints: [
            CLLocationCoordinate2D(latitude: 52.02224357, longitude: 5.78149084),
            CLLocationCoordinate2D(latitude: 52.04520875, longitude: 5.5748937),
            CLLocationCoordinate2D(latitude: 52.03924958, longitude: 5.55054131)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )

    func testRouteControllerMatchPercentage() {
        // These routes differ around 40%
        if let matchPercentage = RouteController.matchPercentage(between: nijmegenArnhemVeenendaal, and: nijmegenBemmelVeenendaal) {
            XCTAssertEqual(matchPercentage, 58.86, accuracy: 1.0)
        } else {
            XCTFail("Should get a match percentage")
        }
        
        // Check for the exact same route for 100%
        if let matchPercentage = RouteController.matchPercentage(between: nijmegenArnhemVeenendaal, and: nijmegenArnhemVeenendaal) {
            XCTAssertEqual(matchPercentage, 100.0)
        } else {
            XCTFail("Should get a match percentage")
        }
        
        // Check same route, but calculated a day later (to account for stability of coordinate geometry of router)
        if let matchPercentage = RouteController.matchPercentage(between: nijmegenBemmelVeenendaal, and: nijmegenBemmelVeenendaal2) {
            XCTAssertEqual(matchPercentage, 100.0)
        } else {
            XCTFail("Should get a match percentage")
        }
        
        // Check a route to a small detour at the end, should match at 2/3
        if let matchPercentage = RouteController.matchPercentage(between: wolfhezeVeenendaalNormal, and: wolfhezeVeenendaalSmallDetourAtEnd) {
            XCTAssertEqual(matchPercentage, 67.0, accuracy: 0.1)
        } else {
            XCTFail("Should get a match percentage")
        }
        
        // Check a route with a very slight difference, should match at more than 90%
        if let matchPercentage = RouteController.matchPercentage(between: a12ToVeenendaalNormal, and: a12ToVeenendaalSlightDifference) {
            XCTAssertEqual(matchPercentage, 91.5, accuracy: 0.1)
        } else {
            XCTFail("Should get a match percentage")
        }
        
        // Check a route with a bigger detour, should match at 54%
        if let matchPercentage = RouteController.matchPercentage(between: a12ToVeenendaalNormal, and: a12ToVeenendaalBiggerDetour) {
            XCTAssertEqual(matchPercentage, 54.3, accuracy: 0.1)
        } else {
            XCTFail("Should get a match percentage")
        }
        
        // Check a route with just the duration increased, should match at 100%
        if let matchPercentage = RouteController.matchPercentage(between: a12ToVeenendaalNormal, and: a12ToVeenendaalNormalWithTraffic) {
            XCTAssertEqual(matchPercentage, 100.0)
        } else {
            XCTFail("Should get a match percentage")
        }
    }
    
    func testRouteControllerBestMatch() {
        // Shuffle the array to prove the order is unimportant
        let firstRoutes = [a12ToVeenendaalNormal, a12ToVeenendaalSlightDifference, a12ToVeenendaalBiggerDetour].shuffled()
        
        // Match a route to the same destination to the following variants:
        // - Same route -> 100% match
        // - Slight difference -> 90.3%
        // - Bigger detour -> 53%
        // --> Same route match is correct
        if let bestMatch = RouteController.bestMatch(for: a12ToVeenendaalNormal, and: firstRoutes) {
            XCTAssertEqual(bestMatch.route, self.a12ToVeenendaalNormal)
            XCTAssertEqual(bestMatch.matchPercentage, 100.0)
        } else {
            XCTFail("Should get a match above 90%")
        }
        
        // Match a route to the same destination to the following variants:
        // - Slight difference -> 90.3%
        // - Bigger detour -> 53%
        // --> Slight difference route match is correct
        let secondRoutes = [a12ToVeenendaalSlightDifference, a12ToVeenendaalBiggerDetour].shuffled()
        if let bestMatch = RouteController.bestMatch(for: a12ToVeenendaalNormal, and: secondRoutes) {
            XCTAssertEqual(bestMatch.route, self.a12ToVeenendaalSlightDifference)
            XCTAssertEqual(bestMatch.matchPercentage, 91.5, accuracy: 0.1)
        } else {
            XCTFail("Should get a match above 90%")
        }
        
        // Match a route to the same destination to the following variant:
        // - Bigger detour -> 53%
        // --> No match, as it's below 90%
        if let bestMatch = RouteController.bestMatch(for: a12ToVeenendaalNormal, and: [a12ToVeenendaalBiggerDetour]) {
            XCTAssertEqual(bestMatch.matchPercentage, 90.3, accuracy: 0.1)
            XCTFail("Shouldn't get a match above 90%")
        }
    }
    
    // MARK: - Applying faster/slower route

    func testApplyingFasterRoute() {
        let routeController = self.dependencies.routeController
        let oldRouteProgress = routeController.routeProgress
        
        // Starting with route 'A12-To-Veenendaal-Normal'
        routeController.routeProgress = .init(
            route: self.a12ToVeenendaalNormal,
            legIndex: 0,
            spokenInstructionIndex: 0
        )
        
        // Try to apply slightly faster route 'A12-To-Veenendaal-Slight-Difference'
        routeController.applyNewRerouteIfNeeded(
            mostSimilarRoute: self.a12ToVeenendaalSlightDifference,
            allRoutes: [self.a12ToVeenendaalSlightDifference],
            currentUpcomingManeuver: routeController.routeProgress.currentLegProgress.upComingStep!,
            durationRemaining: routeController.routeProgress.durationRemaining
        )
        
        // Should be applied
        XCTAssertEqual(
            routeController.routeProgress.durationRemaining,
            RouteProgress(
                route: self.a12ToVeenendaalSlightDifference,
                legIndex: 0,
                spokenInstructionIndex: 0).durationRemaining
        )
        
        // Reset routeProgress
        routeController.routeProgress = oldRouteProgress
    }
    
    func testNotApplyingSlowerRoute() {
        let routeController = self.dependencies.routeController
        let oldRouteProgress = routeController.routeProgress
        
        // Starting with route 'A12-To-Veenendaal-Normal'
        routeController.routeProgress = .init(
            route: self.a12ToVeenendaalNormal,
            legIndex: 0,
            spokenInstructionIndex: 0
        )
        
        // Try to apply slower route 'A12-To-Veenendaal-Slight-Difference'
        routeController.applyNewRerouteIfNeeded(
            mostSimilarRoute: self.a12ToVeenendaalBiggerDetour,
            allRoutes: [self.a12ToVeenendaalBiggerDetour],
            currentUpcomingManeuver: routeController.routeProgress.currentLegProgress.upComingStep!,
            durationRemaining: routeController.routeProgress.durationRemaining
        )
        
        // Shouldn't be applied as slower route isn't 90%+ match
        XCTAssertNotEqual(
            routeController.routeProgress.durationRemaining,
            RouteProgress(
                route: self.a12ToVeenendaalBiggerDetour,
                legIndex: 0,
                spokenInstructionIndex: 0).durationRemaining
        )
        
        // Reset routeProgress
        routeController.routeProgress = oldRouteProgress
    }
    
    // Same exact JSON as a12ToVeenendaalNormal, but with one of the steps increased in 'duration' with 500 secs simulating a traffic jam
    // Makes checking 'durationRemaining' work, as that is a sum of all step's 'duration' in a leg
    lazy var a12ToVeenendaalNormalWithTraffic = Route(
        jsonFileName: "A12-To-Veenendaal-Normal-With-Big-Trafficjam",
        waypoints: [
            CLLocationCoordinate2D(latitude: 52.02224357, longitude: 5.78149084),
            CLLocationCoordinate2D(latitude: 52.03924958, longitude: 5.55054131)
        ],
        bundle: .module,
        accessToken: Constants.accessToken
    )
    
    func testApplyingSlowerRoute() {
        let routeController = self.dependencies.routeController
        let oldRouteProgress = routeController.routeProgress
        
        // Starting with route 'A12-To-Veenendaal-Normal'
        routeController.routeProgress = .init(
            route: self.a12ToVeenendaalNormal,
            legIndex: 0,
            spokenInstructionIndex: 0
        )
        
        // Try to apply slower route 'A12-To-Veenendaal-Normal-With-Big-Trafficjam'
        routeController.applyNewRerouteIfNeeded(
            mostSimilarRoute: self.a12ToVeenendaalNormalWithTraffic,
            allRoutes: [self.a12ToVeenendaalNormalWithTraffic],
            currentUpcomingManeuver: routeController.routeProgress.currentLegProgress.upComingStep!,
            durationRemaining: routeController.routeProgress.durationRemaining
        )
        
        // Should be applied as we match criteria and route is just slower
        XCTAssertEqual(
            routeController.routeProgress.durationRemaining,
            RouteProgress(
                route: self.a12ToVeenendaalNormalWithTraffic,
                legIndex: 0,
                spokenInstructionIndex: 0).durationRemaining
        )
        
        // Reset routeProgress
        routeController.routeProgress = oldRouteProgress
    }
    
    func testApplyingBestMatch() {
        let routeController = self.dependencies.routeController
        let oldRouteProgress = routeController.routeProgress
        
        // Starting with route 'A12-To-Veenendaal-Normal'
        routeController.routeProgress = .init(
            route: self.a12ToVeenendaalNormal,
            legIndex: 0,
            spokenInstructionIndex: 0
        )
        
        // Try to apply slower route 'A12-To-Veenendaal-Normal-With-Big-Trafficjam' or faster route 'A12-To-Veenendaal-Slight-Difference'
        routeController.applyNewRerouteIfNeeded(
            mostSimilarRoute: self.a12ToVeenendaalSlightDifference,
            allRoutes: [self.a12ToVeenendaalNormalWithTraffic, self.a12ToVeenendaalSlightDifference],
            currentUpcomingManeuver: routeController.routeProgress.currentLegProgress.upComingStep!,
            durationRemaining: routeController.routeProgress.durationRemaining
        )
        
        // Slower one should be applied as it has a better match on geometry and the first route we get isn't faster
        XCTAssertEqual(
            routeController.routeProgress.durationRemaining,
            RouteProgress(
                route: self.a12ToVeenendaalNormalWithTraffic,
                legIndex: 0,
                spokenInstructionIndex: 0).durationRemaining
        )
        
        // Reset routeProgress
        routeController.routeProgress = oldRouteProgress
    }
}
