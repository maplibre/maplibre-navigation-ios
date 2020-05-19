//
//  ColorManager.swift
//  MapboxNavigation
//
//  Created by Marcel Hozeman on 23/04/2020.
//  Copyright © 2020 Mapbox. All rights reserved.
//

import Foundation

class ColorManager {
    static let shared = ColorManager()
    
    public var palette = Palette()
}

public struct Palette {
    public var routeLineColor = #colorLiteral(red: 0, green: 0.4980392157, blue: 0.9098039216, alpha: 1)
    public var routeLineCasingColor = #colorLiteral(red: 0, green: 0.3450980392, blue: 0.6352941176, alpha: 1)
    public var routeArrowColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    public var routeArrowCasingColor = #colorLiteral(red: 0, green: 0.4980392157, blue: 0.9098039216, alpha: 1)

    public init() {
    }
}
