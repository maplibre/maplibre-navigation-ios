import Foundation

public extension CGPoint {
    /**
     Calculates the straight line distance between two `CGPoint`.
     */
    func distance(to: CGPoint) -> CGFloat {
        sqrt((x - to.x) * (x - to.x) + (y - to.y) * (y - to.y))
    }
}
