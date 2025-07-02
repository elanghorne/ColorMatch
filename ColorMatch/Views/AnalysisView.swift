//
//  AnalysisView.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/23/25.
//

import SwiftUI
import PhotosUI

struct AnalysisView: View {
    @Binding var image: UIImage?
    @StateObject var viewModel = AnalysisViewModel()
    
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
                VStack {
                    if let image = image {
                        if !viewModel.analysisComplete {
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
                        } else {
                            Text(OutfitAnalysisResult().message)
                                .font(.largeTitle)
                                .padding()
                        }
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 400)
                            .cornerRadius(20)
                            .onAppear {
                                Task {
                                    await viewModel.analyze(image: image)
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
