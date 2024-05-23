//
//  SceneDelegate.swift
//  Example
//
//  Created by Patrick Kladek on 16.05.24.
//

import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
import MapLibre
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private let styleURL = Bundle.main.url(forResource: "Terrain", withExtension: "json")! // swiftlint:disable:this force_unwrapping
	
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
		
        self.window = UIWindow(windowScene: windowScene)
        let viewController = NavigationViewController(styleURL: self.styleURL)

        let waypoints = [
            CLLocation(latitude: 52.032407, longitude: 5.580310),
            CLLocation(latitude: 52.04, longitude: 5.580310)
//            CLLocation(latitude: 51.768686, longitude: 4.6827956)
        ].map { Waypoint(location: $0) }
        
        viewController.mapView?.tracksUserCourse = false
        viewController.mapView?.showsUserLocation = true
        viewController.mapView?.zoomLevel = 12
        viewController.mapView?.centerCoordinate = waypoints[0].coordinate
        viewController.delegate = self
        
        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            let options = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: .automobileAvoidingTraffic)
            options.shapeFormat = .polyline6
            options.distanceMeasurementSystem = .metric
            options.attributeOptions = []
			
            Directions.shared.calculate(options) { _, routes, _ in
                guard let route = routes?.first else { return }
				
                let simulatedLocationManager = SimulatedLocationManager(route: route)
                simulatedLocationManager.speedMultiplier = 2
				
                viewController.start(with: route, locationManager: simulatedLocationManager)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

extension SceneDelegate: NavigationViewControllerDelegate {
    func navigationViewControllerDidArriveAtDestination(_ navigationViewController: NavigationViewController) {
        navigationViewController.endRoute()
        
        print(#function)
    }
}
