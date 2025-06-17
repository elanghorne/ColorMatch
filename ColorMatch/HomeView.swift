//
//  ContentView.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/16/25.
//

import SwiftUI

struct HomeView: View {
    
    let backgroundColor = Color(red: 55/255, green: 55/255, blue: 65/255)
    let matchIconColor = Color(red: 50/255, green: 160/255, blue: 50/255)
    
    @State private var showingCamera = false // controls camera sheet visibility
    @State private var capturedImage: UIImage? = nil
    
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
                .sheet(isPresented: $showingCamera){
                    CameraView(image: $capturedImage).ignoresSafeArea()
                    // need to get rid of space at the top of sheet somehow
                }
                Button(action: {
                    print("Upload button pressed")
                }) {
                    Text("Upload photo")
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
        }
    }
}

#Preview {
    HomeView()
}
