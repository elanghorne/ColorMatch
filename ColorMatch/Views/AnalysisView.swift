//
//  AnalysisView.swift
//  ColorMatch
//

import SwiftUI
import PhotosUI

struct AnalysisView: View {
    @Binding var image: UIImage?
    var isWorn: Bool
    @StateObject var viewModel = AnalysisViewModel()
    @EnvironmentObject var appearance: AppearanceSettings

    var dark: Bool { appearance.isDarkMode }

    // Entry animation
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppColor.background(dark).ignoresSafeArea()

            // Ambient glow (colour-shifts based on result)
            if viewModel.analysisComplete, let result = viewModel.analysisData {
                RadialGradient(
                    colors: [
                        (result.isMatch == true ? AppColor.accentGlow : AppColor.noMatch.opacity(0.25)),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity.animation(.easeIn(duration: 0.6)))
            }

            VStack(spacing: 0) {

                // ── Result / Loading Badge ────────────────────────────────
                Group {
                    if !viewModel.analysisComplete {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColor.accent))
                                .scaleEffect(0.85)
                            Text("Analyzing…")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(AppColor.textSecondary(dark))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColor.surfaceHigh(dark))
                        .clipShape(Capsule())
                    } else if let result = viewModel.analysisData {
                        let matched = result.isMatch == true
                        HStack(spacing: 8) {
                            Image(systemName: matched ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(matched ? AppColor.accent : AppColor.noMatch)
                            Text(result.feedbackMessage.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(matched ? AppColor.accent : AppColor.noMatch)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(matched ? AppColor.accentDim : AppColor.noMatch.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    (matched ? AppColor.accent : AppColor.noMatch).opacity(0.35),
                                    lineWidth: 1
                                )
                        )
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: viewModel.analysisComplete)

                // ── Image ─────────────────────────────────────────────────
                if let image {
                    ZStack(alignment: .bottom) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 480)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.black.opacity(dark ? 0.0 : 0.06), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(dark ? 0.5 : 0.15), radius: 20, x: 0, y: 10)

                        if let debugImage = viewModel.analysisData?.debugImage {
                            Image(uiImage: debugImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColor.accent, lineWidth: 1.5)
                                )
                                .padding(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.94)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.05), value: appeared)
                    .onAppear {
                        appeared = true
                        Task {
                            await viewModel.analyze(image: image, isWorn: isWorn)
                        }
                    }
                }

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColor.background(dark), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    AnalysisView(image: .constant(nil), isWorn: true)
        .environmentObject(AppearanceSettings())
}
