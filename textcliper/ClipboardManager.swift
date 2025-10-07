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
    /// - Parameter text: The text to copy
    /// - Returns: Result indicating success or failure
    @discardableResult
    func copyToClipboard(_ text: String) -> Result<Void, ClipboardError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure(.emptyText)
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let success = pasteboard.setString(trimmed, forType: .string)

        return success ? .success(()) : .failure(.copyFailed)
    }

    /// Gets the current clipboard text
    /// - Returns: The clipboard text, or nil if empty
    func getClipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
}
