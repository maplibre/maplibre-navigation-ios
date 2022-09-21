<div align="center">
  <img src="https://github.com/flitsmeister/flitsmeister-navigation-ios/blob/master/.github/splash-image-ios.png" alt="Flitsmeister Navigation iOS Splash">
</div>
<br>

The Flitsmeister Navigation SDK for iOS is built on a fork of the [Mapbox Navigation SDK v0.21](https://github.com/flitsmeister/flitsmeister-navigation-ios/tree/v0.21.0) which is build on top of the [Mapbox Directions API](https://www.mapbox.com/directions) and contains logic needed to get timed navigation instructions.

With this SDK you can implement turn by turn navigation in your own iOS app while hosting your own Map tiles and Directions API.

# Why have we forked

1. Mapbox decided to put a closed source component to their navigation SDK and introduced a non open source license. Flitsmeister wants an open source solution.
2. Mapbox decided to put telemetry in their SDK. We couldn't turn this off without adjusting the source.
3. We want to use the SDK without paying Mapbox for each MAU and without Mapbox API keys.

All issues are covered with this SDK. 

# What have we changed

- Removed EventManager and all its references, this manager collected telemetry data which we don't want to send
- Updated [Mapbox SDK](https://github.com/mapbox/mapbox-gl-native-ios) from version 4.3 to 5.3
- Added optional config parameter in NavigationMapView constructor to customize certain properties like route line color

# Getting Started

If you are looking to include this inside your project, you have to follow the the following steps:

1. Install Carthage
   - Open terminal
   - [optional] On M1 Mac change terminal to bash: `chsh -s /bin/bash`
   - [Install Homebrew](https://brew.sh/): `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
   - [Install Carthage](https://formulae.brew.sh/formula/carthage): `brew install carthage`
1. Create a new XCode project
1. Create Cartfile
   - Open terminal
   - Change location to root of XCode project: `cd path/to/Project`
    - Create the Cartfile: `touch Cartfile`
   - New file will be added: `Cartfile`
1. Add dependencies to Cartfile
   ```
   binary "https://www.mapbox.com/ios-sdk/Mapbox-iOS-SDK.json" == 5.3.0
   github "flitsmeister/flitsmeister-navigation-ios" ~> 1.0.3
   ```
1. Build the frameworks
   - Open terminal
   - Change location to root of XCode project: `cd path/to/Project`
   - Run: `carthage bootstrap --platform iOS --use-xcframeworks`
   - New files will be added
     - Cartfile.resolved = Indicates which frameworks have been fetched/built
     - Carthage folder = Contains all builded frameworks
1. Drag frameworks into project: `TARGETS -> General -> Frameworks, Libraries..`
   - Mapbox.framework
   - All xcframeworks
1. Add properties to `Info.plist`
   - MGLMapboxAccessToken / String / Leave empty = Ensures that the SDK doesn't crash
   - MGLMapboxAPIBaseURL / String / Add url = Url that is being used to GET the navigation JSON
   - NSLocationWhenInUseUsageDescription / String / Add a description = Needed for the location permission
1. [optional] When app is not running on simulator on M1 Mac: Add `arm64` to `PROJECT -> <Project naam> -> Build Settings -> Excluded Architecture Only`
1. Use the sample code as inspiration

# Getting Help

- **Have a bug to report?** [Open an issue](https://github.com/flitsmeister/flitsmeister-navigation-ios/issues). If possible, include the version of Flitsmeister Services, a full log, and a project that shows the issue.
- **Have a feature request?** [Open an issue](https://github.com/flitsmeister/flitsmeister-navigation-ios/issues/new). Tell us what the feature should do and why you want the feature.

## <a name="sample-code">Sample code

A demo app is currently not available. Please check the Mapbox repository or documentation for examples. You can try the provided demo app, which you need to first run `carthage update --platform iOS --use-xc-frameworks` for in the root of this project.

In order to see the map or calculate a route you need your own Maptile and Direction services.

Use the following code as inspiration:

```
import Mapbox
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation

class ViewController: UIViewController {
    var navigationView: NavigationMapView?
    
    // Keep `RouteController` in memory (class scope),
    // otherwise location updates won't be triggered
    public var mapboxRouteController: RouteController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let navigationView = NavigationMapView(
            frame: .zero,
            // Tile loading can take a while
            styleURL: URL(string: "..."), // TODO: Add style url
            config: MNConfig())
        self.navigationView = navigationView
        view.addSubview(navigationView)
        navigationView.translatesAutoresizingMaskIntoConstraints = false
        navigationView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        navigationView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        navigationView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        navigationView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        // Note: For FM lat/lngs are reversed here
        let waypoints = [
            CLLocation(latitude: 52.032407, longitude: 5.580310),
            CLLocation(latitude: 51.768686, longitude: 4.6827956)
        ].map { Waypoint(location: $0) }
        
        let options = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: .automobileAvoidingTraffic)
        options.shapeFormat = .polyline6
        options.distanceMeasurementSystem = .metric
        options.attributeOptions = []
        
        Directions.shared.calculate(options) { (waypoints, routes, error) in
            guard let route = routes?.first else { return }
            
            let simulatedLocationManager = SimulatedLocationManager(route: route)
            simulatedLocationManager.speedMultiplier = 20
            
            let mapboxRouteController = RouteController(
                along: route,
                directions: Directions.shared,
                locationManager: simulatedLocationManager)
            self.mapboxRouteController = mapboxRouteController
            mapboxRouteController.delegate = self
            mapboxRouteController.resume()
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.didPassVisualInstructionPoint(notification:)), name: .routeControllerDidPassVisualInstructionPoint, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.didPassSpokenInstructionPoint(notification:)), name: .routeControllerDidPassSpokenInstructionPoint, object: nil)
            
            navigationView.showRoutes([route], legIndex: 0)
        }
    }
}

// MARK: - RouteControllerDelegate

extension ViewController: RouteControllerDelegate {
    @objc public func routeController(_ routeController: RouteController, didUpdate locations: [CLLocation]) {
        let camera = MGLMapCamera(
            lookingAtCenter: locations.first!.coordinate,
            acrossDistance: 500,
            pitch: 0,
            heading: 0
        )
        
        navigationView?.setCamera(camera, animated: true)
    }
    
    @objc func didPassVisualInstructionPoint(notification: NSNotification) {
        guard let currentVisualInstruction = currentStepProgress(from: notification)?.currentVisualInstruction else { return }
        
        print(String(
            format: "didPassVisualInstructionPoint primary text: %@ and secondary text: %@",
            String(describing: currentVisualInstruction.primaryInstruction.text),
            String(describing: currentVisualInstruction.secondaryInstruction?.text)))
    }
    
    @objc func didPassSpokenInstructionPoint(notification: NSNotification) {
        guard let currentSpokenInstruction = currentStepProgress(from: notification)?.currentSpokenInstruction else { return }
        
        print("didPassSpokenInstructionPoint text: \(currentSpokenInstruction.text)")
    }
    
    private func currentStepProgress(from notification: NSNotification) -> RouteStepProgress? {
        let routeProgress = notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress
        return routeProgress?.currentLegProgress.currentStepProgress
    }
}
```

# License

Code is [licensed](LICENSE.md) under MIT and ISC. 
ISC is meant to be functionally equivalent to the MIT license.
