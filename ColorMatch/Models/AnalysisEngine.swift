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
        var bodyBox: CGRect
        // var faceBox: CGRect?
        var croppedBodyImage: CGImage
        var croppedFaceImage: CGImage?
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
            if let faceBox = try await self.detectFace(in: croppedBodyImage){ // run face detection on body cropped image
                print("Face bounding box detected: \(faceBox)")
                croppedFaceImage = try self.cropFace(faceBox, outOf: croppedBodyImage) // run face/head crop
                //analysisResult.debugImage = UIImage(cgImage: croppedFaceImage)
            }
        } catch {
            analysisResult.feedbackMessage = error.localizedDescription
            return analysisResult
        }
        if let cropped = croppedFaceImage{ // if face was cropped off (unwrap optional)
            analysisResult.pixelBuffer = self.getPixelData(from: cropped) // run data extraction on face cropped image
        } else {
            analysisResult.pixelBuffer = self.getPixelData(from: croppedBodyImage) // no face detected, run data extraction on original body crop
        }
        
        if let buffer = analysisResult.pixelBuffer { // unwrap pixel buffer into local assignment
            print(Array(buffer[0..<400])) // testing
            
            for i in stride(from: 0, to: buffer.count, by: 4){
                let r = buffer[i]
                let g = buffer[i+1]
                let b = buffer[i+2]
                
                let hsv = convertRGBtoHSV(r,g,b)
                // assignToBucket here
            }
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
    
    /*
     * detectFace
     *
     * detects face in image and provides bounding box (used to crop image above the shoulder)
     *
     * input: CGImage _image_
     * output: CGRect optional
     */
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
    
    /*
     * cropFace
     *
     * crops image horizontally using the detected face bounding box, keeping only the region below
     *
     * input: CGRect _rectangle_ (bounding box of face), CGImage _image_ (full body image)
     * output: CGImage _cgImage_ (cropped image with face removed)
     */
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
    
    /*
     * getPixelData
     *
     * extracts raw RGBA pixel data from CGImage and returns flat byte array
     *
     * input: CGImage _image_
     * output: [UInt8]? _pixelData_ (flattened RGBA values or nil on failure)
     */
    private func getPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
        }
        print(totalBytes)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        return pixelData
    }
    
    /*
     * convertRGBtoHSV
     *
     * converts RGB color values (0–255) into HSV representation
     *
     * input: Int _r_, Int _g_, Int _b_ (red, green, and blue values)
     * output: (h: Int, s: Int, v: Int) tuple representing hue (0–360), saturation (0–100), and value (0–100)
     */
    private func convertRGBtoHSV(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> (h: Int, s: Int, v: Int) {
        var r = Double(r) / 255.0
        var g = Double(g) / 255.0
        var b = Double(b) / 255.0
        
        var cMax = max(r,g,b)
        var cMin = min(r,g,b)
        var delta = cMax - cMin
        
        var hue: Double = 0
        var saturation: Double = 0
        var value: Double = cMax
        
        if delta == 0 {
            hue = 0
        } else if cMax == r {
            hue = (g - b) / delta
        } else if cMax == g {
            hue = 2.0 + (b - r) / delta
        } else if cMax == b {
            hue = 4.0 + (r - g) / delta
        }
        
        if cMax == 0 {
            saturation = 0
        } else {
            saturation = delta / cMax
        }
        
        hue *= 60
        if hue < 0 {
            hue += 360
        }
        
        return (h: Int(hue), s: Int(saturation * 100), v: Int(value * 100))
    }
}

    
