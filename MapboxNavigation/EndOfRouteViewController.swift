import MapboxDirections
import UIKit

private enum ConstraintSpacing: CGFloat {
    case closer = 8.0
    case further = 65.0
}

private enum ContainerHeight: CGFloat {
    case normal = 200
    case commentShowing = 260
}

/// :nodoc:
@objc(MBEndOfRouteContentView)
open class EndOfRouteContentView: UIView {}

/// :nodoc:
@objc(MBEndOfRouteTitleLabel)
open class EndOfRouteTitleLabel: StylableLabel {}

/// :nodoc:
@objc(MBEndOfRouteStaticLabel)
open class EndOfRouteStaticLabel: StylableLabel {}

/// :nodoc:
@objc(MBEndOfRouteCommentView)
open class EndOfRouteCommentView: StylableTextView {}

/// :nodoc:
@objc(MBEndOfRouteButton)
open class EndOfRouteButton: StylableButton {}

@objc(MBEndOfRouteViewController)
class EndOfRouteViewController: UIViewController {
    // MARK: - IBOutlets

    @IBOutlet var labelContainer: UIView!
    @IBOutlet var staticYouHaveArrived: EndOfRouteStaticLabel!
    @IBOutlet var primary: UILabel!
    @IBOutlet var endNavigationButton: UIButton!
    @IBOutlet var stars: RatingControl!
    @IBOutlet var commentView: UITextView!
    @IBOutlet var commentViewContainer: UIView!
    @IBOutlet var showCommentView: NSLayoutConstraint!
    @IBOutlet var hideCommentView: NSLayoutConstraint!
    @IBOutlet var ratingCommentsSpacing: NSLayoutConstraint!
    
    // MARK: - Properties

    lazy var placeholder: String = NSLocalizedString("END_OF_ROUTE_TITLE", bundle: .mapboxNavigation, value: "How can we improve?", comment: "Comment Placeholder Text")
    lazy var endNavigation: String = NSLocalizedString("END_NAVIGATION", bundle: .mapboxNavigation, value: "End Navigation", comment: "End Navigation Button Text")
    
    typealias DismissHandler = (Int, String?) -> Void
    var dismissHandler: DismissHandler?
    var comment: String?
    var rating: Int = 0 {
        didSet {
            self.rating == 0 ? self.hideComments() : self.showComments()
        }
    }
    
    open var destination: Waypoint? {
        didSet {
            guard isViewLoaded else { return }
            self.updateInterface()
        }
    }

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearInterface()
        self.stars.didChangeRating = { [weak self] new in self?.rating = new }
        self.setPlaceholderText()
        self.styleCommentView()
        self.commentViewContainer.alpha = 0.0 // setting initial hidden state
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.roundCorners([.topLeft, .topRight])
        preferredContentSize.height = self.height(for: .normal)
        self.updateInterface()
    }

    // MARK: - IBActions

    @IBAction func endNavigationPressed(_ sender: Any) {
        self.dismissView()
    }
    
    // MARK: - Private Functions

    private func styleCommentView() {
        self.commentView.layer.cornerRadius = 6.0
        self.commentView.layer.borderColor = UIColor.lightGray.cgColor
        self.commentView.layer.borderWidth = 1.0
        self.commentView.textContainerInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
    }
    
    fileprivate func dismissView() {
        let dismissal: () -> Void = { self.dismissHandler?(self.rating, self.comment) }
        guard self.commentView.isFirstResponder else { return _ = dismissal() }
        self.commentView.resignFirstResponder()
        let fireTime = DispatchTime.now() + 0.3 // Not ideal, but works for now
        DispatchQueue.main.asyncAfter(deadline: fireTime, execute: dismissal)
    }
    
    private func showComments(animated: Bool = true) {
        self.showCommentView.isActive = true
        self.hideCommentView.isActive = false
        self.ratingCommentsSpacing.constant = ConstraintSpacing.closer.rawValue
        preferredContentSize.height = self.height(for: .commentShowing)

        let animate = {
            self.view.layoutIfNeeded()
            self.commentViewContainer.alpha = 1.0
            self.labelContainer.alpha = 0.0
        }
        
        let completion: (Bool) -> Void = { _ in self.labelContainer.isHidden = true }
        let noAnimate = { animate(); completion(true) }
        if animated {
            UIView.animate(withDuration: 0.3, animations: animate, completion: nil)
        } else {
            noAnimate()
        }
    }
    
    private func hideComments(animated: Bool = true) {
        self.labelContainer.isHidden = false
        self.showCommentView.isActive = false
        self.hideCommentView.isActive = true
        self.ratingCommentsSpacing.constant = ConstraintSpacing.further.rawValue
        preferredContentSize.height = self.height(for: .normal)
        
        let animate = {
            self.view.layoutIfNeeded()
            self.commentViewContainer.alpha = 0.0
            self.labelContainer.alpha = 1.0
        }
        
        let completion: (Bool) -> Void = { _ in self.commentViewContainer.isHidden = true }
        let noAnimation = { animate(); completion(true) }
        if animated {
            UIView.animate(withDuration: 0.3, animations: animate, completion: nil)
        } else { noAnimation() }
    }
    
    private func height(for height: ContainerHeight) -> CGFloat {
        let window = UIApplication.shared.keyWindow
        let bottomMargin = window!.safeArea.bottom
        return height.rawValue + bottomMargin
    }
    
    private func updateInterface() {
        guard let name = destination?.name?.nonEmptyString else { return self.styleForUnnamedDestination() }
        self.primary.text = name
    }

    private func clearInterface() {
        self.primary.text = nil
        self.stars.rating = 0
    }
    
    private func styleForUnnamedDestination() {
        self.staticYouHaveArrived.alpha = 0.0
        self.primary.text = NSLocalizedString("END_OF_ROUTE_ARRIVED", bundle: .mapboxNavigation, value: "You have arrived", comment: "Title used for arrival")
    }
    
    private func setPlaceholderText() {
        self.commentView.text = self.placeholder
    }
}

// MARK: - UITextViewDelegate

extension EndOfRouteViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text.count == 1, text.rangeOfCharacter(from: CharacterSet.newlines) != nil else { return true }
        textView.resignFirstResponder()
        return false
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.comment = textView.text // Bind data model
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == self.placeholder {
            textView.text = nil
            textView.alpha = 1.0
        }
        textView.becomeFirstResponder()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if (textView.text?.isEmpty ?? true) == true {
            textView.text = self.placeholder
            textView.alpha = 0.9
        }
    }
}
