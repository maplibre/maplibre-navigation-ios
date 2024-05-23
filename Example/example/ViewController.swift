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
    }
	
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.mapView?.styleURL = self.styleURL
		
        self.mapView?.centerCoordinate = .init(latitude: 48.210033, longitude: 16.363449)
    }
}
