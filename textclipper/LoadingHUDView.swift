//
//  LoadingHUDView.swift
//  textclipper
//
//  Created by Michael on 14/10/2025.
//

import SwiftUI

struct LoadingHUDView: View {
    @State private var animationProgress: CGFloat = 0
    @State private var sparklePhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 20) {
            // Loading animation similar to the screenshot
            ZStack {
                // Background capsule
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: 300, height: 50)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // Animated progress dots
                HStack(spacing: 8) {
                    // Edit icon on the left
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 20)

                    // Animated dots
                    HStack(spacing: 6) {
                        ForEach(0..<10, id: \.self) { index in
                            Circle()
                                .fill(dotColor(for: index))
                                .frame(width: 8, height: 8)
                                .opacity(dotOpacity(for: index))
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()

                    // Sparkle icon on the right
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.yellow)
                        .opacity(0.3 + sparklePhase * 0.7)
                        .padding(.trailing, 20)
                }
            }
            .frame(width: 300, height: 50)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            // Status text
            Text("AI-Enhanced OCR")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .onAppear {
            // Start continuous animation
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animationProgress = 1
            }

            // Sparkle pulse animation
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                sparklePhase = 1
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        let position = CGFloat(index) / 10.0
        let progress = animationProgress

        // Calculate distance from progress wave
        let distance = abs(position - progress)

        if distance < 0.2 {
            // Active dot (yellow/white)
            return Color.white
        } else {
            // Inactive dot (gray)
            return Color.white.opacity(0.3)
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let position = CGFloat(index) / 10.0
        let progress = animationProgress

        // Calculate distance from progress wave
        let distance = abs(position - progress)

        if distance < 0.2 {
            // Active dot - full opacity
            return 1.0
        } else if distance < 0.4 {
            // Nearby dot - medium opacity
            return 0.6
        } else {
            // Far dot - low opacity
            return 0.3
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        LoadingHUDView()
    }
}
