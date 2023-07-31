import XCTest
import iOSSnapshotTestCase
import MapboxDirections
@testable import MapboxNavigation
@testable import MapboxCoreNavigation
import TestHelpers

class MapboxNavigationTests: FBSnapshotTestCase {

    private var bogusToken: String!
    private var route: Route!
    private var directions: Directions!

    override func setUp() {
        super.setUp()
        recordMode = false
        // TODO: this is not available in the new `iOSSnapshotTestCase`
//        isDeviceAgnostic = true

        let response = Fixture.JSONFromFileNamed(name: "route-with-lanes", bundle: .module)
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String : Any]
        let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165))
        let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))
        bogusToken = "pk.feedCafeDeadBeefBadeBede"
        directions = Directions(accessToken: bogusToken)
        route = Route(json: jsonRoute, waypoints: [waypoint1, waypoint2], options: RouteOptions(waypoints: [waypoint1, waypoint2]))
    }

    func storyboard() -> UIStoryboard {
        return UIStoryboard(name: "Navigation", bundle: .mapboxNavigation)
    }

    func testLanes() {
        // TODO: testLanes(): Storyboard (<UIStoryboard: 0x60000269a460>) doesn't contain a view controller with identifier 'RouteMapViewController' (NSInvalidArgumentException)
        let controller = storyboard().instantiateViewController(withIdentifier: "RouteMapViewController") as! RouteMapViewController
        XCTAssert(controller.view != nil)

        route.accessToken = bogusToken
        let routeController = RouteController(along: route, directions: directions)
        routeController.advanceStepIndex(to: 7)

        // TODO: this is not available in the new `routeController`
//        controller.lanesView.update(for: routeController.routeProgress.currentLegProgress)
        controller.lanesView.show()

        verify(controller.lanesView)
    }
}
