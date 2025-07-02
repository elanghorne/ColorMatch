//
//  AnalysisViewModel.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/1/25.
//

import Foundation
import PhotosUI

@MainActor
class AnalysisViewModel: ObservableObject{
    @Published var isAnalyzing = false
    @Published var analysisResult: OutfitAnalysisResult?
    @Published var analysisComplete = false
    
    func analyze(image: UIImage) async{
        self.isAnalyzing = true
        let result = await AnalysisEngine().runAnalysis(on: image)
        self.analysisResult = result
        self.isAnalyzing = false
        self.analysisComplete = true
    }
}
    


