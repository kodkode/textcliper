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

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private weak var editWindow: NSWindow?
    private var capturedText: String = ""
    private var hotkeyRegistered = false
    private var autoEditEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        // Register global hotkey (⌘⇧8)
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
        let success = HotkeyManager.shared.registerHotkey { [weak self] in
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
        menu?.addItem(captureItem)

        let editItem = NSMenuItem(
            title: "Edit Captured Text",
            action: #selector(toggleAuto),
            keyEquivalent: ""
        )
        editItem.target = self
        editItem.state = autoEditEnabled ? .on : .off
        menu?.addItem(editItem)

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
