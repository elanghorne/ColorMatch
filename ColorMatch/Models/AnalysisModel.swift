//
//  AnalysisModel.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/23/25.
//

import Foundation
import PhotosUI

// storage for analysis data and final feedback
struct OutfitAnalysisResult{
    var feedbackMessage = "Analyzed!"
    var isMatch: Bool? = nil
    var confidence: Int = 0 // 0-100
    var debugImage: UIImage? = nil //testing
    var pixelBuffer: [UInt8]? = nil
}

// possible errors throughout analysis
enum AnalysisError: LocalizedError {
    case noHumanFound
    case multipleHumansFound
    case imageConversionFailed
    case unknown
    case bodyDetectionRequest
    case failedCrop
    case faceDetectionRequest
    
    var errorDescription: String? {
        switch self {
        case .noHumanFound:
            return "No human found in image. Please try again."
        case .multipleHumansFound:
            return "Multiple humans found in image. Please try again with only 1 person."
        case .imageConversionFailed:
            return "Failed to convert image to CGImage."
        case .unknown:
            return "Unknown error occurred."
        case .bodyDetectionRequest:
            return "Error performing body detection request."
        case .failedCrop:
            return "Failed to crop image."
        case .faceDetectionRequest:
            return "Error performing face detection request."
        }
    }
}

enum ShadeLevel {
    case light
    case medium
    case dark
    case neutral
    
    var value: Int {
        switch self {
        case .light:
            return 1
        case .medium:
            return 2
        case .dark:
            return 3
        case .neutral:
            return 0
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
        return "Label: \(label), Shade: \(shade), Count: \(count), Percentage: \(String(format: "%.2f", percentage))%, Mean Hue: \(meanHue), Hue StdDev: \(String(format: "%.2f", hueStdDev))"
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
