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
        var analysisResult = OutfitAnalysisResult() // create instance of OutfitAnalysisResult structure
        
        guard let cgImage = image.cgImage else { // convert UIImage to CGImage for analysis
            analysisResult.feedbackMessage = AnalysisError.imageConversionFailed.localizedDescription
            return analysisResult
        }
        do {
            let boundingBox = try await self.detectBody(in: cgImage)
            print("Bounding box detected: \(boundingBox)")
            analysisResult.feedbackMessage = "Human detected!"
        } catch let error as AnalysisError {
            analysisResult.feedbackMessage = error.localizedDescription
            return analysisResult
        } catch {
            analysisResult.feedbackMessage = "An unknown error occurred."
            return analysisResult
        }
        return analysisResult
    }
    

    private func detectBody(in image: CGImage) async throws -> CGRect{
        let bodyDetectionRequest = VNDetectHumanRectanglesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        try requestHandler.perform([bodyDetectionRequest])
        guard let result = bodyDetectionRequest.results, let observation = result as? [VNHumanObservation], !observation.isEmpty else {
            print("No human detected. Please try again.")
            throw AnalysisError.noHumanFound
        }
        if observation.count > 1 {
            print("Multiple people detected. Try again with only 1 person.")
            throw AnalysisError.multipleHumansFound
        }
        
        let boundingBox = observation[0].boundingBox
        return boundingBox
    }
}


/* async + closure version
 let bodyDetectionRequest = VNDetectHumanRectanglesRequest { request, error in
     if let error = error {
         print("Error detecting human rectangles: \(error.localizedDescription)")
         return
     }
     guard let observation = request.results as? [VNHumanObservation] else {
         print("No human detected. Please try again.")
         return
     }
     if observation.count > 1 {
         print("Multiple people detected. Try again with only 1 person.")
     }
     let boundingBox = observation[0].boundingBox
     print("Bounding box: \(boundingBox)")
     
 }
 
 do {
     try requestHandler.perform([bodyDetectionRequest])
     return boundingBox
 } catch {
     print("Failed to perform detection request: \(error.localizedDescription)")
     return
 }
 */
