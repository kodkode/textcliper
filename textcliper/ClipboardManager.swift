//
//  ClipboardManager.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//

import AppKit

enum ClipboardError: Error {
    case emptyText
    case copyFailed
}

class ClipboardManager {
    static let shared = ClipboardManager()

    private init() {}

    /// Copies text to the system clipboard
    /// - Parameters:
    ///   - text: The text to copy
    ///   - additive: If true, appends to existing clipboard content. If false, replaces it.
    ///   - separator: The separator to use when appending (default: double newline)
    /// - Returns: Result indicating success or failure
    @discardableResult
    func copyToClipboard(_ text: String, additive: Bool = false, separator: String = "\n\n") -> Result<Void, ClipboardError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure(.emptyText)
        }

        let pasteboard = NSPasteboard.general

        let finalText: String
        if additive, let existingText = pasteboard.string(forType: .string), !existingText.isEmpty {
            // Append to existing clipboard content
            finalText = existingText + separator + trimmed
        } else {
            // Replace clipboard content
            finalText = trimmed
        }

        pasteboard.clearContents()
        let success = pasteboard.setString(finalText, forType: .string)

        return success ? .success(()) : .failure(.copyFailed)
    }

    /// Gets the current clipboard text
    /// - Returns: The clipboard text, or nil if empty
    func getClipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
}
