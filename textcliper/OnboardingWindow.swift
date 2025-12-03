//
//  OnboardingWindow.swift
//  textcliper
//
//  Created for first-time setup experience
//

import SwiftUI
import AppKit

class OnboardingWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to textcliper"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .normal  // Use normal level so permission dialogs appear above

        let hostingView = NSHostingView(rootView: OnboardingView())
        window.contentView = hostingView

        self.init(window: window)
    }
}

struct OnboardingView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss

    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)

                ScreenRecordingPermissionPage()
                    .tag(1)

                CompletionPage()
                    .tag(2)
            }
            .tabViewStyle(.automatic)

            // Bottom navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .keyboardShortcut(.cancelAction)
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Continue") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        NSApplication.shared.keyWindow?.close()
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Welcome to textcliper")
                .font(.system(size: 26, weight: .bold))

            Text("Capture screenshots and extract text instantly")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 10)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "camera", title: "Quick Capture", description: "Press ⌘⇧8 to capture any area")
                FeatureRow(icon: "doc.text", title: "Instant OCR", description: "Automatic text recognition")
                FeatureRow(icon: "doc.on.clipboard", title: "Auto Copy", description: "Text copied to clipboard immediately")
            }
            .padding(.horizontal, 40)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Screen Recording Permission Page

struct ScreenRecordingPermissionPage: View {
    @State private var isPermissionGranted = false
    @State private var hasTriggeredRequest = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 45))
                .foregroundColor(.accentColor)
                .padding(.top, 25)

            Text("Screen Recording Permission")
                .font(.system(size: 20, weight: .bold))

            Text("Grant screen recording permission to capture screenshots")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 7) {
                InstructionStep(number: 1, text: "Click \"Grant Permission\" below")
                InstructionStep(number: 2, text: "macOS will ask for permission")
                InstructionStep(number: 3, text: "Click \"Open System Settings\"")
                InstructionStep(number: 4, text: "Enable textcliper and restart")
            }
            .padding(.horizontal, 50)
            .padding(.top, 8)

            Button(action: requestAndOpenSettings) {
                Label("Grant Permission", systemImage: "hand.raised.fill")
                    .frame(maxWidth: 250)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            if isPermissionGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Permission granted!")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            } else {
                Text("Note: You can skip this and enable it later")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
        .onAppear {
            checkScreenRecordingPermission()
            // Start checking for permission periodically
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if checkScreenRecordingPermission() {
                    timer.invalidate()
                }
            }
        }
    }

    private func requestAndOpenSettings() {
        guard !hasTriggeredRequest else {
            // Already triggered, just open settings
            openSystemSettings()
            return
        }

        hasTriggeredRequest = true

        // Trigger screencapture to show permission dialog and register app
        // The dialog will appear above our normal-level window
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", NSTemporaryDirectory() + "textcliper_temp.png"]

        do {
            try process.run()
            process.waitUntilExit()

            // Clean up temp file
            try? FileManager.default.removeItem(atPath: NSTemporaryDirectory() + "textcliper_temp.png")
        } catch {
        }
    }

    private func openSystemSettings() {
        // Open System Settings directly to Screen Recording pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    private func checkScreenRecordingPermission() -> Bool {
        // Check if we have screen recording permission
        if #available(macOS 10.15, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            DispatchQueue.main.async {
                isPermissionGranted = hasPermission
            }
            return hasPermission
        }
        return true
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Completion Page

struct CompletionPage: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 55))
                .foregroundColor(.green)
                .padding(.top, 30)

            Text("You're All Set!")
                .font(.system(size: 24, weight: .bold))

            Text("textcliper is ready to use")
                .font(.callout)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "keyboard")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Press ⌘⇧8")
                            .font(.headline)
                        Text("Capture and extract text from any screen area")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(11)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                HStack {
                    Image(systemName: "menubar.rectangle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu Bar Icon")
                            .font(.headline)
                        Text("Access settings and features from the menu bar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(11)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .frame(width: 600, height: 500)
    }
}
