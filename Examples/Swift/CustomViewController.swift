import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import Mapbox
import CoreLocation
import AVFoundation
import MapboxDirections
import Turf

class CustomViewController: UIViewController, MGLMapViewDelegate {

    var destination: MGLPointAnnotation!
    let directions = Directions.shared
    var routeController: RouteController!
    var simulateLocation = false

    var userRoute: Route?

    // Start voice instructions
    let voiceController = RouteVoiceController()
    
    var stepsViewController: StepsViewController?

    @IBOutlet var mapView: NavigationMapView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var instructionsBannerView: InstructionsBannerView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let locationManager = simulateLocation ? SimulatedLocationManager(route: userRoute!) : NavigationLocationManager()
        routeController = RouteController(along: userRoute!, locationManager: locationManager)
        
        mapView.delegate = self
        mapView.courseTrackingDelegate = self
        mapView.compassView.isHidden = true
        
        instructionsBannerView.delegate = self

        // Add listeners for progress updates
        resumeNotifications()

        // Start navigation
        routeController.resume()
        
        // Center map on user
        mapView.recenterMap()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // This applies a default style to the top banner.
        DayStyle().apply()
    }

    deinit {
        suspendNotifications()
    }

    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rerouted(_:)), name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateInstructionsBanner(notification:)), name: .routeControllerDidPassVisualInstructionPoint, object: routeController)
    }

    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerWillReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassVisualInstructionPoint, object: nil)
    }

    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        self.mapView.showRoutes([routeController.routeProgress.route])
    }

    // Notifications sent on all location updates
    @objc func progressDidChange(_ notification: NSNotification) {
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as! CLLocation
        
        // Add maneuver arrow
        if routeProgress.currentLegProgress.followOnStep != nil {
            mapView.addArrow(route: routeProgress.route, legIndex: routeProgress.legIndex, stepIndex: routeProgress.currentLegProgress.stepIndex + 1)
        } else {
            mapView.removeArrow()
        }
        
        // Update the top banner with progress updates
        instructionsBannerView.updateDistance(for: routeProgress.currentLegProgress.currentStepProgress)
        instructionsBannerView.isHidden = false
        
        // Update the user puck
        mapView.updateCourseTracking(location: location, animated: true)
    }
    
    @objc func updateInstructionsBanner(notification: NSNotification) {
        guard let routeProgress = notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress else { return }
        instructionsBannerView.update(for: routeProgress.currentLegProgress.currentStepProgress.currentVisualInstruction)
    }

    // Fired when the user is no longer on the route.
    // Update the route on the map.
    @objc func rerouted(_ notification: NSNotification) {
        self.mapView.showRoutes([routeController.routeProgress.route])
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func recenterMap(_ sender: Any) {
        mapView.recenterMap()
    }
    
    func toggleStepsList() {
        if let controller = stepsViewController {
            controller.dismiss()
            stepsViewController = nil
        } else {
            guard let routeController = routeController else { return }
            
            let controller = StepsViewController(routeProgress: routeController.routeProgress)
            controller.delegate = self
            addChild(controller)
            view.addSubview(controller.view)
            
            controller.view.topAnchor.constraint(equalTo: instructionsBannerView.bottomAnchor).isActive = true
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            
            controller.didMove(toParent: self)
            controller.dropDownAnimation()
            
            stepsViewController = controller
            return
        }
    }
}

extension CustomViewController: InstructionsBannerViewDelegate {
    func didTapInstructionsBanner(_ sender: BaseInstructionsBannerView) {
        toggleStepsList()
    }
    
    func didDragInstructionsBanner(_ sender: BaseInstructionsBannerView) {
        toggleStepsList()
    }
}

extension CustomViewController: StepsViewControllerDelegate {
    func didDismissStepsViewController(_ viewController: StepsViewController) {
        viewController.dismiss { [weak self] in
            self?.stepsViewController = nil
        }
    }
    
    func stepsViewController(_ viewController: StepsViewController, didSelect legIndex: Int, stepIndex: Int, cell: StepTableViewCell) {
        viewController.dismiss { [weak self] in
            self?.stepsViewController = nil
        }
    }
}

// MARK: - NavigationMapViewCourseTrackingDelegate
extension CustomViewController: NavigationMapViewCourseTrackingDelegate {

    func updateCamera(_ mapView: NavigationMapView, location: CLLocation, routeProgress: RouteProgress) -> Bool{
        
        let newCamera = MGLMapCamera(lookingAtCenter: location.coordinate, acrossDistance: 750, pitch: 5, heading: location.course)
        let function: CAMediaTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        mapView.setCamera(newCamera, withDuration: 1, animationTimingFunction: function, edgePadding: UIEdgeInsets.zero, completionHandler: nil)
        
        return true
    }

}
