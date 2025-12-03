//
//  SettingsView.swift
//  textcliper
//
//  Created by Claude on 22/10/2025.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    // General Settings
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    // OCR Settings
    @AppStorage("aiEnhancedOCREnabled") private var aiEnhancedOCR = false
    @AppStorage("aiProvider") private var aiProvider = "openai"
    @AppStorage("openaiModel") private var openaiModel = "gpt-4o"
    @AppStorage("geminiModel") private var geminiModel = "gemini-2.5-flash"

    // Clipboard Settings
    @AppStorage("additiveClipboardEnabled") private var additiveClipboard = false

    // History Settings
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 500
    @AppStorage("autoDeleteAfterDays") private var autoDeleteAfterDays = 30

    // Hotkey display
    @State private var currentHotkey: String = "⌘⇧8"
    @State private var showHotkeyRecorder = false
    @State private var showAPIKeyConfig = false
    @State private var showClearHistoryAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Configure textcliper preferences")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                // General Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("General")

                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(enabled: newValue)
                        }

                    Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                        .onChange(of: showMenuBarIcon) { _, newValue in
                            NotificationCenter.default.post(
                                name: NSNotification.Name("UpdateMenuBarVisibility"),
                                object: newValue
                            )
                        }
                }

                Divider()

                // OCR Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("OCR")

                    Toggle("AI-Enhanced OCR", isOn: $aiEnhancedOCR)
                        .help("Use AI to improve OCR accuracy and formatting")

                    HStack {
                        Text("AI Provider")
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $aiProvider) {
                            Text("OpenAI").tag("openai")
                            Text("Gemini").tag("gemini")
                            Text("OCR.space").tag("ocrspace")
                        }
                        .pickerStyle(.segmented)
                        .disabled(!aiEnhancedOCR)
                    }

                    if aiProvider != "ocrspace" {
                        HStack {
                            Text("AI Model")
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: aiProvider == "openai" ? $openaiModel : $geminiModel) {
                                if aiProvider == "openai" {
                                    Text("GPT-4o (Recommended)").tag("gpt-4o")
                                    Text("GPT-4o Mini (Faster)").tag("gpt-4o-mini")
                                    Text("GPT-4 Turbo").tag("gpt-4-turbo")
                                    Text("GPT-4").tag("gpt-4")
                                    Text("o1 (Reasoning)").tag("o1")
                                    Text("o1 Mini (Reasoning)").tag("o1-mini")
                                } else {
                                    Text("Gemini 2.5 Flash (Recommended)").tag("gemini-2.5-flash")
                                    Text("Gemini 2.0 Flash Exp").tag("gemini-2.0-flash-exp")
                                }
                            }
                            .disabled(!aiEnhancedOCR)
                        }
                    }

                    Button("Configure API Keys...") {
                        showAPIKeyConfig = true
                    }
                    .disabled(!aiEnhancedOCR)
                }

                Divider()

                // Hotkey Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Hotkey")

                    HStack {
                        Text("Global Hotkey")
                            .frame(width: 120, alignment: .leading)
                        Text(currentHotkey)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)

                        Spacer()

                        Button("Configure...") {
                            showHotkeyRecorder = true
                        }
                    }
                    .onAppear {
                        loadCurrentHotkey()
                    }
                }

                Divider()

                // Clipboard Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Clipboard")

                    Toggle("Additive Clipboard Mode", isOn: $additiveClipboard)
                        .help("Append multiple captures to clipboard instead of replacing")
                        .onChange(of: additiveClipboard) { _, newValue in
                            NotificationCenter.default.post(
                                name: NSNotification.Name("UpdateAdditiveClipboard"),
                                object: newValue
                            )
                        }
                }

                Divider()

                // History Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("History")

                    HStack {
                        Text("Max History Items")
                            .frame(width: 160, alignment: .leading)
                        TextField("", value: $maxHistoryItems, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("items")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Auto-Delete After")
                            .frame(width: 160, alignment: .leading)
                        Picker("", selection: $autoDeleteAfterDays) {
                            Text("Never").tag(0)
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                        .frame(width: 150)
                    }

                    Button("Clear History...") {
                        showClearHistoryAlert = true
                    }
                    .alert("Clear History", isPresented: $showClearHistoryAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Clear", role: .destructive) {
                            clearHistory()
                        }
                    } message: {
                        Text("Are you sure you want to clear all history items? This action cannot be undone.")
                    }
                }

                Divider()

                // About Section
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("About")

                    HStack(spacing: 16) {
                        // App Icon
                        if let appIcon = NSImage(named: "AppIcon") {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 64, height: 64)
                                .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("textcliper")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Version \(getAppVersion())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showHotkeyRecorder) {
            // Hotkey recorder will be shown via AppDelegate notification
            Text("") // Placeholder
        }
        .sheet(isPresented: $showAPIKeyConfig) {
            // API key config will be shown via AppDelegate notification
            Text("") // Placeholder
        }
        .onChange(of: showHotkeyRecorder) { _, newValue in
            if newValue {
                NotificationCenter.default.post(name: NSNotification.Name("ShowHotkeyRecorder"), object: nil)
                showHotkeyRecorder = false // Reset state
            }
        }
        .onChange(of: showAPIKeyConfig) { _, newValue in
            if newValue {
                NotificationCenter.default.post(name: NSNotification.Name("ShowAPIKeyConfig"), object: nil)
                showAPIKeyConfig = false // Reset state
            }
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }

    // MARK: - Helper Functions

    private func loadCurrentHotkey() {
        // Load from UserDefaults or use default
        if let savedKeyData = UserDefaults.standard.data(forKey: "hotkeySequence"),
           let sequence = try? JSONDecoder().decode(KeySequence.self, from: savedKeyData) {
            currentHotkey = sequence.displayString()
        } else {
            currentHotkey = "⌘⇧8"
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
        }
    }

    private func clearHistory() {
        HistoryService.shared.clearAll()
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
