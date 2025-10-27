import CoreLocation
@testable import MapboxCoreNavigation
import XCTest

let oneMile: CLLocationDistance = .metersPerMile
let oneYard: CLLocationDistance = 0.9144
let oneFeet: CLLocationDistance = 0.3048

class DistanceFormatterTests: XCTestCase {
    var distanceFormatter = DistanceFormatter(approximate: true)
    
    override func setUp() {
        super.setUp()
    }
    
    func assertDistance(_ distance: CLLocationDistance, displayed: String, quantity: String, file: StaticString = #file, line: UInt = #line) {
        let displayedString = self.distanceFormatter.string(from: distance)
        XCTAssertEqual(displayedString, displayed, "Displayed: '\(displayedString)' should be equal to \(displayed)", file: file, line: line)
        
        let attributedString = self.distanceFormatter.attributedString(for: distance as NSNumber)
        XCTAssertEqual(attributedString?.string, displayed, "Displayed: '\(attributedString?.string ?? "")' should be equal to \(displayed)", file: file, line: line)
        guard let checkedAttributedString = attributedString else {
            return
        }
        
        let quantityRange = checkedAttributedString.string.range(of: quantity)
        XCTAssertNotNil(quantityRange, "Displayed: '\(checkedAttributedString.string)' should contain \(quantity)", file: file, line: line)
        guard let checkedQuantityRange = quantityRange else {
            return
        }
        
        var effectiveQuantityRange = NSRange(location: NSNotFound, length: 0)
        let quantityAttrs = checkedAttributedString.attributes(at: checkedQuantityRange.lowerBound.utf16Offset(in: checkedAttributedString.string), effectiveRange: &effectiveQuantityRange)
        XCTAssertEqual(quantityAttrs[NSAttributedString.Key.quantity] as? NSNumber, distance as NSNumber, "'\(quantity)' should have quantity \(distance)", file: file, line: line)
        XCTAssertEqual(effectiveQuantityRange.length, quantity.count, file: file, line: line)
        
        guard checkedQuantityRange.upperBound.utf16Offset(in: checkedAttributedString.string) < checkedAttributedString.length else {
            return
        }
        let unitAttrs = checkedAttributedString.attributes(at: checkedQuantityRange.upperBound.utf16Offset(in: checkedAttributedString.string), effectiveRange: nil)
        XCTAssertNil(unitAttrs[NSAttributedString.Key.quantity], "Unit should not be emphasized like a quantity", file: file, line: line)
    }
    
    func testDistanceFormatters_US() {
        NavigationSettings.shared.distanceUnit = .mile
        self.distanceFormatter.locale = Locale(identifier: "en-US")
        
        self.assertDistance(0, displayed: "0 ft", quantity: "0")
        self.assertDistance(oneFeet * 50, displayed: "50 ft", quantity: "50")
        self.assertDistance(oneFeet * 100, displayed: "100 ft", quantity: "100")
        self.assertDistance(oneFeet * 249, displayed: "250 ft", quantity: "250")
        self.assertDistance(oneFeet * 305, displayed: "300 ft", quantity: "300")
        self.assertDistance(oneMile * 0.1, displayed: "0.1 mi", quantity: "0.1")
        self.assertDistance(oneMile * 0.24, displayed: "0.2 mi", quantity: "0.2")
        self.assertDistance(oneMile * 0.251, displayed: "0.3 mi", quantity: "0.3")
        self.assertDistance(oneMile * 0.75, displayed: "0.8 mi", quantity: "0.8")
        self.assertDistance(oneMile, displayed: "1 mi", quantity: "1")
        self.assertDistance(oneMile * 2.5, displayed: "2.5 mi", quantity: "2.5")
        self.assertDistance(oneMile * 2.9, displayed: "2.9 mi", quantity: "2.9")
        self.assertDistance(oneMile * 3, displayed: "3 mi", quantity: "3")
        self.assertDistance(oneMile * 5.4, displayed: "5 mi", quantity: "5")
    }
    
