//
//  AnalysisError.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 4/5/26.
//
import Foundation

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
            return "Please try again with only 1 person shown."
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
