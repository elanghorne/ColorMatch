//
//  AnalysisModel.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/23/25.
//

import SwiftUI

struct OutfitAnalysisData{
    var feedbackMessage = ""
    var isMatch: Bool = false
    var confidence: Int = 0 // 0-100
    var debugImage: UIImage?
}

enum ShadeLevel {
    case light
    case medium
    case dark
    case neutral
    
    var value: Int {
        switch self {
        case .neutral:
            return 0
        case .light:
            return 1
        case .medium:
            return 2
        case .dark:
            return 3
        }
    }
}

struct ColorBucket: CustomStringConvertible {
    let label: (Int, String)  // label is tuple where .0 is number 1-12 for determining adjacence and .1 is semantic descriptor
    let shade: ShadeLevel
    var count: Int
    var percentage: Double = 0.0
    var meanHue: Int = 0
    var hueStdDev: Double = 0.0
    var meanValue: Int = 0
    var valueStdDev: Double = 0.0
    var pixels: [(h: Int, s: Int, v: Int)] = []
    
    var description: String {
        return "Label: \(label)\nShade: \(shade)\nCount: \(count)\nPercentage: \(String(format: "%.2f", percentage))%\nMean Hue: \(meanHue)\nHue StdDev: \(String(format: "%.2f", hueStdDev))\nMean Value: \(meanValue)\nValue StdDev: \(String(format: "%.2f", valueStdDev))\nFirst 25 pixels: \(Array(pixels[0..<25]))\n"
    }
    init(label: (Int, String), shade: ShadeLevel, count: Int) {
        self.label = label
        self.shade = shade
        self.count = count
    }
    init(label: (Int, String), shade: ShadeLevel, count: Int, pixels: [(h: Int, s: Int, v: Int)]) {
        self.label = label
        self.shade = shade
        self.count = count
        self.pixels = pixels
    }
}
