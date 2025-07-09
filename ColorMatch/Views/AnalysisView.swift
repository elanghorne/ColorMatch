//
//  AnalysisView.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/23/25.
//

import SwiftUI
import PhotosUI

struct AnalysisView: View {
    @Binding var image: UIImage? // binding to either selectedImage or capturedImage
    @StateObject var viewModel = AnalysisViewModel()
    
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea() // apply background color
                VStack {
                    if let image = image { // if binding to UIImage passed in isn't nil
                        if !viewModel.analysisComplete { // if analysis hasn't been completed yet
                            VStack {
                                Text("Analyzing Image...")
                                    .font(.largeTitle)
                                    .padding()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            }
                        } else { //if analysis is already complete
                            Text(OutfitAnalysisResult().feedbackMessage) // display feedback message
                                .font(.largeTitle)
                                .padding()

                        }
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 400)
                            .cornerRadius(20)
                            .onAppear { // when image is displayed
                                Task {
                                    await viewModel.analyze(image: image) // call to analyze method passing the image
                                }
                            }
                    }
            }
        }
    }
}

#Preview {
    AnalysisView(image: .constant(nil))
}