    func testDistanceFormatters_DE() {
        NavigationSettings.shared.distanceUnit = .kilometer
        self.distanceFormatter.locale = Locale(identifier: "de-DE")
        
        self.assertDistance(0, displayed: "0 m", quantity: "0")
        self.assertDistance(4, displayed: "5 m", quantity: "5")
        self.assertDistance(11, displayed: "10 m", quantity: "10")
        self.assertDistance(15, displayed: "15 m", quantity: "15")
        self.assertDistance(24, displayed: "25 m", quantity: "25")
        self.assertDistance(89, displayed: "100 m", quantity: "100")
        self.assertDistance(226, displayed: "250 m", quantity: "250")
        self.assertDistance(275, displayed: "300 m", quantity: "300")
        self.assertDistance(500, displayed: "500 m", quantity: "500")
        self.assertDistance(949, displayed: "950 m", quantity: "950")
        self.assertDistance(951, displayed: "950 m", quantity: "950")
        self.assertDistance(999, displayed: "1 km", quantity: "1")
        self.assertDistance(1000, displayed: "1 km", quantity: "1")
        self.assertDistance(1001, displayed: "1 km", quantity: "1")
        self.assertDistance(2500, displayed: "2,5 km", quantity: "2,5")
        self.assertDistance(2900, displayed: "2,9 km", quantity: "2,9")
        self.assertDistance(3000, displayed: "3 km", quantity: "3")
        self.assertDistance(3500, displayed: "4 km", quantity: "4")
    }
    
    func testDistanceFormatters_GB() {
        NavigationSettings.shared.distanceUnit = .mile
        self.distanceFormatter.locale = Locale(identifier: "en-GB")
        
        self.assertDistance(0, displayed: "0 yd", quantity: "0")
        self.assertDistance(oneYard * 4, displayed: "0 yd", quantity: "0")
        self.assertDistance(oneYard * 5, displayed: "10 yd", quantity: "10")
        self.assertDistance(oneYard * 12, displayed: "10 yd", quantity: "10")
        self.assertDistance(oneYard * 24, displayed: "25 yd", quantity: "25")
        self.assertDistance(oneYard * 25, displayed: "25 yd", quantity: "25")
        self.assertDistance(oneYard * 38, displayed: "50 yd", quantity: "50")
        self.assertDistance(oneYard * 126, displayed: "150 yd", quantity: "150")
        self.assertDistance(oneYard * 150, displayed: "150 yd", quantity: "150")
        self.assertDistance(oneYard * 174, displayed: "150 yd", quantity: "150")
        self.assertDistance(oneYard * 175, displayed: "200 yd", quantity: "200")
        self.assertDistance(oneMile / 2, displayed: "0.5 mi", quantity: "0.5")
        self.assertDistance(oneMile, displayed: "1 mi", quantity: "1")
        self.assertDistance(oneMile * 2.5, displayed: "2.5 mi", quantity: "2.5")
        self.assertDistance(oneMile * 3, displayed: "3 mi", quantity: "3")
    }
    
    func testDistanceFormatters_he_IL() {
        NavigationSettings.shared.distanceUnit = .kilometer
        self.distanceFormatter.numberFormatter.locale = Locale(identifier: "he-IL")
        
        self.assertDistance(0, displayed: "0 מ׳", quantity: "0")
        self.assertDistance(4, displayed: "5 מ׳", quantity: "5")
        self.assertDistance(11, displayed: "10 מ׳", quantity: "10")
        self.assertDistance(15, displayed: "15 מ׳", quantity: "15")
        self.assertDistance(24, displayed: "25 מ׳", quantity: "25")
        self.assertDistance(89, displayed: "100 מ׳", quantity: "100")
        self.assertDistance(226, displayed: "250 מ׳", quantity: "250")
        self.assertDistance(275, displayed: "300 מ׳", quantity: "300")
        self.assertDistance(500, displayed: "500 מ׳", quantity: "500")
        self.assertDistance(949, displayed: "950 מ׳", quantity: "950")
        self.assertDistance(951, displayed: "950 מ׳", quantity: "950")
    }
    
    func testInches() {
        let oneMeter: CLLocationDistance = 1
        let oneMeterInInches = oneMeter.converted(to: .inch)
        XCTAssertEqual(oneMeterInInches, 39.3700787, accuracy: 0.00001)
    }
}
