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
        var buckets: [ColorBucket] = []
        var analysisResult = OutfitAnalysisResult()
        var bodyBox: CGRect
        var croppedBodyImage: CGImage
        var croppedFaceImage: CGImage?

        #if DEBUG
        print("Initial orientation: \(image.imageOrientation)")
        #endif

        let orientedImage = image.normalized()
        guard let cgImage = orientedImage.cgImage else {
            analysisResult.feedbackMessage = AnalysisError.imageConversionFailed.localizedDescription
            return analysisResult
        }

        if isWorn {
            do {
                bodyBox = try await self.detectBody(in: cgImage)
                #if DEBUG
                print("Bounding box detected: \(bodyBox)")
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
            } catch {
                analysisResult.feedbackMessage = error.localizedDescription
                return analysisResult
            }
            do {
                if let faceBox = try await self.detectFace(in: croppedBodyImage) {
                    #if DEBUG
                    print("Face bounding box detected: \(faceBox)")
                    #endif
                    croppedFaceImage = try self.cropFace(faceBox, outOf: croppedBodyImage)
                }
            } catch {
                analysisResult.feedbackMessage = error.localizedDescription
                return analysisResult
            }
            let sourceImage = croppedFaceImage ?? croppedBodyImage
            let downsampled = downsample(sourceImage)
            analysisResult.pixelBuffer = self.getPixelData(from: downsampled)
        } else {
            let downsampled = downsample(cgImage)
            analysisResult.pixelBuffer = self.getPixelData(from: downsampled)
        }

        if let buffer = analysisResult.pixelBuffer {
            for i in stride(from: 0, to: buffer.count, by: 4) {
                let r = buffer[i]
                let g = buffer[i+1]
                let b = buffer[i+2]
                let hsv = convertRGBtoHSV(r, g, b)
                assignToBucket(pixel: hsv, buckets: &buckets)
            }

            let totalPixels = buffer.count / 4
            for i in buckets.indices {
                buckets[i].percentage = Double(buckets[i].count) / Double(totalPixels) * 100.0
                buckets[i].meanHue = buckets[i].hueSum / buckets[i].count
                buckets[i].meanValue = buckets[i].valueSum / buckets[i].count
            }

            buckets.sort(by: { $0.count < $1.count })
            combineAdjacentBuckets(in: &buckets)
            determineHarmony(from: &buckets, storeIn: &analysisResult)

            if let isMatch = analysisResult.isMatch {
                analysisResult.feedbackMessage = isMatch ? "You match!" : "You don't match."
            }

            #if DEBUG
            print("Buckets after trimming:\n", buckets)
            print("Bucket count: \(buckets.count)")
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
     * cropBody
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
            try requestHandler.perform([faceDetectionRequest])
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
        guard let croppedImage = image.cropping(to: convertedRect) else {
            throw AnalysisError.failedCrop
        }
        return croppedImage
    }

    /*
     * downsample
     *
     * scales image down to a maximum dimension for faster pixel analysis
     *
     * input: CGImage _image_, Int _maxDimension_
     * output: CGImage (scaled image, or original if already small enough)
     */
    private func downsample(_ image: CGImage, maxDimension: Int = 400) -> CGImage {
        let width = image.width
        let height = image.height
        guard max(width, height) > maxDimension else { return image }

        let scale = Double(maxDimension) / Double(max(width, height))
        let newWidth = max(1, Int(Double(width) * scale))
        let newHeight = max(1, Int(Double(height) * scale))

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
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

        let cMax = max(r, g, b)
        let cMin = min(r, g, b)
        let delta = cMax - cMin

        var hue: Double = 0
        if delta > 0 {
            if cMax == r {
                hue = (g - b) / delta
            } else if cMax == g {
                hue = 2.0 + (b - r) / delta
            } else {
                hue = 4.0 + (r - g) / delta
            }
            hue *= 60
            if hue < 0 { hue += 360 }
        }

        let saturation = cMax == 0 ? 0.0 : delta / cMax

        return (h: Int(hue), s: Int(saturation * 100), v: Int(cMax * 100))
    }

    private func getBucketLabel(from h: Int, and s: Int, and v: Int) -> (Int, String) {
        if s <= 5 || (s <= 15 && v <= 20) || (h <= 45 && s <= 15) {
            return (0, "Neutral")
        } else if h <= 45 && s <= 70 && v >= 20 && v <= 90 {
            return (0, "Neutral") // tans/browns
        } else {
            switch h {
            case 0..<30:   return (1,  "Red")
            case 30..<60:  return (2,  "Orange")
            case 60..<90:  return (3,  "Yellow")
            case 90..<120: return (4,  "Yellow-green")
            case 120..<150:return (5,  "Green")
            case 150..<180:return (6,  "Cyan-green")
            case 180..<210:return (7,  "Cyan")
            case 210..<240:return (8,  "Blue")
            case 240..<270:return (9,  "Indigo")
            case 270..<300:return (10, "Violet")
            case 300..<330:return (11, "Magenta")
            default:       return (12, "Red-magenta")
            }
        }
    }

    private func getShadeLevel(from v: Int) -> ShadeLevel {
        switch v {
        case 20..<40:  return .dark
        case 40..<55:  return .medium
        case 55..<101: return .light
        default:       return .neutral
        }
    }

    private func assignToBucket(pixel: (h: Int, s: Int, v: Int), buckets: inout [ColorBucket]) {
        let label = getBucketLabel(from: pixel.h, and: pixel.s, and: pixel.v)
        let shade = getShadeLevel(from: pixel.v)
        let isNeutral = label == (0, "Neutral") || shade == .neutral

        if isNeutral {
            if let i = buckets.firstIndex(where: { $0.label == (0, "Neutral") }) {
                buckets[i].count += 1
                buckets[i].hueSum += pixel.h
                buckets[i].valueSum += pixel.v
            } else {
                buckets.append(ColorBucket(label: (0, "Neutral"), shade: .neutral, count: 1, hue: pixel.h, value: pixel.v))
            }
            return
        }

        if let i = buckets.firstIndex(where: { $0.label == label && $0.shade == shade }) {
            buckets[i].count += 1
            buckets[i].hueSum += pixel.h
            buckets[i].valueSum += pixel.v
        } else {
            buckets.append(ColorBucket(label: label, shade: shade, count: 1, hue: pixel.h, value: pixel.v))
        }
    }

    private func determineHarmony(from buckets: inout [ColorBucket], storeIn analysisResult: inout OutfitAnalysisResult) {
        for i in stride(from: buckets.count - 1, through: 0, by: -1) {
            if buckets[i].percentage <= 5 {
                buckets.remove(at: i)
            }
        }

        switch buckets.count {
        case 1:
            analysisResult.isMatch = true
        case 2:
            let hasNeutral = buckets.contains { $0.label.1 == "Neutral" }
            analysisResult.isMatch = hasNeutral ? true : twoBucketAnalysis(on: buckets)
        case 3:
            let hasNeutral = buckets.contains { $0.label.1 == "Neutral" }
            if hasNeutral {
                removeNeutral(from: &buckets)
                analysisResult.isMatch = twoBucketAnalysis(on: buckets)
            } else {
                analysisResult.isMatch = threeBucketAnalysis(on: buckets)
            }
        case 4:
            let hasNeutral = buckets.contains { $0.label.1 == "Neutral" }
            if hasNeutral {
                removeNeutral(from: &buckets)
                analysisResult.isMatch = threeBucketAnalysis(on: buckets)
            } else {
                analysisResult.isMatch = false
            }
        default:
            analysisResult.isMatch = false
        }
    }

    private func removeNeutral(from buckets: inout [ColorBucket]) {
        if let i = buckets.firstIndex(where: { $0.label.1 == "Neutral" }) {
            buckets.remove(at: i)
        }
    }

    private func twoBucketAnalysis(on buckets: [ColorBucket]) -> Bool {
        #if DEBUG
        print("Running 2 bucket... hues: \(buckets[0].meanHue), \(buckets[1].meanHue)")
        #endif
        let h1 = buckets[0].meanHue
        let h2 = buckets[1].meanHue
        return isAnalogous(h1, h2) || isComplementary(h1, h2)
    }

    private func threeBucketAnalysis(on buckets: [ColorBucket]) -> Bool {
        #if DEBUG
        print("Running 3 bucket... hues: \(buckets[0].meanHue), \(buckets[1].meanHue), \(buckets[2].meanHue)")
        #endif
        let h1 = buckets[0].meanHue
        let h2 = buckets[1].meanHue
        let h3 = buckets[2].meanHue
        return isAnalogous(h1, h2, h3) || isTriadic(h1, h2, h3) || isSplitComplementary(h1, h2, h3)
    }

    private func angleDifference(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b)
        return min(diff, 360 - diff)
    }

    private func isComplementary(_ hueA: Int, _ hueB: Int) -> Bool {
        let diff = angleDifference(hueA, hueB)
        return diff >= 150 && diff <= 210
    }

    // Two hues are analogous if they fall within 60° of each other on the color wheel
    private func isAnalogous(_ hueA: Int, _ hueB: Int) -> Bool {
        return angleDifference(hueA, hueB) <= 60
    }

    // Three hues are analogous if the minimum arc containing all three is ≤ 80°
    private func isAnalogous(_ hueA: Int, _ hueB: Int, _ hueC: Int) -> Bool {
        let sorted = [hueA, hueB, hueC].sorted()
        let gaps = [sorted[1] - sorted[0], sorted[2] - sorted[1], 360 - sorted[2] + sorted[0]]
        let maxGap = gaps.max()!
        return (360 - maxGap) <= 80
    }

    private func isTriadic(_ hueA: Int, _ hueB: Int, _ hueC: Int) -> Bool {
        let hues = [hueA, hueB, hueC].sorted()
        let diff1 = angleDifference(hues[0], hues[1])
        let diff2 = angleDifference(hues[1], hues[2])
        let diff3 = angleDifference(hues[2], hues[0])
        return [diff1, diff2, diff3].allSatisfy { $0 >= 100 && $0 <= 140 }
    }

    private func isSplitComplementary(_ hueA: Int, _ hueB: Int, _ hueC: Int) -> Bool {
        let hues = [hueA, hueB, hueC]
        for i in 0..<3 {
            let base = hues[i]
            let comp1 = hues[(i + 1) % 3]
            let comp2 = hues[(i + 2) % 3]
            let diff1 = angleDifference(base, comp1)
            let diff2 = angleDifference(base, comp2)
            let betweenComps = angleDifference(comp1, comp2)
            // comp1 and comp2 should be near-opposite the base (150–210°) and close to each other (≤ 60°)
            if diff1 >= 150 && diff1 <= 210 && diff2 >= 150 && diff2 <= 210 && betweenComps <= 60 {
                return true
            }
        }
        return false
    }

    private func isAdjacentHue(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
        return abs((bucket1.label.0 % 12) - (bucket2.label.0 % 12)) == 1
    }

    private func isAdjacentShade(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
        return bucket1.label.0 == bucket2.label.0 && abs(bucket1.shade.value - bucket2.shade.value) == 1
    }

    private func combineAdjacentBuckets(in buckets: inout [ColorBucket]) {
        // Merge buckets in the same hue family that are adjacent on the color wheel
        var merged = true
        while merged {
            merged = false
            for i in 0..<buckets.count - 1 {
                if isAdjacentHue(buckets[i], buckets[i + 1]) {
                    buckets[i].count += buckets[i + 1].count
                    buckets[i].meanHue = (buckets[i].meanHue + buckets[i + 1].meanHue) / 2
                    buckets[i].meanValue = (buckets[i].meanValue + buckets[i + 1].meanValue) / 2
                    buckets.remove(at: i + 1)
                    merged = true
                    break
                }
            }
        }

        // Merge buckets with the same hue label that differ only by shade
        merged = true
        while merged {
            merged = false
            for i in 0..<buckets.count - 1 {
                if isAdjacentShade(buckets[i], buckets[i + 1]) {
                    buckets[i].count += buckets[i + 1].count
                    buckets[i].meanHue = (buckets[i].meanHue + buckets[i + 1].meanHue) / 2
                    buckets[i].meanValue = (buckets[i].meanValue + buckets[i + 1].meanValue) / 2
                    buckets.remove(at: i + 1)
                    merged = true
                    break
                }
            }
        }
    }
}
