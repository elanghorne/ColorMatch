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
    @State private(set) var isWorn: Bool = true
    
    func handlePhotoPickerChange(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            if let data = try? await newItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        }
    }
    
   @ViewBuilder var analysisDestination: some View {
            if capturedImage != nil {
                AnalysisView(image: $capturedImage, isWorn: isWorn) // pass binding to capturedImage to AnalysisView if an image is there
         } else if selectedImage != nil {
             AnalysisView(image: $selectedImage, isWorn: isWorn) // pass binding to selectedImage to AnalysisView if an image is there
         } else {
             Text("Error: No image to analyze.") // display error for debugging
         }
    }
    
    var body: some View {
        NavigationStack { // allows nagivagation link
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack {
                    Spacer()
                    Text("MATCH")
                        .bold()
                        .monospaced()
                        .font(.largeTitle)
                        .foregroundColor(Color.white)
                    Picker("Select an option", selection: $isWorn) {

                        Text("Outfit worn").tag(true)
                        Text("Outfit laid-out").tag(false)
                    }
                    .tint(.white)
                    Button(action: {
                        print("Match button pressed")
                        isLaunchingCamera = true // triggers progress view for camera hang
                        showingCamera = true // shows camera view
                    }){
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
                            if isLaunchingCamera { // progress view for camera delay
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
                    .onChange(of: selectedItem) { _, newValue in
                        handlePhotoPickerChange(newValue)
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
                .onChange(of: showingCamera) { oldValue, newValue in
                    if !newValue {
                        isLaunchingCamera = false // removes progress view when user goes back to HomeView
                    }
                }
                .navigationDestination(isPresented: $navigateToAnalysis) { // triggers when navigateToAnalysis is true
                    analysisDestination
                }
            }
            .onChange(of: capturedImage) { oldValue, newValue in // if capturedImage changes and the new value is not nil
                if newValue != nil {
                    navigateToAnalysis = true // triggers navigation/updates state
                }
            }
            .onChange(of: selectedImage) { oldValue, newValue in // if selectedImage changes and the new value is not nil
                if newValue != nil {
                    navigateToAnalysis = true // triggers navigation/updates state
                }
            }
            .onChange(of: navigateToAnalysis) { oldValue, newValue in //
                if newValue == false {
                    selectedImage = nil
                    capturedImage = nil
                }
            }
        }
    }
}


#Preview {
    HomeView()
}

