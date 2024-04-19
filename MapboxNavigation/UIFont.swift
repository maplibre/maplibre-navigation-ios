import UIKit

extension UIFont {
    var fontSizeMultiplier: CGFloat {
        switch UIApplication.shared.preferredContentSizeCategory {
        case UIContentSizeCategory.accessibilityExtraExtraExtraLarge: 23 / 16
        case UIContentSizeCategory.accessibilityExtraExtraLarge: 22 / 16
        case UIContentSizeCategory.accessibilityExtraLarge: 21 / 16
        case UIContentSizeCategory.accessibilityLarge: 20 / 16
        case UIContentSizeCategory.accessibilityMedium: 19 / 16
        case UIContentSizeCategory.extraExtraExtraLarge: 19 / 16
        case UIContentSizeCategory.extraExtraLarge: 18 / 16
        case UIContentSizeCategory.extraLarge: 17 / 16
        case UIContentSizeCategory.large: 1
        case UIContentSizeCategory.medium: 15 / 16
        case UIContentSizeCategory.small: 14 / 16
        case UIContentSizeCategory.extraSmall: 13 / 16
        default: 1
        }
    }
    
    /**
     Returns an adjusted font for the `preferredContentSizeCategory`.
     */
    @objc public var adjustedFont: UIFont {
        let font = self.with(multiplier: self.fontSizeMultiplier)
        return font
    }
    
    func with(multiplier: CGFloat) -> UIFont {
        let font = UIFont(descriptor: fontDescriptor, size: pointSize * self.fontSizeMultiplier)
        return font
    }
    
    func with(fontFamily: String?) -> UIFont {
        guard let fontFamily else { return self }
        let weight = (fontDescriptor.object(forKey: .traits) as! [String: Any])[UIFontDescriptor.TraitKey.weight.rawValue]
        let descriptor = UIFontDescriptor(name: fontName, size: pointSize).withFamily(fontFamily).addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func with(weight: CGFloat) -> UIFont {
        let font = UIFont(descriptor: fontDescriptor.addingAttributes([.traits: weight]), size: pointSize)
        return font
    }
}
