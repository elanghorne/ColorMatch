//
//  AnalysisModel.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/23/25.
//

import Foundation


// storage for analysis data and final feedback
struct OutfitAnalysisResult{
    var feedbackMessage = "Analyzed!"
}

// possible errors throughout analysis
enum AnalysisError: LocalizedError {
    case noHumanFound
    case multipleHumansFound
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
            case .noHumanFound:
            return "No human found in image."
        case .multipleHumansFound:
            return "Multiple humans found in image."
        case .imageConversionFailed:
            return "Failed to convert image to CGImage."
        }
    }

}
