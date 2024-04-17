import CoreLocation
@testable import MapboxCoreNavigation
import MapboxDirections
import Turf
import XCTest

let response = Fixture.JSONFromFileNamed(name: "routeWithInstructions", bundle: .module)
let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String: Any]
// -122.413165,37.795042
let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165))
// -122.433378,37.7727
let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))
let directions = Directions(accessToken: "pk.feedCafeDeadBeefBadeBede")
let route = Route(json: jsonRoute, waypoints: [waypoint1, waypoint2], options: NavigationRouteOptions(waypoints: [waypoint1, waypoint2]))

let waitForInterval: TimeInterval = 30

class MapboxCoreNavigationTests: XCTestCase {
    var navigation: RouteController!
    
    func testDepart() {
        route.accessToken = "foo"
        self.navigation = RouteController(along: route, directions: directions)
        let depart = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165), altitude: 1, horizontalAccuracy: 1, verticalAccuracy: 1, course: 0, speed: 10, timestamp: Date())
        
        expectation(forNotification: .routeControllerDidPassSpokenInstructionPoint, object: self.navigation) { notification -> Bool in
            XCTAssertEqual(notification.userInfo?.count, 1)
            
            let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
            
            return routeProgress != nil && routeProgress?.currentLegProgress.userHasArrivedAtWaypoint == false
        }
        
        self.navigation.resume()
        self.navigation.locationManager(self.navigation.locationManager, didUpdateLocations: [depart])
        
        waitForExpectations(timeout: waitForInterval) { error in
            XCTAssertNil(error)
        }
    }
    
    func makeLocation(latitude: Double, longitude: Double, course: CLLocationDirection) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), altitude: 1, horizontalAccuracy: 1, verticalAccuracy: 1, course: course, speed: 10, timestamp: Date())
    }
    
    func testNewStep() {
        route.accessToken = "foo"
        let coordOnStep1 = route.legs[0].steps[1].coordinates![5]
        let location = self.makeLocation(latitude: coordOnStep1.latitude, longitude: coordOnStep1.longitude, course: 250)
        
        let locationManager = ReplayLocationManager(locations: [location, location])
        self.navigation = RouteController(along: route, directions: directions, locationManager: locationManager)
        
        expectation(forNotification: .routeControllerDidPassSpokenInstructionPoint, object: self.navigation) { notification -> Bool in
            XCTAssertEqual(notification.userInfo?.count, 1)
            
            let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
            
            return routeProgress?.currentLegProgress.stepIndex == 1
        }
        
        self.navigation.resume()
        
        waitForExpectations(timeout: waitForInterval) { error in
            XCTAssertNil(error)
        }
    }
    
    func testJumpAheadToLastStep() {
        route.accessToken = "foo"
        let coordOnLastStep = route.legs[0].steps[6].coordinates![5]
        let location = self.makeLocation(latitude: coordOnLastStep.latitude, longitude: coordOnLastStep.longitude, course: 171)
        
        let locationManager = ReplayLocationManager(locations: [location, location])
        self.navigation = RouteController(along: route, directions: directions, locationManager: locationManager)
        
        expectation(forNotification: .routeControllerDidPassSpokenInstructionPoint, object: self.navigation) { notification -> Bool in
            XCTAssertEqual(notification.userInfo?.count, 1)
            
            let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
            
            return routeProgress?.currentLegProgress.stepIndex == 6
        }
        
        self.navigation.resume()
        
        waitForExpectations(timeout: waitForInterval) { error in
            XCTAssertNil(error)
        }
    }
    
    func testShouldReroute() {
        route.accessToken = "foo"
        let firstLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 38, longitude: -123),
                                       altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: 0,
                                       timestamp: Date())
        
        let secondLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 38, longitude: -124),
                                        altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: 0,
                                        timestamp: Date(timeIntervalSinceNow: 1))
        
        let locationManager = ReplayLocationManager(locations: [firstLocation, secondLocation])
        self.navigation = RouteController(along: route, directions: directions, locationManager: locationManager)
        
        expectation(forNotification: .routeControllerWillReroute, object: self.navigation) { notification -> Bool in
            XCTAssertEqual(notification.userInfo?.count, 1)
            
            let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as? CLLocation
            return location?.coordinate == secondLocation.coordinate
        }
        
        self.navigation.resume()
        
        waitForExpectations(timeout: waitForInterval) { error in
            XCTAssertNil(error)
        }
    }
    
    func testArrive() {
        route.accessToken = "foo"
        let locations: [CLLocation] = route.legs.first!.steps.first!.coordinates!.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let locationManager = ReplayLocationManager(locations: locations)
        locationManager.speedMultiplier = 20
        
        self.navigation = RouteController(along: route, directions: directions, locationManager: locationManager)
        
        expectation(forNotification: .routeControllerProgressDidChange, object: self.navigation) { notification -> Bool in
            let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
            return routeProgress != nil
        }
        
        self.navigation.resume()
        
        let timeout = locations.last!.timestamp.timeIntervalSince(locations.first!.timestamp) / locationManager.speedMultiplier
        waitForExpectations(timeout: timeout + 2) { error in
            XCTAssertNil(error)
        }
    }
    
    func testFailToReroute() {
        route.accessToken = "foo"
        let directionsClientSpy = DirectionsSpy(accessToken: "garbage", host: nil)
        self.navigation = RouteController(along: route, directions: directionsClientSpy)
        
        expectation(forNotification: .routeControllerWillReroute, object: self.navigation) { _ -> Bool in
            true
        }
        
        expectation(forNotification: .routeControllerDidFailToReroute, object: self.navigation) { _ -> Bool in
            true
        }
        
        self.navigation.rerouteForDiversion(from: CLLocation(latitude: 0, longitude: 0), along: self.navigation.routeProgress)
        directionsClientSpy.fireLastCalculateCompletion(with: nil, routes: nil, error: NSError())
        
        waitForExpectations(timeout: 2) { error in
            XCTAssertNil(error)
        }
    }
}
