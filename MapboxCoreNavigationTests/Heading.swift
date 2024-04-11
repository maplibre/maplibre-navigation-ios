import CoreLocation

class Heading: CLHeading {
    
    private var _heading: CLLocationDirection
    private var _accuracy: CLLocationDirection
    
    init(heading: CLLocationDirection, accuracy: CLLocationDirection) {
        self._heading = heading
        self._accuracy = accuracy
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override var trueHeading: CLLocationDirection {
        get {
            return _heading
        }
        set {
            _heading = newValue
        }
    }
    
    open override var headingAccuracy: CLLocationDirection {
        get {
            return _accuracy
        }
        set {
            _accuracy = newValue
        }
    }
}
