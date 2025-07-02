//
//  AnalysisEngine.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/1/25.
//

import Foundation
import PhotosUI

struct AnalysisEngine {
    func runAnalysis(on image: UIImage) async -> OutfitAnalysisResult {
        try? await Task.sleep(nanoseconds: 1_000_000_000 * 5)
        return OutfitAnalysisResult()
    }
}
