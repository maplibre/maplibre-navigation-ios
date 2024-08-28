import Foundation
import MapboxDirections
import Turf
#if canImport(CarPlay)
import CarPlay
#endif

/**
 `RouteProgress` stores the user’s progress along a route.
 */
@objc(MBRouteProgress)
open class RouteProgress: NSObject {
    private static let reroutingAccuracy: CLLocationAccuracy = 90

    /**
     Returns the current `Route`.
     */
    @objc public let route: Route

    /**
     Index representing current `RouteLeg`.
     */
    @objc public var legIndex: Int {
        didSet {
            assert(self.legIndex >= 0 && self.legIndex < self.route.legs.endIndex)
            // TODO: Set stepIndex to 0 or last index based on whether leg index was incremented or decremented.
            self.currentLegProgress = RouteLegProgress(leg: self.currentLeg)
        }
    }

    /**
     If waypoints are provided in the `Route`, this will contain which leg the user is on.
     */
    @objc public var currentLeg: RouteLeg {
        self.route.legs[self.legIndex]
    }

    /**
     Returns true if `currentLeg` is the last leg.
     */
    public var isFinalLeg: Bool {
        guard let lastLeg = route.legs.last else { return false }
        return self.currentLeg == lastLeg
    }

    /**
     Total distance traveled by user along all legs.
     */
    @objc public var distanceTraveled: CLLocationDistance {
        self.route.legs.prefix(upTo: self.legIndex).map(\.distance).reduce(0, +) + self.currentLegProgress.distanceTraveled
    }

    /**
     Total seconds remaining on all legs.
     */
    @objc public var durationRemaining: TimeInterval {
        self.route.legs.suffix(from: self.legIndex + 1).map(\.expectedTravelTime).reduce(0, +) + self.currentLegProgress.durationRemaining
    }

    /**
     Number between 0 and 1 representing how far along the `Route` the user has traveled.
     */
    @objc public var fractionTraveled: Double {
        self.distanceTraveled / self.route.distance
    }

    /**
     Total distance remaining in meters along route.
     */
    @objc public var distanceRemaining: CLLocationDistance {
        self.route.distance - self.distanceTraveled
    }

    /**
     Number of waypoints remaining on the current route.
     */
    @objc public var remainingWaypoints: [Waypoint] {
        self.route.legs.suffix(from: self.legIndex).map(\.destination)
    }

    /**
     Returns the progress along the current `RouteLeg`.
     */
    @objc public var currentLegProgress: RouteLegProgress

    /**
     Tuple containing a `CongestionLevel` and a corresponding `TimeInterval` representing the expected travel time for this segment.
     */
    public typealias TimedCongestionLevel = (CongestionLevel, TimeInterval)

    /**
     If the route contains both `segmentCongestionLevels` and `expectedSegmentTravelTimes`, this property is set to a deeply nested array of `TimeCongestionLevels` per segment per step per leg.
     */
    public var congestionTravelTimesSegmentsByStep: [[[TimedCongestionLevel]]] = []

    /**
     An dictionary containing a `TimeInterval` total per `CongestionLevel`. Only `CongestionLevel` founnd on that step will present. Broken up by leg and then step.
     */
    public var congestionTimesPerStep: [[[CongestionLevel: TimeInterval]]] = [[[:]]]

    /**
     Intializes a new `RouteProgress`.

     - parameter route: The route to follow.
     - parameter legIndex: Zero-based index indicating the current leg the user is on.
     */
    @objc public init(route: Route, legIndex: Int = 0, spokenInstructionIndex: Int = 0) {
        self.route = route
        self.legIndex = legIndex
        self.currentLegProgress = RouteLegProgress(leg: route.legs[legIndex], stepIndex: 0, spokenInstructionIndex: spokenInstructionIndex)
        super.init()

        for (legIndex, leg) in route.legs.enumerated() {
            var maneuverCoordinateIndex = 0

            self.congestionTimesPerStep.append([])

            /// An index into the route’s coordinates and congestionTravelTimesSegmentsByStep that corresponds to a step’s maneuver location.
            var congestionTravelTimesSegmentsByLeg: [[TimedCongestionLevel]] = []

            if let segmentCongestionLevels = leg.segmentCongestionLevels, let expectedSegmentTravelTimes = leg.expectedSegmentTravelTimes {
                for step in leg.steps {
                    guard let coordinates = step.coordinates else { continue }
                    let stepCoordinateCount = step.maneuverType == .arrive ? Int(step.coordinateCount) : coordinates.dropLast().count
                    let nextManeuverCoordinateIndex = maneuverCoordinateIndex + stepCoordinateCount - 1

                    guard nextManeuverCoordinateIndex < segmentCongestionLevels.count else { continue }
                    guard nextManeuverCoordinateIndex < expectedSegmentTravelTimes.count else { continue }

                    let stepSegmentCongestionLevels = Array(segmentCongestionLevels[maneuverCoordinateIndex ..< nextManeuverCoordinateIndex])
                    let stepSegmentTravelTimes = Array(expectedSegmentTravelTimes[maneuverCoordinateIndex ..< nextManeuverCoordinateIndex])
                    maneuverCoordinateIndex = nextManeuverCoordinateIndex

                    let stepTimedCongestionLevels = Array(zip(stepSegmentCongestionLevels, stepSegmentTravelTimes))
                    congestionTravelTimesSegmentsByLeg.append(stepTimedCongestionLevels)
                    var stepCongestionValues: [CongestionLevel: TimeInterval] = [:]
                    for (segmentCongestion, segmentTime) in stepTimedCongestionLevels {
                        stepCongestionValues[segmentCongestion] = (stepCongestionValues[segmentCongestion] ?? 0) + segmentTime
                    }

                    self.congestionTimesPerStep[legIndex].append(stepCongestionValues)
                }
            }

            self.congestionTravelTimesSegmentsByStep.append(congestionTravelTimesSegmentsByLeg)
        }
    }

