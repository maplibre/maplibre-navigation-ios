//
//  ViewController.swift
//  Example
//
//  Created by Patrick Kladek on 16.05.24.
//

import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
import MapLibre

class ViewController: NavigationViewController {
    private let styleURL = Bundle.main.url(forResource: "Terrain", withExtension: "json")! // swiftlint:disable:this force_unwrapping
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        self.mapView?.styleURL = self.styleURL
        self.mapView?.reloadStyle(nil)
		
//        let navigationView = NavigationMapView(frame: .zero, styleURL: self.styleURL, config: MNConfig())
//        self.navigationView = navigationView
//        self.view.addSubview(navigationView)
//
//        navigationView.translatesAutoresizingMaskIntoConstraints = false
//        navigationView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
//        navigationView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//        navigationView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
//        navigationView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
//
//        let waypoints = [
//            CLLocation(latitude: 52.032407, longitude: 5.580310),
//            CLLocation(latitude: 51.768686, longitude: 4.6827956)
//        ].map { Waypoint(location: $0) }
//
//        navigationView.zoomLevel = 12
//        navigationView.centerCoordinate = waypoints[0].coordinate
//
//        let options = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: .automobileAvoidingTraffic)
//        options.shapeFormat = .polyline6
//        options.distanceMeasurementSystem = .metric
//        options.attributeOptions = []
//
//        print("[\(type(of: self))] Calculating routes with URL: \(Directions.shared.url(forCalculating: options))")
//
//        let viewController = NavigationViewController()
//
//        Directions.shared.calculate(options) { _, routes, _ in
//            guard let route = routes?.first else { return }
//
//            let simulatedLocationManager = SimulatedLocationManager(route: route)
//            simulatedLocationManager.speedMultiplier = 2
//
//            viewController.mapView?.styleURL = self.styleURL
//            self.present(viewController, animated: true) {
//                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
//                    viewController.begin(with: route, locationManager: simulatedLocationManager)
//                }
//            }
//        }
    }
	
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.mapView?.styleURL = self.styleURL
		
        self.mapView?.centerCoordinate = .init(latitude: 48.210033, longitude: 16.363449)
    }
}
