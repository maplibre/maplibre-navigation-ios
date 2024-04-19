import Foundation

public class Fixture: NSObject {
    public class func stringFromFileNamed(name: String, bundle: Bundle) -> String {
        guard let path = bundle.path(forResource: name, ofType: "json") ?? bundle.path(forResource: name, ofType: "geojson") else {
            return ""
        }
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            return ""
        }
    }
    
    @objc public class func JSONFromFileNamed(name: String, bundle: Bundle) -> [String: Any] {
        guard let path = bundle.path(forResource: name, ofType: "json") ?? bundle.path(forResource: name, ofType: "geojson") else {
            return [:]
        }
        guard let data = NSData(contentsOfFile: path) else {
            return [:]
        }
        do {
            return try JSONSerialization.jsonObject(with: data as Data, options: []) as! [String: AnyObject]
        } catch {
            return [:]
        }
    }
}
