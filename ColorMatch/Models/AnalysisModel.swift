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
}

struct ColorBucket {
    let label: String
    let shade: ShadeLevel
    var count: Int
}
