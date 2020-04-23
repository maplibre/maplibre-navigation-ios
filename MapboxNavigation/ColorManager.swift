//
//  ColorManager.swift
//  MapboxNavigation
//
//  Created by Marcel Hozeman on 23/04/2020.
//  Copyright © 2020 Mapbox. All rights reserved.
//

import Foundation

public class ColorManager {
    static let shared = ColorManager()
    
    var palette = Palette()
}

public struct Palette {
    var tintColor = #colorLiteral(red: 0.1843137255, green: 0.4784313725, blue: 0.7764705882, alpha: 1)
    var tintStrokeColor = #colorLiteral(red: 0.1843137255, green: 0.4784313725, blue: 0.7764705882, alpha: 1)
}
