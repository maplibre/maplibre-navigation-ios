import CoreLocation
import MapboxDirections
import MapboxCoreNavigation

extension Fixture {
    
    class func route(from filename: String) -> Route {
        let response = Fixture.JSONFromFileNamed(name: filename, bundle: Bundle(for: AppDelegate.self))
        return route(from: response)
    }
    
    private class func route(from response: [String: Any]) -> Route {
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String: Any]
        let jsonWaypoints = response["waypoints"] as! [[String: Any]]
        
        let waypoints: [Waypoint] = jsonWaypoints.map { (waypointDict) -> Waypoint in
            let locationDict = waypointDict["location"] as! [CLLocationDegrees]
            let coord = CLLocationCoordinate2D(latitude: locationDict[1], longitude: locationDict[0])
            return Waypoint(coordinate: coord)
        }
        
        let options = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: .automobileAvoidingTraffic)
        let route = Route(json: jsonRoute, waypoints: waypoints, options: options)
        return route
    }
}
