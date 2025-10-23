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
    private weak var historyWindow: NSWindow?
    private weak var settingsWindow: NSWindow?
    private var capturedText: String = ""
    private var hotkeyRegistered = false
    private var additiveClipboardEnabled = false // Additive clipboard mode
    private var currentKeySequence: KeySequence = KeySequence(legacyKeyCode: UInt32(kVK_ANSI_8), legacyModifiers: UInt32(cmdKey | shiftKey))
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

        // Listen for notifications from SettingsView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowHotkeyRecorder),
            name: NSNotification.Name("ShowHotkeyRecorder"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowAPIKeyConfig),
            name: NSNotification.Name("ShowAPIKeyConfig"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateMenuBarVisibility),
            name: NSNotification.Name("UpdateMenuBarVisibility"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateAdditiveClipboard),
            name: NSNotification.Name("UpdateAdditiveClipboard"),
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
            sequence: currentKeySequence
        ) { [weak self] in
            print("🔥 Hotkey triggered!")
            self?.triggerCaptureAndCopy()
        }

        if success {
            hotkeyRegistered = true
            print("✅ Hotkey successfully registered: \(currentKeySequence.displayString())")
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

        let additiveClipboardItem = NSMenuItem(
            title: "Additive Clipboard",
            action: #selector(toggleAdditiveClipboard),
            keyEquivalent: ""
        )
        additiveClipboardItem.target = self
        additiveClipboardItem.state = additiveClipboardEnabled ? .on : .off
        menu?.addItem(additiveClipboardItem)

        menu?.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(
            title: "History...",
            action: #selector(openHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        menu?.addItem(historyItem)

        menu?.addItem(NSMenuItem.separator())

        let aiEnhancedItem = NSMenuItem(
            title: "AI-Enhanced OCR",
            action: #selector(toggleAIEnhanced),
            keyEquivalent: ""
        )
        aiEnhancedItem.target = self
        aiEnhancedItem.state = UserDefaults.standard.bool(forKey: "aiEnhancedOCREnabled") ? .on : .off
        menu?.addItem(aiEnhancedItem)

        // AI Provider submenu
        let aiProviderItem = NSMenuItem(
            title: "AI Provider",
            action: nil,
            keyEquivalent: ""
        )
        let aiProviderMenu = NSMenu()

        let currentProvider = UserDefaults.standard.string(forKey: "aiProvider") ?? "openai"

        let useOpenAIItem = NSMenuItem(
            title: "OpenAI",
            action: #selector(selectOpenAI),
            keyEquivalent: ""
        )
        useOpenAIItem.target = self
        useOpenAIItem.state = (currentProvider == "openai") ? .on : .off
        aiProviderMenu.addItem(useOpenAIItem)

        // OpenAI model submenu
        if currentProvider == "openai" {
            aiProviderMenu.addItem(NSMenuItem.separator())

            let openAIModelItem = NSMenuItem(title: "OpenAI Model", action: nil, keyEquivalent: "")
            let openAIModelMenu = NSMenu()

            let currentOpenAIModel = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o"

            let openAIModels = [
                ("gpt-4o", "GPT-4o (Recommended)"),
                ("gpt-4o-mini", "GPT-4o Mini (Faster)"),
                ("gpt-4-turbo", "GPT-4 Turbo"),
                ("gpt-4", "GPT-4"),
                ("o1", "o1 (Reasoning)"),
                ("o1-mini", "o1 Mini (Reasoning)")
            ]

            for (modelId, modelName) in openAIModels {
                let modelItem = NSMenuItem(title: modelName, action: #selector(selectOpenAIModel(_:)), keyEquivalent: "")
                modelItem.target = self
                modelItem.representedObject = modelId
                modelItem.state = (currentOpenAIModel == modelId) ? .on : .off
                openAIModelMenu.addItem(modelItem)
            }

            openAIModelItem.submenu = openAIModelMenu
            aiProviderMenu.addItem(openAIModelItem)
        }

        let useGeminiItem = NSMenuItem(
            title: "Google Gemini",
            action: #selector(selectGemini),
            keyEquivalent: ""
        )
        useGeminiItem.target = self
        useGeminiItem.state = (currentProvider == "gemini") ? .on : .off
        aiProviderMenu.addItem(useGeminiItem)

        // Gemini model submenu
        if currentProvider == "gemini" {
            aiProviderMenu.addItem(NSMenuItem.separator())

            let geminiModelItem = NSMenuItem(title: "Gemini Model", action: nil, keyEquivalent: "")
            let geminiModelMenu = NSMenu()

            let currentGeminiModel = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.5-flash"

            let models = [
                ("gemini-2.5-flash", "Gemini 2.5 Flash (Recommended)"),
                ("gemini-2.0-flash-exp", "Gemini 2.0 Flash Exp")
            ]

            for (modelId, modelName) in models {
                let modelItem = NSMenuItem(title: modelName, action: #selector(selectGeminiModel(_:)), keyEquivalent: "")
                modelItem.target = self
                modelItem.representedObject = modelId
                modelItem.state = (currentGeminiModel == modelId) ? .on : .off
                geminiModelMenu.addItem(modelItem)
            }

            geminiModelItem.submenu = geminiModelMenu
            aiProviderMenu.addItem(geminiModelItem)
        }

        let useOCRSpaceItem = NSMenuItem(
            title: "OCR.space",
            action: #selector(selectOCRSpace),
            keyEquivalent: ""
        )
        useOCRSpaceItem.target = self
        useOCRSpaceItem.state = (currentProvider == "ocrspace") ? .on : .off
        aiProviderMenu.addItem(useOCRSpaceItem)

        aiProviderItem.submenu = aiProviderMenu
        menu?.addItem(aiProviderItem)

        let configureAPIItem = NSMenuItem(
            title: "Configure API Keys...",
            action: #selector(configureAPIKey),
            keyEquivalent: ""
        )
        configureAPIItem.target = self
        menu?.addItem(configureAPIItem)

        menu?.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu?.addItem(settingsItem)

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

    @objc private func toggleAdditiveClipboard(_ sender: NSMenuItem) {
        additiveClipboardEnabled.toggle()
        sender.state = additiveClipboardEnabled ? .on : .off

        let status = additiveClipboardEnabled ? "enabled" : "disabled"
        print("📋 Additive Clipboard \(status)")

        // Clear clipboard when toggling OFF
        if !additiveClipboardEnabled {
            NSPasteboard.general.clearContents()
            print("🗑️ Clipboard cleared")
        }

        // Show a brief notification
        showNotification(
            title: "Additive Clipboard \(additiveClipboardEnabled ? "Enabled" : "Disabled")",
            message: additiveClipboardEnabled
                ? "New captures will be appended to clipboard"
                : "Clipboard cleared - new captures will replace content"
        )
    }

    @objc private func toggleAIEnhanced(_ sender: NSMenuItem) {
        let currentValue = UserDefaults.standard.bool(forKey: "aiEnhancedOCREnabled")
        let newValue = !currentValue

        // Check if API key is configured when enabling
        if newValue {
            let provider = UserDefaults.standard.string(forKey: "aiProvider") ?? "openai"
            let hasKey: Bool
            let providerName: String

            if provider == "openai" {
                hasKey = KeychainService.shared.getOpenAIKey() != nil
                providerName = "OpenAI"
            } else if provider == "gemini" {
                hasKey = KeychainService.shared.getGeminiKey() != nil
                providerName = "Gemini"
            } else if provider == "ocrspace" {
                hasKey = KeychainService.shared.getOCRSpaceKey() != nil
                providerName = "OCR.space"
            } else {
                hasKey = false
                providerName = "Unknown"
            }

            if !hasKey {
                showAlert(
                    title: "API Key Required",
                    message: "Please configure your \(providerName) API key first using 'Configure API Keys...' menu option."
                )
                return
            }
        }

        UserDefaults.standard.set(newValue, forKey: "aiEnhancedOCREnabled")
        sender.state = newValue ? .on : .off

        let status = newValue ? "enabled" : "disabled"
        print("🤖 AI-Enhanced OCR \(status)")
    }

    @objc private func selectOpenAI() {
        UserDefaults.standard.set("openai", forKey: "aiProvider")
        setupMenu() // Refresh menu to update checkmarks
        let model = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o"
        print("🔄 Switched to OpenAI (\(model))")
    }

    @objc private func selectGemini() {
        UserDefaults.standard.set("gemini", forKey: "aiProvider")
        setupMenu() // Refresh menu to update checkmarks
        let model = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.5-flash"
        print("🔄 Switched to Google Gemini (\(model))")
    }

    @objc private func selectOCRSpace() {
        UserDefaults.standard.set("ocrspace", forKey: "aiProvider")
        setupMenu() // Refresh menu to update checkmarks
        print("🔄 Switched to OCR.space")
    }

    @objc private func selectGeminiModel(_ sender: NSMenuItem) {
        guard let modelId = sender.representedObject as? String else { return }
        UserDefaults.standard.set(modelId, forKey: "geminiModel")
        setupMenu() // Refresh menu to update checkmarks
        print("🔄 Switched Gemini model to \(modelId)")
    }

    @objc private func selectOpenAIModel(_ sender: NSMenuItem) {
        guard let modelId = sender.representedObject as? String else { return }
        UserDefaults.standard.set(modelId, forKey: "openaiModel")
        setupMenu() // Refresh menu to update checkmarks
        print("🔄 Switched OpenAI model to \(modelId)")
    }

    @objc private func configureAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Configure API Keys"
        alert.informativeText = "Configure your AI provider API keys.\nKeys are stored securely in macOS Keychain."
        alert.alertStyle = .informational

        // Create container view for all text fields (increased height for 3 fields)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 180))

        // OpenAI label and field
        let openAILabel = NSTextField(labelWithString: "OpenAI API Key:")
        openAILabel.frame = NSRect(x: 0, y: 152, width: 340, height: 20)
        container.addSubview(openAILabel)

        let openAIField = NSTextField(frame: NSRect(x: 0, y: 128, width: 340, height: 24))
        openAIField.placeholderString = "sk-proj-..."
        openAIField.stringValue = KeychainService.shared.getOpenAIKey() ?? ""
        openAIField.drawsBackground = true
        openAIField.backgroundColor = NSColor.textBackgroundColor
        openAIField.isBordered = true
        openAIField.bezelStyle = .squareBezel
        container.addSubview(openAIField)

        // Gemini label and field
        let geminiLabel = NSTextField(labelWithString: "Gemini API Key:")
        geminiLabel.frame = NSRect(x: 0, y: 96, width: 340, height: 20)
        container.addSubview(geminiLabel)

        let geminiField = NSTextField(frame: NSRect(x: 0, y: 72, width: 340, height: 24))
        geminiField.placeholderString = "AIza..."
        geminiField.stringValue = KeychainService.shared.getGeminiKey() ?? ""
        geminiField.drawsBackground = true
        geminiField.backgroundColor = NSColor.textBackgroundColor
        geminiField.isBordered = true
        geminiField.bezelStyle = .squareBezel
        container.addSubview(geminiField)

        // OCR.space label and field
        let ocrSpaceLabel = NSTextField(labelWithString: "OCR.space API Key:")
        ocrSpaceLabel.frame = NSRect(x: 0, y: 40, width: 340, height: 20)
        container.addSubview(ocrSpaceLabel)

        let ocrSpaceField = NSTextField(frame: NSRect(x: 0, y: 16, width: 340, height: 24))
        ocrSpaceField.placeholderString = "K8..."
        ocrSpaceField.stringValue = KeychainService.shared.getOCRSpaceKey() ?? ""
        ocrSpaceField.drawsBackground = true
        ocrSpaceField.backgroundColor = NSColor.textBackgroundColor
        ocrSpaceField.isBordered = true
        ocrSpaceField.bezelStyle = .squareBezel
        container.addSubview(ocrSpaceField)

        alert.accessoryView = container
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Save OpenAI key
            let openAIKey = openAIField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !openAIKey.isEmpty {
                if KeychainService.shared.saveOpenAIKey(openAIKey) {
                    print("✅ OpenAI API key saved to Keychain")
                } else {
                    showAlert(title: "Error", message: "Failed to save OpenAI API key.")
                    return
                }
            }

            // Save Gemini key
            let geminiKey = geminiField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !geminiKey.isEmpty {
                if KeychainService.shared.saveGeminiKey(geminiKey) {
                    print("✅ Gemini API key saved to Keychain")
                } else {
                    showAlert(title: "Error", message: "Failed to save Gemini API key.")
                    return
                }
            }

            // Save OCR.space key
            let ocrSpaceKey = ocrSpaceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ocrSpaceKey.isEmpty {
                if KeychainService.shared.saveOCRSpaceKey(ocrSpaceKey) {
                    print("✅ OCR.space API key saved to Keychain")
                } else {
                    showAlert(title: "Error", message: "Failed to save OCR.space API key.")
                    return
                }
            }

            showAlert(title: "Success", message: "API keys saved successfully!")
        }
    }

    @objc private func openHistory() {
        // Close existing window if open
        historyWindow?.close()

        let contentView = HistoryView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Capture History"
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.isReleasedWhenClosed = false

        historyWindow = window
    }

    @objc private func openSettings() {
        // Close existing window if open
        settingsWindow?.close()

        let contentView = SettingsView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Settings"
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.isReleasedWhenClosed = false

        settingsWindow = window
    }

    @objc private func configureHotkey() {
        // Close existing window if open
        hotkeyWindow?.close()

        // Create binding holder for sequence
        let sequenceHolder = KeySequenceHolder(sequence: currentKeySequence)

        let contentView = HotkeyRecorderWindow(
            sequence: sequenceHolder.binding
        ) { [weak self] newSequence in
            self?.updateHotkey(sequence: newSequence)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Configure Hotkey Sequence"
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.isReleasedWhenClosed = false

        hotkeyWindow = window
    }

    private func updateHotkey(sequence: KeySequence) {
        currentKeySequence = sequence
        saveHotkeyPreferences()
        updateCaptureMenuItemKeyEquivalent()
        attemptHotkeyRegistration()
    }

    private func updateCaptureMenuItemKeyEquivalent() {
        guard let menuItem = captureMenuItem else { return }

        // For sequences, we can't use traditional menu shortcuts
        // Instead, update the menu title to show the sequence
        let sequenceDisplay = currentKeySequence.compactDisplayString()
        menuItem.title = "Capture Screenshot (\(sequenceDisplay))"

        // Clear any key equivalent
        menuItem.keyEquivalent = ""
        menuItem.keyEquivalentModifierMask = []
    }

    private func saveHotkeyPreferences() {
        // Save as JSON
        if let jsonString = currentKeySequence.toJSONString() {
            UserDefaults.standard.set(jsonString, forKey: "hotkeySequence")
            print("💾 Saved hotkey sequence: \(currentKeySequence.displayString())")
        }
    }

    private func loadHotkeyPreferences() {
        // Try to load new JSON format first
        if let jsonString = UserDefaults.standard.string(forKey: "hotkeySequence"),
           let sequence = KeySequence.fromJSONString(jsonString) {
            currentKeySequence = sequence
            print("📂 Loaded hotkey sequence: \(currentKeySequence.displayString())")
            return
        }

        // Fall back to legacy format (keyCode + modifiers)
        if let savedKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? UInt32,
           let savedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt32 {
            currentKeySequence = KeySequence(legacyKeyCode: savedKeyCode, legacyModifiers: savedModifiers)
            print("📂 Loaded legacy hotkey, converted to sequence: \(currentKeySequence.displayString())")
            // Save in new format
            saveHotkeyPreferences()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Notification Handlers

    @objc private func handleShowHotkeyRecorder(_ notification: Notification) {
        configureHotkey()
    }

    @objc private func handleShowAPIKeyConfig(_ notification: Notification) {
        configureAPIKey()
    }

    @objc private func handleUpdateMenuBarVisibility(_ notification: Notification) {
        if let showIcon = notification.object as? Bool {
            if showIcon {
                if statusItem == nil {
                    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                    if let button = statusItem?.button {
                        button.image = NSImage(systemSymbolName: "doc.text.viewfinder", accessibilityDescription: "Screen to Text")
                        button.imagePosition = .imageLeading
                    }
                    statusItem?.menu = menu
                }
            } else {
                if let item = statusItem {
                    NSStatusBar.system.removeStatusItem(item)
                    statusItem = nil
                }
            }
        }
    }

    @objc private func handleUpdateAdditiveClipboard(_ notification: Notification) {
        if let enabled = notification.object as? Bool {
            additiveClipboardEnabled = enabled
            // Update menu item state if needed
            setupMenu()
        }
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
        // Automatically process text (detect and format tables)
        let processedText = TextProcessingService.shared.autoProcessCapture(text)
        capturedText = processedText

        // Copy to clipboard with additive mode if enabled
        let copyResult = ClipboardManager.shared.copyToClipboard(processedText, additive: additiveClipboardEnabled)

        switch copyResult {
        case .success:
            let preview = String(processedText.prefix(100))
            let ellipsis = processedText.count > 100 ? "..." : ""
            let characterCount = processedText.count
            let wordCount = processedText.split(separator: " ").count

            // Add to history (save processed text)
            let historyItem = HistoryItem(text: processedText)
            HistoryService.shared.addItem(historyItem)

            // Sync to iCloud if enabled
            if CloudSyncService.shared.iCloudSyncEnabled {
                Task {
                    try? await CloudSyncService.shared.uploadItem(historyItem)
                }
            }

            // Show success HUD
            HUDManager.shared.showHUD(
                message: "\(preview)\(ellipsis)",
                characterCount: characterCount,
                wordCount: wordCount,
                fullText: text,
                showActions: false,
                isAdditive: additiveClipboardEnabled,
                duration: 2.5
            )
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
        // Dismiss any loading HUD
        HUDManager.shared.dismissHUD()

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

        let contentView = TextEditorWindow(
            text: textHolder.binding,
            onCopy: { [weak self] editedText in
                self?.capturedText = editedText
                let result = ClipboardManager.shared.copyToClipboard(editedText)

                if case .success = result {
                    self?.showNotification(
                        title: "Text Copied",
                        message: "Edited text copied to clipboard."
                    )
                }
            },
            showShareActions: false
        )

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
private class KeySequenceHolder: ObservableObject {
    @Published var sequence: KeySequence

    init(sequence: KeySequence) {
        self.sequence = sequence
    }

    var binding: Binding<KeySequence> {
        Binding(
            get: { self.sequence },
            set: { self.sequence = $0 }
        )
    }
}
