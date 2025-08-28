//
//  AnalysisEngine.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/1/25.
//

import Foundation
import PhotosUI
import Vision
import SwiftUI

struct AnalysisEngine {
    func runAnalysis(on image: UIImage, isWorn: Bool) async -> OutfitAnalysisResult {
        var darkBlueArray: [(Int, Int, Int)] = [] // TESTING
        var buckets: [ColorBucket] = []
        var analysisResult = OutfitAnalysisResult() // create instance of OutfitAnalysisResult structure
        var bodyBox: CGRect
        // var faceBox: CGRect?
        var croppedBodyImage: CGImage
        var croppedFaceImage: CGImage?
        var finalImage: CGImage?

        #if DEBUG
        print("Initial orientation: \(image.imageOrientation)") // debug
        #endif

        let orientedImage = image.normalized()
        guard let cgImage = orientedImage.cgImage else { // convert UIImage to CGImage for analysis
            analysisResult.feedbackMessage = AnalysisError.imageConversionFailed.localizedDescription
            return analysisResult
        }

        if isWorn {
            do {
                bodyBox = try await self.detectBody(in: cgImage)
                #if DEBUG
                print("Bounding box detected: \(bodyBox)")
                // analysisResult.feedbackMessage = "Human detected!"
                #endif
            } catch let error as AnalysisError {
                analysisResult.feedbackMessage = error.localizedDescription
                return analysisResult
            } catch {
                analysisResult.feedbackMessage = AnalysisError.unknown.localizedDescription
                return analysisResult
            }
            do {
                croppedBodyImage = try self.cropBody(in: cgImage, to: bodyBox)
                #if DEBUG
                // for visualizing the body crop during debug:
                // let debugImage = UIImage(cgImage: croppedBodyImage)
                // analysisResult.debugImage = debugImage
                #endif
            } catch {
                analysisResult.feedbackMessage = error.localizedDescription
                return analysisResult
            }
            do {
                if let faceBox = try await self.detectFace(in: croppedBodyImage) { // run face detection on body cropped image
                    #if DEBUG
                    print("Face bounding box detected: \(faceBox)")
                    #endif
                    croppedFaceImage = try self.cropFace(faceBox, outOf: croppedBodyImage) // run face/head crop
                    #if DEBUG
                    // analysisResult.debugImage = UIImage(cgImage: croppedFaceImage)
                    #endif
                }
            } catch {
                analysisResult.feedbackMessage = error.localizedDescription
                return analysisResult
            }
            if let cropped = croppedFaceImage { // if face was cropped off (unwrap optional)
                analysisResult.pixelBuffer = self.getPixelData(from: cropped) // run data extraction on face cropped image
                finalImage = cropped
            } else {
                analysisResult.pixelBuffer = self.getPixelData(from: croppedBodyImage) // no face detected, run data extraction on original body crop
                finalImage = croppedBodyImage
            }
        } else {
            analysisResult.pixelBuffer = self.getPixelData(from: cgImage)
            finalImage = cgImage
        }

        #if DEBUG
        var hsvArray: [Int] = [] // array for saturation/value testing
        #endif

        if let buffer = analysisResult.pixelBuffer { // unwrap pixel buffer into local assignment
            #if DEBUG
            // print("Original image buffer:", Array(buffer[0..<400])) // testing
            #endif

            for i in stride(from: 0, to: buffer.count, by: 4) {
                let r = buffer[i]
                let g = buffer[i+1]
                let b = buffer[i+2]

                var hsv = convertRGBtoHSV(r, g, b) // 3 element tuple of a single pixel's hsv values
                assignToBucket(pixel: &hsv, buckets: &buckets, testingArray: &darkBlueArray)

                #if DEBUG
                hsvArray.append(hsv.0)
                hsvArray.append(hsv.1)
                hsvArray.append(hsv.2)
                #endif
            }

            // calculate percentage of total image for each bucket
            let totalPixels = buffer.count / 4
            for i in buckets.indices {
                buckets[i].percentage = Double(buckets[i].count) / Double(totalPixels) * 100.0
            }

            // sort bucket array smallest - largest
            buckets.sort(by: { $0.count < $1.count } )
            var hueArray: [UInt16] = []
            var valueArray: [UInt16] = []
            for i in 0..<buckets.count {
                for pixel in buckets[i].pixels {
                    hueArray.append(UInt16(pixel.0))
                    valueArray.append(UInt16(pixel.2))
                }
                let (hueStdDev, meanHue) = calculateStdDevAndMean(of: hueArray)
                buckets[i].hueStdDev = hueStdDev
                buckets[i].meanHue = meanHue
                let (valueStdDev, meanValue) = calculateStdDevAndMean(of: valueArray)
                buckets[i].valueStdDev = valueStdDev
                buckets[i].meanValue = meanValue
            }
            combineAdjacentBuckets(in: &buckets)
            determineHarmony(from: &buckets, storeIn: &analysisResult)
            if let isMatch = analysisResult.isMatch {
                if isMatch {
                    analysisResult.feedbackMessage = "You match!"
                } else {
                    analysisResult.feedbackMessage = "You don't match."
                }
            }

            #if DEBUG
            print("Buckets after trimming:\n", buckets)
            print("Bucket count: \(buckets.count)")
            #endif

            #if DEBUG
            // testing hsv to rgb conversion to confirm accuracy in image
            var testingRGBAarray: [UInt8] = []
            for i in stride(from: 0, to: hsvArray.count, by: 3) {
                let h = hsvArray[i]
                let s = hsvArray[i+1]
                let v = hsvArray[i+2]

                let rgba = convertHSVtoRGBA(h, s, v)
                testingRGBAarray.append(rgba.0)
                testingRGBAarray.append(rgba.1)
                testingRGBAarray.append(rgba.2)
                testingRGBAarray.append(rgba.3)
            }

            // showing difference between new and original rgba values for debugging
            var diffArray: [Int] = []
            for i in 0..<min(buffer.count, testingRGBAarray.count) {
                let original = Int(buffer[i])
                let reconstructed = Int(testingRGBAarray[i])
                let diff = reconstructed - original
                diffArray.append(diff)
            }
            // print(Array(diffArray[0..<1000]))

            // create and store altered image in analysisResult for debugging (blackout/color testing)
            if let finalImage = finalImage {
                if let testImage = createImage(from: testingRGBAarray, width: finalImage.width, height: finalImage.height) {
                    // analysisResult.debugImage = UIImage(cgImage: testImage)
                }
            }
            #endif
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
        //print("Converted CGRect: \(convertedRect)")
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
        // print("Converted CGRect: \(convertedRect)")
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
    
    /*
     * convertHSVtoRGBA
     *
     * converts HSV color values into RGBA representation (normalized 0–255)
     *
     * input: Int _h_, _s_, _v_ (hue in degrees, saturation/value as percentages)
     * output: (r: UInt8, g: UInt8, b: UInt8, a: UInt8) tuple representing final color in RGBA format
     *
     * note: assumes output alpha is always 255 (fully opaque)
     */
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
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
        return newImage
    }
    
    private func getBucketLabel(from h: Int, and s: Int, and v: Int) -> (Int, String) {
        if (s <= 5) || (s <= 15 && v <= 20) || (h >= 0 && h <= 45 && s <= 15) {
            return (0, "Neutral") // gray
        } else if h >= 0 && h <= 45 && s > 10 && s <= 70 && v >= 20 && v <= 90 {
            return (0, "Neutral") // tans/browns
        } else {
            switch h {
                
            case 0..<30:
                return (1, "Red")
            case 30..<60:
                return (2, "Orange")
            case 60..<90:
                return (3, "Yellow")
            case 90..<120:
                return (4, "Yellow-green")
            case 120..<150:
                return (5, "Green")
            case 150..<180:
                return (6, "Cyan-green")
            case 180..<210:
                return (7, "Cyan")
            case 210..<240:
                return (8, "Blue")
            case 240..<270:
                return (9, "Indigo")
            case 270..<300:
                return (10, "Violet")
            case 300..<330:
                return (11, "Magenta")
            default:
                return (12, "Red-magenta")
            }
        }
        
    }
    
    private func getShadeLevel(from v: Int) -> ShadeLevel {
        switch v {
            
        case 20..<40:
            return .dark
        case 40..<55:
            return .medium
        case 55..<101:
            return .light
        default:
            return .neutral
        }
    }
    
    
    private func assignToBucket(pixel: inout (h: Int, s: Int, v: Int), buckets: inout [ColorBucket], testingArray: inout [(Int, Int, Int)]){
        let label = getBucketLabel(from: pixel.h, and: pixel.s, and: pixel.v)
        let shade = getShadeLevel(from: pixel.v)
        #if DEBUG
        // debugging array
        if label == (8, "Blue") && shade == .dark {
            testingArray.append((pixel.h, pixel.s, pixel.v))
        }
        #endif
        // this ensures there is only 1 neutral bucket
        if label == (0, "Neutral") || shade == .neutral {
           // pixel.v = 0
            if let i = buckets.firstIndex(where: { $0.label == (0, "Neutral") || $0.shade == .neutral } ) {
                buckets[i].count += 1
                buckets[i].pixels.append( (pixel.h, pixel.s, pixel.v) )
            } else {
                buckets.append( ColorBucket(label: (0, "Neutral"), shade: .neutral, count: 1, pixels: [(pixel.h, pixel.s, pixel.v)]) )
            }
            return
        }
        // bucket assignment/creation for non-neutrals
        if let i = buckets.firstIndex(where: {$0.label == label && $0.shade == shade} ) {
            buckets[i].count += 1
            buckets[i].pixels.append( (pixel.h, pixel.s, pixel.v) )
        } else {
            buckets.append( ColorBucket(label: label, shade: shade, count: 1, pixels: [(pixel.h, pixel.s, pixel.v)]) )
        }
        // pixel edits for debugging/troubleshooting
        if label.1 == "Orange" && shade == .light {
            pixel.h = 250 // blue
            pixel.s = 100
            pixel.v = 100
        } else if label.1 == "Red" && shade == .dark {
            pixel.h = 0 // red
            pixel.s = 100
            pixel.v = 100
        } else if label.1 == "Red" && shade == .medium {
            pixel.h = 70 // yellow
            pixel.s = 100
            pixel.v = 100
        } //else if label == "Red-magenta" && shade == .light {
        
    }
    
    
    private func determineHarmony(from buckets: inout [ColorBucket], storeIn analysisResult: inout OutfitAnalysisResult) {
        // remove low percentage buckets (noise)
        for i in stride(from: buckets.count - 1, through: 0, by: -1) {
            if buckets[i].percentage <= 5 {
                buckets.remove(at: i)
            }
        }
        
        if buckets.count == 1 { // 1 dominant color
            analysisResult.isMatch = true // automatic match
        } else if buckets.count == 2 { // 2 dominant colors
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" {
                analysisResult.isMatch = true // auto match if 1 bucket is neutral
            } else {
                analysisResult.isMatch = twoBucketAnalysis(on: buckets) // run 2 color harmony analysis
            }
        } else if buckets.count == 3 { // 3 dominant colors
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" || buckets[2].label.1 == "Neutral" {
                removeNeutral(from: &buckets)
                analysisResult.isMatch = twoBucketAnalysis(on: buckets) // run 2bucket if there's a neutral
            } else {
                analysisResult.isMatch = threeBucketAnalysis(on: buckets) // run 3bucket if no neutral
            }
        } else if buckets.count == 4 {
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" || buckets[2].label.1 == "Neutral" || buckets[3].label.1 == "Neutral" {
                removeNeutral(from: &buckets)
                analysisResult.isMatch = threeBucketAnalysis(on: buckets)
            } else {
                analysisResult.isMatch = false
            }
        } else {
            analysisResult.isMatch = false
        }
        
    }
    
    private func removeNeutral(from buckets: inout [ColorBucket]) {
        for i in 0..<buckets.count {
            if buckets[i].label.1 == "Neutral"{
                buckets.remove(at: i)
                return
            }
        }
    }
    
    private func twoBucketAnalysis(on buckets: [ColorBucket]) -> Bool {
        #if DEBUG
        print("Running 2 bucket...")
        #endif
        let bucket1 = buckets[0]
        let bucket2 = buckets[1]
        
        var h1array: [UInt16] = []
        var s1array: [UInt16] = []
        var v1array: [UInt16] = []
        for pixel in bucket1.pixels {
            h1array.append(UInt16(pixel.0))
            s1array.append(UInt16(pixel.1))
            v1array.append(UInt16(pixel.2))
        }
        let h1max = h1array.max()!
        let h1min = h1array.min()!
        let (hue1StdDev, hue1Mean) = calculateStdDevAndMean(of: h1array)
        
        let sat1max = s1array.max()!
        let sat1min = s1array.min()!
        let (sat1StdDev, sat1Mean) = calculateStdDevAndMean(of: s1array)
        
        let value1max = v1array.max()!
        let value1min = v1array.min()!
        let (value1StdDev, value1Mean) = calculateStdDevAndMean(of: v1array)
        #if DEBUG
        print("BUCKET 1")
        print("\t    Hue:\tSaturation:\tValue:")
        print("Max:     \(h1max)\t\t\(sat1max)\t\t\t\(value1max)")
        print("Min:     \(h1min)\t\t\(sat1min)\t\t\t\(value1min)")
        print("StdDev: \(String(format: "%.2f", hue1StdDev))\t\t\(String(format: "%.2f", sat1StdDev))\t\t\(String(format: "%.2f", value1StdDev))")
        print("Mean: \(String(format: "%.2f", hue1Mean))\t\t\(String(format: "%.2f", sat1Mean))\t\t\(String(format: "%.2f", value1Mean))")
        #endif
        var h2array: [UInt16] = []
        var s2array: [UInt16] = []
        var v2array: [UInt16] = []
        for pixel in bucket2.pixels {
            h2array.append(UInt16(pixel.0))
            s2array.append(UInt16(pixel.1))
            v2array.append(UInt16(pixel.2))
        }
        let h2max = h2array.max()!
        let h2min = h2array.min()!
        let (hue2StdDev, hue2Mean) = calculateStdDevAndMean(of: h2array)
        
        let sat2max = s2array.max()!
        let sat2min = s2array.min()!
        let (sat2StdDev, sat2Mean) = calculateStdDevAndMean(of: s2array)
        
        let value2max = v2array.max()!
        let value2min = v2array.min()!
        let (value2StdDev, value2Mean) = calculateStdDevAndMean(of: v2array)
        #if DEBUG
        print("BUCKET 2")
        print("\t    Hue:\tSaturation:\tValue:")
        print("Max:     \(h2max)\t\t\(sat2max)\t\t\t\(value2max)")
        print("Min:     \(h2min)\t\t\(sat2min)\t\t\t\(value2min)")
        print("StdDev: \(String(format: "%.2f", hue2StdDev))\t\t\(String(format: "%.2f", sat2StdDev))\t\t\(String(format: "%.2f", value2StdDev))")
        print("Mean: \(String(format: "%.2f", hue2Mean))\t\t\(String(format: "%.2f", sat2Mean))\t\t\(String(format: "%.2f", value2Mean))")
        #endif
        if isComplementary(hue1Mean, hue2Mean) || isAnalogous(hue1Mean, hue2Mean) {
            return true
        } else {
            return false
        }
    }
    
    private func threeBucketAnalysis(on buckets: [ColorBucket]) -> Bool {
        #if DEBUG
        print("Running 3 bucket...")
        #endif
        let bucket1 = buckets[0]
        let bucket2 = buckets[1]
        let bucket3 = buckets[2]
        
        var h1array: [UInt16] = []
        var s1array: [UInt16] = []
        var v1array: [UInt16] = []
        for pixel in bucket1.pixels {
            h1array.append(UInt16(pixel.0))
            s1array.append(UInt16(pixel.1))
            v1array.append(UInt16(pixel.2))
        }
        let h1max = h1array.max()!
        let h1min = h1array.min()!
        let (hue1StdDev, hue1Mean) = calculateStdDevAndMean(of: h1array)
        
        let sat1max = s1array.max()!
        let sat1min = s1array.min()!
        let (sat1StdDev, sat1Mean) = calculateStdDevAndMean(of: s1array)
        
        let value1max = v1array.max()!
        let value1min = v1array.min()!
        let (value1StdDev, value1Mean) = calculateStdDevAndMean(of: v1array)
        #if DEBUG
        print("BUCKET 1")
        print("\t    Hue:\tSaturation:\tValue:")
        print("Max:     \(h1max)\t\t\(sat1max)\t\t\t\(value1max)")
        print("Min:     \(h1min)\t\t\(sat1min)\t\t\t\(value1min)")
        print("StdDev: \(String(format: "%.2f", hue1StdDev))\t\t\(String(format: "%.2f", sat1StdDev))\t\t\(String(format: "%.2f", value1StdDev))")
        print("Mean: \(String(format: "%.2f", hue1Mean))\t\t\(String(format: "%.2f", sat1Mean))\t\t\(String(format: "%.2f", value1Mean))")
        #endif
        var h2array: [UInt16] = []
        var s2array: [UInt16] = []
        var v2array: [UInt16] = []
        for pixel in bucket2.pixels {
            h2array.append(UInt16(pixel.0))
            s2array.append(UInt16(pixel.1))
            v2array.append(UInt16(pixel.2))
        }
        let h2max = h2array.max()!
        let h2min = h2array.min()!
        let (hue2StdDev, hue2Mean) = calculateStdDevAndMean(of: h2array)
        
        let sat2max = s2array.max()!
        let sat2min = s2array.min()!
        let (sat2StdDev, sat2Mean) = calculateStdDevAndMean(of: s2array)
        
        let value2max = v2array.max()!
        let value2min = v2array.min()!
        let (value2StdDev, value2Mean) = calculateStdDevAndMean(of: v2array)
        #if DEBUG
        print("BUCKET 2")
        print("\t    Hue:\tSaturation:\tValue:")
        print("Max:     \(h2max)\t\t\(sat2max)\t\t\t\(value2max)")
        print("Min:     \(h2min)\t\t\(sat2min)\t\t\t\(value2min)")
        print("StdDev: \(String(format: "%.2f", hue2StdDev))\t\t\(String(format: "%.2f", sat2StdDev))\t\t\(String(format: "%.2f", value2StdDev))")
        print("Mean: \(String(format: "%.2f", hue2Mean))\t\t\(String(format: "%.2f", sat2Mean))\t\t\(String(format: "%.2f", value2Mean))")
        #endif
        var h3array: [UInt16] = []
        var s3array: [UInt16] = []
        var v3array: [UInt16] = []
        for pixel in bucket3.pixels {
            h3array.append(UInt16(pixel.0))
            s3array.append(UInt16(pixel.1))
            v3array.append(UInt16(pixel.2))
        }
        
        let h3max = h3array.max()!
        let h3min = h3array.min()!
        let (hue3StdDev, hue3Mean) = calculateStdDevAndMean(of: h3array)
        
        let sat3max = s3array.max()!
        let sat3min = s3array.min()!
        let (sat3StdDev, sat3Mean) = calculateStdDevAndMean(of: s3array)
        
        let value3max = v3array.max()!
        let value3min = v3array.min()!
        let (value3StdDev, value3Mean) = calculateStdDevAndMean(of: v3array)
        #if DEBUG
        print("BUCKET 3")
        print("\t    Hue:\tSaturation:\tValue:")
        print("Max:     \(h3max)\t\t\(sat3max)\t\t\t\(value3max)")
        print("Min:     \(h3min)\t\t\(sat3min)\t\t\t\(value3min)")
        print("StdDev: \(String(format: "%.2f", hue3StdDev))\t\t\(String(format: "%.2f", sat3StdDev))\t\t\(String(format: "%.2f", value3StdDev))")
        print("Mean: \(String(format: "%.2f", hue3Mean))\t\t\(String(format: "%.2f", sat3Mean))\t\t\(String(format: "%.2f", value3Mean))")
        #endif
        if isAnalogous(hue1Mean, hue2Mean, hue3Mean) || isTriadic(hue1Mean, hue2Mean, hue3Mean) || isSplitComplementary(hue1Mean, hue2Mean, hue3Mean) {
            return true
        } else {
            return false
        }
    }
    
    private func calculateStdDevAndMean(of values: [UInt16]) -> (Double, Int) {
        let N: Double = Double(values.count)
        let mean = values.map { Double($0) }.reduce(0,+) / N
        
        let stdDev = sqrt(values.map { pow( (Double($0) - mean), 2) }.reduce(0,+) / N)
        
        return (stdDev, Int(mean.rounded()))
    }
    
    private func angleDifference(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b)
        return min(diff, 360 - diff)
    }
    
    private func isComplementary(_ hueA: Int, _ hueB: Int) -> Bool {
        let diff = angleDifference(hueA, hueB)
        
        if diff >= 175 && diff <= 185 {
            return true
        } else {
            return false
        }
    }
    
    private func isAnalogous(_ hueA: Int, _ hueB: Int) -> Bool {
        let diff = angleDifference(hueA, hueB)
        
        if diff >= 35 {
            return true
        } else {
            return false
        }
    }
    private func isAnalogous(_ hueA: Int, _ hueB: Int, _ hueC: Int) -> Bool {
        let maxHue = max(hueA, hueB, hueC)
        let minHue = min(hueA, hueB, hueC)
        let diff = angleDifference(maxHue, minHue)
        
        if diff <= 65 {
            return true
        } else {
            return false
        }
    }
    private func isTriadic(_ hueA: Int, _ hueB: Int, _ hueC: Int) -> Bool {
        let hues = [hueA, hueB, hueC].sorted()
        
        let diff1 = angleDifference(hues[0], hues[1])
        let diff2 = angleDifference(hues[1], hues[2])
        let diff3 = angleDifference(hues[2], hues[0])
        
        return [diff1, diff2, diff3].allSatisfy { $0 >= 110 && $0 <= 130 }
    }
    private func isSplitComplementary(_ hueA: Int, _ hueB: Int, _ hueC: Int) -> Bool {
        let hues = [hueA, hueB, hueC]
        
        for i in 0..<3 {
            let base = hues[i]
            let comp1 = hues[(i + 1) % 3]
            let comp2 = hues[(i + 2) % 3]
            
            let diff1 = angleDifference(base, comp1)
            let diff2 = angleDifference(base, comp2)
            let betweenComplementaries = angleDifference(comp1, comp2)
            
            let baseOpposite = (diff1 >= 150 && diff1 <= 210) && (diff2 >= 150 && diff2 <= 210)
            
            let areAnalogous = betweenComplementaries <= 60
            
            if baseOpposite && areAnalogous {
                return true
            }
        }
        
        return false
    }
    /*
     either pass in buckets separately or pass in entire array and loop through to determine if any are adjacent
     latter is probably better (will have to pass by reference and condense buckets within function. returns nothing. either combines buckets or exits having done nothing)
     may need to be combined with isAdjacent (run inside the loop within)
     */
    private func isAdjacentHue(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
        if abs( (bucket1.label.0 % 12) - (bucket2.label.0 % 12) ) == 1 {
            return true
        }
        return false
    }
    
    private func isAdjacentShade(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
        if abs(bucket1.shade.value - bucket2.shade.value) == 1 && bucket1.label.0 == bucket2.label.0 {
            return true
        }
        return false
    }

    private func combineAdjacentBuckets(in buckets: inout [ColorBucket]) {
        var potentialAdjacentHues: Bool = true
        while potentialAdjacentHues {
            for i in 0..<buckets.count {
                if isAdjacentHue(buckets[i], buckets[(i+1) % buckets.count]){
                    if (buckets[i].hueStdDev < 5.0) && (buckets[(i+1) % buckets.count].hueStdDev < 5.0) {
                        buckets[i].count += buckets[(i+1) % buckets.count].count
                        buckets[i].meanHue = (buckets[i].meanHue + buckets[(i+1) % buckets.count].meanHue) / 2
                        buckets.remove(at: (i+1) % buckets.count)
                        break
                    }
                } else {
                    potentialAdjacentHues = false
                }
                
            }
        }
        var potentialAdjacentShades: Bool = true
        while potentialAdjacentShades {
            for i in 0..<buckets.count {
                if isAdjacentShade(buckets[i], buckets[(i+1) % buckets.count]){
                    if abs(buckets[i].meanValue - buckets[(i+1) % buckets.count].meanValue) < 10 {
                        buckets[i].count += buckets[(i+1) % buckets.count].count
                        buckets[i].meanHue = (buckets[i].meanHue + buckets[(i+1) % buckets.count].meanHue) / 2
                        buckets.remove(at: (i+1) % buckets.count)
                        break
                    }
                } else {
                    potentialAdjacentShades = false
                }
            }
        }
    }
}

