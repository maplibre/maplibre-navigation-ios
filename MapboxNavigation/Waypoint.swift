import CoreLocation
import MapboxDirections

extension Waypoint {
    var location: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    var instructionComponent: VisualInstructionComponent? {
        guard let name else { return nil }
        return VisualInstructionComponent(type: .text, text: name, imageURL: nil, abbreviation: nil, abbreviationPriority: NSNotFound)
    }
    
    var instructionComponents: [VisualInstructionComponent]? {
        (self.instructionComponent != nil) ? [self.instructionComponent!] : nil
    }
}
