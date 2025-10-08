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
    let fullText: String
    let showActions: Bool
    let onShare: ((ShareDestination) -> Void)?

    init(message: String, characterCount: Int, wordCount: Int, fullText: String = "", showActions: Bool = false, onShare: ((ShareDestination) -> Void)? = nil) {
        self.message = message
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.fullText = fullText
        self.showActions = showActions
        self.onShare = onShare
    }

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

            // Action buttons (Option C)
            if showActions {
                HStack(spacing: 10) {
                    ShareActionButton(icon: "note.text", label: "Note", color: .orange) {
                        onShare?(.notes)
                    }

                    ShareActionButton(icon: "envelope", label: "Mail", color: .blue) {
                        onShare?(.mail)
                    }

                    ShareActionButton(icon: "message", label: "Msg", color: .green) {
                        onShare?(.messages)
                    }

                    ShareActionButton(icon: "ellipsis", label: "More", color: .gray) {
                        onShare?(.saveFile)
                    }
                }
                .padding(.top, 4)
            }
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

// MARK: - Share Action Button Component

struct ShareActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        VStack(spacing: 30) {
            HUDView(
                message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore.",
                characterCount: 156,
                wordCount: 23,
                fullText: "Full text here",
                showActions: false
            )

            HUDView(
                message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                characterCount: 156,
                wordCount: 23,
                fullText: "Full text here",
                showActions: true,
                onShare: { destination in
                    print("Share to: \(destination)")
                }
            )
        }
        .padding()
    }
}
