import CoreLocation
import Foundation

/**
 `ReplayLocationManager` replays an array of locations exactly as they were
 recorded with the single exception of the location’s timestamp which will be
 adjusted by interval between locations.
 */
@objc(MBReplayLocationManager)
open class ReplayLocationManager: NavigationLocationManager {
    /**
     `speedMultiplier` adjusts the speed of the replay.
     */
    @objc public var speedMultiplier: TimeInterval = 1
    
    var currentIndex: Int = 0
    
    var startDate: Date?
    
    /**
     `locations` to be replayed.
     */
    @objc public var locations: [CLLocation]! {
        didSet {
            self.currentIndex = 0
        }
    }
    
    @objc override open var location: CLLocation? {
        lastKnownLocation
    }
    
    public init(locations: [CLLocation]) {
        self.locations = locations.sorted { $0.timestamp < $1.timestamp }
        super.init()
    }
    
    deinit {
        stopUpdatingLocation()
    }
    
    override open func startUpdatingLocation() {
        self.startDate = Date()
        self.tick()
    }
    
    override open func stopUpdatingLocation() {
        self.startDate = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.tick), object: nil)
    }
    
    @objc fileprivate func tick() {
        guard let startDate else { return }
        let location = self.locations[self.currentIndex]
        lastKnownLocation = location
        delegate?.locationManager?(self, didUpdateLocations: [location])
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.tick), object: nil)
        
        if self.currentIndex < self.locations.count - 1 {
            let nextLocation = self.locations[self.currentIndex + 1]
            let interval = nextLocation.timestamp.timeIntervalSince(location.timestamp) / TimeInterval(self.speedMultiplier)
            let intervalSinceStart = Date().timeIntervalSince(startDate) + interval
            let actualInterval = nextLocation.timestamp.timeIntervalSince(self.locations.first!.timestamp)
            let diff = min(max(0, intervalSinceStart - actualInterval), 0.9) // Don't try to resync more than 0.9 seconds per location update
            let syncedInterval = interval - diff
            
            perform(#selector(self.tick), with: nil, afterDelay: syncedInterval)
            self.currentIndex += 1
        } else {
            self.currentIndex = 0
        }
    }
}
