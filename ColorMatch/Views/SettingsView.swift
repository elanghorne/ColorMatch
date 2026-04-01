//
//  SettingsView.swift
//  ColorMatch
//
//  Created by Eric Langhorne on 8/21/25.
//

import SwiftUI

// Note: The main settings UI lives in SettingsPanel inside HomeView.swift,
// presented as a bottom sheet. This file is kept as a placeholder for
// future full-screen settings if needed.

struct SettingsView: View {
    @EnvironmentObject var appearance: AppearanceSettings

    var body: some View {
        SettingsPanel()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppearanceSettings())
}
