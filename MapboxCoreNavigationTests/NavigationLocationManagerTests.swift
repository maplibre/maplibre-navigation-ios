import XCTest
import MapboxCoreNavigation
import CoreLocation


class NavigationLocationManagerTests: XCTestCase {
    
    func testNavigationLocationManagerDefaultAccuracy() {
        let locationManager = NavigationLocationManager()
        XCTAssertEqual(locationManager.desiredAccuracy, kCLLocationAccuracyBest)
    }
}
