import CoreLocation
import MapboxDirections
import Turf

private let maximumSpeed: CLLocationSpeed = 30 // ~108 kmh
private let minimumSpeed: CLLocationSpeed = 6 // ~21 kmh
private var distanceFilter: CLLocationDistance = 10
private var verticalAccuracy: CLLocationAccuracy = 10
private var horizontalAccuracy: CLLocationAccuracy = 40
// minimumSpeed will be used when a location have maximumTurnPenalty
private let maximumTurnPenalty: CLLocationDirection = 90
// maximumSpeed will be used when a location have minimumTurnPenalty
private let minimumTurnPenalty: CLLocationDirection = 0
// Go maximum speed if distance to nearest coordinate is >= `safeDistance`
private let safeDistance: CLLocationDistance = 50

private class SimulatedLocation: CLLocation {
    var turnPenalty: Double = 0
    
    override var description: String {
        "\(super.description) \(self.turnPenalty)"
    }
}

/// Provides methods for modifying the locations along the `SimulatedLocationManager`'s route.
@objc public protocol SimulatedLocationManagerDelegate: AnyObject {
    /// Offers the delegate an opportunity to modify the next location along the route. This can be useful when testing re-routing.
    ///
    /// - Parameters:
    ///   - simulatedLocationManager: The location manager simulating locations along a given route.
    ///   - originalLocation: The next coordinate along the route.
    /// - Returns: The next coordinate that the location manager will return as the "current" location. Return the `originalLocation` to follow the route, or modify it to go off route.
    ///
    /// ## Examples
    /// ```
    /// extension MyDelegate: SimulatedLocationManagerDelegate {
    ///     func simulatedLocationManager(_ simulatedLocationManager: SimulatedLocationManager, locationFor originalLocation: CLLocation) -> CLLocation {
    ///         // go off track 100 meters East of the original route
    ///         let offsetCoordinate = originalLocation.coordinate.coordinate(at: 100, facing: 90)
    ///         return CLLocation(latitude: offsetCoordinate.latitude, longitude: offsetCoordinate.longitude)
    ///     }
    /// }
    /// ```
    @objc
    func simulatedLocationManager(_ simulatedLocationManager: SimulatedLocationManager, locationFor originalLocation: CLLocation) -> CLLocation
}

/**
 The `SimulatedLocationManager` class simulates location updates along a given route.
 
 The route will be replaced upon a `RouteControllerDidReroute` notification.
 */
@objc(MBSimulatedLocationManager)
open class SimulatedLocationManager: NavigationLocationManager {
    fileprivate var currentDistance: CLLocationDistance = 0
    fileprivate var currentLocation = CLLocation()
    fileprivate var currentSpeed: CLLocationSpeed = 30
    
    fileprivate var locations: [SimulatedLocation]!
    fileprivate var routeLine = [CLLocationCoordinate2D]()
    
    /**
     Specify the multiplier to use when calculating speed based on the RouteLeg’s `expectedSegmentTravelTimes`.
     */
    @objc public var speedMultiplier: Double = 1

    /// Instead of following the given route, go slightly off route. Useful for testing rerouting.
    @objc public weak var simulatedLocationManagerDelegate: SimulatedLocationManagerDelegate?

    @objc override open var location: CLLocation? {
        self.currentLocation
    }
    
    var route: Route? {
        didSet {
            self.reset()
        }
    }
    
    override public func copy(with zone: NSZone? = nil) -> Any {
        let copy = SimulatedLocationManager(route: route!)
        copy.currentDistance = self.currentDistance
        copy.currentLocation = self.currentLocation
        copy.currentSpeed = self.currentSpeed
        copy.locations = self.locations
        copy.routeLine = self.routeLine
        copy.speedMultiplier = self.speedMultiplier
        return copy
    }
    
    var routeProgress: RouteProgress?
    
