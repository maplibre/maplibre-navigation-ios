import MapboxDirections
import UIKit

extension VisualInstructionComponent {
    static let scale = UIScreen.main.scale
    
    var cacheKey: String? {
        switch type {
        case .exit, .exitCode:
            guard let exitCode = text else { return nil }
            return "exit-" + exitCode + "-\(VisualInstructionComponent.scale)"
        case .image:
            guard let imageURL else { return self.genericCacheKey }
            return "\(imageURL.absoluteString)-\(VisualInstructionComponent.scale)"
        case .text, .delimiter:
            return nil
        }
    }
    
    var genericCacheKey: String {
        "generic-" + (text ?? "nil")
    }
}
