//
//  HotkeyManager.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//

import Foundation
import AppKit
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?

    private init() {}

    /// Registers a global hotkey (⌘⇧8)
    /// - Parameter callback: The action to perform when hotkey is pressed
    /// - Returns: True if registration succeeded
    @discardableResult
    func registerHotkey(callback: @escaping () -> Void) -> Bool {
        self.callback = callback

        // Note: We skip the permission check here because AXIsProcessTrustedWithOptions
        // sometimes returns false even when permission is granted (especially in Xcode)
        // The actual RegisterEventHotKey call will fail if permission isn't granted

        // Define hotkey ID
        let hotKeyID = EventHotKeyID(signature: OSType(0x54455854), id: 1) // 'TEXT'

        // Define event type
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        // Create event handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                // Call callback on main thread
                DispatchQueue.main.async {
                    manager.callback?()
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return false
        }

        // Register hotkey: ⌘⇧8
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_8),                    // Key code for 8
            UInt32(cmdKey | shiftKey),             // Modifiers: Command + Shift
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKey
        )

        if registerStatus == noErr {
            print("Global hotkey registered: ⌘⇧8")
            return true
        } else {
            print("Failed to register hotkey: \(registerStatus)")
            return false
        }
    }

    /// Unregisters the global hotkey
    func unregisterHotkey() {
        if let eventHotKey = eventHotKey {
            UnregisterEventHotKey(eventHotKey)
            self.eventHotKey = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        callback = nil
    }

    /// Checks if accessibility permissions are granted
    /// - Returns: True if permissions are granted
    func checkAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Prompts the user to grant accessibility permissions
    /// - Returns: True if already granted, false if prompt was shown
    @discardableResult
    func promptForAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Shows an alert about accessibility permissions
    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Please grant Accessibility permission in System Settings > Privacy & Security > Accessibility to enable the global hotkey (⌘⇧8)."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to Accessibility
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    deinit {
        unregisterHotkey()
    }
}
