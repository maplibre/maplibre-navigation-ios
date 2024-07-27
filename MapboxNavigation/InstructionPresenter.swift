import MapboxDirections
import UIKit

protocol InstructionPresenterDataSource: AnyObject {
    var availableBounds: (() -> CGRect)! { get }
    var font: UIFont! { get }
    var textColor: UIColor! { get }
    var shieldHeight: CGFloat { get }
}

typealias DataSource = InstructionPresenterDataSource

class InstructionPresenter {
    private let instruction: VisualInstruction
    private weak var dataSource: DataSource?

    required init(_ instruction: VisualInstruction, dataSource: DataSource, imageRepository: ImageRepository = .shared, downloadCompletion: ShieldDownloadCompletion?) {
        self.instruction = instruction
        self.dataSource = dataSource
        self.imageRepository = imageRepository
        self.onShieldDownload = downloadCompletion
    }

    typealias ImageDownloadCompletion = (UIImage?) -> Void
    typealias ShieldDownloadCompletion = (NSAttributedString) -> Void
    
    let onShieldDownload: ShieldDownloadCompletion?

    private let imageRepository: ImageRepository
    
    func attributedText() -> NSAttributedString {
        let string = NSMutableAttributedString()
        self.fittedAttributedComponents().forEach { string.append($0) }
        return string
    }
    
    func fittedAttributedComponents() -> [NSAttributedString] {
        guard let source = dataSource else { return [] }
        var attributedPairs = attributedPairs(for: instruction, dataSource: source, imageRepository: imageRepository, onImageDownload: completeShieldDownload)
        let availableBounds = source.availableBounds()
        let totalWidth: CGFloat = attributedPairs.attributedStrings.map { $0.size() }.reduce(CGSize.zero, +).width
        let stringFits = totalWidth <= availableBounds.width
        
        guard !stringFits else { return attributedPairs.attributedStrings }
        
        let indexedComponents: [IndexedVisualInstructionComponent] = attributedPairs.components.enumerated().map { IndexedVisualInstructionComponent(component: $1, index: $0) }
        let filtered = indexedComponents.filter {
            switch $0.component {
            case let .text(text):
                text.abbreviation != nil
            default:
                false
            }
        }
        let sorted = filtered.sorted {
            switch ($0.component, $1.component) {
            case let (.text(text0), .text(text1)):
                text0.abbreviationPriority ?? 0 < text1.abbreviationPriority ?? 0
            default:
                false
            }
        }

        for component in sorted {
            let isFirst = component.index == 0
            let joinChar = isFirst ? "" : " "
            guard case let .text(text) = component.component else { continue }
            guard let abbreviation = text.abbreviation else { continue }
            
            attributedPairs.attributedStrings[component.index] = NSAttributedString(string: joinChar + abbreviation, attributes: self.attributes(for: source))
            let newWidth: CGFloat = attributedPairs.attributedStrings.map { $0.size() }.reduce(.zero, +).width
            
            if newWidth <= availableBounds.width {
                break
            }
        }
        
        return attributedPairs.attributedStrings
    }
    
    typealias AttributedInstructionComponents = (components: [VisualInstruction.Component], attributedStrings: [NSAttributedString])
    
