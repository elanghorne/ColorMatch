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

        let orientedImage = image.normalized()
        guard let cgImage = orientedImage.cgImage else {
            analysisResult.feedbackMessage = AnalysisError.imageConversionFailed.localizedDescription
            return analysisResult
        }

        if isWorn {
            do {
                bodyBox = try await self.detectBody(in: cgImage)
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
                    croppedFaceImage = try self.cropFace(faceBox, outOf: croppedBodyImage)
                }
            } catch {
                analysisResult.feedbackMessage = error.localizedDescription
                return analysisResult
            }
            if let cropped = croppedFaceImage {
                analysisResult.pixelBuffer = self.getPixelData(from: cropped)
            } else {
                analysisResult.pixelBuffer = self.getPixelData(from: croppedBodyImage)
            }
        } else {
            analysisResult.pixelBuffer = self.getPixelData(from: cgImage)
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
            }

            buckets.sort(by: { $0.count < $1.count })
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
            determineHarmony(from: &buckets, storeResultsIn: &analysisResult)
            if let isMatch = analysisResult.isMatch {
                analysisResult.feedbackMessage = isMatch ? "You match!" : "You don't match."
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
    private func detectBody(in image: CGImage) async throws -> CGRect {
        let bodyDetectionRequest = VNDetectHumanRectanglesRequest()
        bodyDetectionRequest.upperBodyOnly = false
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try requestHandler.perform([bodyDetectionRequest])
        } catch {
            throw AnalysisError.bodyDetectionRequest
        }
        guard let observation = bodyDetectionRequest.results, !observation.isEmpty else {
            throw AnalysisError.noHumanFound
        }
        if observation.count > 1 {
            throw AnalysisError.multipleHumansFound
        }
        return observation[0].boundingBox
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
        let convertedRect = CGRect(
            x: width * rectangle.origin.x,
            y: height * (1 - rectangle.origin.y - rectangle.height),
            width: width * rectangle.width,
            height: height * rectangle.height
        )
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
        let convertedRect = CGRect(
            x: 0,
            y: height * (1 - rectangle.origin.y),
            width: width,
            height: height - (height * rectangle.height)
        )
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
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }

    /*
     * convertRGBtoHSV
     *
     * converts RGB color values (0–255) into HSV representation
     *
     * input: UInt8 _r_, _g_, _b_ (red, green, and blue values)
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
        if hue < 0 { hue += 360 }

        return (h: Int(hue), s: Int(saturation * 100), v: Int(value * 100))
    }

    private func getBucketLabel(from h: Int, and s: Int, and v: Int) -> (Int, String) {
        if (s <= 5) || (s <= 15 && v <= 20) || (h >= 0 && h <= 45 && s <= 15) {
            return (0, "Neutral")
        } else if h >= 0 && h <= 45 && s > 10 && s <= 70 && v >= 20 && v <= 90 {
            return (0, "Neutral")
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

        if label == (0, "Neutral") || shade == .neutral {
            if let i = buckets.firstIndex(where: { $0.label == (0, "Neutral") || $0.shade == .neutral }) {
                buckets[i].count += 1
                buckets[i].pixels.append((pixel.h, pixel.s, pixel.v))
            } else {
                buckets.append(ColorBucket(label: (0, "Neutral"), shade: .neutral, count: 1, pixels: [(pixel.h, pixel.s, pixel.v)]))
            }
            return
        }

        if let i = buckets.firstIndex(where: { $0.label == label && $0.shade == shade }) {
            buckets[i].count += 1
            buckets[i].pixels.append((pixel.h, pixel.s, pixel.v))
        } else {
            buckets.append(ColorBucket(label: label, shade: shade, count: 1, pixels: [(pixel.h, pixel.s, pixel.v)]))
        }
    }

    private func determineHarmony(from buckets: inout [ColorBucket], storeResultsIn analysisResult: inout OutfitAnalysisResult) {
        for i in stride(from: buckets.count - 1, through: 0, by: -1) {
            if buckets[i].percentage <= 5 {
                buckets.remove(at: i)
            }
        }

        if buckets.count == 1 {
            analysisResult.isMatch = true
        } else if buckets.count == 2 {
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" {
                analysisResult.isMatch = true
            } else {
                analysisResult.isMatch = twoBucketAnalysis(on: buckets)
            }
        } else if buckets.count == 3 {
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" || buckets[2].label.1 == "Neutral" {
                removeNeutral(from: &buckets)
                analysisResult.isMatch = twoBucketAnalysis(on: buckets)
            } else {
                analysisResult.isMatch = threeBucketAnalysis(on: buckets)
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
            if buckets[i].label.1 == "Neutral" {
                buckets.remove(at: i)
                return
            }
        }
    }

    private func twoBucketAnalysis(on buckets: [ColorBucket]) -> Bool {
        let bucket1 = buckets[0]
        let bucket2 = buckets[1]

        let h1array = bucket1.pixels.map { UInt16($0.0) }
        let h2array = bucket2.pixels.map { UInt16($0.0) }

        let (_, hue1Mean) = calculateStdDevAndMean(of: h1array)
        let (_, hue2Mean) = calculateStdDevAndMean(of: h2array)

        return isComplementary(hue1Mean, hue2Mean) || isAnalogous(hue1Mean, hue2Mean)
    }

    private func threeBucketAnalysis(on buckets: [ColorBucket]) -> Bool {
        let bucket1 = buckets[0]
        let bucket2 = buckets[1]
        let bucket3 = buckets[2]

        let h1array = bucket1.pixels.map { UInt16($0.0) }
        let h2array = bucket2.pixels.map { UInt16($0.0) }
        let h3array = bucket3.pixels.map { UInt16($0.0) }

        let (_, hue1Mean) = calculateStdDevAndMean(of: h1array)
        let (_, hue2Mean) = calculateStdDevAndMean(of: h2array)
        let (_, hue3Mean) = calculateStdDevAndMean(of: h3array)

        return isAnalogous(hue1Mean, hue2Mean, hue3Mean)
            || isTriadic(hue1Mean, hue2Mean, hue3Mean)
            || isSplitComplementary(hue1Mean, hue2Mean, hue3Mean)
    }

    private func calculateStdDevAndMean(of values: [UInt16]) -> (Double, Int) {
        let N = Double(values.count)
        let mean = values.map { Double($0) }.reduce(0, +) / N
        let stdDev = sqrt(values.map { pow(Double($0) - mean, 2) }.reduce(0, +) / N)
        return (stdDev, Int(mean.rounded()))
    }

    private func angleDifference(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b)
        return min(diff, 360 - diff)
    }

    private func isComplementary(_ hueA: Int, _ hueB: Int) -> Bool {
        let diff = angleDifference(hueA, hueB)
        return diff >= 175 && diff <= 185
    }

    private func isAnalogous(_ hueA: Int, _ hueB: Int) -> Bool {
        return angleDifference(hueA, hueB) >= 35
    }

    private func isAnalogous(_ hueA: Int, _ hueB: Int, _ hueC: Int) -> Bool {
        let diff = angleDifference(max(hueA, hueB, hueC), min(hueA, hueB, hueC))
        return diff <= 65
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
            if baseOpposite && betweenComplementaries <= 60 {
                return true
            }
        }
        return false
    }

    private func isAdjacentHue(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
        return abs((bucket1.label.0 % 12) - (bucket2.label.0 % 12)) == 1
    }

    private func isAdjacentShade(_ bucket1: ColorBucket, _ bucket2: ColorBucket) -> Bool {
        return abs(bucket1.shade.value - bucket2.shade.value) == 1 && bucket1.label.0 == bucket2.label.0
    }

    private func combineAdjacentBuckets(in buckets: inout [ColorBucket]) {
        var potentialAdjacentHues = true
        while potentialAdjacentHues {
            for i in 0..<buckets.count {
                if isAdjacentHue(buckets[i], buckets[(i + 1) % buckets.count]) {
                    if buckets[i].hueStdDev < 5.0 && buckets[(i + 1) % buckets.count].hueStdDev < 5.0 {
                        buckets[i].count += buckets[(i + 1) % buckets.count].count
                        buckets[i].meanHue = (buckets[i].meanHue + buckets[(i + 1) % buckets.count].meanHue) / 2
                        buckets.remove(at: (i + 1) % buckets.count)
                        break
                    }
                } else {
                    potentialAdjacentHues = false
                }
            }
        }
        var potentialAdjacentShades = true
        while potentialAdjacentShades {
            for i in 0..<buckets.count {
                if isAdjacentShade(buckets[i], buckets[(i + 1) % buckets.count]) {
                    if abs(buckets[i].meanValue - buckets[(i + 1) % buckets.count].meanValue) < 10 {
                        buckets[i].count += buckets[(i + 1) % buckets.count].count
                        buckets[i].meanHue = (buckets[i].meanHue + buckets[(i + 1) % buckets.count].meanHue) / 2
                        buckets.remove(at: (i + 1) % buckets.count)
                        break
                    }
                } else {
                    potentialAdjacentShades = false
                }
            }
        }
    }
}
