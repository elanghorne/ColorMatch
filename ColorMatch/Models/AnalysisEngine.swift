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

    func runAnalysis(on image: UIImage, isWorn: Bool) async -> OutfitAnalysisData {
        var buckets: [ColorBucket] = []
        var analysisData = OutfitAnalysisData()
        
        let buffer: [UInt8]
        do {
            buffer = try preprocess(image, isWorn)
        } catch let error as AnalysisError {
            analysisData.feedbackMessage = error.localizedDescription
            return analysisData
        } catch {
            analysisData.feedbackMessage = AnalysisError.unknown.localizedDescription
            return analysisData
        }
        
        processCleanedBuffer(buffer, &buckets)
        determineHarmony(from: &buckets, storeResultsIn: &analysisData)
        if let isMatch = analysisData.isMatch {
            analysisData.feedbackMessage = isMatch ? "You match!" : "You don't match."
        }

        return analysisData
    }


    private func determineHarmony(from buckets: inout [ColorBucket], storeResultsIn analysisData: inout OutfitAnalysisData) {
        for i in stride(from: buckets.count - 1, through: 0, by: -1) {
            if buckets[i].percentage <= 5 {
                buckets.remove(at: i)
            }
        }

        if buckets.count == 1 {
            analysisData.isMatch = true
        } else if buckets.count == 2 {
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" {
                analysisData.isMatch = true
            } else {
                analysisData.isMatch = twoBucketAnalysis(on: buckets)
            }
        } else if buckets.count == 3 {
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" || buckets[2].label.1 == "Neutral" {
                removeNeutral(from: &buckets)
                analysisData.isMatch = twoBucketAnalysis(on: buckets)
            } else {
                analysisData.isMatch = threeBucketAnalysis(on: buckets)
            }
        } else if buckets.count == 4 {
            if buckets[0].label.1 == "Neutral" || buckets[1].label.1 == "Neutral" || buckets[2].label.1 == "Neutral" || buckets[3].label.1 == "Neutral" {
                removeNeutral(from: &buckets)
                analysisData.isMatch = threeBucketAnalysis(on: buckets)
            } else {
                analysisData.isMatch = false
            }
        } else {
            analysisData.isMatch = false
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


}
