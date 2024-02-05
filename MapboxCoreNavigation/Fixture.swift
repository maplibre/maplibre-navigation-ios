import Foundation

@objc(MBFixture)
internal class Fixture: NSObject {
    @objc class func stringFromFileNamed(name: String) -> String {
        guard let path = Bundle.module.path(forResource: name, ofType: "json") ?? Bundle(for: self).path(forResource: name, ofType: "geojson") else {
            return ""
        }
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            return ""
        }
    }
    
    @objc class func JSONFromFileNamed(name: String) -> [String: Any] {
        guard let path = Bundle.module.path(forResource: name, ofType: "json") ?? Bundle(for: self).path(forResource: name, ofType: "geojson") else {
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
