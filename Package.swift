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
			path: "XcodeProj/MapboxNavigationTests",
			resources: [
				.copy("Resources2/route.json"),
				.copy("Resources2/Fixtures.xcassets"),
				.copy("Fixtures/EmptyStyle.json"),
				.copy("Fixtures/route-for-lane-testing.json"),
				.copy("Fixtures/route-with-banner-instructions.json"),
				.copy("Fixtures/route-with-instructions.json"),
				.copy("Fixtures/route-with-lanes.json"),
				.copy("ReferenceImages_64/")
			]
		),
		.testTarget(
			name: "MapboxCoreNavigationTests",
			dependencies: [
				"MapboxNavigation",
				"MapboxCoreNavigation"
			],
			path: "XcodeProj/MapboxCoreNavigationTests",
			resources: [
				.copy("Resources")
			]
		)
	]
)
