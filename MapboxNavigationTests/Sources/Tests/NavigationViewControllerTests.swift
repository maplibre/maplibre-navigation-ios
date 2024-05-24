import MapboxCoreNavigation
import MapboxDirections
@testable import MapboxNavigation
import MapLibre
import Turf
import XCTest

let response = Fixture.JSONFromFileNamed(name: "route-with-instructions", bundle: .module)
let otherResponse = Fixture.JSONFromFileNamed(name: "route-for-lane-testing", bundle: .module)

class NavigationViewControllerTests: XCTestCase {
    let fakeDirections = Directions(accessToken: "abc", host: "ab")
    var customRoadName = [CLLocationCoordinate2D: String?]()
    
    var updatedStyleNumberOfTimes = 0
    
    lazy var dependencies: (navigationViewController: NavigationViewController, startLocation: CLLocation, poi: [CLLocation], endLocation: CLLocation, voice: RouteVoiceController) = {
        let voice = FakeVoiceController()
        let nav = NavigationViewController(for: initialRoute,
                                           dayStyle: DayStyle(demoStyle: ()),
                                           directions: Directions(accessToken: "garbage", host: nil),
                                           voiceController: voice)
        
        nav.delegate = self
        
        let routeController = nav.routeController!
        let firstCoord = routeController.routeProgress.currentLegProgress.nearbyCoordinates.first!
        let firstLocation = location(at: firstCoord)
        
        var poi = [CLLocation]()
        let taylorStreetIntersection = routeController.routeProgress.route.legs.first!.steps.first!.intersections!.first!
        let turkStreetIntersection = routeController.routeProgress.route.legs.first!.steps[3].intersections!.first!
        let fultonStreetIntersection = routeController.routeProgress.route.legs.first!.steps[5].intersections!.first!
        
        poi.append(location(at: taylorStreetIntersection.location))
        poi.append(location(at: turkStreetIntersection.location))
        poi.append(location(at: fultonStreetIntersection.location))
        
        let lastCoord = routeController.routeProgress.currentLegProgress.remainingSteps.last!.coordinates!.first!
        let lastLocation = location(at: lastCoord)
        
        return (navigationViewController: nav, startLocation: firstLocation, poi: poi, endLocation: lastLocation, voice: voice)
    }()
    
