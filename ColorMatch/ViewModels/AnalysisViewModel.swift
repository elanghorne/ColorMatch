//
//  AnalysisViewModel.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/1/25.
//

import Foundation
import PhotosUI

@MainActor // keeps on main thread, so changes aren't published from background threads
class AnalysisViewModel: ObservableObject{
   // @Published var isAnalyzing = false
    @Published var analysisResult: OutfitAnalysisResult?
    @Published var analysisComplete = false
    
    func analyze(image: UIImage, isWorn: Bool) async{
    //    self.isAnalyzing = true
        let result = await AnalysisEngine().runAnalysis(on: image, isWorn: isWorn) // runs analysis on image and stores return value in result
        self.analysisResult = result // publishes result
     //   self.isAnalyzing = false
        self.analysisComplete = true // marks analysis is complete
    }
}
    


