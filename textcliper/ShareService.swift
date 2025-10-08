//
//  ShareService.swift
//  textcliper
//
//  Created by Michael on 08/10/2025.
//

import AppKit
import Contacts
import UniformTypeIdentifiers

enum ShareDestination {
    case notes
    case mail
    case messages
    case reminders
    case saveFile
}

enum ShareError: Error {
    case serviceUnavailable
    case userCancelled
    case sharingFailed
}

class ShareService {
    static let shared = ShareService()

    private init() {}

    /// Share text to a specific destination
    /// - Parameters:
    ///   - text: The text to share
    ///   - destination: The destination app/service
    ///   - completion: Called with result
    func share(text: String, to destination: ShareDestination, completion: @escaping (Result<Void, ShareError>) -> Void) {
        switch destination {
        case .notes:
            shareToNotes(text: text, completion: completion)
        case .mail:
            shareToMail(text: text, completion: completion)
        case .messages:
            shareToMessages(text: text, completion: completion)
        case .reminders:
            shareToReminders(text: text, completion: completion)
        case .saveFile:
            saveToFile(text: text, completion: completion)
        }
    }

    /// Share using native macOS share sheet
    /// - Parameters:
    ///   - text: The text to share
    ///   - sourceView: The view to anchor the share sheet to (optional)
    func shareWithSheet(text: String, sourceView: NSView? = nil) {
        let picker = NSSharingServicePicker(items: [text])

        if let view = sourceView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else {
            // Show at mouse location if no view provided
            let mouseLocation = NSEvent.mouseLocation
            let fakeView = NSView(frame: NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1))

            // Get frontmost window or create temporary one
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.contentView?.addSubview(fakeView)
                picker.show(relativeTo: fakeView.bounds, of: fakeView, preferredEdge: .minY)
                fakeView.removeFromSuperview()
            }
        }
    }

    // MARK: - Private Sharing Methods

    private func shareToNotes(text: String, completion: @escaping (Result<Void, ShareError>) -> Void) {
        // Use AppleScript to create a new note
        let script = """
        tell application "Notes"
            tell account "iCloud"
                make new note at folder "Notes" with properties {body:"\(text.escapedForAppleScript())"}
            end tell
            activate
        end tell
        """

        executeAppleScript(script, completion: completion)
    }

    private func shareToMail(text: String, completion: @escaping (Result<Void, ShareError>) -> Void) {
        // Use NSSharingService for Mail
        let service = NSSharingService(named: .composeEmail)

        guard service != nil else {
            completion(.failure(.serviceUnavailable))
            return
        }

        // Create temporary file for attachment if needed, or just share as text
        if service!.canPerform(withItems: [text]) {
            service!.perform(withItems: [text])
            completion(.success(()))
        } else {
            // Fallback to mailto URL
            let mailtoURL = "mailto:?body=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: mailtoURL) {
                NSWorkspace.shared.open(url)
                completion(.success(()))
            } else {
                completion(.failure(.sharingFailed))
            }
        }
    }

    private func shareToMessages(text: String, completion: @escaping (Result<Void, ShareError>) -> Void) {
        // Use NSSharingService for Messages
        let service = NSSharingService(named: .composeMessage)

        guard service != nil else {
            completion(.failure(.serviceUnavailable))
            return
        }

        if service!.canPerform(withItems: [text]) {
            service!.perform(withItems: [text])
            completion(.success(()))
        } else {
            completion(.failure(.sharingFailed))
        }
    }

    private func shareToReminders(text: String, completion: @escaping (Result<Void, ShareError>) -> Void) {
        // Use AppleScript to create a new reminder
        let script = """
        tell application "Reminders"
            tell list "Reminders"
                make new reminder with properties {name:"\(text.escapedForAppleScript())"}
            end tell
            activate
        end tell
        """

        executeAppleScript(script, completion: completion)
    }

    private func saveToFile(text: String, completion: @escaping (Result<Void, ShareError>) -> Void) {
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "Captured Text.txt"
            panel.canCreateDirectories = true

            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        try text.write(to: url, atomically: true, encoding: .utf8)
                        completion(.success(()))
                    } catch {
                        completion(.failure(.sharingFailed))
                    }
                } else {
                    completion(.failure(.userCancelled))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func executeAppleScript(_ script: String, completion: @escaping (Result<Void, ShareError>) -> Void) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)

            if error != nil {
                completion(.failure(.sharingFailed))
            } else {
                completion(.success(()))
            }
        } else {
            completion(.failure(.serviceUnavailable))
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Escapes a string for use in AppleScript
    func escapedForAppleScript() -> String {
        return self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
