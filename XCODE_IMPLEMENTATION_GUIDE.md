# Xcode Implementation Guide for Screen to Text (textcliper)

## Project Context

This guide is for implementing the Screen to Text macOS menu bar application in Xcode using Swift and SwiftUI, replicating the functionality of the Python version in this repository.

## Project Details from User

- **Project Name**: `textcliper` (note: no second 'p')
- **Language**: Swift
- **UI Framework**: SwiftUI (macOS App)
- **Main Files**:
  - `ContentView.swift` (current UI)
  - `textcliperApp.swift` (app entry point)
  - Test files included

## Required Functionality (from Python version)

### Core Features
1. **Menu Bar App**: Runs in menu bar (no dock icon, no main window)
2. **Screenshot + OCR**: Capture screen selection → extract text with Vision framework
3. **Global Hotkey**: ⌘⇧8 triggers screenshot + OCR + copy to clipboard
4. **Menu Items**:
   - "Capture Screenshot" - manual trigger
   - "Edit Captured Text" - opens window to edit before copying
   - "Quit" - exits app

### Technical Implementation Requirements

#### 1. App Configuration

**Info.plist additions:**
```xml
<key>NSScreenCaptureUsageDescription</key>
<string>This app needs screen recording permission to capture screenshots for text extraction.</string>
<key>NSAccessibilityUsageDescription</key>
<string>This app needs accessibility permission to register the global hotkey (⌘⇧8).</string>
<key>LSUIElement</key>
<true/>
```
Note: `LSUIElement` hides the dock icon and makes it menu-bar-only

**Entitlements needed:**
- Screen Recording capability (automatic with usage description)
- Accessibility (for global hotkey)

#### 2. Menu Bar Setup (NSStatusItem)

Convert from window-based app to menu bar app:

```swift
import SwiftUI
import AppKit

@main
struct textcliperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "🔍" // Or use SF Symbol
        }

        // Create menu
        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: "Capture Screenshot", action: #selector(captureScreenshot), keyEquivalent: ""))
        menu?.addItem(NSMenuItem(title: "Edit Captured Text", action: #selector(editText), keyEquivalent: ""))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Setup global hotkey (⌘⇧8)
        setupGlobalHotkey()
    }

    @objc func captureScreenshot() {
        // Implementation below
    }

    @objc func editText() {
        // Implementation below
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func setupGlobalHotkey() {
        // Implementation below
    }
}
```

#### 3. Screenshot Capture

Use native `screencapture` command for interactive selection:

```swift
import Foundation

func captureScreenshot(completion: @escaping (URL?) -> Void) {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("screenshot_\(UUID().uuidString).png")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-i", tempURL.path] // -i for interactive selection

    process.terminationHandler = { process in
        DispatchQueue.main.async {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                completion(tempURL)
            } else {
                completion(nil) // User cancelled
            }
        }
    }

    try? process.run()
}
```

#### 4. OCR with Vision Framework

Use Vision framework revision 3 (LiveText) for best accuracy:

```swift
import Vision
import AppKit

func performOCR(on imageURL: URL, completion: @escaping (String?) -> Void) {
    guard let image = NSImage(contentsOf: imageURL),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        completion(nil)
        return
    }

    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            completion(nil)
            return
        }

        let recognizedText = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }.joined(separator: "\n")

        // Minimal post-processing (remove artifact lines)
        let cleaned = cleanText(recognizedText)
        completion(cleaned)
    }

    // Use revision 3 (LiveText) for best accuracy - requires macOS 13+
    if #available(macOS 13, *) {
        request.revision = VNRecognizeTextRequestRevision3
    } else {
        request.revision = VNRecognizeTextRequestRevision1
    }

    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? handler.perform([request])
}

func cleanText(_ text: String) -> String {
    // Remove artifact lines (repeated single characters like "eee")
    let lines = text.components(separatedBy: .newlines)
    let cleaned = lines.filter { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 {
            return true
        }
        let uniqueChars = Set(trimmed)
        return uniqueChars.count > 1 // Keep lines with varied characters
    }
    return cleaned.joined(separator: "\n")
}
```

#### 5. Clipboard Integration

```swift
import AppKit

func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}
```

#### 6. Global Hotkey (⌘⇧8)

Use Carbon API or CGEvent for global hotkey:

