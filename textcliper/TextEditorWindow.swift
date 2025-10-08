//
//  TextEditorWindow.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//

import SwiftUI

struct TextEditorWindow: View {
    @Binding var text: String
    var onCopy: (String) -> Void
    var showShareActions: Bool = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Captured Text")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 500, minHeight: 300)
                .border(Color.gray.opacity(0.3), width: 1)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))

            // Share actions (if enabled)
            if showShareActions {
                VStack(spacing: 12) {
                    Text("Share to:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        ShareActionButton(icon: "note.text", label: "Note", color: .orange) {
                            shareText(to: .notes)
                        }

                        ShareActionButton(icon: "envelope", label: "Mail", color: .blue) {
                            shareText(to: .mail)
                        }

                        ShareActionButton(icon: "message", label: "Msg", color: .green) {
                            shareText(to: .messages)
                        }

                        ShareActionButton(icon: "ellipsis", label: "More", color: .gray) {
                            shareText(to: .saveFile)
                        }

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Copy to Clipboard") {
                    onCopy(text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: showShareActions ? 500 : 400)
    }

    private func shareText(to destination: ShareDestination) {
        ShareService.shared.share(text: text, to: destination) { result in
            switch result {
            case .success:
                print("✅ Successfully shared to \(destination)")
                dismiss()
            case .failure(let error):
                print("❌ Failed to share: \(error)")
            }
        }
    }
}

#Preview {
    TextEditorWindow(text: .constant("Sample text for preview\nLine 2\nLine 3")) { text in
        print("Copy: \(text)")
    }
}
