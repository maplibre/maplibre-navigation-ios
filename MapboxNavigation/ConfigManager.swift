//
//  ConfigManager.swift
//  MapboxNavigation
//
//  Created by Marcel Hozeman on 23/04/2020.
//  Copyright © 2020 Mapbox. All rights reserved.
//

import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    
    public var config = MNConfig()
}

public struct MNConfig {
    // Route
    public var routeLineColor = #colorLiteral(red: 0, green: 0.4980392157, blue: 0.9098039216, alpha: 1)
    public var routeLineAlpha: Double = 1
    public var routeLineCasingColor = #colorLiteral(red: 0, green: 0.3450980392, blue: 0.6352941176, alpha: 1)
    public var routeLineCasingAlpha: Double = 1
    
    // Alternative route
    public var routeLineAlternativeColor = #colorLiteral(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    public var routeLineAlternativeAlpha: Double = 1
    public var routeLineCasingAlternativeColor = #colorLiteral(red: 0.5019607843, green: 0.4980392157, blue: 0.5019607843, alpha: 1)
    public var routeLineCasingAlternativeAlpha: Double = 1
    
    // Arrow
    public var routeArrowColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    public var routeArrowCasingColor = #colorLiteral(red: 0, green: 0.4980392157, blue: 0.9098039216, alpha: 1)
    
    public init() {
    }
}
