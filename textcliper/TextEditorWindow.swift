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
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    TextEditorWindow(text: .constant("Sample text for preview\nLine 2\nLine 3")) { text in
        print("Copy: \(text)")
    }
}
