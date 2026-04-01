//
//  ColorMatchApp.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 6/16/25.
//

import SwiftUI

@main
struct ColorMatchApp: App {
    @StateObject private var appearance = AppearanceSettings()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appearance)
                .preferredColorScheme(appearance.isDarkMode ? .dark : .light)
        }
    }
}
