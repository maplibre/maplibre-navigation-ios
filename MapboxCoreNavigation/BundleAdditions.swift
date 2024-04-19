import Foundation

extension Bundle {
    /**
     Returns a set of strings containing supported background mode types.
     */
    public var backgroundModes: Set<String> {
        if let modes = object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] {
            return Set<String>(modes)
        }
        return []
    }
    
    var locationAlwaysAndWhenInUseUsageDescription: String? {
        object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") as? String
    }
    
    var locationWhenInUseUsageDescription: String? {
        object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String
    }
    
    var locationAlwaysUsageDescription: String? {
        object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") as? String
    }
    
    class var mapboxCoreNavigation: Bundle { Bundle(for: RouteController.self) }
}
