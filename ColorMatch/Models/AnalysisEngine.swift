//
//  AnalysisEngine.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/1/25.
//

import Foundation
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
        print("Bucket count: \(buckets.count)")
        for bucket in buckets {
            print("\(bucket.label.1) - \(bucket.shade) - \(String(format: "%.2f", bucket.percentage))%")
        }
        analysisData.isMatch = determineHarmony(from: &buckets)
        analysisData.feedbackMessage = analysisData.isMatch ? "You match!" : "You don't match."

        return analysisData
    }


}
