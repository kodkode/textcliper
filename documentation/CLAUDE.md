# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**textclipper** is a macOS menu bar utility that captures screenshots and extracts text using OCR (Optical Character Recognition). The app runs as an LSUIElement (background app with menu bar icon) and provides a global hotkey (⌘⇧8) for quick screenshot-to-text capture.

## Architecture

### Core Components

The app uses a **singleton-based service architecture** where each major functionality is encapsulated in its own service class:

1. **AppDelegate** (textclipper/AppDelegate.swift) - Central coordinator
   - Manages menu bar status item and UI
   - Orchestrates all services (OCR, hotkey, clipboard)
   - Handles app lifecycle and permission flows
   - Owns the notification and alert system

2. **OCRService** (textclipper/OCRService.swift) - Screenshot + text extraction
   - Uses `/usr/sbin/screencapture` for screenshot capture (NOT CGWindowListCreateImage)
   - Leverages Apple's Vision framework for OCR
   - Process-based approach with async completion handlers
   - Temp file management in system temp directory

3. **HotkeyManager** (textclipper/HotkeyManager.swift) - Global hotkey registration
   - Uses Carbon Event Manager (EventHotKeyRef)
   - Requires Accessibility permissions
   - Registers ⌘⇧8 globally across macOS

4. **ClipboardManager** (textclipper/ClipboardManager.swift) - System pasteboard access
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
xcodebuild build -project textclipper.xcodeproj -scheme textclipper -configuration Debug

# Run from Xcode (recommended for development)
# Open textclipper.xcodeproj in Xcode and press Cmd+R
```

### Testing
```bash
# Run unit tests
xcodebuild test -project textclipper.xcodeproj -scheme textclipper -destination 'platform=macOS'

# Clean build
xcodebuild clean -project textclipper.xcodeproj -scheme textclipper
```

### Local Installation (Test as End User)
```bash
# Install to /Applications for production testing
./install_to_applications.sh

# This script will:
# 1. Build Release configuration
# 2. Terminate running instances
# 3. Remove old version from /Applications
# 4. Copy new build to /Applications
# 5. Launch the installed app

# After installation, grant permissions to "textclipper" (not "Xcode"):
# - System Settings → Privacy & Security → Screen Recording
# - System Settings → Privacy & Security → Accessibility
```

### Fresh Installation Simulation (New User Experience)
```bash
# To test the complete new user experience (onboarding, first launch, etc.)
# First, reset ALL app data and permissions:
./reset_for_fresh_install.sh

# This will remove:
# - All capture history and API keys
# - App preferences and settings
# - iCloud sync local cache
# - Privacy permissions
# - Onboarding completion status
# - Sandboxed container data

# Then reinstall:
./install_to_applications.sh

# The app will now behave exactly as it would for a first-time user:
# - Onboarding flow will be shown
# - No history or saved data
# - Permissions must be granted
# - API keys must be configured
```

### Verify Build Configuration
```bash
# Check critical build settings
xcodebuild -showBuildSettings -project textclipper.xcodeproj -scheme textclipper | grep -E "ENABLE_APP_SANDBOX|GENERATE_INFOPLIST_FILE|INFOPLIST_FILE"

# Expected output (Release configuration):
#   ENABLE_APP_SANDBOX = YES  (App Store requirement)
#   GENERATE_INFOPLIST_FILE = NO
#   INFOPLIST_FILE = textclipper/Info.plist

# Verify permission strings in built app
plutil -p ~/Library/Developer/Xcode/DerivedData/textclipper*/Build/Products/Debug/textclipper.app/Contents/Info.plist | grep Usage

