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
        let bodyBox: CGRect
        let faceBox: CGRect?
        let croppedBodyImage: CGImage
        let croppedFaceImage: CGImage
       // print("Initial orientation: \(image.imageOrientation)") // debug
        let orientedImage = image.normalized()
        guard let cgImage = orientedImage.cgImage else { // convert UIImage to CGImage for analysis
            analysisResult.feedbackMessage = AnalysisError.imageConversionFailed.localizedDescription
            return analysisResult
        }
        let debugImage1 = UIImage(cgImage: cgImage)
        //analysisResult.debugImage = debugImage1
        print("Orientation after conversion: \(debugImage1.imageOrientation)")
        do {
            bodyBox = try await self.detectBody(in: cgImage)
            print("Bounding box detected: \(bodyBox)")
            analysisResult.feedbackMessage = "Human detected!"
        } catch let error as AnalysisError {
            analysisResult.feedbackMessage = error.localizedDescription
            return analysisResult
        } catch {
            analysisResult.feedbackMessage = AnalysisError.unknown.localizedDescription
            return analysisResult
        }
        do {
            croppedBodyImage = try self.cropBody(in: cgImage, to: bodyBox)
            //let debugImage = UIImage(cgImage: croppedBodyImage)
            //analysisResult.debugImage = debugImage
        } catch {
            analysisResult.feedbackMessage = error.localizedDescription
            return analysisResult
        }
        do {
            
            if let faceBox = try await self.detectFace(in: croppedBodyImage){
                print("Face bounding box detected: \(faceBox)")
                croppedFaceImage = try self.cropFace(faceBox, outOf: croppedBodyImage)
                analysisResult.debugImage = UIImage(cgImage: croppedFaceImage)
            }
               
            
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
        bodyDetectionRequest.upperBodyOnly = false
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
    private func cropBody(in image: CGImage, to rectangle: CGRect) throws -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let convertedRect = CGRect(x: width * rectangle.origin.x, y: height * (1 - rectangle.origin.y - rectangle.height), width: width * rectangle.width, height: height * rectangle.height)
        print("Converted CGRect: \(convertedRect)")
        guard let croppedImage = image.cropping(to: convertedRect) else {
            throw AnalysisError.failedCrop
        }
        return croppedImage
    }
    
    private func detectFace(in image: CGImage) async throws -> CGRect? {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try requestHandler.perform( [faceDetectionRequest] )
        } catch {
            throw AnalysisError.faceDetectionRequest
        }
        
        guard let observation = faceDetectionRequest.results, !observation.isEmpty else {
            return nil
        }
        return observation[0].boundingBox
    }
    private func cropFace(_ rectangle: CGRect, outOf image: CGImage) throws -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let convertedRect = CGRect(x: 0, y: (height * (1 - rectangle.origin.y)), width: width, height: height - (height * rectangle.height))
        print("Converted CGRect: \(convertedRect)")
        guard let croppedImage = image.cropping(to: convertedRect) else {
            throw AnalysisError.failedCrop
        }
        return croppedImage
    }
}


