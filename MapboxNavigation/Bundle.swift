import UIKit

extension Bundle {
    class var mapboxNavigation: Bundle { .module }
    
    func image(named: String) -> UIImage? {
        UIImage(named: named, in: self, compatibleWith: nil)
    }
    
    var microphoneUsageDescription: String? {
        let para = "NSMicrophoneUsageDescription"
        let key = "Privacy - Microphone Usage Description"
        return object(forInfoDictionaryKey: para) as? String ?? object(forInfoDictionaryKey: key) as? String
    }
}
