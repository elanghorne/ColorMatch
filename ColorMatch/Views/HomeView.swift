//
//  HomeView.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/16/25.
//

import SwiftUI
import PhotosUI


struct HomeView: View {
    
    @State private var showingCamera = false  // controls camera sheet visibility
    @State private var isLaunchingCamera = false // controls loading camera sheet
    @State private var navigateToAnalysis = false // controls navigation to AnalysisView
    @State private var selectedItem: PhotosPickerItem? // holds selected photo item
    @State private var selectedImage: UIImage? // holds loaded image
    @State private var capturedImage: UIImage? = nil // holds captured photo
    
    var body: some View {

        ZStack {
            AppColor.background.ignoresSafeArea()
            NavigationStack {
                VStack {
                    Spacer()
                    Text("MATCH")
                        .bold()
                        .monospaced()
                        .font(.largeTitle)
                        .foregroundColor(Color.white)
                    
                    Button(action: {
                        print("Match button pressed")
                        isLaunchingCamera = true
                        showingCamera = true // shows camera view
                    }) {
                        ZStack {
                            // circular button in center
                            Circle()
                                .frame(width: 250, height: 250)
                                .foregroundColor(AppColor.matchIcon)
                                .clipShape(Circle())
                                .contentShape(Circle())
                            Circle()
                                .stroke(AppColor.background, lineWidth: 7)
                                .frame(width: 220, height: 220)
                                .clipShape(Circle())
                                .contentShape(Circle())
                                .foregroundColor(AppColor.matchIcon)
                            Image(systemName: "camera")
                                .font(.system(size: 75))
                                .foregroundColor(AppColor.background)
                        }
                    }
                    // trims button shape from square to circle
                    .frame(width: 250, height: 250)
                    .background(Color.red.opacity(0.3))
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .padding()
                    .fullScreenCover(isPresented: $showingCamera){ //covers entire screen vs .sheet leaving gap at top
                        CameraView(image: $capturedImage).ignoresSafeArea()
                        
                    }
                    .overlay(
                        Group {
                            if isLaunchingCamera {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                        })
                    
                    // photo picker button
                    PhotosPicker(selection: $selectedItem, // bind to the selected item
                                 matching: .images, // show images only
                                 photoLibrary: .shared()
                    ) {
                        Text("Select Photo")
                    }
                    
                    Spacer()
                    HStack {
                        Button(action: {
                            print("Info button pressed")
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 25))
                            //.foregroundColor(Color.white)
                        }
                        Spacer()
                        Button(action: {
                            print("Settings button pressed")
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 25))
                            //.foregroundColor(Color.white)
                        }
                    }
                    
                }
                .padding()
                .onChange(of: showingCamera) { newValue in
                    if !newValue {
                        isLaunchingCamera = false
                    }
                }

                NavigationLink(
                    destination:
                       Group {
                           if capturedImage != nil {
                            AnalysisView(image: $capturedImage)
                        } else if selectedImage != nil {
                            AnalysisView(image: $selectedImage)
                        } else {
                            Text("Error: No image to analyze.")
                        }
                        }, isActive: $navigateToAnalysis) {
                            EmptyView()
                        }
            }
            .onChange(of: capturedImage) {newValue in
                if newValue != nil {
                    navigateToAnalysis = true
                }}
            .onChange(of: selectedImage) { newValue in
                if newValue != nil {
                    navigateToAnalysis = true
                }}
        }
    }
}

#Preview {
    HomeView()
}
