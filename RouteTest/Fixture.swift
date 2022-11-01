import Foundation
import MapboxDirections
import MapboxCoreNavigation

class Fixture {
    class func JSONFromFileNamed(name: String, bundle: Bundle = .main) -> [String: Any] {
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
    
    class func route(from url: URL) -> Route {
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
    
    class func route(from filename: String) -> Route {
        let response = Fixture.JSONFromFileNamed(name: filename)
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
}
