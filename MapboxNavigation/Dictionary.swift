import Foundation

public extension Dictionary where Key == Int, Value: NSExpression {
    /**
     Returns a copy of the stop dictionary with each value multiplied by the given factor.
     */
    func multiplied(by factor: Double) -> Dictionary {
        var newCameraStop: [Int: NSExpression] = [:]
        for stop in self {
            let currentValue = stop.value.constantValue as! Double
            let newValue = currentValue * factor
            newCameraStop[stop.key] = NSExpression(forConstantValue: newValue)
        }
        return newCameraStop as! [Key: Value]
    }
}

extension [Int: Double] {
    /**
     Returns a copy of the stop dictionary with each value multiplied by the given factor.
     */
    func multiplied(by factor: Double) -> Dictionary {
        // This assignment should be a no-op, but it avoids hitting a type checking error I'm seeing in XCode Version 16.0 (16A242d) (stable release)
        // I did not experience this error on XCode 15.4
        //
        // The error is:
        // > Cannot convert return expression of type 'Dictionary<Int, Double>' to return type 'Dictionary<String, Optional<JSONValue>>.RawValue' (aka 'Dictionary<String, Optional<Any>>')
        //
        // JSONValue is defined in turf.
        // Maybe the complexity of the various expressible-by-literal's in JSONValue/JSONObject are leading to a compiler edgecase? Just a guess.
        let tmp = mapValues { $0 * factor }
        return tmp
    }
}
