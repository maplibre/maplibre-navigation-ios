import CoreLocation
import MapboxDirections

extension RouteOptions {
    var activityType: CLActivityType {
        switch profileIdentifier {
        case ProfileIdentifier.cycling, ProfileIdentifier.walking:
            .fitness
        default:
            .automotiveNavigation
        }
    }
    
    /**
     Returns a copy of RouteOptions without the specified waypoint.
     
     - parameter waypoint: the Waypoint to exclude.
     - returns: a copy of self excluding the specified waypoint.
     */
    public func without(waypoint: Waypoint) -> RouteOptions {
        let waypointsWithoutSpecified = waypoints.filter { $0 != waypoint }
        let copy = try! self.copy()
        copy.waypoints = waypointsWithoutSpecified
        
        return copy
    }
}

extension Encodable where Self: Decodable {
    func copy() throws -> Self {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
