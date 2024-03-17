import Foundation
import iOSSnapshotTestCase

@nonobjc extension FBSnapshotTestCase {
    func verify(_ view: UIView) {
        FBSnapshotVerifyView(view, suffixes: ["_64"])
    }
    func verify(_ layer: CALayer) {
        FBSnapshotVerifyLayer(layer, suffixes: ["_64"])
    }
}
