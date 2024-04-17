// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "maplibre-navigation-ios",
    defaultLocalization: "en",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "MapboxNavigation",
            targets: [
                "MapboxNavigation"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/flitsmeister/mapbox-directions-swift", exact: "0.23.3"),
        .package(url: "https://github.com/flitsmeister/turf-swift", exact: "0.2.2"),
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", from: "6.0.0"),
        .package(url: "https://github.com/ceeK/Solar.git", exact: "3.0.1"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.53.6")
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
                .product(name: "Solar", package: "Solar")
            ],
            path: "MapboxNavigation",
            resources: [
                .copy("Resources/Assets.xcassets")
            ]
        ),
        .target(
            name: "MapboxNavigationObjC",
            dependencies: [
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution")
            ],
            path: "MapboxNavigationObjC"
        ),
        .testTarget(
            name: "MapboxNavigationTests",
            dependencies: [
                "MapboxNavigation",
                "MapboxCoreNavigation",
                "Solar"
            ],
            path: "MapboxNavigationTests",
            resources: [
                // NOTE: Ideally we would just put all resources like route.json and Assets.xcassets in Folder 'Resources'
                // but an Xcode/SPM bug is preventing us from doing so. It is not possible to copy and process files into the same
                // destination directiory ('*.bundle/Resources') without a code signing error:
                // This is the error message:
                //	CodeSign ~/Library/Developer/Xcode/DerivedData/maplibre-navigation-ios-cdijqyqwjamndzfaqhxchbiayzsb/Build/Products/Debug-iphonesimulator/maplibre-navigation-ios_MapboxNavigationTests.bundle  (in target 'maplibre-navigation-ios_MapboxNavigationTests' from project 'maplibre-navigation-ios')
                //	cd ~/Developer/maplibre-navigation-ios
                //
                //	Signing Identity:     "-"
                //
                //	/usr/bin/codesign --force --sign - --timestamp\=none --generate-entitlement-der ~/Library/Developer/Xcode/DerivedData/maplibre-navigation-ios-cdijqyqwjamndzfaqhxchbiayzsb/Build/Products/Debug-iphonesimulator/maplibre-navigation-ios_MapboxNavigationTests.bundle
                //
                //	~/Library/Developer/Xcode/DerivedData/maplibre-navigation-ios-cdijqyqwjamndzfaqhxchbiayzsb/Build/Products/Debug-iphonesimulator/maplibre-navigation-ios_MapboxNavigationTests.bundle: bundle format unrecognized, invalid, or unsuitable
                //	Command CodeSign failed with a nonzero exit code
                //
                // Instead the json files are placed in a Folder called 'Fixtures' and manually specified for copying
                // The Assets.xcassets is compiled into an Assets.car
                // This results in a flat Bundle file structure however the tests pass.
				
                .process("Assets.xcassets"),
                .copy("Fixtures/EmptyStyle.json"),
                .copy("Fixtures/route.json"),
                .copy("Fixtures/route-for-lane-testing.json"),
                .copy("Fixtures/route-with-banner-instructions.json"),
                .copy("Fixtures/route-with-instructions.json"),
                .copy("Fixtures/route-with-lanes.json")
            ]
        ),
        .testTarget(
            name: "MapboxCoreNavigationTests",
            dependencies: [
                "MapboxNavigation",
                "MapboxCoreNavigation"
            ],
            path: "MapboxCoreNavigationTests",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
