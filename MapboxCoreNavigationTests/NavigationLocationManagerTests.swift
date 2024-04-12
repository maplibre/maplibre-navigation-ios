import CoreLocation
import MapboxCoreNavigation
import XCTest

class NavigationLocationManagerTests: XCTestCase {
    func testNavigationLocationManagerDefaultAccuracy() {
        let locationManager = NavigationLocationManager()
        XCTAssertEqual(locationManager.desiredAccuracy, kCLLocationAccuracyBest)
    }
}
