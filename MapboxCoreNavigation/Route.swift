//
//  Route.swift
//  MapboxCoreNavigation
//
//  Created by Sander van Tulden on 28/10/2022.
//  Copyright © 2022 Mapbox. All rights reserved.
//

import CoreLocation
import MapboxDirections

extension Route {
    static func from(jsonFileName: String, waypoints: [CLLocationCoordinate2D], polylineShapeFormat: RouteShapeFormat = .polyline6, bundle: Bundle = .main, accessToken: String) throws -> Route {
        let convertedWaypoints = waypoints.compactMap { waypoint in
            Waypoint(coordinate: waypoint)
        }
        let routeOptions = NavigationRouteOptions(waypoints: convertedWaypoints)
        routeOptions.shapeFormat = polylineShapeFormat
		
        let path = bundle.url(forResource: jsonFileName, withExtension: "json") ?? bundle.url(forResource: jsonFileName, withExtension: "geojson")!
        let data = try Data(contentsOf: path)
		
        let decoder = JSONDecoder()
        let result = try decoder.decode(RouteResponse.self, from: data)
		
        return result.routes!.first!
    }
}
