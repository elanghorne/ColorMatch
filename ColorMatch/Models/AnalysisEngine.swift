//
//  AnalysisEngine.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/1/25.
//

import Foundation
import PhotosUI
import Vision

struct AnalysisEngine {
    func runAnalysis(on image: UIImage) async -> OutfitAnalysisResult {
        let analysisResult = OutfitAnalysisResult()
        
        return analysisResult
    }
    
    private func convertImage(from image: UIImage) -> CGImage{
        let cgImage = image.cgImage!
        return cgImage
    }
    private func detectBody(in image: CGImage) -> CGRect{
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        let detectionRequest = VNDetectHumanRectanglesRequest { request, error in
            if let error = error {
                analysisResult.feedbackMessage = "Error detecting human rectangles: \(error.localizedDescription)"
                return
            }
            guard let observations = request.results as? [VNHumanObservation] else {
                analysisResult.feedbackMessage = "No person detected. Please try again."
                return
            }
            for observation in observations {
                let boundingBox = observation.boundingBox
                print("Bounding box: \(boundingBox)")
            }
        }
        do {
            try requestHandler.perform([detectionRequest])
        } catch {
            analysisResult.feedbackMessage = "Error performing detection request: \(error.localizedDescription)"
        }
    }
}
