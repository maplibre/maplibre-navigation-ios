import CoreLocation
import Foundation
import MapboxCoreNavigation
import MapboxDirections

class RouteControllerDelegateSpy: RouteControllerDelegate {
    private(set) var recentMessages: [String] = []

    public func reset() {
        self.recentMessages.removeAll()
    }

    func routeController(_ routeController: RouteController, shouldRerouteFrom location: CLLocation) -> Bool {
        self.recentMessages.append(#function)
        return true
    }

    func routeController(_ routeController: RouteController, willRerouteFrom location: CLLocation) {
        self.recentMessages.append(#function)
    }

    func routeController(_ routeController: RouteController, shouldDiscard location: CLLocation) -> Bool {
        self.recentMessages.append(#function)
        return true
    }
    
    func routeController(_ routeController: RouteController, didRerouteAlong route: Route, reason: RouteController.RerouteReason) {
        self.recentMessages.append(#function)
    }

    func routeController(_ routeController: RouteController, didFailToRerouteWith error: Error) {
        self.recentMessages.append(#function)
    }

    func routeController(_ routeController: RouteController, didUpdate locations: [CLLocation]) {
        self.recentMessages.append(#function)
    }

    func routeController(_ routeController: RouteController, didArriveAt waypoint: Waypoint) -> Bool {
        self.recentMessages.append(#function)
        return true
    }
    
    func routeController(_ routeController: RouteController, shouldPreventReroutesWhenArrivingAt waypoint: Waypoint) -> Bool {
        self.recentMessages.append(#function)
        return true
    }
}
