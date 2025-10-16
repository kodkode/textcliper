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
    @State private var showProcessingMenu = false
    @State private var refreshID = UUID()
    @State private var textHistory: [String] = []
    @State private var originalText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Edit Captured Text")
                    .font(.headline)

                Spacer()

                // Undo button
                if !textHistory.isEmpty {
                    Button(action: undoLastChange) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 12))
                            Text("Undo (\(textHistory.count))")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.borderless)
                }
            }

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 500, minHeight: 300)
                .border(Color.gray.opacity(0.3), width: 1)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .id(refreshID)

            // Text Processing Tools
            VStack(spacing: 8) {
                Text("Text Processing:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Cleanup Actions
                        ProcessingButton(icon: "sparkles", label: "Clean Up", color: .blue) {
                            saveToHistory()
                            text = TextProcessingService.shared.fullCleanup(text)
                            refreshID = UUID()
                        }

                        ProcessingButton(icon: "space", label: "Fix Spaces", color: .cyan) {
                            saveToHistory()
                            text = TextProcessingService.shared.removeExtraSpaces(text)
                            refreshID = UUID()
                        }

                        // Case Conversion
                        ProcessingButton(icon: "textformat", label: "UPPERCASE", color: .purple) {
                            saveToHistory()
                            text = TextProcessingService.shared.toUppercase(text)
                            refreshID = UUID()
                        }

                        ProcessingButton(icon: "textformat", label: "lowercase", color: .purple) {
                            saveToHistory()
                            text = TextProcessingService.shared.toLowercase(text)
                            refreshID = UUID()
                        }

                        ProcessingButton(icon: "textformat", label: "Title Case", color: .purple) {
                            saveToHistory()
                            text = TextProcessingService.shared.toTitleCase(text)
                            refreshID = UUID()
                        }

                        // Smart Formatting
                        ProcessingButton(icon: "quote.opening", label: "Smart Quotes", color: .orange) {
                            saveToHistory()
                            text = TextProcessingService.shared.convertToSmartQuotes(text)
                            refreshID = UUID()
                        }

                        ProcessingButton(icon: "minus", label: "Em Dashes", color: .orange) {
                            saveToHistory()
                            text = TextProcessingService.shared.convertToEmDashes(text)
                            refreshID = UUID()
                        }

                        // Code Formatting
                        if TextProcessingService.shared.appearsToBeCode(text) {
                            ProcessingButton(icon: "curlybraces", label: "Code Block", color: .green) {
                                saveToHistory()
                                text = TextProcessingService.shared.wrapInCodeBlock(text)
                                refreshID = UUID()
                            }
                        }

                        // Detection Info
                        if TextProcessingService.shared.containsURLs(text) {
                            ProcessingButton(icon: "link", label: "URLs: \(TextProcessingService.shared.extractURLs(text).count)", color: .indigo) {
                                showDetectedItems(type: .url)
                            }
                        }

                        if TextProcessingService.shared.containsEmails(text) {
                            ProcessingButton(icon: "envelope", label: "Emails: \(TextProcessingService.shared.extractEmails(text).count)", color: .indigo) {
                                showDetectedItems(type: .email)
                            }
                        }

                        if TextProcessingService.shared.containsPhoneNumbers(text) {
                            ProcessingButton(icon: "phone", label: "Phones: \(TextProcessingService.shared.extractPhoneNumbers(text).count)", color: .indigo) {
                                showDetectedItems(type: .phoneNumber)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 8)

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
        .frame(minWidth: 600, idealWidth: 700, minHeight: showShareActions ? 600 : 520, idealHeight: showShareActions ? 650 : 560)
        .onAppear {
            // Save original text when window opens
            if originalText.isEmpty {
                originalText = text
            }
        }
    }

    // MARK: - Undo functionality

    private func saveToHistory() {
        textHistory.append(text)
        // Limit history to 10 items
        if textHistory.count > 10 {
            textHistory.removeFirst()
        }
    }

    private func undoLastChange() {
        guard !textHistory.isEmpty else { return }
        text = textHistory.removeLast()
        refreshID = UUID()
        print("⏪ Undo: Reverted to previous state (\(textHistory.count) remaining)")
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

    private func showDetectedItems(type: TextProcessingService.DetectionType) {
        let items: [String]
        switch type {
        case .url:
            items = TextProcessingService.shared.extractURLs(text)
        case .email:
            items = TextProcessingService.shared.extractEmails(text)
        case .phoneNumber:
            items = TextProcessingService.shared.extractPhoneNumbers(text)
        }

        let alert = NSAlert()
        alert.messageText = "Detected \(type)s"
        alert.informativeText = items.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Processing Button Component

struct ProcessingButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            print("🔘 Button clicked: \(label)")
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
        }
        .buttonStyle(.borderless)
        .focusable(false)
    }
}

#Preview {
    TextEditorWindow(text: .constant("Sample text for preview\nLine 2\nLine 3")) { text in
        print("Copy: \(text)")
    }
}