    public var averageCongestionLevelRemainingOnLeg: CongestionLevel? {
        let coordinatesLeftOnStepCount = Int(floor(Double(currentLegProgress.currentStepProgress.step.coordinateCount) * self.currentLegProgress.currentStepProgress.fractionTraveled))

        guard coordinatesLeftOnStepCount >= 0 else { return .unknown }

        guard self.legIndex < self.congestionTravelTimesSegmentsByStep.count,
              self.currentLegProgress.stepIndex < self.congestionTravelTimesSegmentsByStep[self.legIndex].count else { return .unknown }

        let congestionTimesForStep = self.congestionTravelTimesSegmentsByStep[self.legIndex][self.currentLegProgress.stepIndex]
        guard coordinatesLeftOnStepCount <= congestionTimesForStep.count else { return .unknown }

        let remainingCongestionTimesForStep = congestionTimesForStep.suffix(from: coordinatesLeftOnStepCount)
        let remainingCongestionTimesForRoute = self.congestionTimesPerStep[self.legIndex].suffix(from: self.currentLegProgress.stepIndex + 1)

        var remainingStepCongestionTotals: [CongestionLevel: TimeInterval] = [:]
        for stepValues in remainingCongestionTimesForRoute {
            for (key, value) in stepValues {
                remainingStepCongestionTotals[key] = (remainingStepCongestionTotals[key] ?? 0) + value
            }
        }

        for (segmentCongestion, segmentTime) in remainingCongestionTimesForStep {
            remainingStepCongestionTotals[segmentCongestion] = (remainingStepCongestionTotals[segmentCongestion] ?? 0) + segmentTime
        }

        if self.durationRemaining < 60 {
            return .unknown
        } else {
            if let max = remainingStepCongestionTotals.max(by: { a, b in a.value < b.value }) {
                return max.key
            } else {
                return .unknown
            }
        }
    }

    func reroutingOptions(with current: CLLocation) -> RouteOptions {
        let oldOptions = self.route.routeOptions
        let user = Waypoint(coordinate: current.coordinate)

        if current.course >= 0 {
            user.heading = current.course
            user.headingAccuracy = RouteProgress.reroutingAccuracy
        }
        let newWaypoints = [user] + self.remainingWaypoints
        let newOptions = oldOptions.copy() as! RouteOptions
        newOptions.waypoints = newWaypoints

        return newOptions
    }
}

/**
 `RouteLegProgress` stores the user’s progress along a route leg.
 */
@objc(MBRouteLegProgress)
open class RouteLegProgress: NSObject {
    /**
     Returns the current `RouteLeg`.
     */
    @objc public let leg: RouteLeg

    /**
     Index representing the current step.
     */
    @objc public var stepIndex: Int {
        didSet {
            assert(self.stepIndex >= 0 && self.stepIndex < self.leg.steps.endIndex)
            self.currentStepProgress = RouteStepProgress(step: self.currentStep)
        }
    }

    /**
     The remaining steps for user to complete.
     */
    @objc public var remainingSteps: [RouteStep] {
        Array(self.leg.steps.suffix(from: self.stepIndex + 1))
    }

    /**
     Total distance traveled in meters along current leg.
     */
    @objc public var distanceTraveled: CLLocationDistance {
        self.leg.steps.prefix(upTo: self.stepIndex).map(\.distance).reduce(0, +) + self.currentStepProgress.distanceTraveled
    }

    /**
     Duration remaining in seconds on current leg.
     */
    @objc public var durationRemaining: TimeInterval {
        self.remainingSteps.map(\.expectedTravelTime).reduce(0, +) + self.currentStepProgress.durationRemaining
    }

