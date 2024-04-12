import Foundation
import MapboxDirections

extension ManeuverDirection {
    init(angle: Int) {
        let description = switch angle {
        case -30 ..< 30:
            "straight"
        case 30 ..< 60:
            "slight right"
        case 60 ..< 150:
            "right"
        case 150 ..< 180:
            "sharp right"
        case -180 ..< -150:
            "sharp left"
        case -150 ..< -60:
            "left"
        case -50 ..< -30:
            "slight left"
        default:
            "straight"
        }
        self.init(description: description)!
    }
}
