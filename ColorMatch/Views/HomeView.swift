//
//  HomeView.swift
//  ColorMatch
//

import SwiftUI
import PhotosUI

// MARK: - Pulsing Ring Modifier
struct PulsingRing: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content.overlay(
            Circle()
                .stroke(AppColor.accentGlow, lineWidth: pulsing ? 1 : 8)
                .scaleEffect(pulsing ? 1.22 : 1.0)
                .opacity(pulsing ? 0 : 0.6)
                .animation(
                    Animation.easeOut(duration: 2.0).repeatForever(autoreverses: false),
                    value: pulsing
                )
                .onAppear { pulsing = true }
        )
    }
}

extension View {
    func pulsingRing() -> some View { self.modifier(PulsingRing()) }
}

// MARK: - Slow Press Button Style
struct SlowPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeInOut(duration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Custom Mode Picker
struct ModePicker: View {
    @Binding var isWorn: Bool
    let dark: Bool

    var body: some View {
        HStack(spacing: 0) {
            modeButton(label: "Outfit worn", selected: isWorn) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isWorn = true }
            }
            modeButton(label: "Laid-out", selected: !isWorn) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isWorn = false }
            }
        }
        .background(AppColor.surfaceHigh(dark))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColor.pickerBorder(dark), lineWidth: 1))
        .frame(width: 240)
    }

    @ViewBuilder
    private func modeButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular, design: .rounded))
                .foregroundColor(selected ? AppColor.accent : AppColor.unselectedText(dark))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if selected {
                            Capsule()
                                .fill(AppColor.accentDim)
                                .overlay(Capsule().stroke(AppColor.accent.opacity(0.4), lineWidth: 1))
                                .padding(3)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Panel
struct InfoPanel: View {
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("HOW IT WORKS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundColor(AppColor.textSecondary(dark))

            VStack(alignment: .leading, spacing: 14) {
                InfoRow(icon: "camera.fill",
                        text: "Take or upload a photo of the outfit you'd like to test for color harmony.",
                        dark: dark)
                InfoRow(icon: "figure.stand",
                        text: "The outfit can be worn, or laid out on a neutral background.",
                        dark: dark)
                InfoRow(icon: "rectangle.and.hand.point.up.left",
                        text: "Background doesn't matter if the outfit is worn — just the clothes.",
                        dark: dark)
                InfoRow(icon: "sparkles",
                        text: "More detailed feedback coming soon.",
                        dark: dark)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface(dark).ignoresSafeArea())
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let dark: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColor.accent)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(AppColor.textPrimary(dark))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Settings Panel
struct SettingsPanel: View {
    @EnvironmentObject var appearance: AppearanceSettings

    var dark: Bool { appearance.isDarkMode }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("SETTINGS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundColor(AppColor.textSecondary(dark))

            // ── Appearance ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("APPEARANCE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(AppColor.textSecondary(dark).opacity(0.6))
                    .padding(.bottom, 4)

                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColor.accent)
                            .frame(width: 20)
                        Text(dark ? "Dark mode" : "Light mode")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(AppColor.textPrimary(dark))
                    }
                    Spacer()
                    Toggle("", isOn: $appearance.isDarkMode)
                        .tint(AppColor.accent)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColor.surfaceHigh(dark))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColor.pickerBorder(dark), lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface(dark).ignoresSafeArea())
    }
}

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    var dark: Bool { appearance.isDarkMode }

    @State private var showingCamera       = false
    @State private var isLaunchingCamera   = false
    @State private var navigateToAnalysis  = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var capturedImage: UIImage? = nil
    @State private(set) var isWorn: Bool   = true
    @State private var showingInfo   = false
    @State private var showingSettings = false

    func handlePhotoPickerChange(_ newItem: PhotosPickerItem?) {
        guard let newItem else { return }
        Task {
            if let data  = try? await newItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        }
    }

    @ViewBuilder var analysisDestination: some View {
        if capturedImage != nil {
            AnalysisView(image: $capturedImage, isWorn: isWorn)
        } else if selectedImage != nil {
            AnalysisView(image: $selectedImage, isWorn: isWorn)
        } else {
            Text("Error: No image to analyze.")
                .foregroundColor(AppColor.textSecondary(dark))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background(dark).ignoresSafeArea()

                RadialGradient(
                    colors: [AppColor.accentGlow.opacity(dark ? 0.18 : 0.10), Color.clear],
                    center: .center,
                    startRadius: 80,
                    endRadius: 340
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {

                    // ── Wordmark ──────────────────────────────────────────
                    Text("MATCH")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .tracking(12)
                        .foregroundColor(AppColor.textPrimary(dark))
                        .padding(.top, 24)

                    Spacer()

                    // ── Mode Picker ───────────────────────────────────────
                    VStack(spacing: 8) {
                        Text("MODE")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(AppColor.textSecondary(dark))

                        ModePicker(isWorn: $isWorn, dark: dark)
                    }
                    .padding(.bottom, 36)


                    // ── Camera Button ─────────────────────────────────────
                    Button(action: {
                        isLaunchingCamera = true
                        showingCamera = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColor.accentDim)
                                .frame(width: 230, height: 230)
                                .pulsingRing()

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColor.accent,
                                            Color(red: 30/255, green: 160/255, blue: 60/255)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 200, height: 200)
                                .shadow(color: AppColor.accentGlow, radius: 24, x: 0, y: 8)

                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                                .frame(width: 175, height: 175)

                            if isLaunchingCamera {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.4)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 56, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(SlowPressButtonStyle())
                    .frame(width: 230, height: 230)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .fullScreenCover(isPresented: $showingCamera) {
                        CameraView(image: $capturedImage).ignoresSafeArea()
                    }

                    Spacer()

                    // ── Photo Library Button ──────────────────────────────
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 15, weight: .medium))
                            Text("Choose from library")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(AppColor.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(AppColor.accentDim)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColor.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .onChange(of: selectedItem) { _, newValue in
                        handlePhotoPickerChange(newValue)
                    }
                    .padding(.bottom, 24)

                    // ── Bottom Bar ────────────────────────────────────────
                    HStack {
                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(AppColor.textSecondary(dark))
                        }
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(AppColor.textSecondary(dark))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                }
            }
            .onChange(of: showingCamera) { _, newValue in
                if !newValue { isLaunchingCamera = false }
            }
            .navigationDestination(isPresented: $navigateToAnalysis) {
                analysisDestination
            }
            .onChange(of: capturedImage) { _, newValue in
                if newValue != nil { navigateToAnalysis = true }
            }
            .onChange(of: selectedImage) { _, newValue in
                if newValue != nil { navigateToAnalysis = true }
            }
            .onChange(of: navigateToAnalysis) { _, newValue in
                if newValue == false {
                    selectedImage  = nil
                    capturedImage  = nil
                }
            }
            .sheet(isPresented: $showingInfo) {
                InfoPanel(dark: dark)
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppColor.surface(dark))
            }
            .sheet(isPresented: $showingSettings) {
                SettingsPanel()
                    .presentationDetents([.fraction(0.3)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppColor.surface(dark))
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppearanceSettings())
}