    /**
     Distance remaining on the current leg.
     */
    @objc public var distanceRemaining: CLLocationDistance {
        self.remainingSteps.map(\.distance).reduce(0, +) + self.currentStepProgress.distanceRemaining
    }

    /**
     Number between 0 and 1 representing how far along the current leg the user has traveled.
     */
    @objc public var fractionTraveled: Double {
        self.distanceTraveled / self.leg.distance
    }

    @objc public var userHasArrivedAtWaypoint = false

    /**
     Returns the `RouteStep` before a given step. Returns `nil` if there is no step prior.
     */
    @objc public func stepBefore(_ step: RouteStep) -> RouteStep? {
        guard let index = leg.steps.firstIndex(of: step) else {
            return nil
        }
        if index > 0 {
            return self.leg.steps[index - 1]
        }
        return nil
    }

    /**
     Returns the `RouteStep` after a given step. Returns `nil` if there is not a step after.
     */
    @objc public func stepAfter(_ step: RouteStep) -> RouteStep? {
        guard let index = leg.steps.firstIndex(of: step) else {
            return nil
        }
        if index + 1 < self.leg.steps.endIndex {
            return self.leg.steps[index + 1]
        }
        return nil
    }

    /**
     Returns the `RouteStep` before the current step.

     If there is no `priorStep`, nil is returned.
     */
    @objc public var priorStep: RouteStep? {
        guard self.stepIndex - 1 >= 0 else {
            return nil
        }
        return self.leg.steps[self.stepIndex - 1]
    }

    /**
     Returns the current `RouteStep` for the leg the user is on.
     */
    @objc public var currentStep: RouteStep {
        self.leg.steps[self.stepIndex]
    }

    /**
     Returns the upcoming `RouteStep`.

     If there is no `upcomingStep`, nil is returned.
     */
    @objc public var upComingStep: RouteStep? {
        guard self.stepIndex + 1 < self.leg.steps.endIndex else {
            return nil
        }
        return self.leg.steps[self.stepIndex + 1]
    }

    /**
     Returns step 2 steps ahead.

     If there is no `followOnStep`, nil is returned.
     */
    @objc public var followOnStep: RouteStep? {
        guard self.stepIndex + 2 < self.leg.steps.endIndex else {
            return nil
        }
        return self.leg.steps[self.stepIndex + 2]
    }

    /**
     Return bool whether step provided is the current `RouteStep` the user is on.
     */
    @objc public func isCurrentStep(_ step: RouteStep) -> Bool {
        step == self.currentStep
    }

    /**
     Returns the progress along the current `RouteStep`.
     */
    @objc public var currentStepProgress: RouteStepProgress

    /**
     Intializes a new `RouteLegProgress`.

     - parameter leg: Leg on a `Route`.
     - parameter stepIndex: Current step the user is on.
     */
    @objc public init(leg: RouteLeg, stepIndex: Int = 0, spokenInstructionIndex: Int = 0) {
        self.leg = leg
        self.stepIndex = stepIndex
        self.currentStepProgress = RouteStepProgress(step: leg.steps[stepIndex], spokenInstructionIndex: spokenInstructionIndex)
    }

    /**
     Returns an array of `CLLocationCoordinate2D` of the prior, current and upcoming step geometry.
     */
    @objc public var nearbyCoordinates: [CLLocationCoordinate2D] {
        let priorCoords = self.priorStep?.coordinates ?? []
        let upcomingCoords = self.upComingStep?.coordinates ?? []
        let currentCoords = self.currentStep.coordinates ?? []
        let nearby = priorCoords + currentCoords + upcomingCoords
        assert(!nearby.isEmpty, "Step must have coordinates")
        return nearby
    }

    typealias StepIndexDistance = (index: Int, distance: CLLocationDistance)

    func closestStep(to coordinate: CLLocationCoordinate2D) -> StepIndexDistance? {
        var currentClosest: StepIndexDistance?
        let remainingSteps = self.leg.steps.suffix(from: self.stepIndex)

        for (currentStepIndex, step) in remainingSteps.enumerated() {
            guard let coords = step.coordinates else { continue }
            guard let closestCoordOnStep = LineString(coords).closestCoordinate(to: coordinate) else { continue }
            let foundIndex = currentStepIndex + self.stepIndex

            let distanceFromLine = closestCoordOnStep.coordinate.distance(to: coordinate)
            // First time around, currentClosest will be `nil`.
            guard let currentClosestDistance = currentClosest?.distance else {
                currentClosest = (index: foundIndex, distance: distanceFromLine)
                continue
            }

            if distanceFromLine < currentClosestDistance {
                currentClosest = (index: foundIndex, distance: distanceFromLine)
            }
        }

        return currentClosest
    }
}

/**
 `RouteStepProgress` stores the user’s progress along a route step.
 */
