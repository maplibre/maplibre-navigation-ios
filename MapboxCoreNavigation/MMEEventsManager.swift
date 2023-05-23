import Polyline
import MapboxDirections
import AVFoundation
import UIKit

let SecondsBeforeCollectionAfterFeedbackEvent: TimeInterval = 20
let EventVersion = 8

extension UIDevice {
    @nonobjc var machine: String {
        get {
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            return machineMirror.children.reduce("") { (identifier: String, element: Mirror.Child) in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
        }
    }
}
