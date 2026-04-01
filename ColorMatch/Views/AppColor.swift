//
//  AppColor.swift
//  ColorMatch
//

import SwiftUI

struct AppColor {

    // MARK: - Dark theme (default)
    struct Dark {
        static let background    = Color(red: 14/255,  green: 14/255,  blue: 18/255)
        static let surface       = Color(red: 24/255,  green: 24/255,  blue: 30/255)
        static let surfaceHigh   = Color(red: 36/255,  green: 36/255,  blue: 44/255)
        static let textPrimary   = Color.white
        static let textSecondary = Color(white: 0.55)
        static let pickerBorder  = Color.white.opacity(0.08)
        static let unselectedText = Color(white: 0.75)
    }

    // MARK: - Light theme
    struct Light {
        static let background    = Color(red: 245/255, green: 245/255, blue: 247/255)
        static let surface       = Color(red: 255/255, green: 255/255, blue: 255/255)
        static let surfaceHigh   = Color(red: 232/255, green: 232/255, blue: 236/255)
        static let textPrimary   = Color(red: 20/255,  green: 20/255,  blue: 24/255)
        static let textSecondary = Color(white: 0.50)
        static let pickerBorder  = Color.black.opacity(0.08)
        static let unselectedText = Color(white: 0.38)
    }

    // MARK: - Accent (shared)
    static let accent     = Color(red: 52/255,  green: 199/255, blue: 89/255)
    static let accentDim  = Color(red: 52/255,  green: 199/255, blue: 89/255).opacity(0.15)
    static let accentGlow = Color(red: 52/255,  green: 199/255, blue: 89/255).opacity(0.35)
    static let noMatch    = Color(red: 255/255, green: 69/255,  blue: 58/255)

    // MARK: - Theme-resolved helpers
    static func background(_ dark: Bool)     -> Color { dark ? Dark.background    : Light.background }
    static func surface(_ dark: Bool)        -> Color { dark ? Dark.surface       : Light.surface }
    static func surfaceHigh(_ dark: Bool)    -> Color { dark ? Dark.surfaceHigh   : Light.surfaceHigh }
    static func textPrimary(_ dark: Bool)    -> Color { dark ? Dark.textPrimary   : Light.textPrimary }
    static func textSecondary(_ dark: Bool)  -> Color { dark ? Dark.textSecondary : Light.textSecondary }
    static func pickerBorder(_ dark: Bool)   -> Color { dark ? Dark.pickerBorder  : Light.pickerBorder }
    static func unselectedText(_ dark: Bool) -> Color { dark ? Dark.unselectedText : Light.unselectedText }
}