@objc(MBRouteStepProgress)
open class RouteStepProgress: NSObject {
    /**
     Returns the current `RouteStep`.
     */
    @objc public let step: RouteStep

    /**
     Returns distance user has traveled along current step.
     */
    @objc public var distanceTraveled: CLLocationDistance = 0

    /**
     Returns distance from user to end of step.
     */
    @objc public var userDistanceToManeuverLocation: CLLocationDistance = Double.infinity

    /**
     Total distance in meters remaining on current step.
     */
    @objc public var distanceRemaining: CLLocationDistance {
        self.step.distance - self.distanceTraveled
    }

    /**
     Number between 0 and 1 representing fraction of current step traveled.
     */
    @objc public var fractionTraveled: Double {
        guard self.step.distance > 0 else { return 1 }
        return self.distanceTraveled / self.step.distance
    }

    /**
     Number of seconds remaining on current step.
     */
    @objc public var durationRemaining: TimeInterval {
        (1 - self.fractionTraveled) * self.step.expectedTravelTime
    }
    
    /**
     Intializes a new `RouteStepProgress`.

     - parameter step: Step on a `RouteLeg`.
     */
    @objc public init(step: RouteStep, spokenInstructionIndex: Int = 0) {
        self.step = step
        self.intersectionIndex = 0
        self.spokenInstructionIndex = spokenInstructionIndex
    }

    /**
     All intersections on the current `RouteStep` and also the first intersection on the upcoming `RouteStep`.

     The upcoming `RouteStep` first `Intersection` is added because it is omitted from the current step.
     */
    @objc public var intersectionsIncludingUpcomingManeuverIntersection: [Intersection]?

    /**
     The next intersection the user will travel through.

     The step must contain `intersectionsIncludingUpcomingManeuverIntersection` otherwise this property will be `nil`.
     */
    @objc public var upcomingIntersection: Intersection? {
        guard let intersections = intersectionsIncludingUpcomingManeuverIntersection, intersections.startIndex ..< intersections.endIndex - 1 ~= intersectionIndex else {
            return nil
        }

        return intersections[intersections.index(after: self.intersectionIndex)]
    }

    /**
     Index representing the current intersection.
     */
    @objc public var intersectionIndex: Int = 0

    /**
     The current intersection the user will travel through.

     The step must contain `intersectionsIncludingUpcomingManeuverIntersection` otherwise this property will be `nil`.
     */
    @objc public var currentIntersection: Intersection? {
        guard let intersections = intersectionsIncludingUpcomingManeuverIntersection, intersections.startIndex ..< intersections.endIndex ~= intersectionIndex else {
            return nil
        }

        return intersections[self.intersectionIndex]
    }

    /**
     Returns an array of the calculated distances from the current intersection to the next intersection on the current step.
     */
    @objc public var intersectionDistances: [CLLocationDistance]?

    /**
     The distance in meters the user is to the next intersection they will pass through.
     */
    public var userDistanceToUpcomingIntersection: CLLocationDistance?

    /**
     Index into `step.instructionsDisplayedAlongStep` representing the current visual instruction for the step.
     */
    @objc public var visualInstructionIndex: Int = 0

    /**
     An `Array` of remaining `VisualInstruction` for a step.
     */
    @objc public var remainingVisualInstructions: [VisualInstructionBanner]? {
        guard let visualInstructions = step.instructionsDisplayedAlongStep else { return nil }
        return Array(visualInstructions.suffix(from: self.visualInstructionIndex))
    }

    /**
     Index into `step.instructionsSpokenAlongStep` representing the current spoken instruction.
     */
    @objc public var spokenInstructionIndex: Int = 0

    /**
     An `Array` of remaining `SpokenInstruction` for a step.
     */
    @objc public var remainingSpokenInstructions: [SpokenInstruction]? {
        guard
            let instructions = step.instructionsSpokenAlongStep,
            spokenInstructionIndex <= instructions.endIndex
        else { return nil }
        return Array(instructions.suffix(from: self.spokenInstructionIndex))
    }

    /**
     Current spoken instruction for the user's progress along a step.
     */
    @objc public var currentSpokenInstruction: SpokenInstruction? {
        guard let instructionsSpokenAlongStep = step.instructionsSpokenAlongStep else { return nil }
        guard self.spokenInstructionIndex < instructionsSpokenAlongStep.count else { return nil }
        return instructionsSpokenAlongStep[self.spokenInstructionIndex]
    }

    /**
     Current visual instruction for the user's progress along a step.
     */
    @objc public var currentVisualInstruction: VisualInstructionBanner? {
        guard let instructionsDisplayedAlongStep = step.instructionsDisplayedAlongStep else { return nil }
        guard self.visualInstructionIndex < instructionsDisplayedAlongStep.count else { return nil }
        return instructionsDisplayedAlongStep[self.visualInstructionIndex]
    }
}
