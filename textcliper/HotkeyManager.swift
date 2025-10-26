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
    private var carbonHotKeyRef: EventHotKeyRef?
    private var carbonEventHandler: EventHandlerRef?
    private var callback: (() -> Void)?
    private var registeredSequence: KeySequence?

    // Buffer to track recent keypresses
    private var keypressBuffer: [(press: KeyPress, time: Date)] = []
    private let maxBufferSize = 10
    private var lastSeenModifiers: UInt32 = 0  // Track actual modifier state

    private init() {
        setupCarbonEventHandler()
    }

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
        self.lastSeenModifiers = 0

        print("🔧 Registering hotkey sequence: \(sequence.displayString())")

        // For single-key sequences, use Carbon Event Manager for true global hotkeys
        if sequence.count == 1 {
            let press = sequence.presses[0]
            return registerCarbonHotkey(keyCode: press.keyCode, modifiers: press.modifiers)
        }

        // For multi-key sequences, use NSEvent monitors (requires Accessibility)
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
        // Unregister Carbon hotkey
        if let hotKeyRef = carbonHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            carbonHotKeyRef = nil
            print("🔧 Carbon hotkey unregistered")
        }

        // Unregister NSEvent monitors
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
        lastSeenModifiers = 0

        print("🔧 Hotkey unregistered")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let now = Date()
        let modifiers = event.modifierFlags.carbonModifiers()
        var didAddToBuffer = false

        if event.type == .keyDown {
            // Regular key pressed - merge any trailing modifiers into combo
            mergeModifiersIntoCombo(finalModifiers: modifiers, time: now)

            // Record the key press with current modifiers
            let keyPress = KeyPress(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            keypressBuffer.append((press: keyPress, time: now))
            print("🔵 KeyDown: keyCode=\(event.keyCode), modifiers=\(modifiers), char=\(event.characters ?? "nil")")
            didAddToBuffer = true

        } else if event.type == .flagsChanged {
            // Modifier key pressed or released
            if isModifierKeyCode(UInt32(event.keyCode)) {
                // Only record when modifiers INCREASE (a new key is pressed)
                // Ignore oscillations and decreases
                if modifiers > lastSeenModifiers {
                    // Modifier key was PRESSED - record it temporarily
                    let keyPress = KeyPress(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                    keypressBuffer.append((press: keyPress, time: now))
                    print("🟡 Modifier press: keyCode=\(event.keyCode), modifiers=\(lastSeenModifiers)→\(modifiers)")
                    didAddToBuffer = true
                } else if modifiers < lastSeenModifiers {
                    // Modifiers decreased/released - clear any pending modifier-only presses
                    print("🔻 Modifier released: modifiers=\(lastSeenModifiers)→\(modifiers)")

                    // If buffer only contains modifiers (no regular keys), clear it
                    let hasRegularKey = keypressBuffer.contains { !isModifierKeyCode($0.press.keyCode) }
                    if !hasRegularKey && !keypressBuffer.isEmpty {
                        print("🧹 Clearing modifier-only buffer")
                        keypressBuffer.removeAll()
                    }
                }
                // Always update state for modifier changes
                lastSeenModifiers = modifiers
            }
        }

        // Update last seen modifiers for keyDown events
        if event.type == .keyDown {
            lastSeenModifiers = modifiers
        }

        // Only check for match if we actually added something to the buffer
        if didAddToBuffer {
            checkForMatch(at: now)
        }
    }

    private func mergeModifiersIntoCombo(finalModifiers: UInt32, time: Date) {
        // Remove trailing modifier-only presses that are part of this combo
        var indicesToRemove: [Int] = []

        // Look backwards through buffer
        for i in stride(from: keypressBuffer.count - 1, through: 0, by: -1) {
            let entry = keypressBuffer[i]

            // Is this a modifier key?
            if isModifierKeyCode(entry.press.keyCode) {
                indicesToRemove.append(i)
                print("🔀 Merging modifier from buffer: keyCode=\(entry.press.keyCode)")
            } else {
                // Hit a non-modifier key, stop
                break
            }
        }

        // Remove the modifier-only presses
        for index in indicesToRemove.sorted(by: >) {
            keypressBuffer.remove(at: index)
        }

        if !indicesToRemove.isEmpty {
            print("✅ Merged \(indicesToRemove.count) modifiers into combo")
        }
    }

    private func checkForMatch(at now: Date) {
        print("📝 Buffer size: \(keypressBuffer.count)")

        // Trim buffer to max size
        if keypressBuffer.count > maxBufferSize {
            keypressBuffer.removeFirst()
        }

        // Clean old entries ONLY for multi-key sequences
        if let sequence = registeredSequence, sequence.count > 1 {
            let cutoffTime = now.addingTimeInterval(-sequence.maxTimeBetweenKeys * Double(sequence.count))
            keypressBuffer.removeAll { $0.time < cutoffTime }
        }

        // Check if buffer matches registered sequence
        if let sequence = registeredSequence {
            print("🎯 Checking match - Registered: \(sequence.displayString()), Buffer count: \(keypressBuffer.count)")
            if sequence.matches(buffer: keypressBuffer) {
                print("🔥 Hotkey sequence matched!")

                // Clear buffer AND reset modifier state to allow immediate re-trigger
                keypressBuffer = []
                lastSeenModifiers = 0
                print("♻️ Reset state for next trigger")

                // Trigger callback on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.callback?()
                }
            } else {
                print("❌ No match")
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

    // MARK: - Carbon Event Manager (for true global hotkeys)

    private func setupCarbonEventHandler() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]

        let callback: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            print("🔥 Carbon hotkey triggered!")

            // Trigger callback on main thread
            DispatchQueue.main.async {
                manager.callback?()
            }

            return noErr
        }

        let userDataPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventTypes,
            userDataPtr,
            &carbonEventHandler
        )
    }

    private func registerCarbonHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x48545359) // 'HTSY' (HoTkeY System)
        hotKeyID.id = 1

        // Convert Carbon modifiers to Carbon Event Manager format
        var carbonModifiers: UInt32 = 0
        if modifiers & UInt32(cmdKey) != 0 {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers & UInt32(shiftKey) != 0 {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers & UInt32(optionKey) != 0 {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers & UInt32(controlKey) != 0 {
            carbonModifiers |= UInt32(controlKey)
        }

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            carbonHotKeyRef = ref
            print("✅ Carbon hotkey registered: keyCode=\(keyCode), modifiers=\(modifiers)")
            return true
        } else {
            print("❌ Failed to register Carbon hotkey: status=\(status)")
            return false
        }
    }

    deinit {
        if let handler = carbonEventHandler {
            RemoveEventHandler(handler)
        }
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
