import CoreLocation

class Heading: CLHeading {
    private var _heading: CLLocationDirection
    private var _accuracy: CLLocationDirection
    
    init(heading: CLLocationDirection, accuracy: CLLocationDirection) {
        self._heading = heading
        self._accuracy = accuracy
        super.init()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open var trueHeading: CLLocationDirection {
        get {
            self._heading
        }
        set {
            self._heading = newValue
        }
    }
    
    override open var headingAccuracy: CLLocationDirection {
        get {
            self._accuracy
        }
        set {
            self._accuracy = newValue
        }
    }
}