    lazy var initialRoute: Route = {
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String: Any]
        let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165))
        let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))
        let route = Route(json: jsonRoute, waypoints: [waypoint1, waypoint2], options: NavigationRouteOptions(waypoints: [waypoint1, waypoint2]))
        
        route.accessToken = "foo"
        
        return route
    }()
    
    lazy var newRoute: Route = {
        let jsonRoute = (otherResponse["routes"] as! [AnyObject]).first as! [String: Any]
        let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.901166, longitude: -77.036548))
        let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 38.900206, longitude: -77.033792))
        let route = Route(json: jsonRoute, waypoints: [waypoint1, waypoint2], options: NavigationRouteOptions(waypoints: [waypoint1, waypoint2]))
        
        route.accessToken = "bar"
        
        return route
    }()
    
    override func setUp() {
        super.setUp()
        self.customRoadName.removeAll()
    }
    
    // Brief: navigationViewController(_:roadNameAt:) delegate method is implemented,
    //        with a road name provided and wayNameView label is visible.
    func testNavigationViewControllerDelegateRoadNameAtLocationImplemented() {
        let navigationViewController = self.dependencies.navigationViewController
        let routeController = navigationViewController.routeController!
        
        // Identify a location to set the custom road name.
        let taylorStreetLocation = self.dependencies.poi.first!
        let roadName = "Taylor Swift Street"
        self.customRoadName[taylorStreetLocation.coordinate] = roadName
        
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [taylorStreetLocation])
        
        let wayNameView = (navigationViewController.mapViewController?.navigationView.wayNameView)!
        let currentRoadName = wayNameView.text
        XCTAssertEqual(currentRoadName, roadName, "Expected: \(roadName); Actual: \(String(describing: currentRoadName))")
        XCTAssertFalse(wayNameView.isHidden, "WayNameView should be visible.")
    }
    
    func testNavigationShouldNotCallStyleManagerDidRefreshAppearanceMoreThanOnceWithOneStyle() {
        let navigationViewController = NavigationViewController(for: initialRoute,
                                                                dayStyle: DayStyle(demoStyle: ()),
                                                                directions: fakeDirections,
                                                                voiceController: FakeVoiceController())
        let routeController = navigationViewController.routeController!
        navigationViewController.styleManager.delegate = self
        
        let someLocation = self.dependencies.poi.first!
        
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        
        XCTAssertEqual(self.updatedStyleNumberOfTimes, 0, "The style should not be updated.")
        self.updatedStyleNumberOfTimes = 0
    }
    
    // If tunnel flags are enabled and we need to switch styles, we should not force refresh the map style because we have only 1 style.
    func testNavigationShouldNotCallStyleManagerDidRefreshAppearanceWhenOnlyOneStyle() {
        let navigationViewController = NavigationViewController(for: initialRoute, dayStyle: DayStyle(demoStyle: ()), directions: fakeDirections, voiceController: FakeVoiceController())
        let routeController = navigationViewController.routeController!
        navigationViewController.styleManager.delegate = self
        
        let someLocation = self.dependencies.poi.first!
        
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        
        XCTAssertEqual(self.updatedStyleNumberOfTimes, 0, "The style should not be updated.")
        self.updatedStyleNumberOfTimes = 0
    }
    
    func testNavigationShouldNotCallStyleManagerDidRefreshAppearanceMoreThanOnceWithTwoStyles() {
        let navigationViewController = NavigationViewController(for: initialRoute, dayStyle: DayStyle(demoStyle: ()), nightStyle: NightStyle(demoStyle: ()), directions: fakeDirections, voiceController: FakeVoiceController())
        let routeController = navigationViewController.routeController!
        navigationViewController.styleManager.delegate = self
        
        let someLocation = self.dependencies.poi.first!
        
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [someLocation])
        
        XCTAssertEqual(self.updatedStyleNumberOfTimes, 0, "The style should not be updated.")
        self.updatedStyleNumberOfTimes = 0
    }
    
    // Brief: navigationViewController(_:roadNameAt:) delegate method is implemented,
    //        with a blank road name (empty string) provided and wayNameView label is hidden.
    func testNavigationViewControllerDelegateRoadNameAtLocationEmptyString() {
        let navigationViewController = self.dependencies.navigationViewController
        let routeController = navigationViewController.routeController!
        
        // Identify a location to set the custom road name.
        let turkStreetLocation = self.dependencies.poi[1]
        let roadName = ""
        self.customRoadName[turkStreetLocation.coordinate] = roadName
        
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [turkStreetLocation])
        
        let wayNameView = (navigationViewController.mapViewController?.navigationView.wayNameView)!
        let currentRoadName = wayNameView.text
        XCTAssertEqual(currentRoadName, roadName, "Expected: \(roadName); Actual: \(String(describing: currentRoadName))")
        XCTAssertTrue(wayNameView.isHidden, "WayNameView should be hidden.")
    }
    
    func testNavigationViewControllerDelegateRoadNameAtLocationUmimplemented() {
        let navigationViewController = self.dependencies.navigationViewController
        
        // We break the communication between CLLocation and MBRouteController
        // Intent: Prevent the routecontroller from being fed real location updates
        navigationViewController.routeController.locationManager.delegate = nil

        let routeController = navigationViewController.routeController!
        
        // Identify a location without a custom road name.
        let fultonStreetLocation = self.dependencies.poi[2]
        
        navigationViewController.mapViewController!.labelRoadNameCompletionHandler = { defaultRaodNameAssigned in
            XCTAssertTrue(defaultRaodNameAssigned, "label road name was not successfully set")
        }
        
        routeController.locationManager(routeController.locationManager, didUpdateLocations: [fultonStreetLocation])
    }
    
    func testDestinationAnnotationUpdatesUponReroute() {
        let styleLoaded = XCTestExpectation(description: "Style Loaded")
        let navigationViewController = NavigationViewControllerTestable(for: initialRoute, dayStyle: DayStyle.blankStyleForTesting, styleLoaded: styleLoaded)

        // wait for the style to load -- routes won't show without it.
        wait(for: [styleLoaded], timeout: 5)
        navigationViewController.route = self.initialRoute

        runUntil {
            !(navigationViewController.mapView!.annotations?.isEmpty ?? true)
        }
        
        guard let annotations = navigationViewController.mapView?.annotations else { return XCTFail("Annotations not found.") }

        let firstDestination = self.initialRoute.routeOptions.waypoints.last!.coordinate
        let destinations = annotations.filter(self.annotationFilter(matching: firstDestination))
        XCTAssert(!destinations.isEmpty, "Destination annotation does not exist on map")
    
        // lets set the second route
        navigationViewController.route = self.newRoute
        
        guard let newAnnotations = navigationViewController.mapView?.annotations else { return XCTFail("New annotations not found.") }
        let secondDestination = self.newRoute.routeOptions.waypoints.last!.coordinate

        // do we have a destination on the second route?
        let newDestinations = newAnnotations.filter(self.annotationFilter(matching: secondDestination))
        XCTAssert(!newDestinations.isEmpty, "New destination annotation does not exist on map")
    }
    
    private func annotationFilter(matching coordinate: CLLocationCoordinate2D) -> ((MLNAnnotation) -> Bool) {
        let filter = { (annotation: MLNAnnotation) -> Bool in
            guard let pointAnno = annotation as? MLNPointAnnotation else { return false }
            return pointAnno.coordinate == coordinate
        }
        return filter
    }
}

