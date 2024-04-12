import Foundation
import MapboxDirections
#if canImport(CarPlay)
import CarPlay

public extension CongestionLevel {
    /**
     Converts a CongestionLevel to a CPTimeRemainingColor.
     */
    @available(iOS 12.0, *)
    var asCPTimeRemainingColor: CPTimeRemainingColor {
        switch self {
        case .unknown:
            .default
        case .low:
            .green
        case .moderate:
            .orange
        case .heavy:
            .red
        case .severe:
            .red
        }
    }
}
#endif
