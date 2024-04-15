import CoreGraphics
import UIKit

typealias RatingClosure = (Int) -> Void // rating

/*@IBDesignable*/
class RatingControl: UIStackView {
    // MARK: Constants

    static let defaultSize = CGSize(width: 32.0, height: 32.0)
    private let starTemplate = UIImage(named: "star", in: .mapboxNavigation, compatibleWith: nil)
    
    // MARK: Properties

    private var stars = [UIButton]()
    
    var didChangeRating: RatingClosure?
    
    var rating: Int = 0 {
        didSet {
            self.updateSelectionStates()
            self.didChangeRating?(self.rating)
        }
    }
    
    @objc public dynamic var selectedColor: UIColor = #colorLiteral(red: 0.1205472574, green: 0.2422055006, blue: 0.3489340544, alpha: 1) {
        didSet {
            updateSelectionStates()
        }
    }

    @objc public dynamic var normalColor: UIColor = #colorLiteral(red: 0.8508961797, green: 0.8510394692, blue: 0.850877285, alpha: 1) {
        didSet {
            updateSelectionStates()
        }
    }
    
    @objc public dynamic var starSize: CGSize = defaultSize {
        didSet {
            self.configureStars()
        }
    }
    
    @objc public dynamic var starCount: Int = 5 {
        didSet {
            self.configureStars()
        }
    }
    
    // MARK: Initializers

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.configureStars()
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        self.configureStars()
    }
    
    // MARK: Private Functions

    private func configureStars() {
        self.removeStars()
        self.addStars()
        self.updateSelectionStates()
    }
    
    private func addStars() {
        for index in 0 ..< self.starCount {
            let button = UIButton(type: .custom)
            button.setImage(self.starTemplate, for: .normal)
            button.adjustsImageWhenHighlighted = false
            self.addButtonSizeConstraints(to: button)
            
            let setRatingNumber = index + 1
            let localizedString = NSLocalizedString("RATING_ACCESSIBILITY_SET", bundle: .mapboxNavigation, value: "Set %ld-star rating", comment: "Format for accessibility label of button for setting a rating; 1 = number of stars")
            button.accessibilityLabel = String.localizedStringWithFormat(localizedString, setRatingNumber)
            
            button.addTarget(self, action: #selector(RatingControl.ratingButtonTapped(button:)), for: .touchUpInside)
            
            addArrangedSubview(button)
            
            self.stars.append(button)
        }
    }
    
    private func removeStars() {
        for star in self.stars {
            removeArrangedSubview(star)
            star.removeFromSuperview()
        }
        self.stars.removeAll()
    }
    
    private func updateSelectionStates() {
        for (index, button) in self.stars.enumerated() {
            let selected = index < self.rating
            button.tintColor = selected ? self.selectedColor : self.normalColor
            button.isSelected = selected
            
            self.setAccessibility(for: button, at: index)
        }
    }
    
    private func setAccessibility(for button: UIButton, at index: Int) {
        self.setAccessibilityHint(for: button, at: index)
        
        let value: String = if self.rating == 0 {
            NSLocalizedString("NO_RATING", bundle: .mapboxNavigation, value: "No rating set.", comment: "Accessibility value of label indicating the absence of a rating")
        } else {
            String.localizedStringWithFormat(NSLocalizedString("RATING_STARS_FORMAT", bundle: .mapboxNavigation, value: "%ld star(s) set.", comment: "Format for accessibility value of label indicating the existing rating; 1 = number of stars"), self.rating)
        }
        
        button.accessibilityValue = value
    }
    
    private func setAccessibilityHint(for button: UIButton, at index: Int) {
        guard self.rating == (index + 1) else { return } // This applies only to the zero-resettable button.
        
        button.accessibilityHint = NSLocalizedString("RATING_ACCESSIBILITY_RESET", bundle: .mapboxNavigation, value: "Tap to reset the rating to zero.", comment: "Rating Reset To Zero Accessability Hint")
    }
    
    private func addButtonSizeConstraints(to view: UIView) {
        view.widthAnchor.constraint(equalToConstant: self.starSize.width).isActive = true
        view.heightAnchor.constraint(equalToConstant: self.starSize.height).isActive = true
    }
    
    @objc private func ratingButtonTapped(button sender: UIButton) {
        guard let index = stars.firstIndex(of: sender) else { return assertionFailure("RatingControl.swift: The Star button that was tapped was not found in the RatingControl.stars array. This should never happen.") }
        let selectedRating = index + 1
        
        self.rating = (selectedRating == self.rating) ? 0 : selectedRating
    }
}
