import Foundation
import MapLibre

extension MLNVectorTileSource {
    var isMapboxStreets: Bool {
        guard let configurationURL else {
            return false
        }
        return configurationURL.scheme == "mapbox" && configurationURL.host!.components(separatedBy: ",").contains("mapbox.mapbox-streets-v7")
    }
}