    /**
     Initalizes a new `SimulatedLocationManager` with the given route.
     
     - parameter route: The initial route.
     - returns: A `SimulatedLocationManager`
     */
    @objc public init(route: Route) {
        super.init()
        self.initializeSimulatedLocationManager(for: route, currentDistance: 0, currentSpeed: 30)
    }

    /**
     Initalizes a new `SimulatedLocationManager` with the given routeProgress.
     
     - parameter routeProgress: The routeProgress of the current route.
     - returns: A `SimulatedLocationManager`
     */
    @objc public init(routeProgress: RouteProgress) {
        super.init()
        let currentDistance = self.calculateCurrentDistance(routeProgress.distanceTraveled)
        self.initializeSimulatedLocationManager(for: routeProgress.route, currentDistance: currentDistance, currentSpeed: 0)
    }

    private func initializeSimulatedLocationManager(for route: Route, currentDistance: CLLocationDistance, currentSpeed: CLLocationSpeed) {
        self.currentSpeed = currentSpeed
        self.currentDistance = currentDistance
        self.route = route
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.didReroute(_:)), name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressDidChange(_:)), name: .routeControllerProgressDidChange, object: nil)
    }
    
    private func reset() {
        if let coordinates = route?.coordinates {
            self.routeLine = coordinates
            self.locations = coordinates.simulatedLocationsWithTurnPenalties()
        }
    }
    
    private func calculateCurrentDistance(_ distance: CLLocationDistance) -> CLLocationDistance {
        distance + (self.currentSpeed * self.speedMultiplier)
    }
    
    @objc private func progressDidChange(_ notification: Notification) {
        self.routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
    }
    
    @objc private func didReroute(_ notification: Notification) {
        guard let routeController = notification.object as? RouteController else {
            return
        }
        
        self.route = routeController.routeProgress.route
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
    }
    
    override open func startUpdatingLocation() {
        DispatchQueue.main.async(execute: self.tick)
    }
    
    override open func stopUpdatingLocation() {
        DispatchQueue.main.async {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.tick), object: nil)
        }
    }
    
    @objc fileprivate func tick() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.tick), object: nil)
        
        let polyline = LineString(routeLine)
        
        guard let newCoordinate = polyline.coordinateFromStart(distance: currentDistance) else {
            return
        }
        
        // Closest coordinate ahead
        guard let lookAheadCoordinate = polyline.coordinateFromStart(distance: currentDistance + 10) else { return }
        guard let closestCoordinate = polyline.closestCoordinate(to: newCoordinate) else { return }
        
        let closestLocation = self.locations[closestCoordinate.index]
        let distanceToClosest = closestLocation.distance(from: CLLocation(newCoordinate))
        
        let distance = min(max(distanceToClosest, 10), safeDistance)
        guard let coordinatesNearby = polyline.trimmed(from: newCoordinate, distance: 100)?.coordinates else { return }

        // Simulate speed based on expected segment travel time
        if let expectedSegmentTravelTimes = routeProgress?.currentLeg.expectedSegmentTravelTimes,
           let coordinates = routeProgress?.route.coordinates,
           let closestCoordinateOnRoute = LineString(routeProgress!.route.coordinates!).closestCoordinate(to: newCoordinate),
           let nextCoordinateOnRoute = coordinates.after(element: coordinates[closestCoordinateOnRoute.index]),
           let time = expectedSegmentTravelTimes.optional[closestCoordinateOnRoute.index] {
            let distance = coordinates[closestCoordinateOnRoute.index].distance(to: nextCoordinateOnRoute)
            self.currentSpeed = max(distance / time, 2)
        } else {
            self.currentSpeed = self.calculateCurrentSpeed(distance: distance, coordinatesNearby: coordinatesNearby, closestLocation: closestLocation)
        }
        
        var location = CLLocation(coordinate: newCoordinate,
                                  altitude: 0,
                                  horizontalAccuracy: horizontalAccuracy,
                                  verticalAccuracy: verticalAccuracy,
                                  course: newCoordinate.direction(to: lookAheadCoordinate).wrap(min: 0, max: 360),
                                  speed: self.currentSpeed,
                                  timestamp: Date())

        if let delegate = self.simulatedLocationManagerDelegate {
            location = delegate.simulatedLocationManager(self, locationFor: location)
        }

        self.currentLocation = location
        lastKnownLocation = location
        
        delegate?.locationManager?(self, didUpdateLocations: [self.currentLocation])
        self.currentDistance = self.calculateCurrentDistance(self.currentDistance)
        perform(#selector(self.tick), with: nil, afterDelay: 1)
    }
    
    private func calculateCurrentSpeed(distance: CLLocationDistance, coordinatesNearby: [CLLocationCoordinate2D]? = nil, closestLocation: SimulatedLocation) -> CLLocationSpeed {
        // More than 10 nearby coordinates indicates that we are in a roundabout or similar complex shape.
        if let coordinatesNearby, coordinatesNearby.count >= 10 {
            return minimumSpeed
        }
        // Maximum speed if we are a safe distance from the closest coordinate
        else if distance >= safeDistance {
            return maximumSpeed
        }
        // Base speed on previous or upcoming turn penalty
        else {
            let reversedTurnPenalty = maximumTurnPenalty - closestLocation.turnPenalty
            return reversedTurnPenalty.scale(minimumIn: minimumTurnPenalty, maximumIn: maximumTurnPenalty, minimumOut: minimumSpeed, maximumOut: maximumSpeed)
        }
    }
}

