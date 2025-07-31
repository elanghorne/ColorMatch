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
        var finalImage: CGImage?
        if let cropped = croppedFaceImage{ // if face was cropped off (unwrap optional)
            analysisResult.pixelBuffer = self.getPixelData(from: cropped)// run data extraction on face cropped image
            finalImage = cropped
        } else {
            analysisResult.pixelBuffer = self.getPixelData(from: croppedBodyImage) // no face detected, run data extraction on original body crop
            finalImage = croppedBodyImage
        }
        
        var hsvArray: [Int] = [] // array for saturation/value testing
        if let buffer = analysisResult.pixelBuffer { // unwrap pixel buffer into local assignment
            print("Original image buffer:", Array(buffer[0..<400])) // testing
            
            for i in stride(from: 0, to: buffer.count - 3, by: 4){
                let r = buffer[i]
                let g = buffer[i+1]
                let b = buffer[i+2]
                
                let hsv = convertRGBtoHSV(r,g,b)
                // assignToBucket(pixel: hsv)
                hsvArray.append(hsv.0)
                hsvArray.append(hsv.1)
                hsvArray.append(hsv.2)
            }
            print("HSV array:", Array(hsvArray[0..<400]))
            var testingRGBAarray: [UInt8] = []
            for i in stride(from: 0, to: hsvArray.count - 2, by: 3){
                let h = hsvArray[i]
                let s = hsvArray[i+1]
                let v = hsvArray[i+2]
                
                let rgba = convertHSVtoRGBA(h,s,v)
                testingRGBAarray.append(rgba.0)
                testingRGBAarray.append(rgba.1)
                testingRGBAarray.append(rgba.2)
                testingRGBAarray.append(rgba.3)
            }
            var diffArray: [Int] = []

            for i in 0..<min(buffer.count, testingRGBAarray.count) {
                let original = Int(buffer[i])
                let reconstructed = Int(testingRGBAarray[i])
                let diff = reconstructed - original
                diffArray.append(diff)
            }

            // print(Array(diffArray[0..<1000]))
            if let finalImage = finalImage { // unwrap
                if let testImage = createImage(from: testingRGBAarray, width: finalImage.width, height: finalImage.height){
                    analysisResult.debugImage = UIImage(cgImage: testImage)
                }
                
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
        let r = Double(r) / 255.0
        let g = Double(g) / 255.0
        let b = Double(b) / 255.0
        
        let cMax = max(r,g,b)
        let cMin = min(r,g,b)
        let delta = cMax - cMin
        
        var hue: Double = 0
        var saturation: Double = 0
        let value: Double = cMax
        
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
    
    private func convertHSVtoRGBA(_ h: Int, _ s: Int, _ v: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8){
        let s = Double(s) / 100.0
        let v = Double(v) / 100.0
        let hPrime = Double(h) / 60.0
        let c = v * s
        let m = v - c
        let x = c * (1 - abs(hPrime.truncatingRemainder(dividingBy: 2.0) - 1))
        var r1: Double, g1: Double, b1: Double
        
        switch Int(hPrime) {
        case 0..<1:
            r1 = c
            g1 = x
            b1 = 0
        case 1..<2:
            r1 = x
            g1 = c
            b1 = 0
        case 2..<3:
            r1 = 0
            g1 = c
            b1 = x
        case 3..<4:
            r1 = 0
            g1 = x
            b1 = c
        case 4..<5:
            r1 = x
            g1 = 0
            b1 = c
        default:
            r1 = c
            g1 = 0
            b1 = x
        }
        let r = UInt8(clamping: Int((r1 + m) * 255))
        let g = UInt8(clamping: Int((g1 + m) * 255))
        let b = UInt8(clamping: Int((b1 + m) * 255))
        let a = UInt8(255)
        
        return ((r: r, g: g, b: b, a: a))
    }
    
    private func createImage(from pixelData: [UInt8], width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        let dataProvider = CGDataProvider(data: Data(pixelData) as CFData)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        
        let newImage = CGImage(
                            width: width,
                            height: height,
                            bitsPerComponent: 8,
                            bitsPerPixel: 32,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue),
                            provider: dataProvider!,
                            decode: nil,
                            shouldInterpolate: false,
                            intent: .defaultIntent
        )
        return newImage
    }
    
    private func assignToBucket(pixel: (h: Int, s: Int, v: Int)) {
        
    }
}

    
