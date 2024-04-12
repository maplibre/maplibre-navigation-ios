import Foundation
import MapboxDirections
import UIKit

public extension UIEdgeInsets {
    static func + (left: UIEdgeInsets, right: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: left.top + right.top,
                     left: left.left + right.left,
                     bottom: left.bottom + right.bottom,
                     right: left.right + right.right)
    }
    
    static func > (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> Bool {
        (lhs.top + lhs.left + lhs.bottom + lhs.right)
            > (rhs.top + rhs.left + rhs.bottom + rhs.right)
    }
}

extension UIEdgeInsets: ExpressibleByFloatLiteral {
    public typealias FloatLiteralType = Double
    
    public init(floatLiteral value: FloatLiteralType) {
        let padding = CGFloat(value)
        self.init(top: padding, left: padding, bottom: padding, right: padding)
    }
}
