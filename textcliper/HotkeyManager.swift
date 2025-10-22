//
//  HotkeyManager.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//  Rewritten by Claude on 15/10/2025 for sequence support
//

import Foundation
import AppKit
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var callback: (() -> Void)?
    private var registeredSequence: KeySequence?

    // Buffer to track recent keypresses
    private var keypressBuffer: [(press: KeyPress, time: Date)] = []
    private let maxBufferSize = 10

    private init() {}

    /// Registers a global hotkey sequence
    /// - Parameters:
    ///   - sequence: The key sequence to register
    ///   - callback: The action to perform when sequence is detected
    /// - Returns: True if registration succeeded
    @discardableResult
    func registerHotkey(sequence: KeySequence, callback: @escaping () -> Void) -> Bool {
        // Unregister existing hotkey first
        unregisterHotkey()

        guard !sequence.isEmpty else {
            print("❌ Cannot register empty sequence")
            return false
        }

        self.callback = callback
        self.registeredSequence = sequence
        self.keypressBuffer = []

        print("🔧 Registering hotkey sequence: \(sequence.displayString())")

        // Set up global event monitor (works even when app is not active)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Set up local event monitor (works when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event // Don't consume the event
        }

        if globalMonitor != nil || localMonitor != nil {
            print("✅ Hotkey sequence registered successfully")
            return true
        } else {
            print("❌ Failed to register hotkey sequence")
            return false
        }
    }

    /// Legacy method for backward compatibility with single-key hotkeys
    @discardableResult
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) -> Bool {
        let sequence = KeySequence(legacyKeyCode: keyCode, legacyModifiers: modifiers)
        return registerHotkey(sequence: sequence, callback: callback)
    }

    /// Unregisters the global hotkey
    func unregisterHotkey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        callback = nil
        registeredSequence = nil
        keypressBuffer = []

        print("🔧 Hotkey unregistered")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let now = Date()
        let modifiers = event.modifierFlags.carbonModifiers()

        var keyPress: KeyPress?

        if event.type == .keyDown {
            // Regular key pressed - this includes any modifiers held down
            let keyCode = UInt32(event.keyCode)
            keyPress = KeyPress(keyCode: keyCode, modifiers: modifiers)
        } else if event.type == .flagsChanged {
            // Modifier key pressed/released - IGNORE
            // Modifiers are captured automatically with keyDown events
            // This prevents recording modifier keys as separate keypresses
            return
        }

        guard let press = keyPress else {
            return
        }

        // Add to buffer
        keypressBuffer.append((press: press, time: now))

        // Trim buffer to max size
        if keypressBuffer.count > maxBufferSize {
            keypressBuffer.removeFirst()
        }

        // Clean old entries (older than max timing constraint)
        if let sequence = registeredSequence {
            let cutoffTime = now.addingTimeInterval(-sequence.maxTimeBetweenKeys * Double(sequence.count))
            keypressBuffer.removeAll { $0.time < cutoffTime }
        }

        // Check if buffer matches registered sequence
        if let sequence = registeredSequence {
            if sequence.matches(buffer: keypressBuffer) {
                print("🔥 Hotkey sequence matched!")

                // Clear buffer to prevent repeated triggers
                keypressBuffer = []

                // Trigger callback on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.callback?()
                }
            }
        }
    }

    private func isModifierKeyCode(_ keyCode: UInt32) -> Bool {
        let modifierKeyCodes: [UInt32] = [
            59,  // Left Control
            62,  // Right Control
            58,  // Left Option
            61,  // Right Option
            56,  // Left Shift
            60,  // Right Shift
            55,  // Left Command
            54   // Right Command
        ]
        return modifierKeyCodes.contains(keyCode)
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

    deinit {
        unregisterHotkey()
    }
}

extension NSEvent.ModifierFlags {
    func carbonModifiers() -> UInt32 {
        var modifiers: UInt32 = 0

        if contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        return modifiers
    }
}
