//
//  ContentView.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/16/25.
//

import SwiftUI
import PhotosUI


struct HomeView: View {
    
    let backgroundColor = Color(red: 55/255, green: 55/255, blue: 65/255)
    let matchIconColor = Color(red: 50/255, green: 160/255, blue: 50/255)
    
    @State private var showingCamera = false  // controls camera sheet visibility


    @State private var isLaunchingCamera = false // controls loading camera sheet
    @State private var capturedImage: UIImage? = nil // holds captured photo
    @State private var selectedItem: PhotosPickerItem? // holds selected photo item
    @State private var selectedImage: UIImage? // holds loaded image

    
    var body: some View {

        ZStack {
            backgroundColor.ignoresSafeArea()
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
                            .foregroundColor(matchIconColor)
                            .clipShape(Circle())
                            .contentShape(Circle())
                        Circle()
                            .stroke(Color(backgroundColor), lineWidth: 7)
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                            .contentShape(Circle())
                            .foregroundColor(matchIconColor)
                        Image(systemName: "camera")
                            .font(.system(size: 75))
                            .foregroundColor(backgroundColor)
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
        }
    }
}

#Preview {
    HomeView()
}
