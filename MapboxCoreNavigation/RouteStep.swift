import MapboxDirections

extension RouteStep {
    static func == (left: RouteStep, right: RouteStep) -> Bool {
        var finalHeading = false
        if let leftFinalHeading = left.finalHeading, let rightFinalHeading = right.finalHeading {
            finalHeading = leftFinalHeading == rightFinalHeading
        }
        
        let maneuverType = left.maneuverType == right.maneuverType
        let maneuverLocation = left.maneuverLocation == right.maneuverLocation
        
        return maneuverLocation && maneuverType && finalHeading
    }
    
    /**
     Returns true if the route step is on a motorway.
     */
    public var isMotorway: Bool {
        intersections?.first?.outletRoadClasses?.contains(.motorway) ?? false
    }
    
    /**
     Returns true if the route travels on a motorway primarily identified by a route number rather than a road name.
     */
    var isNumberedMotorway: Bool {
        guard self.isMotorway else { return false }
        guard let codes, let digitRange = codes.first?.rangeOfCharacter(from: .decimalDigits) else {
            return false
        }
        return !digitRange.isEmpty
    }
    
    /**
     Returns the last instruction for a given step.
     */
    public var lastInstruction: SpokenInstruction? {
        instructionsSpokenAlongStep?.last
    }
}