    func attributedPairs(for instruction: VisualInstruction, dataSource: DataSource, imageRepository: ImageRepository, onImageDownload: @escaping ImageDownloadCompletion) -> AttributedInstructionComponents {
        let components = instruction.components
        var strings: [NSAttributedString] = []
        var processedComponents: [VisualInstruction.Component] = []
        
        for (index, component) in components.enumerated() {
            let isFirst = index == 0
            let joinChar = isFirst ? "" : " "
            let joinString = NSAttributedString(string: joinChar, attributes: attributes(for: dataSource))
            let initial = NSAttributedString()
            
            // This is the closure that builds the string.
            let build: (_: VisualInstruction.Component, _: [NSAttributedString]) -> Void = { component, attributedStrings in
                processedComponents.append(component)
                strings.append(attributedStrings.reduce(initial, +))
            }
            let isShield: (_: VisualInstruction.Component?) -> Bool = { component in
                guard case let .image(image, _) = component else { return false }
				
                return image.shield != nil
            }
            let componentBefore = components.component(before: component)
            let componentAfter = components.component(after: component)
            
            switch component {
            // Throw away exit components. We know this is safe because we know that if there is an exit component,
            //  there is an exit code component, and the latter contains the information we care about.
            case .exit:
                continue
                
            // If we have a exit, in the first two components, lets handle that.
            case .exitCode where 0 ... 1 ~= index:
                guard let maneuverDirection = instruction.maneuverDirection else { fallthrough }
                guard let exitString = self.attributedString(forExitComponent: component, maneuverDirection: maneuverDirection, dataSource: dataSource) else { fallthrough }
                build(component, [exitString])
                
            // if it's a delimiter, skip it if it's between two shields.
            case .delimiter where isShield(componentBefore) && isShield(componentAfter):
                continue
                
            // If we have an icon component, lets turn it into a shield.
            case .image:
                if let shieldString = self.attributedString(forShieldComponent: component, repository: imageRepository, dataSource: dataSource, onImageDownload: onImageDownload) {
                    build(component, [joinString, shieldString])
                } else if let genericShieldString = self.attributedString(forGenericShield: component, dataSource: dataSource) {
                    build(component, [joinString, genericShieldString])
                } else {
                    fallthrough
                }
                
            // Otherwise, process as text component.
            default:
                guard let componentString = self.attributedString(forTextComponent: component, dataSource: dataSource) else { continue }
                build(component, [joinString, componentString])
            }
        }
        
        assert(processedComponents.count == strings.count, "The number of processed components must match the number of attributed strings")
        return (components: processedComponents, attributedStrings: strings)
    }

    func attributedString(forExitComponent component: VisualInstruction.Component, maneuverDirection: ManeuverDirection, dataSource: DataSource) -> NSAttributedString? {
        guard case let .exitCode(exitCode) = component else { return nil }
		
        let side: ExitSide = maneuverDirection == .left ? .left : .right
        guard let exitString = exitShield(side: side, text: exitCode.text, component: component, dataSource: dataSource) else { return nil }
		
        return exitString
    }
    
    func attributedString(forGenericShield component: VisualInstruction.Component, dataSource: DataSource) -> NSAttributedString? {
        guard case let .image(_, text) = component else { return nil }
		
        return self.genericShield(text: text.text, component: component, dataSource: dataSource)
    }
    
    func attributedString(forShieldComponent shield: VisualInstruction.Component, repository: ImageRepository, dataSource: DataSource, onImageDownload: @escaping ImageDownloadCompletion) -> NSAttributedString? {
        guard case let .image(image, text) = shield else { return nil }
        guard let shieldKey = image.shield?.name else { return nil }
        
        // If we have the shield already cached, use that.
        if let cachedImage = repository.cachedImageForKey(shieldKey) {
            return self.attributedString(withFont: dataSource.font, shieldImage: cachedImage)
        }
        
        // Let's download the shield
        self.shieldImageForComponent(shield, in: repository, height: dataSource.shieldHeight, completion: onImageDownload)
        
        // Return nothing in the meantime, triggering downstream behavior (generic shield or text)
        return nil
    }
    
    func attributedString(forTextComponent component: VisualInstruction.Component, dataSource: DataSource) -> NSAttributedString? {
        guard case let .text(text) = component else { return nil }
		
        return NSAttributedString(string: text.text, attributes: self.attributes(for: dataSource))
    }
    
    private func shieldImageForComponent(_ component: VisualInstruction.Component, in repository: ImageRepository, height: CGFloat, completion: @escaping ImageDownloadCompletion) {
        guard case let .image(image, text) = component else { return }
        guard let shieldKey = image.shield?.name else { return }
        guard let imageURL = image.imageURL() else { return }
		
        repository.imageWithURL(imageURL, cacheKey: shieldKey, completion: completion)
    }

    private func instructionHasDownloadedAllShields() -> Bool {
        let imageComponents = self.instruction.components.filter {
            switch $0 {
            case .image:
                true
            default:
                false
            }
        }
        guard !imageComponents.isEmpty else { return false }
        
        for component in imageComponents {
            guard case let .image(image, _) = component else { continue }
            guard let key = image.shield?.name else { continue }

            if self.imageRepository.cachedImageForKey(key) == nil {
                return false
            }
        }
        return true
    }

    private func attributes(for dataSource: InstructionPresenterDataSource) -> [NSAttributedString.Key: Any] {
        [.font: dataSource.font as Any, .foregroundColor: dataSource.textColor as Any]
    }

    private func attributedString(withFont font: UIFont, shieldImage: UIImage) -> NSAttributedString {
        let attachment = ShieldAttachment()
        attachment.font = font
        attachment.image = shieldImage
        return NSAttributedString(attachment: attachment)
    }
    
