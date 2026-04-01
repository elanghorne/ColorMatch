//
//  AppearanceSettings.swift
//  ColorMatch
//

import SwiftUI

class AppearanceSettings: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
}
