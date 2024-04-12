import CoreLocation
import MapboxDirections
import MapboxDirectionsObjc

extension RouteOptions {
    var activityType: CLActivityType {
        switch profileIdentifier {
        case MBDirectionsProfileIdentifier.cycling, MBDirectionsProfileIdentifier.walking:
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
        let copy = copy() as! RouteOptions
        copy.waypoints = waypointsWithoutSpecified
        
        return copy
    }
}