private extension Double {
    func scale(minimumIn: Double, maximumIn: Double, minimumOut: Double, maximumOut: Double) -> Double {
        ((maximumOut - minimumOut) * (self - minimumIn) / (maximumIn - minimumIn)) + minimumOut
    }
}

private extension CLLocation {
    convenience init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

private extension Array where Element: Hashable {
    struct OptionalSubscript {
        var elements: [Element]
        subscript(index: Int) -> Element? {
            index < self.elements.count ? self.elements[index] : nil
        }
    }
    
    var optional: OptionalSubscript { OptionalSubscript(elements: self) }
}

private extension Array where Element: Equatable {
    func after(element: Element) -> Element? {
        if let index = firstIndex(of: element), index + 1 <= count {
            return index + 1 == count ? self[0] : self[index + 1]
        }
        return nil
    }
}

private extension [CLLocationCoordinate2D] {
    // Calculate turn penalty for each coordinate.
    func simulatedLocationsWithTurnPenalties() -> [SimulatedLocation] {
        var locations = [SimulatedLocation]()
        
        for (coordinate, nextCoordinate) in zip(prefix(upTo: endIndex - 1), suffix(from: 1)) {
            let currentCoordinate = locations.isEmpty ? first! : coordinate
            let course = coordinate.direction(to: nextCoordinate).wrap(min: 0, max: 360)
            let turnPenalty = currentCoordinate.direction(to: coordinate).difference(from: coordinate.direction(to: nextCoordinate))
            let location = SimulatedLocation(coordinate: coordinate,
                                             altitude: 0,
                                             horizontalAccuracy: horizontalAccuracy,
                                             verticalAccuracy: verticalAccuracy,
                                             course: course,
                                             speed: minimumSpeed,
                                             timestamp: Date())
            location.turnPenalty = Swift.max(Swift.min(turnPenalty, maximumTurnPenalty), minimumTurnPenalty)
            locations.append(location)
        }
        
        locations.append(SimulatedLocation(coordinate: last!,
                                           altitude: 0,
                                           horizontalAccuracy: horizontalAccuracy,
                                           verticalAccuracy: verticalAccuracy,
                                           course: locations.last!.course,
                                           speed: minimumSpeed,
                                           timestamp: Date()))
        
        return locations
    }
}
