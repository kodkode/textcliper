//
//  AppDelegate.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//

import AppKit
import SwiftUI
import UserNotifications
import Combine
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private weak var editWindow: NSWindow?
    private weak var hotkeyWindow: NSWindow?
    private var capturedText: String = ""
    private var hotkeyRegistered = false
    private var autoEditEnabled = false
    private var currentKeyCode: UInt32 = UInt32(kVK_ANSI_8)
    private var currentModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    private var captureMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load saved hotkey preferences
        loadHotkeyPreferences()

        // Request notification permissions
        requestNotificationPermissions()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.text.viewfinder", accessibilityDescription: "Screen to Text")
            button.imagePosition = .imageLeading
        }

        // Create menu
        setupMenu()

        // Register global hotkey
        attemptHotkeyRegistration()

        // Listen for app becoming active to retry hotkey registration
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidActivate(_ notification: Notification) {
        // Retry hotkey registration if not yet registered
        if !hotkeyRegistered {
            attemptHotkeyRegistration()
        }
    }

    private func attemptHotkeyRegistration() {
        let hasPermission = HotkeyManager.shared.checkAccessibilityPermissions()
        print("🔍 Accessibility permission check: \(hasPermission)")

        // Try to register regardless of check result
        // The check sometimes returns false even when permission is granted (Xcode bug)
        let success = HotkeyManager.shared.registerHotkey(
            keyCode: currentKeyCode,
            modifiers: currentModifiers
        ) { [weak self] in
            print("🔥 Hotkey triggered!")
            self?.triggerCaptureAndCopy()
        }

        if success {
            hotkeyRegistered = true
            print("✅ Hotkey successfully registered (⌘⇧8)")
        } else {
            print("❌ Hotkey registration failed - accessibility permission may not be granted")
            print("   Go to: System Settings > Privacy & Security > Accessibility")
            print("   Enable: Xcode (or textcliper), then restart the app")

            // Only show alert if registration actually failed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAccessibilityInstructions()
            }
        }
    }

    private func setupMenu() {
        menu = NSMenu()

        let captureItem = NSMenuItem(
            title: "Capture Screenshot",
            action: #selector(captureScreenshot),
            keyEquivalent: ""
        )
        captureItem.target = self
        captureMenuItem = captureItem
        updateCaptureMenuItemKeyEquivalent()
        menu?.addItem(captureItem)

        let barcodeItem = NSMenuItem(
            title: "Scan QR/Barcode",
            action: #selector(scanBarcode),
            keyEquivalent: ""
        )
        barcodeItem.target = self
        menu?.addItem(barcodeItem)

        let editItem = NSMenuItem(
            title: "Edit Captured Text",
            action: #selector(toggleAuto),
            keyEquivalent: ""
        )
        editItem.target = self
        editItem.state = autoEditEnabled ? .on : .off
        menu?.addItem(editItem)

        menu?.addItem(NSMenuItem.separator())

        let configureHotkeyItem = NSMenuItem(
            title: "Configure Hotkey...",
            action: #selector(configureHotkey),
            keyEquivalent: ""
        )
        configureHotkeyItem.target = self
        menu?.addItem(configureHotkeyItem)

        menu?.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func checkPermissions() {
        let hasAccessibility = HotkeyManager.shared.checkAccessibilityPermissions()

        // Check screen recording permission
        var hasScreenRecording = false
        if #available(macOS 10.15, *) {
            hasScreenRecording = CGPreflightScreenCaptureAccess()
        }

        let message = """
        Accessibility: \(hasAccessibility ? "✅ Granted" : "❌ Not Granted")
        Hotkey Registered: \(hotkeyRegistered ? "✅ Yes" : "❌ No")
        Screen Recording: \(hasScreenRecording ? "✅ Granted" : "⚠️ Will prompt on first capture")

        App Sandbox: ✅ Disabled (unsandboxed)

        Note: Screen recording permission is handled automatically by macOS.
        The first time you capture, macOS will prompt if needed.
        """

        showAlert(title: "Permission Status", message: message)

        // Try to register hotkey again if we have permission
        if hasAccessibility && !hotkeyRegistered {
            attemptHotkeyRegistration()
        }
    }

    @objc private func captureScreenshot() {
        triggerCaptureAndCopy()
    }

    @objc private func scanBarcode() {
        print("📱 Triggering QR/Barcode scan...")

        OCRService.shared.captureAndScanBarcode { [weak self] result in
            switch result {
            case .success(let barcodeData):
                self?.handleScannedBarcode(barcodeData)
            case .failure(let error):
                self?.handleBarcodeError(error)
            }
        }
    }

    @objc private func editText() {
        if capturedText.isEmpty {
            showAlert(
                title: "No Text Captured",
                message: "Please capture a screenshot first using 'Capture Screenshot' or the hotkey ⌘⇧8."
            )
            return
        }

        openEditWindow()
    }

    @objc private func toggleAuto(_ sender: NSMenuItem) {
        autoEditEnabled.toggle()
        sender.state = autoEditEnabled ? .on : .off
    }

    @objc private func configureHotkey() {
        // Close existing window if open
        hotkeyWindow?.close()

        // Create binding holders
        let keyCodeHolder = KeyCodeHolder(keyCode: currentKeyCode)
        let modifiersHolder: ModifiersHolder = ModifiersHolder(modifiers: currentModifiers)

        let contentView = HotkeyRecorderWindow(
            keyCode: keyCodeHolder.binding,
            modifiers: modifiersHolder.binding
        ) { [weak self] newKeyCode, newModifiers in
            self?.updateHotkey(keyCode: newKeyCode, modifiers: newModifiers)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Configure Hotkey"
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.isReleasedWhenClosed = false

        hotkeyWindow = window
    }

    private func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        currentKeyCode = keyCode
        currentModifiers = modifiers
        saveHotkeyPreferences()
        updateCaptureMenuItemKeyEquivalent()
        attemptHotkeyRegistration()
    }

    private func updateCaptureMenuItemKeyEquivalent() {
        guard let menuItem = captureMenuItem else { return }

        // Convert keyCode to character
        let keyChar = keyCodeToCharacter(currentKeyCode)
        menuItem.keyEquivalent = keyChar

        // Convert Carbon modifiers to NSEvent.ModifierFlags
        var modifierMask: NSEvent.ModifierFlags = []
        if (currentModifiers & UInt32(cmdKey)) != 0 {
            modifierMask.insert(.command)
        }
        if (currentModifiers & UInt32(shiftKey)) != 0 {
            modifierMask.insert(.shift)
        }
        if (currentModifiers & UInt32(optionKey)) != 0 {
            modifierMask.insert(.option)
        }
        if (currentModifiers & UInt32(controlKey)) != 0 {
            modifierMask.insert(.control)
        }

        menuItem.keyEquivalentModifierMask = modifierMask
    }

    private func keyCodeToCharacter(_ keyCode: UInt32) -> String {
        // Map common key codes to characters
        switch Int(keyCode) {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return " "
        case kVK_Return: return "\r"
        case kVK_Tab: return "\t"
        case kVK_Delete: return "\u{8}"
        case kVK_Escape: return "\u{1b}"
        default: return ""
        }
    }

    private func saveHotkeyPreferences() {
        UserDefaults.standard.set(currentKeyCode, forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(currentModifiers, forKey: "hotkeyModifiers")
    }

    private func loadHotkeyPreferences() {
        if let savedKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? UInt32 {
            currentKeyCode = savedKeyCode
        }
        if let savedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt32 {
            currentModifiers = savedModifiers
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Core Functionality

    private func triggerCaptureAndCopy() {
        // Let the screencapture tool handle permissions natively
        // macOS will prompt automatically when needed (first time only)
        print("📸 Triggering screenshot capture...")

        // Proceed with capture - screencapture will handle permission prompts
        OCRService.shared.captureAndExtractText { [weak self] result in
            switch result {
            case .success(let text):
                self?.handleExtractedText(text)
            case .failure(let error):
                self?.handleOCRError(error)
            }
        }
    }

    private func handleExtractedText(_ text: String) {
        capturedText = text

        // Copy to clipboard
        let copyResult = ClipboardManager.shared.copyToClipboard(text)

        switch copyResult {
        case .success:
            let preview = String(text.prefix(50))
            let ellipsis = text.count > 50 ? "..." : ""
            showNotification(
                title: "Text Copied",
                message: "\(preview)\(ellipsis)"
            )
            if autoEditEnabled { openEditWindow() }
        case .failure(let error):
            showAlert(
                title: "Copy Failed",
                message: "Failed to copy text to clipboard: \(error.localizedDescription)"
            )
        }
    }

    private func handleScannedBarcode(_ barcodeData: String) {
        // Copy to clipboard
        let copyResult = ClipboardManager.shared.copyToClipboard(barcodeData)

        switch copyResult {
        case .success:
            let preview = String(barcodeData.prefix(50))
            let ellipsis = barcodeData.count > 50 ? "..." : ""
            showNotification(
                title: "QR/Barcode Scanned",
                message: "\(preview)\(ellipsis)"
            )
        case .failure(let error):
            showAlert(
                title: "Copy Failed",
                message: "Failed to copy barcode data to clipboard: \(error.localizedDescription)"
            )
        }
    }

    private func handleBarcodeError(_ error: OCRError) {
        switch error {
        case .screenshotFailed:
            // User likely cancelled - no alert needed
            break
        case .imageLoadFailed:
            showAlert(
                title: "Screenshot Error",
                message: "Failed to load the captured screenshot."
            )
        case .ocrFailed:
            showAlert(
                title: "Scan Error",
                message: "Failed to scan for QR/Barcode."
            )
        case .noTextDetected:
            showAlert(
                title: "No Code Found",
                message: "No QR code or barcode was detected in the captured screenshot."
            )
        case .permissionDenied:
            showAlert(
                title: "Permission Required",
                message: "Please grant Screen Recording permission in System Settings > Privacy & Security."
            )
        }
    }

    private func handleOCRError(_ error: OCRError) {
        switch error {
        case .screenshotFailed:
            // User likely cancelled - no alert needed
            break
        case .imageLoadFailed:
            showAlert(
                title: "Screenshot Error",
                message: "Failed to load the captured screenshot."
            )
        case .ocrFailed:
            showAlert(
                title: "OCR Error",
                message: "Failed to extract text from the screenshot."
            )
        case .noTextDetected:
            showAlert(
                title: "No Text Found",
                message: "No text was detected in the captured screenshot."
            )
        case .permissionDenied:
            showAlert(
                title: "Permission Required",
                message: "Please grant Screen Recording permission in System Settings > Privacy & Security."
            )
        }
    }

    // MARK: - Edit Window

    private func openEditWindow() {
        // Close existing window if open
        editWindow?.close()

        // Create text binding using a class to hold the state
        let textHolder = TextHolder(text: capturedText)

        let contentView = TextEditorWindow(text: textHolder.binding) { [weak self] editedText in
            self?.capturedText = editedText
            let result = ClipboardManager.shared.copyToClipboard(editedText)

            if case .success = result {
                self?.showNotification(
                    title: "Text Copied",
                    message: "Edited text copied to clipboard."
                )
            }
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Edit Captured Text"
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.isReleasedWhenClosed = false

        editWindow = window
    }

    // MARK: - Notifications

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Alerts

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func showAccessibilityInstructions() {
        let alert = NSAlert()
        alert.messageText = "Enable Accessibility Permission"
        alert.informativeText = """
        To use the global hotkey (⌘⇧8), please:

        1. Click "Open System Settings" below
        2. Find "textcliper" in the list
        3. Toggle it ON
        4. Restart the app

        The app is running from Xcode, so look for:
        • "textcliper" or
        • "Xcode" (if textcliper isn't listed)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregisterHotkey()
    }
}

// MARK: - Helper Classes

/// Helper class to create a binding for the text editor
private class TextHolder: ObservableObject {
    @Published var text: String

    init(text: String) {
        self.text = text
    }

    var binding: Binding<String> {
        Binding(
            get: { self.text },
            set: { self.text = $0 }
        )
    }
}

/// Helper class to create a binding for keyCode
private class KeyCodeHolder: ObservableObject {
    @Published var keyCode: UInt32

    init(keyCode: UInt32) {
        self.keyCode = keyCode
    }

    var binding: Binding<UInt32> {
        Binding(
            get: { self.keyCode },
            set: { self.keyCode = $0 }
        )
    }
}

/// Helper class to create a binding for modifiers
private class ModifiersHolder: ObservableObject {
    @Published var modifiers: UInt32

    init(modifiers: UInt32) {
        self.modifiers = modifiers
    }

    var binding: Binding<UInt32> {
        Binding(
            get: { self.modifiers },
            set: { self.modifiers = $0 }
        )
    }
}
