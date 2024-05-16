//
//  Toursprung.swift
//  Navigation
//
//  Created by Patrick Kladek on 06.03.24.
//

import Foundation
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
import MapLibre
import OSLog

public typealias JSONDictionary = [String: Any]

// MARK: - Toursprung

public class Toursprung {
    public enum ToursprungError: LocalizedError, Equatable {
        case invalidUrl(message: String?)
        case invalidResponse(message: String?)
        case noRoute(message: String?)
        case noSegment(message: String?)
        case forbidden(message: String?)
        case invalidInput(message: String?)
        case profileNotFound(message: String?)
        case notAuthorized(message: String?)

        public var errorDescription: String? {
            switch self {
            case let .invalidUrl(message):
                errorDescription(message: message, defaultMessage: "Calculating route failed")
            case let .invalidResponse(message):
                errorDescription(message: message, defaultMessage: "Calculating route failed")
            case let .noRoute(message):
                errorDescription(message: message, defaultMessage: "No route found.")
            case let .noSegment(message):
                errorDescription(message: message, defaultMessage: "No segment found.")
            case let .forbidden(message):
                errorDescription(message: message, defaultMessage: "Forbidden access.")
            case let .invalidInput(message):
                errorDescription(message: message, defaultMessage: "Invalid input.")
            case let .profileNotFound(message: message):
                errorDescription(message: message, defaultMessage: "ProfileNotFound")
            case let .notAuthorized(message: message):
                errorDescription(message: message, defaultMessage: "NotAuthorized")
            }
        }

        public var failureReason: String? {
            switch self {
            case let .invalidUrl(message):
                self.errorDescription(message: message, defaultMessage: "Calculating route failed because url can't be created")
            case let .invalidResponse(message):
                self.errorDescription(message: message, defaultMessage: "Hudhud responded with invalid route")
            case let .noRoute(message):
                self.errorDescription(message: message, defaultMessage: "No route found.")
            case let .noSegment(message):
                self.errorDescription(message: message, defaultMessage: "No segment found.")
            case let .forbidden(message):
                self.errorDescription(message: message, defaultMessage: "Forbidden access.")
            case let .invalidInput(message):
                self.errorDescription(message: message, defaultMessage: "Invalid input.")
            case let .profileNotFound(message: message):
                self.errorDescription(message: message, defaultMessage: "Profile Not Found")
            case let .notAuthorized(message: message):
                self.errorDescription(message: message, defaultMessage: "Not Authorized")
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .invalidUrl:
                "Retry with another destination"
            case .invalidResponse:
                "Update the app or retry with another destination"
            case .noRoute:
                "Retry with another destination"
            case .noSegment:
                "Retry with another destination"
            case .forbidden:
                "Forbidden access."
            case .invalidInput:
                "Invalid input."
            case .profileNotFound:
                "Profile Not Found"
            case .notAuthorized:
                "Not Authorized"
            }
        }

        public var helpAnchor: String? {
            switch self {
            case .invalidUrl:
                "Search for another location and start navigation to there"
            case .invalidResponse:
                "Go to the AppStore and download the newest version of the App. Alternatively search for another location and start navigation to there."
            case .noRoute:
                "Search for another location and start navigation to there"
            case .noSegment:
                "Search for another location and start navigation to there"
            case .forbidden:
                "Forbidden access"
            case .invalidInput:
                "Invalid input"
            case .profileNotFound:
                "Profile Not Found"
            case .notAuthorized:
                "Not Authorized"
            }
        }

        // MARK: - Private

        private func errorDescription(message: String?, defaultMessage: String) -> String {
            var description = defaultMessage
            if let message {
                description += " \(message)"
            }
            return description
        }
    }

    public typealias RouteCompletionHandler = (_ waypoints: [Waypoint]?, _ routes: [Route]?, _ error: Error?) -> Void

    public static let shared = Toursprung()

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Public

    public struct RouteCalculationResult {
        public let waypoints: [Waypoint]
        public let routes: [Route]
    }

