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

class ViewController: UIViewController {
    private let styleURL = Bundle.main.url(forResource: "Terrain", withExtension: "json")! // swiftlint:disable:this force_unwrapping
	
    var navigationView: NavigationMapView?
	
    // Keep `RouteController` in memory (class scope),
    // otherwise location updates won't be triggered
    public var mapboxRouteController: RouteController?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        let navigationView = NavigationMapView(frame: .zero, styleURL: self.styleURL, config: MNConfig())
        self.navigationView = navigationView
        self.view.addSubview(navigationView)
		
        navigationView.translatesAutoresizingMaskIntoConstraints = false
        navigationView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        navigationView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        navigationView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        navigationView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		
        let waypoints = [
            CLLocation(latitude: 52.032407, longitude: 5.580310),
            CLLocation(latitude: 51.768686, longitude: 4.6827956)
        ].map { Waypoint(location: $0) }
		
        Task {
            do {
                let routeOptions = NavigationRouteOptions(waypoints: waypoints)
                let result = try await Toursprung.shared.calculate(routeOptions)
                guard let route = result.routes.first else { return }
				
                await MainActor.run {
                    let simulatedLocationManager = SimulatedLocationManager(route: route)
                    simulatedLocationManager.speedMultiplier = 2
					
                    //					let viewController = NavigationViewController(for: route, locationManager: simulatedLocationManager)
                    //					viewController.mapView?.styleURL = self.styleURL
                    //					self.present(viewController, animated: true)
//
                    let mapboxRouteController = RouteController(along: route,
                                                                directions: Directions.shared,
                                                                locationManager: simulatedLocationManager)
                    self.mapboxRouteController = mapboxRouteController
                    mapboxRouteController.delegate = self
                    mapboxRouteController.resume()
					
                    NotificationCenter.default.addObserver(self, selector: #selector(self.didPassVisualInstructionPoint(notification:)), name: .routeControllerDidPassVisualInstructionPoint, object: nil)
                    NotificationCenter.default.addObserver(self, selector: #selector(self.didPassSpokenInstructionPoint(notification:)), name: .routeControllerDidPassSpokenInstructionPoint, object: nil)
					
                    navigationView.showRoutes([route], legIndex: 0)
                }
            } catch {
                print(error)
            }
        }
    }
}

// MARK: - RouteControllerDelegate

extension ViewController: RouteControllerDelegate {
    @objc
    func routeController(_ routeController: RouteController, didUpdate locations: [CLLocation]) {
        let camera = MLNMapCamera(lookingAtCenter: locations.first!.coordinate, acrossDistance: 500, pitch: 0, heading: 0)
		
        self.navigationView?.setCamera(camera, animated: true)
    }
	
    @objc
    func didPassVisualInstructionPoint(notification: NSNotification) {
        guard let currentVisualInstruction = currentStepProgress(from: notification)?.currentVisualInstruction else { return }
		
        print(String(
            format: "didPassVisualInstructionPoint primary text: %@ and secondary text: %@",
            String(describing: currentVisualInstruction.primaryInstruction.text),
            String(describing: currentVisualInstruction.secondaryInstruction?.text)))
    }
	
    @objc
    func didPassSpokenInstructionPoint(notification: NSNotification) {
        guard let currentSpokenInstruction = currentStepProgress(from: notification)?.currentSpokenInstruction else { return }
		
        print("didPassSpokenInstructionPoint text: \(currentSpokenInstruction.text)")
    }
	
    private
    func currentStepProgress(from notification: NSNotification) -> RouteStepProgress? {
        let routeProgress = notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
        return routeProgress?.currentLegProgress.currentStepProgress
    }
}
