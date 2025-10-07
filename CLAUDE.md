# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**textcliper** is a macOS menu bar utility that captures screenshots and extracts text using OCR (Optical Character Recognition). The app runs as an LSUIElement (background app with menu bar icon) and provides a global hotkey (⌘⇧8) for quick screenshot-to-text capture.

## Architecture

### Core Components

The app uses a **singleton-based service architecture** where each major functionality is encapsulated in its own service class:

1. **AppDelegate** (textcliper/AppDelegate.swift) - Central coordinator
   - Manages menu bar status item and UI
   - Orchestrates all services (OCR, hotkey, clipboard)
   - Handles app lifecycle and permission flows
   - Owns the notification and alert system

2. **OCRService** (textcliper/OCRService.swift) - Screenshot + text extraction
   - Uses `/usr/sbin/screencapture` for screenshot capture (NOT CGWindowListCreateImage)
   - Leverages Apple's Vision framework for OCR
   - Process-based approach with async completion handlers
   - Temp file management in system temp directory

3. **HotkeyManager** (textcliper/HotkeyManager.swift) - Global hotkey registration
   - Uses Carbon Event Manager (EventHotKeyRef)
   - Requires Accessibility permissions
   - Registers ⌘⇧8 globally across macOS

4. **ClipboardManager** (textcliper/ClipboardManager.swift) - System pasteboard access
   - Simple wrapper around NSPasteboard
   - Result-based error handling

### Data Flow

```
User triggers (⌘⇧8 or menu click)
    ↓
AppDelegate.triggerCaptureAndCopy()
    ↓
OCRService.captureAndExtractText()
    ↓
    ├─→ captureScreenshot() → /usr/sbin/screencapture -i
    └─→ performOCR() → Vision VNRecognizeTextRequest
    ↓
ClipboardManager.copyToClipboard()
    ↓
UNUserNotificationCenter shows success notification
```

## Build & Run

### Development Build
```bash
# Build for development
xcodebuild build -project textcliper.xcodeproj -scheme textcliper -configuration Debug

# Run from Xcode (recommended for development)
# Open textcliper.xcodeproj in Xcode and press Cmd+R
```

### Testing
```bash
# Run unit tests
xcodebuild test -project textcliper.xcodeproj -scheme textcliper -destination 'platform=macOS'

# Clean build
xcodebuild clean -project textcliper.xcodeproj -scheme textcliper
```

### Verify Build Configuration
```bash
# Check critical build settings
xcodebuild -showBuildSettings -project textcliper.xcodeproj -scheme textcliper | grep -E "ENABLE_APP_SANDBOX|GENERATE_INFOPLIST_FILE|INFOPLIST_FILE"

# Expected output:
#   ENABLE_APP_SANDBOX = NO
#   GENERATE_INFOPLIST_FILE = NO
#   INFOPLIST_FILE = textcliper/Info.plist

# Verify permission strings in built app
plutil -p ~/Library/Developer/Xcode/DerivedData/textcliper*/Build/Products/Debug/textcliper.app/Contents/Info.plist | grep Usage
```

## Critical Configuration

### ⚠️ DO NOT Change These Settings

1. **App Sandbox MUST Be Disabled**
   - Setting: `ENABLE_APP_SANDBOX = NO` in project.pbxproj
   - Reason: The app uses `/usr/sbin/screencapture`, which cannot run in sandboxed apps
   - If enabled: Screenshot capture will fail with permission loops

2. **Manual Info.plist MUST Be Used**
   - Settings in project.pbxproj:
     - `GENERATE_INFOPLIST_FILE = NO`
     - `INFOPLIST_FILE = textcliper/Info.plist`
   - Reason: NSScreenCaptureUsageDescription and NSAccessibilityUsageDescription must be embedded
   - If auto-generated: Permission strings missing → macOS falls back to generic prompts → TCC loops

3. **No Manual Permission Checking**
   - DO NOT add `CGPreflightScreenCaptureAccess()` or `CGRequestScreenCaptureAccess()` calls
   - Reason: Creates conflicts with system permission flow, causes loops
   - Let macOS and screencapture handle permissions natively

### Required Permissions

The app requires two macOS permissions:
- **Screen Recording**: For screenshot capture via screencapture
- **Accessibility**: For global hotkey registration (⌘⇧8)

When running from Xcode, permissions are granted to Xcode itself, not the app. This is normal for development.

## Permission Debugging

If permission issues arise:

```bash
# 1. Check if permission strings are in BUILT app (not just source)
plutil -p ~/Library/Developer/Xcode/DerivedData/textcliper*/Build/Products/Debug/textcliper.app/Contents/Info.plist | grep NSScreenCaptureUsageDescription

# 2. Verify sandbox is disabled
xcodebuild -showBuildSettings -project textcliper.xcodeproj -scheme textcliper | grep ENABLE_APP_SANDBOX

# 3. Reset permissions for clean test
tccutil reset ScreenCapture
killall textcliper

# 4. Check entitlements
codesign -d --entitlements - ~/Library/Developer/Xcode/DerivedData/textcliper*/Build/Products/Debug/textcliper.app
```

