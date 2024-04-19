import CoreLocation
import Foundation
#if os(iOS)
import UIKit
#endif

#if os(iOS)
import UIKit
#endif

public extension UIDevice {
    /**
     Returns a `Bool` whether the device is plugged in. Returns false if not an iOS device.
     */
    @objc var isPluggedIn: Bool {
        #if os(iOS)
        return [.charging, .full].contains(UIDevice.current.batteryState)
        #else
        return false
        #endif
    }
}
