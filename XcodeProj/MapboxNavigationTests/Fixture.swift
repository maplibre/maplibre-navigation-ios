import XCTest
import MapboxCoreNavigation
import Foundation
import MapboxDirections
import CoreLocation

internal extension Fixture {
    
    class func downloadRouteFixture(coordinates: [CLLocationCoordinate2D], fileName: String, completion: @escaping () -> Void) {
        let accessToken = "<# Mapbox Access Token #>"
        let directions = Directions(accessToken: accessToken)
        
        let options = RouteOptions(coordinates: coordinates, profileIdentifier: .automobileAvoidingTraffic)
        options.includesSteps = true
        options.routeShapeResolution = .full
        let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName)
        
        _ = directions.calculate(options, completionHandler: { (waypoints, routes, error) in
            guard let route = routes?.first else { return }
            
            NSKeyedArchiver.archiveRootObject(route, toFile: filePath)
            print("Route downloaded to \(filePath)")
            completion()
        })
    }
    
    class var blankStyle: URL {
		let path = Bundle.module.path(forResource: "EmptyStyle", ofType: "json")
        return URL(fileURLWithPath: path!)
    }
    
    class func route(from jsonFile: String, bundle: Bundle, waypoints: [Waypoint]) -> Route {
        let response = JSONFromFileNamed(name: jsonFile, bundle: bundle)
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String : Any]
        return Route(json: jsonRoute, waypoints: waypoints, options: RouteOptions(waypoints: waypoints))
    }

    class func routeWithBannerInstructions() -> Route {
        return route(from: "route-with-banner-instructions", bundle: .module, waypoints: [Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165)), Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))])
    }
}
