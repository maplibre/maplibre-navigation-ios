import CoreLocation
@testable import MapboxNavigation
import Solar
import XCTest

enum Location {
    static let sf = CLLocation(latitude: 37.78, longitude: -122.40)
    static let london = CLLocation(latitude: 51.50, longitude: -0.12)
    static let paris = CLLocation(latitude: 48.85, longitude: 2.35)
}

class StyleManagerTests: XCTestCase {
    var location = Location.london
    var styleManager: StyleManager!
    
    override func setUp() {
        super.setUp()
        self.styleManager = StyleManager(self, dayStyle: DayStyle(demoStyle: ()), nightStyle: NightStyle(demoStyle: ()))
        self.styleManager.automaticallyAdjustsStyleForTimeOfDay = true
    }
    
    func testStyleManagerLondon() {
        self.location = Location.london
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let beforeSunrise = dateFormatter.date(from: "05:00")!
        let afterSunrise = dateFormatter.date(from: "09:00")!
        let noonDate = dateFormatter.date(from: "12:00")!
        let beforeSunset = dateFormatter.date(from: "16:00")!
        let afterSunset = dateFormatter.date(from: "21:00")!
        let midnight = dateFormatter.date(from: "00:00")!
        
        self.styleManager.stubbedDate = beforeSunrise
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
        self.styleManager.stubbedDate = afterSunrise
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = noonDate
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = beforeSunset
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = afterSunset
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
        self.styleManager.stubbedDate = midnight
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
    }

    func testStyleManagerParisWithSeconds() {
        self.location = Location.paris
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "CET")

        NSTimeZone.default = NSTimeZone(abbreviation: "CET")! as TimeZone

        let justBeforeSunrise = dateFormatter.date(from: "08:44:05")!
        let justAfterSunrise = dateFormatter.date(from: "08:44:30")!
        let noonDate = dateFormatter.date(from: "12:00:00")!
        let juetBeforeSunset = dateFormatter.date(from: "17:04:05")!
        let justAfterSunset = dateFormatter.date(from: "17:04:30")!
        let midnight = dateFormatter.date(from: "00:00:00")!

        self.styleManager.stubbedDate = justBeforeSunrise
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
        self.styleManager.stubbedDate = justAfterSunrise
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = noonDate
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = juetBeforeSunset
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = justAfterSunset
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
        self.styleManager.stubbedDate = midnight
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
    }
    
    func testStyleManagerSanFrancisco() {
        self.location = Location.sf
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        dateFormatter.timeZone = TimeZone(identifier: "PST")
        dateFormatter.locale = Locale(identifier: "en_US")

        NSTimeZone.default = NSTimeZone(abbreviation: "PST")! as TimeZone
        
        let beforeSunrise = dateFormatter.date(from: "05:00 AM")!
        let afterSunrise = dateFormatter.date(from: "09:00 AM")!
        let noonDate = dateFormatter.date(from: "12:00 PM")!
        let beforeSunset = dateFormatter.date(from: "04:00 PM")!
        let afterSunset = dateFormatter.date(from: "09:00 PM")!
        let midnight = dateFormatter.date(from: "00:00 AM")!
        
        self.styleManager.stubbedDate = beforeSunrise
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
        self.styleManager.stubbedDate = afterSunrise
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = noonDate
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = beforeSunset
        XCTAssert(self.styleManager.styleType(for: self.location) == .day)
        self.styleManager.stubbedDate = afterSunset
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
        self.styleManager.stubbedDate = midnight
        XCTAssert(self.styleManager.styleType(for: self.location) == .night)
    }

    func testTimeIntervalsUntilTimeOfDayChanges() {
        self.location = Location.paris
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone(identifier: "CET")

        NSTimeZone.default = NSTimeZone(abbreviation: "CET")! as TimeZone

        let sunrise = dateFormatter.date(from: "08:00")!
        let sunset = dateFormatter.date(from: "18:00")!

        let beforeSunriseAfterMidnight = dateFormatter.date(from: "02:00")!
        let afterSunriseBeforeSunset = dateFormatter.date(from: "11:00")!
        let afterSunsetBeforeMidnight = dateFormatter.date(from: "22:00")!

        XCTAssert(beforeSunriseAfterMidnight.intervalUntilTimeOfDayChanges(sunrise: sunrise, sunset: sunset) == (6 * 3600))
        XCTAssert(afterSunriseBeforeSunset.intervalUntilTimeOfDayChanges(sunrise: sunrise, sunset: sunset) == (7 * 3600))
        XCTAssert(afterSunsetBeforeMidnight.intervalUntilTimeOfDayChanges(sunrise: sunrise, sunset: sunset) == (10 * 3600))
    }
}

extension StyleManagerTests: StyleManagerDelegate {
    func styleManagerDidRefreshAppearance(_ styleManager: StyleManager) {}
    func styleManager(_ styleManager: StyleManager, didApply style: Style) {}
    
    func locationFor(styleManager: StyleManager) -> CLLocation? {
        self.location
    }
}
