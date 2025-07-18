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
        let boundingBox: CGRect
        
        guard let cgImage = image.cgImage else { // convert UIImage to CGImage for analysis
            analysisResult.feedbackMessage = AnalysisError.imageConversionFailed.localizedDescription
            return analysisResult
        }
        do {
            boundingBox = try await self.detectBody(in: cgImage)
            print("Bounding box detected: \(boundingBox)")
            analysisResult.feedbackMessage = "Human detected!"
        } catch let error as AnalysisError {
            analysisResult.feedbackMessage = error.localizedDescription
            return analysisResult
        } catch {
            analysisResult.feedbackMessage = AnalysisError.unknown.localizedDescription
            return analysisResult
        }
        do {
            let croppedImage = try self.cropImage(in: cgImage, to: boundingBox)
            let debugImage = UIImage(cgImage: croppedImage)
            analysisResult.debugImage = debugImage
        } catch {
            analysisResult.feedbackMessage = error.localizedDescription
            return analysisResult
        }

        
        return analysisResult
    }
    
/*
 * detectBody
 *
 * detects human body in provided image and provides bounding box for cropping
 *
 * input: CGImage _image_
 * output: CGRect _boundingBox_
 */
    private func detectBody(in image: CGImage) async throws -> CGRect{
        let bodyDetectionRequest = VNDetectHumanRectanglesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try requestHandler.perform([bodyDetectionRequest])
        } catch {
            print("Error performing request: \(error.localizedDescription)")
            throw AnalysisError.bodyDetectionRequest
        }
        guard let observation = bodyDetectionRequest.results, !observation.isEmpty else {
            print("No human detected. Please try again.")
            throw AnalysisError.noHumanFound
        }
        if observation.count > 1 {
            print("\(observation.count) people detected. Try again with only 1 person.")
            throw AnalysisError.multipleHumansFound
        }
        
        let boundingBox = observation[0].boundingBox
        return boundingBox
    }

/*
 * cropImage
 *
 * crops cgImage to provided bounding box
 *
 * input: CGImage _image_, CGRect _rectangle_
 * output: CGImage _cgImage_ (cropped image)
 */
    private func cropImage(in image: CGImage, to rectangle: CGRect) throws -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let convertedRect = CGRect(x: width * rectangle.origin.x, y: height * (1 - rectangle.origin.y), width: width, height: height)
        guard let croppedImage = image.cropping(to: convertedRect) else {
            throw AnalysisError.failedCrop
        }
        return croppedImage
    }
}
