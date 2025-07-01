//
//  AnalysisViewModel.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 7/1/25.
//

import Foundation
import PhotosUI

class AnalysisViewModel: ObservableObject{
    @Published var isAnalyzing = false
    
    func analyze(image: UIImage){
        isAnalyzing = true
    }
}
