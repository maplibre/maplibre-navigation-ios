import CoreLocation

class Heading: CLHeading {
    private var _heading: CLLocationDirection
    private var _accuracy: CLLocationDirection
    
    init(heading: CLLocationDirection, accuracy: CLLocationDirection) {
        _heading = heading
        _accuracy = accuracy
        super.init()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open var trueHeading: CLLocationDirection {
        get {
            _heading
        }
        set {
            _heading = newValue
        }
    }
    
    override open var headingAccuracy: CLLocationDirection {
        get {
            _accuracy
        }
        set {
            _accuracy = newValue
        }
    }
}