    @discardableResult
    public func calculate(_ options: RouteOptions) async throws -> RouteCalculationResult {
        let url = try options.url
        let answer: (data: Data, response: URLResponse) = try await URLSession.shared.data(from: url)
        let json: JSONDictionary

        guard answer.response.mimeType == "application/json" else {
            throw ToursprungError.invalidResponse(message: "MIME Type not matching application/json")
        }

        do {
            json = try JSONSerialization.jsonObject(with: answer.data, options: []) as? [String: Any] ?? [:]
        } catch let error as ToursprungError {
            throw ToursprungError.invalidResponse(message: "Route error occurred: \(error.localizedDescription)")
        }

        let apiStatusCode = json["code"] as? String
        let apiMessage = json["message"] as? String
        guard (apiStatusCode == nil && apiMessage == nil) || apiStatusCode == "Ok" else {
            switch apiStatusCode {
            case "InvalidInput":
                throw ToursprungError.invalidInput(message: apiMessage)
            case "Not Authorized - No Token":
                throw ToursprungError.notAuthorized(message: apiMessage)
            case "Not Authorized - Invalid Token":
                throw ToursprungError.notAuthorized(message: apiMessage)
            case "Forbidden":
                throw ToursprungError.forbidden(message: apiMessage)
            case "ProfileNotFound":
                throw ToursprungError.profileNotFound(message: apiMessage)
            case "NoSegment":
                throw ToursprungError.noSegment(message: apiMessage)
            case "NoRoute":
                throw ToursprungError.noRoute(message: apiMessage)
            default:
                throw ToursprungError.invalidResponse(message: nil)
            }
        }

        let response = try options.response(from: json)
        for route in response.routes {
            route.routeIdentifier = json["uuid"] as? String
        }
        guard let httpResponse = answer.response as? HTTPURLResponse else {
            throw ToursprungError.invalidResponse(message: "Unexpected response type")
        }
        let httpStatusCode = httpResponse.statusCode
        switch httpStatusCode {
        case 500 ... 599:
            throw ToursprungError.invalidResponse(message: "Server error HTTP status code: \(httpStatusCode)")
        case 200 ... 299:
            return RouteCalculationResult(waypoints: response.waypoint, routes: response.routes)
        default:
            throw ToursprungError.invalidResponse(message: "Server error occurred")
        }
    }
}

// MARK: - Private

private extension RouteOptions {
    var url: URL {
        get throws {
            let stops = self.waypoints.map { "\($0.coordinate.longitude),\($0.coordinate.latitude)" }.joined(separator: ";")

            var components = URLComponents()
            components.scheme = "https"
            components.host = "gh.maptoolkit.net"
            components.path = "/navigate/directions/v5/gh/car/\(stops)"
            components.queryItems = [
                URLQueryItem(name: "access_token", value: ""),
                URLQueryItem(name: "alternatives", value: "false"),
                URLQueryItem(name: "geometries", value: "polyline6"),
                URLQueryItem(name: "overview", value: "full"),
                URLQueryItem(name: "steps", value: "true"),
                URLQueryItem(name: "continue_straight", value: "true"),
                URLQueryItem(name: "annotations", value: "congestion,distance"),
                URLQueryItem(name: "language", value: Locale.preferredLanguages.first ?? "en-US"),
                URLQueryItem(name: "roundabout_exits", value: "true"),
                URLQueryItem(name: "voice_instructions", value: "true"),
                URLQueryItem(name: "banner_instructions", value: "true"),
                URLQueryItem(name: "voice_units", value: "metric")
            ]
            guard let url = components.url else {
                throw Toursprung.ToursprungError.invalidUrl(message: "Couldn't create url from URLComponents")
            }

            return url
        }
    }

    func response(from json: JSONDictionary) throws -> (waypoint: [Waypoint], routes: [Route]) {
        var namedWaypoints: [Waypoint] = []
        if let jsonWaypoints = (json["waypoints"] as? [JSONDictionary]) {
            namedWaypoints = try zip(jsonWaypoints, self.waypoints).compactMap { api, local -> Waypoint? in
                guard let location = api["location"] as? [Double] else {
                    return nil
                }

                let coordinate = try CLLocationCoordinate2D(geoJSON: location)
                let possibleAPIName = api["name"] as? String
                let apiName = possibleAPIName?.nonEmptyString
                return Waypoint(coordinate: coordinate, name: local.name ?? apiName)
            }
        }

        let routes = (json["routes"] as? [JSONDictionary] ?? []).compactMap {
            Route(json: $0, waypoints: waypoints, options: self)
        }
        return (namedWaypoints, routes)
    }
}

public extension CLLocationCoordinate2D {
    enum GeoJSONError: LocalizedError {
        case invalidCoordinates
        case invalidType

        public var errorDescription: String? {
            switch self {
            case .invalidCoordinates:
                "Can not read coordinates"
            case .invalidType:
                "Expecting different GeoJSON type"
            }
        }

        public var failureReason: String? {
            switch self {
            case .invalidCoordinates:
                "data has more or less then 2 coordinates, expecting exactly 2"
            case .invalidType:
                "type should be either LineString or Point"
            }
        }
    }

    init(geoJSON array: [Double]) throws {
        guard array.count == 2 else {
            throw GeoJSONError.invalidCoordinates
        }

        self.init(latitude: array[1], longitude: array[0])
    }

    init(geoJSON point: JSONDictionary) throws {
        guard point["type"] as? String == "Point" else {
            throw GeoJSONError.invalidType
        }

        try self.init(geoJSON: point["coordinates"] as? [Double] ?? [])
    }

    static func coordinates(geoJSON lineString: JSONDictionary) throws -> [CLLocationCoordinate2D] {
        let type = lineString["type"] as? String
        guard type == "LineString" || type == "Point" else {
            throw GeoJSONError.invalidType
        }

        let coordinates = lineString["coordinates"] as? [[Double]] ?? []
        return try coordinates.map { try self.init(geoJSON: $0) }
    }
}