# Verify sandbox entitlement for screencapture
codesign -d --entitlements - ~/Library/Developer/Xcode/DerivedData/textclipper*/Build/Products/Release/textclipper.app | grep -A 2 "temporary-exception"
```

## Critical Configuration

### ⚠️ DO NOT Change These Settings

1. **App Sandbox Configuration (App Store Version)**
   - Setting: `ENABLE_APP_SANDBOX = YES` in Release configuration (required for App Store)
   - Special entitlement: `com.apple.security.temporary-exception.mach-register.global-name` with value `com.apple.screencapture.interactive`
   - This allows `/usr/sbin/screencapture` to work within the sandbox (similar to TextSniper)
   - **Critical**: The entitlement MUST be present in `textclipper.entitlements` for interactive screenshot selection to work
   - If removed: Screenshot capture will fail even with Screen Recording permission

2. **Manual Info.plist MUST Be Used**
   - Settings in project.pbxproj:
     - `GENERATE_INFOPLIST_FILE = NO`
     - `INFOPLIST_FILE = textclipper/Info.plist`
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
plutil -p ~/Library/Developer/Xcode/DerivedData/textclipper*/Build/Products/Debug/textclipper.app/Contents/Info.plist | grep NSScreenCaptureUsageDescription

# 2. Verify sandbox configuration and entitlements
xcodebuild -showBuildSettings -project textclipper.xcodeproj -scheme textclipper -configuration Release | grep ENABLE_APP_SANDBOX
codesign -d --entitlements - ~/Library/Developer/Xcode/DerivedData/textclipper*/Build/Products/Release/textclipper.app | grep -A 2 "temporary-exception"

# 3. Reset permissions for clean test
tccutil reset ScreenCapture
killall textclipper

# 4. Check entitlements
codesign -d --entitlements - ~/Library/Developer/Xcode/DerivedData/textclipper*/Build/Products/Debug/textclipper.app
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
- **Cause**: Missing temporary-exception entitlement
- **Fix**: Verify `com.apple.security.temporary-exception.mach-register.global-name` entitlement exists in `textclipper.entitlements`
- **Reason**: Sandboxed apps need this special entitlement to communicate with screencapture service

## Documentation

The repository contains extensive debugging documentation from a complex permission loop issue that was resolved:

- **[DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)** - Navigation hub for all docs
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Fast troubleshooting guide
- **[DEBUGGING_METHODOLOGY.md](DEBUGGING_METHODOLOGY.md)** - Complete debugging process
- **[LESSONS_LEARNED.md](LESSONS_LEARNED.md)** - Debugging principles and insights

These documents contain valuable information about macOS permission systems, build configuration debugging, and systematic troubleshooting methodology.

## Project Structure

```
textclipper/
├── textclipper.xcodeproj/          # Xcode project
├── textclipper/                     # Main app source
│   ├── textclipperApp.swift        # App entry point
│   ├── AppDelegate.swift          # Main coordinator
│   ├── OCRService.swift           # Screenshot + OCR
│   ├── HotkeyManager.swift        # Global hotkey
│   ├── ClipboardManager.swift     # Pasteboard access
│   ├── TextEditorWindow.swift     # Edit UI (SwiftUI)
│   ├── ContentView.swift          # Unused (Settings scene)
│   ├── Info.plist                 # App metadata (CRITICAL)
│   └── textclipper.entitlements    # App capabilities
├── textclipperTests/               # Unit tests
├── textclipperUITests/             # UI tests
└── [Documentation files]          # Debugging guides
```

## When Making Changes

### Adding New Permissions
1. Add usage description to `textclipper/Info.plist`
2. Verify it appears in built app: `plutil -p .../app.app/Contents/Info.plist`
3. Add required entitlements to `textclipper.entitlements` if needed
4. Test with clean TCC state: `tccutil reset ServiceName`

### Modifying Build Settings
1. Keep App Sandbox enabled for App Store builds (Release configuration)
2. Ensure temporary-exception entitlement remains in entitlements file
3. Never enable Info.plist auto-generation
4. Verify changes: `xcodebuild -showBuildSettings | grep SETTING_NAME`
5. Test clean build: `xcodebuild clean build`

### Debugging Permission Issues
1. Always check the BUILT app bundle, not source files
2. Use `plutil` to inspect actual Info.plist in built app
3. Use `codesign` to verify actual entitlements
4. Reset TCC between tests for clean state
5. Check Console.app for system permission logs

## iCloud Sync Implementation

### CloudKit Sync Limits

**Upload:** Unlimited - all unsynced items are uploaded to CloudKit
**Download:** Cursor-based pagination (50 items per batch)
- Automatically fetches ALL items from CloudKit using pagination
- No data loss - continues fetching until all records are downloaded
- Sorted by timestamp (newest first)

**Local Storage:**
- Maximum 1000 items (safety limit)
- Auto-deletes items older than 30 days
- Cleanup runs on app launch and when adding items

### How Pagination Works

The app uses CloudKit cursor-based pagination to ensure ALL history items are downloaded:

1. First batch: Fetches up to 50 items
2. If cursor exists: Fetches next 50 items
3. Repeats until cursor is nil (all items fetched)
4. Processes all fetched records and adds new items to local storage

**Example:** If you have 700 items in iCloud:
- Batch 1: Items 1-50
- Batch 2: Items 51-100
- ...
- Batch 14: Items 651-700
- Result: All 700 items downloaded successfully

This ensures no data loss when:
- Reinstalling the app
- Setting up on a new device
- After clearing local data
- After being offline for extended periods

## Important Notes

- The app is designed to run as LSUIElement (no dock icon, menu bar only)
- All UI is menu-based except for the text editor window
- Screenshot selection is handled by the system screencapture tool (interactive)
- OCR happens on background thread with main-thread completion
- Temp files are automatically cleaned up after OCR
- The app supports both hotkey trigger and manual menu trigger
- iCloud sync uses cursor-based pagination to download ALL items (no 50-item limit)
