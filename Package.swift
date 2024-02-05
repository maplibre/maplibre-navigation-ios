// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "maplibre-navigation-ios",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "MapboxNavigation",
            targets: [
                "MapboxNavigation"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/flitsmeister/mapbox-directions-swift", exact: "0.23.2"),
        .package(url: "https://github.com/flitsmeister/turf-swift", exact: "0.2.2"),
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", from: "5.0.0"),
        .package(url: "https://github.com/ceeK/Solar.git", exact: "3.0.1")
    ],
    targets: [
        .target(
            name: "MapboxCoreNavigation",
            dependencies: [
                .product(name: "Turf", package: "turf-swift"),
                .product(name: "MapboxDirections", package: "mapbox-directions-swift"),
                "MapboxCoreNavigationObjC"
            ],
            path: "MapboxCoreNavigation",
            resources: [.process("resources")]
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
                .product(name: "Solar", package: "Solar"),
            ],
            path: "MapboxNavigation"
        ),
        .target(
            name: "MapboxNavigationObjC",
            dependencies: [
                .product(name: "Mapbox", package: "maplibre-gl-native-distribution")
            ],
            path: "MapboxNavigationObjC"
        )
    ]
)