extension NavigationViewControllerTests: NavigationViewControllerDelegate, StyleManagerDelegate {
    func locationFor(styleManager: StyleManager) -> CLLocation? {
        self.dependencies.poi.first!
    }
    
    func styleManagerDidRefreshAppearance(_ styleManager: StyleManager) {
        self.updatedStyleNumberOfTimes += 1
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, roadNameAt location: CLLocation) -> String? {
        self.customRoadName[location.coordinate] ?? nil
    }
}

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

private extension NavigationViewControllerTests {
    func location(at coordinate: CLLocationCoordinate2D) -> CLLocation {
        CLLocation(coordinate: coordinate,
                   altitude: 5,
                   horizontalAccuracy: 10,
                   verticalAccuracy: 5,
                   course: 20,
                   speed: 15,
                   timestamp: Date())
    }
}

class NavigationViewControllerTestable: NavigationViewController {
    var styleLoadedExpectation: XCTestExpectation
   
    required init(for route: Route,
                  dayStyle: Style,
                  styleLoaded: XCTestExpectation) {
        self.styleLoadedExpectation = styleLoaded
        super.init(for: route, dayStyle: dayStyle, directions: Directions(accessToken: "abc", host: ""), voiceController: FakeVoiceController())
    }
    
    @objc(initWithRoute:dayStyle:nightStyle:directions:routeController:locationManager:voiceController:)
    required init(for route: Route, dayStyle: Style, nightStyle: Style? = nil, directions: Directions = Directions.shared, routeController: RouteController? = nil, locationManager: NavigationLocationManager? = nil, voiceController: RouteVoiceController? = nil) {
        fatalError("init(for:directions:dayStyle:nightStyle:routeController:locationManager:voiceController:) has not been implemented")
    }

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        self.styleLoadedExpectation.fulfill()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("This initalizer is not supported in this testing subclass.")
    }
}

extension DayStyle {
    static var blankStyleForTesting: Self {
        Self(mapStyleURL: Fixture.blankStyle)
    }
}

class FakeVoiceController: RouteVoiceController {
    override func speak(_ instruction: SpokenInstruction, with locale: Locale?, ignoreProgress: Bool = false) {
        // no-op
    }
    
    override func pauseSpeechAndPlayReroutingDing(notification: NSNotification) {
        // no-op
    }
}
