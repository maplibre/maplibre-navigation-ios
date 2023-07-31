import UIKit

class BundleHelper { }

extension Bundle {
    
    class var mapboxNavigation: Bundle {
        get { Bundle.module }
    }
    
    func image(named: String) -> UIImage? {
        return UIImage(named: named, in: self, compatibleWith: nil)
    }
    
    var microphoneUsageDescription: String? {
        get {
            let para = "NSMicrophoneUsageDescription"
            let key = "Privacy - Microphone Usage Description"
            return object(forInfoDictionaryKey: para) as? String ?? object(forInfoDictionaryKey: key) as? String
        }
    }
}
