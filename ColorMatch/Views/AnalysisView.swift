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

    
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack {
                if let image = image {
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
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 400)
                        .cornerRadius(20)
                    
                }
            }
        }
    }
}

#Preview {
    AnalysisView(image: .constant(nil))
}
