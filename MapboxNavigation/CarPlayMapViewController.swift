import Foundation
import MapLibre
#if canImport(CarPlay)
import CarPlay

@available(iOS 12.0, *)
class CarPlayMapViewController: UIViewController, MLNMapViewDelegate {
    static let defaultAltitude: CLLocationDistance = 16000
    
    var styleManager: StyleManager!
    /// A very coarse location manager used for distinguishing between daytime and nighttime.
    fileprivate let coarseLocationManager: CLLocationManager = {
        let coarseLocationManager = CLLocationManager()
        coarseLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        return coarseLocationManager
    }()
    
    var isOverviewingRoutes: Bool = false
    
    var mapView: NavigationMapView {
        view as! NavigationMapView
    }

    lazy var recenterButton: CPMapButton = {
        let recenterButton = CPMapButton { [weak self] button in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.mapView.setUserTrackingMode(.followWithCourse, animated: true, completionHandler: nil)
            button.isHidden = true
        }
        
        let bundle = Bundle.mapboxNavigation
        recenterButton.image = UIImage(named: "carplay_locate", in: bundle, compatibleWith: traitCollection)
        return recenterButton
    }()
    
    override func loadView() {
        let mapView = NavigationMapView()
        mapView.delegate = self
//        mapView.navigationMapDelegate = self
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        
        view = mapView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.styleManager = StyleManager(self)
        self.styleManager.styles = [DayStyle(demoStyle: ()), NightStyle(demoStyle: ())]

        self.resetCamera(animated: false, altitude: CarPlayMapViewController.defaultAltitude)
        self.mapView.setUserTrackingMode(.followWithCourse, animated: true, completionHandler: nil)
    }
    
    public func zoomInButton() -> CPMapButton {
        let zoomInButton = CPMapButton { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.mapView.setZoomLevel(strongSelf.mapView.zoomLevel + 1, animated: true)
        }
        let bundle = Bundle.mapboxNavigation
        zoomInButton.image = UIImage(named: "carplay_plus", in: bundle, compatibleWith: traitCollection)
        return zoomInButton
    }
    
    public func zoomOutButton() -> CPMapButton {
        let zoomInOut = CPMapButton { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.mapView.setZoomLevel(strongSelf.mapView.zoomLevel - 1, animated: true)
        }
        let bundle = Bundle.mapboxNavigation
        zoomInOut.image = UIImage(named: "carplay_minus", in: bundle, compatibleWith: traitCollection)
        return zoomInOut
    }

    // MARK: - MLNMapViewDelegate

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        if let mapView = mapView as? NavigationMapView {
            mapView.localizeLabels()
        }
    }
    
    func resetCamera(animated: Bool = false, altitude: CLLocationDistance? = nil) {
        let camera = self.mapView.camera
        if let altitude {
            camera.altitude = altitude
        }
        camera.pitch = 60
        self.mapView.setCamera(camera, animated: animated)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        self.mapView.setContentInset(self.mapView.safeArea, animated: false, completionHandler: nil)
        
        guard self.isOverviewingRoutes else {
            super.viewSafeAreaInsetsDidChange()
            return
        }
        
        guard let routes = mapView.routes,
              let active = routes.first else {
            super.viewSafeAreaInsetsDidChange()
            return
        }
        
        self.mapView.fit(to: active, animated: false)
    }
}

@available(iOS 12.0, *)
extension CarPlayMapViewController: StyleManagerDelegate {
    func locationFor(styleManager: StyleManager) -> CLLocation? {
        self.mapView.userLocationForCourseTracking ?? self.mapView.userLocation?.location ?? self.coarseLocationManager.location
    }
    
    func styleManager(_ styleManager: StyleManager, didApply style: Style) {
        let styleURL = style.previewMapStyleURL
        if self.mapView.styleURL != styleURL {
            self.mapView.style?.transition = MLNTransition(duration: 0.5, delay: 0)
            self.mapView.styleURL = styleURL
        }
    }
    
    func styleManagerDidRefreshAppearance(_ styleManager: StyleManager) {
        self.mapView.reloadStyle(self)
    }
}
#endif
