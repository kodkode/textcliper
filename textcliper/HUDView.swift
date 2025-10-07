//
//  HUDView.swift
//  textcliper
//
//  Created by Michael on 07/10/2025.
//

import SwiftUI

struct HUDView: View {
    let message: String
    let characterCount: Int
    let wordCount: Int

    var body: some View {
        VStack(spacing: 16) {
            // Success icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("Copied to Clipboard")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Word count badge
            HStack(spacing: 6) {
                Image(systemName: "text.word.spacing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)

                Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
        )
        .frame(maxWidth: 360)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        HUDView(
            message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore.",
            characterCount: 156,
            wordCount: 23
        )
        .padding()
    }
}
