import Foundation
import MapboxDirections
import MapboxCoreNavigation
import CoreLocation

public class Fixture {
    public class func JSONFromFileNamed(name: String, bundle: Bundle) -> [String: Any] {
        guard let path = bundle.path(forResource: name, ofType: "json") ?? bundle.path(forResource: name, ofType: "geojson") else {
            return [:]
        }
        guard let data = NSData(contentsOfFile: path) else {
            return [:]
        }
        do {
            return try JSONSerialization.jsonObject(with: data as Data, options: []) as! [String: AnyObject]
        } catch {
            return [:]
        }
    }
    
    public class func route(from url: URL) -> Route {
        let semaphore = DispatchSemaphore(value: 0)
        
        var json = [String: Any]()
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                assertionFailure("No route data")
                return
            }
            json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String : Any]
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return route(from: json)
    }
    
    public class func route(from filename: String, bundle: Bundle) -> Route {
        let response = Fixture.JSONFromFileNamed(name: filename, bundle: bundle)
        return route(from: response)
    }
    
    fileprivate class func route(from response: [String: Any]) -> Route {
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
    
    public class func route(from jsonFile: String, waypoints: [Waypoint], bundle: Bundle) -> Route {
        let response = JSONFromFileNamed(name: jsonFile, bundle: bundle)
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String : Any]
        return Route(json: jsonRoute, waypoints: waypoints, options: RouteOptions(waypoints: waypoints))
    }
    
    public class func routeWithBannerInstructions(bundle: Bundle) -> Route {
        return route(from: "route-with-banner-instructions", waypoints: [Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165)), Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))], bundle: bundle)
    }
    
    public class func blankStyle(bundle: Bundle) -> URL {
        let path = bundle.path(forResource: "EmptyStyle", ofType: "json")
        return URL(fileURLWithPath: path!)
    }
    
}