**Reference**: See [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for comprehensive permission troubleshooting.

## Code Conventions

### Service Pattern
All services use singleton pattern with `static let shared`:
```swift
class ServiceName {
    static let shared = ServiceName()
    private init() {}
}
```

### Error Handling
Use Result types for operations that can fail:
```swift
func operation() -> Result<SuccessType, ErrorType>
```

### Async Operations
Use completion handlers with Result:
```swift
func asyncOperation(completion: @escaping (Result<Data, Error>) -> Void)
```

## Key Technical Details

### screencapture Usage
The app invokes screencapture via Process (not NSTask):
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
process.arguments = ["-i", tempURL.path]  // -i = interactive selection
try process.run()
```

### Hotkey Registration
Uses Carbon Event Manager (legacy but necessary for global hotkeys):
```swift
// Cmd+Shift+8
let keyCode: UInt32 = 28  // '8' key
let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
RegisterEventHotKey(keyCode, modifiers, hotKeyID, ...)
```

### OCR Processing
Uses Vision framework with VNRecognizeTextRequest:
- Revision 3 (LiveText) for macOS 13+
- Language: en-US
- Recognition level: accurate
- Language correction enabled

## Common Issues

### "Permission loop when capturing screenshots"
- **Verify**: Permission strings are in the BUILT app (not just Info.plist source)
- **Fix**: Ensure `GENERATE_INFOPLIST_FILE = NO` in project settings
- **Details**: See [DEBUGGING_METHODOLOGY.md](DEBUGGING_METHODOLOGY.md)

### "Hotkey not working"
- **Cause**: Accessibility permission not granted
- **Fix**: System Settings → Privacy & Security → Accessibility → Enable "Xcode"
- **Note**: When running from Xcode, permission goes to Xcode, not the app

### "screencapture not executing"
- **Cause**: App Sandbox enabled
- **Fix**: Verify `ENABLE_APP_SANDBOX = NO` in build settings
- **Reason**: Sandboxed apps cannot execute system binaries

## Documentation

The repository contains extensive debugging documentation from a complex permission loop issue that was resolved:

- **[DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)** - Navigation hub for all docs
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Fast troubleshooting guide
- **[DEBUGGING_METHODOLOGY.md](DEBUGGING_METHODOLOGY.md)** - Complete debugging process
- **[LESSONS_LEARNED.md](LESSONS_LEARNED.md)** - Debugging principles and insights

These documents contain valuable information about macOS permission systems, build configuration debugging, and systematic troubleshooting methodology.

## Project Structure

```
textcliper/
├── textcliper.xcodeproj/          # Xcode project
├── textcliper/                     # Main app source
│   ├── textcliperApp.swift        # App entry point
│   ├── AppDelegate.swift          # Main coordinator
│   ├── OCRService.swift           # Screenshot + OCR
│   ├── HotkeyManager.swift        # Global hotkey
│   ├── ClipboardManager.swift     # Pasteboard access
│   ├── TextEditorWindow.swift     # Edit UI (SwiftUI)
│   ├── ContentView.swift          # Unused (Settings scene)
│   ├── Info.plist                 # App metadata (CRITICAL)
│   └── textcliper.entitlements    # App capabilities
├── textcliperTests/               # Unit tests
├── textcliperUITests/             # UI tests
└── [Documentation files]          # Debugging guides
```

## When Making Changes

### Adding New Permissions
1. Add usage description to `textcliper/Info.plist`
2. Verify it appears in built app: `plutil -p .../app.app/Contents/Info.plist`
3. Add required entitlements to `textcliper.entitlements` if needed
4. Test with clean TCC state: `tccutil reset ServiceName`

### Modifying Build Settings
1. Never enable App Sandbox
2. Never enable Info.plist auto-generation
3. Verify changes: `xcodebuild -showBuildSettings | grep SETTING_NAME`
4. Test clean build: `xcodebuild clean build`

### Debugging Permission Issues
1. Always check the BUILT app bundle, not source files
2. Use `plutil` to inspect actual Info.plist in built app
3. Use `codesign` to verify actual entitlements
4. Reset TCC between tests for clean state
5. Check Console.app for system permission logs

## Important Notes

- The app is designed to run as LSUIElement (no dock icon, menu bar only)
- All UI is menu-based except for the text editor window
- Screenshot selection is handled by the system screencapture tool (interactive)
- OCR happens on background thread with main-thread completion
- Temp files are automatically cleaned up after OCR
- The app supports both hotkey trigger and manual menu trigger
