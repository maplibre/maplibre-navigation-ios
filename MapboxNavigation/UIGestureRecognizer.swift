import Foundation
import UIKit

extension UIGestureRecognizer {
    var point: CGPoint? {
        guard let view else { return nil }
        return location(in: view)
    }
    
    func requireFailure(of gestures: [UIGestureRecognizer]?) {
        guard let gestures else { return }
        gestures.forEach(require(toFail:))
    }
}
