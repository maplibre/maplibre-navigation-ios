// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "maplibre-navigation-ios",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MapboxNavigation",
            targets: [
                "MapboxNavigation"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasharkema/mapbox-directions-swift.git", branch: "main"),
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", from: "5.12.2"),
        .package(url: "https://github.com/mapbox/MapboxGeocoder.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/flitsmeister/turf-swift.git", exact: "0.2.2"),
        .package(url: "https://github.com/mapbox/mapbox-speech-swift.git", from: "2.1.1"),
        .package(url: "https://github.com/ceeK/Solar.git", from: "3.0.1"),
    ],
    targets: [
        .target(
            name: "MapboxCoreNavigation",
            dependencies: [
                .product(name: "Turf", package: "turf-swift"),
                .product(name: "MapboxDirections", package: "mapbox-directions-swift"),
                "MapboxCoreNavigationObjC",
            ],
            path: "MapboxCoreNavigation"
        ),
        .target(
            name: "MapboxCoreNavigationObjC",
            path: "MapboxCoreNavigationObjC"
        ),
        .target(
            name: "MapboxNavigation",
            dependencies: [
                "MapboxCoreNavigation",
                "MapboxNavigationObjC",
                .product(name: "MapboxSpeech", package: "mapbox-speech-swift"),
                .product(name: "Solar", package: "Solar"),
            ],
            path: "MapboxNavigation"
        ),
        .target(
            name: "MapboxNavigationObjC",
            dependencies: [
                .product(name: "Mapbox", package: "maplibre-gl-native-distribution"),
            ],
            path: "MapboxNavigationObjC"
        ),
        .testTarget(
            name: "MapboxCoreNavigationTests",
            dependencies: ["MapboxCoreNavigation", "MapboxNavigation"],
            path: "MapboxCoreNavigationTests"
        ),
    ]
)