```swift
import Carbon

var hotKeyRef: EventHotKeyRef?
var eventHandler: EventHandlerRef?

func setupGlobalHotkey() {
    let hotKeyID = EventHotKeyID(signature: OSType(0x54584554), id: 1) // 'TEXT'
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                   eventKind: OSType(kEventHotKeyPressed))

    InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
        captureAndProcess()
        return noErr
    }, 1, &eventType, nil, &eventHandler)

    // ⌘⇧8 = Command + Shift + 8
    RegisterEventHotKey(UInt32(kVK_ANSI_8),
                        UInt32(cmdKey | shiftKey),
                        hotKeyID,
                        GetApplicationEventTarget(),
                        0,
                        &hotKeyRef)
}

func captureAndProcess() {
    captureScreenshot { url in
        guard let imageURL = url else { return }

        performOCR(on: imageURL) { text in
            guard let recognizedText = text else { return }

            copyToClipboard(recognizedText)

            // Optional: Show notification
            showNotification(title: "Text Copied", message: "\(recognizedText.prefix(50))...")

            // Cleanup temp file
            try? FileManager.default.removeItem(at: imageURL)
        }
    }
}
```

#### 7. Edit Text Window Feature

Create a separate window for text editing (from Python version's recent feature):

```swift
import SwiftUI

struct TextEditorWindow: View {
    @Binding var text: String
    var onCopy: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Captured Text")
                .font(.headline)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 500, minHeight: 300)
                .border(Color.gray.opacity(0.3))

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Copy to Clipboard") {
                    copyToClipboard(text)
                    onCopy()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 600, height: 400)
    }
}

// In AppDelegate:
var editWindow: NSWindow?
var capturedText: String = ""

@objc func editText() {
    if capturedText.isEmpty {
        // Show alert that no text has been captured yet
        let alert = NSAlert()
        alert.messageText = "No Text Captured"
        alert.informativeText = "Please capture a screenshot first."
        alert.runModal()
        return
    }

    let contentView = TextEditorWindow(text: .constant(capturedText)) {
        // On copy callback
    }

    editWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    editWindow?.contentView = NSHostingView(rootView: contentView)
    editWindow?.title = "Edit Captured Text"
    editWindow?.center()
    editWindow?.makeKeyAndOrderFront(nil)
}
```

#### 8. Notifications (Optional)

```swift
import UserNotifications

func showNotification(title: String, message: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message

    let request = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: nil)

    UNUserNotificationCenter.current().add(request)
}

// Request permission in applicationDidFinishLaunching:
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
```

## Implementation Steps

1. **Modify Info.plist**: Add usage descriptions and LSUIElement
2. **Update textcliperApp.swift**: Implement AppDelegate with menu bar setup
3. **Create OCRService.swift**: Put screenshot + OCR logic in separate file
4. **Create TextEditorWindow.swift**: SwiftUI view for text editing
5. **Add global hotkey**: Implement Carbon-based hotkey registration
6. **Test permissions**: Run and grant Screen Recording + Accessibility permissions
7. **Build & distribute**: Archive and export (optionally code-sign)

## Testing Checklist

- [ ] App appears in menu bar (not dock)
- [ ] Menu items work (Capture Screenshot, Edit Text, Quit)
- [ ] ⌘⇧8 triggers screenshot capture
- [ ] Interactive screenshot selection works
- [ ] OCR extracts text accurately
- [ ] Text copied to clipboard automatically
- [ ] Edit Text window allows modifications before copying
- [ ] Permissions requested on first run
- [ ] Works on macOS 13+ with LiveText (revision 3)
- [ ] Graceful fallback on older macOS versions

## File Structure

```
textcliper/
├── textcliperApp.swift          # Main app + AppDelegate
├── ContentView.swift             # Can be minimal or removed
├── OCRService.swift              # Screenshot + OCR logic
├── TextEditorWindow.swift        # Edit text UI
├── Info.plist                    # Permissions + LSUIElement
├── textcliper.entitlements       # App capabilities
└── Assets.xcassets               # Optional: custom icon
```

## Key Differences from Python Version

- **No external dependencies**: Everything is native macOS
- **Better performance**: Native APIs, no PyInstaller overhead
- **Proper code signing**: Can be signed and notarized for distribution
- **Native UI**: SwiftUI for edit window, native menu bar
- **Automatic permission prompts**: System handles permission UI

## Distribution Notes

Unlike the Python version which requires Gatekeeper bypass:
- Can be properly code-signed with Apple Developer account
- Can be notarized for smooth installation
- Users won't see security warnings if properly signed

## References

- Python implementation: See `menubar_app.py` in parent directory
- Vision framework docs: https://developer.apple.com/documentation/vision
- NSStatusItem docs: https://developer.apple.com/documentation/appkit/nsstatusitem
- Carbon hotkey: https://developer.apple.com/documentation/carbon/1572321-registereventhotkey