    private func genericShield(text: String, component: VisualInstruction.Component, dataSource: DataSource) -> NSAttributedString? {
        guard case let .image(image, text) = component else { return nil }
        guard let cacheKey = image.shield?.name else { return nil }

        let additionalKey = GenericRouteShield.criticalHash(dataSource: dataSource)
        let attachment = GenericShieldAttachment()
        
        let key = [cacheKey, additionalKey].joined(separator: "-")
        if let image = imageRepository.cachedImageForKey(key) {
            attachment.image = image
        } else {
            let view = GenericRouteShield(pointSize: dataSource.font.pointSize, text: text.text)
            guard let image = takeSnapshot(on: view) else { return nil }
            self.imageRepository.storeImage(image, forKey: key, toDisk: false)
            attachment.image = image
        }
        
        attachment.font = dataSource.font

        return NSAttributedString(attachment: attachment)
    }
    
    private func exitShield(side: ExitSide = .right, text: String, component: VisualInstruction.Component, dataSource: DataSource) -> NSAttributedString? {
        guard case let .image(image, text) = component else { return nil }
        guard let cacheKey = image.shield?.name else { return nil }
        
        let additionalKey = ExitView.criticalHash(side: side, dataSource: dataSource)
        let attachment = ExitAttachment()

        let key = [cacheKey, additionalKey].joined(separator: "-")
        if let image = imageRepository.cachedImageForKey(key) {
            attachment.image = image
        } else {
            let view = ExitView(pointSize: dataSource.font.pointSize, side: side, text: text.text)
            guard let image = takeSnapshot(on: view) else { return nil }
            self.imageRepository.storeImage(image, forKey: key, toDisk: false)
            attachment.image = image
        }
        
        attachment.font = dataSource.font
        
        return NSAttributedString(attachment: attachment)
    }
    
    private func completeShieldDownload(_ image: UIImage?) {
        // We *must* be on main thread here, because attributedText() looks at object properties only accessible on main thread.
        DispatchQueue.main.async {
            self.onShieldDownload?(self.attributedText()) // FIXME: Can we work with the image directly?
        }
    }
    
    private func takeSnapshot(on view: UIView) -> UIImage? {
        view.imageRepresentation
    }
}

protocol ImagePresenter: TextPresenter {
    var image: UIImage? { get }
}

protocol TextPresenter {
    var text: String? { get }
    var font: UIFont { get }
}

class ImageInstruction: NSTextAttachment, ImagePresenter {
    var font: UIFont = .systemFont(ofSize: UIFont.systemFontSize)
    var text: String?
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        guard let image else {
            return super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
        }
        let yOrigin = (font.capHeight - image.size.height).rounded() / 2
        return CGRect(x: 0, y: yOrigin, width: image.size.width, height: image.size.height)
    }
}

class TextInstruction: ImageInstruction {}
class ShieldAttachment: ImageInstruction {}
class GenericShieldAttachment: ShieldAttachment {}
class ExitAttachment: ImageInstruction {}
class RoadNameLabelAttachment: TextInstruction {
    var scale: CGFloat?
    var color: UIColor?

    var compositeImage: UIImage? {
        guard let image, let text, let color, let scale else {
            return nil
        }
        
        var currentImage: UIImage?
        let textHeight = font.lineHeight
        let pointY = (image.size.height - textHeight) / 2
        currentImage = image.insert(text: text as NSString, color: color, font: font, atPoint: CGPoint(x: 0, y: pointY), scale: scale)
        
        return currentImage
    }
    
    convenience init(image: UIImage, text: String, color: UIColor, font: UIFont, scale: CGFloat) {
        self.init()
        self.image = image
        self.font = font
        self.text = text
        self.color = color
        self.scale = scale
        self.image = self.compositeImage ?? image
    }
}

private extension CGSize {
    static var greatestFiniteSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

private struct IndexedVisualInstructionComponent {
    let component: Array<VisualInstruction.Component>.Element
    let index: Array<VisualInstruction.Component>.Index
}

private extension [VisualInstruction.Component] {
    func component(before component: VisualInstruction.Component) -> VisualInstruction.Component? {
        guard let index = firstIndex(of: component) else {
            return nil
        }
        if index > 0 {
            return self[index - 1]
        }
        return nil
    }
    
    func component(after component: VisualInstruction.Component) -> VisualInstruction.Component? {
        guard let index = firstIndex(of: component) else {
            return nil
        }
        if index + 1 < endIndex {
            return self[index + 1]
        }
        return nil
    }
}
