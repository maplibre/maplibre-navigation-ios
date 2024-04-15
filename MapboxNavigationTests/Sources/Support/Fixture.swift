import CoreLocation
import Foundation
import MapboxCoreNavigation
import MapboxDirections
import XCTest

extension Fixture {
    class var blankStyle: URL {
        let path = Bundle.module.path(forResource: "EmptyStyle", ofType: "json")
        return URL(fileURLWithPath: path!)
    }
	
    class func routeWithBannerInstructions() -> Route {
        route(from: "route-with-banner-instructions", bundle: .module, waypoints: [Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165)), Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))])
    }
}

// MARK: - Private

private extension Fixture {
    class func route(from jsonFile: String, bundle: Bundle, waypoints: [Waypoint]) -> Route {
        let response = JSONFromFileNamed(name: jsonFile, bundle: bundle)
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String: Any]
        return Route(json: jsonRoute, waypoints: waypoints, options: RouteOptions(waypoints: waypoints))
    }
}
