import Foundation
import FBSnapshotTestCase

@nonobjc extension FBSnapshotTestCase {
    func verify(_ view: UIView) {
        snapshotVerifyViewOrLayer(view, identifier: nil, suffixes: ["_64"], overallTolerance: 1.0, defaultReferenceDirectory: nil, defaultImageDiffDirectory: nil)
    }
    func verify(_ layer: CALayer) {
        snapshotVerifyViewOrLayer(layer, identifier: nil, suffixes: ["_64"], overallTolerance: 1.0, defaultReferenceDirectory: nil, defaultImageDiffDirectory: nil)
    }
}
