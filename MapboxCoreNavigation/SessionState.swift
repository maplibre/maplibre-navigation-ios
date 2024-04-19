import CoreLocation
import Foundation
import MapboxDirections
import UIKit.UIDevice

struct SessionState {
    let identifier = UUID()
    var departureTimestamp: Date?
    var arrivalTimestamp: Date?
    
    var totalDistanceCompleted: CLLocationDistance = 0
    
    var numberOfReroutes = 0
    var lastRerouteDate: Date?
    
    var currentRoute: Route
    var originalRoute: Route
    
    var terminated = false
    
    private(set) var timeSpentInPortrait: TimeInterval = 0
    private(set) var timeSpentInLandscape: TimeInterval = 0
    
    private(set) var lastTimeInLandscape = Date()
    private(set) var lastTimeInPortrait = Date()
    
    private(set) var timeSpentInForeground: TimeInterval = 0
    private(set) var timeSpentInBackground: TimeInterval = 0
    
    private(set) var lastTimeInForeground = Date()
    private(set) var lastTimeInBackground = Date()
    
    var pastLocations = FixedLengthQueue<CLLocation>(length: 40)
    
    init(currentRoute: Route, originalRoute: Route) {
        self.currentRoute = currentRoute
        self.originalRoute = originalRoute
    }
    
    public mutating func reportChange(to orientation: UIDeviceOrientation) {
        if orientation.isPortrait {
            self.timeSpentInLandscape += abs(self.lastTimeInPortrait.timeIntervalSinceNow)
            self.lastTimeInPortrait = Date()
        } else if orientation.isLandscape {
            self.timeSpentInPortrait += abs(self.lastTimeInLandscape.timeIntervalSinceNow)
            self.lastTimeInLandscape = Date()
        }
    }
    
    public mutating func reportChange(to applicationState: UIApplication.State) {
        if applicationState == .active {
            self.timeSpentInForeground += abs(self.lastTimeInBackground.timeIntervalSinceNow)
            
            self.lastTimeInForeground = Date()
        } else if applicationState == .background {
            self.timeSpentInBackground += abs(self.lastTimeInForeground.timeIntervalSinceNow)
            self.lastTimeInBackground = Date()
        }
    }
}

class FixedLengthQueue<T> {
    private var objects = [T]()
    private var length: Int
    
    public init(length: Int) {
        self.length = length
    }
    
    public func push(_ obj: T) {
        self.objects.append(obj)
        if self.objects.count == self.length {
            self.objects.remove(at: 0)
        }
    }
    
    public var allObjects: [T] {
        Array(self.objects)
    }
}
