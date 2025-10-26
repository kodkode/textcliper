# textcliper Backup Manifest
## Pre-App Store Refactor - Website Distribution Version

**Backup Date:** 2025-10-24
**Purpose:** Preserve non-sandboxed architecture before App Store submission refactor
**Version:** v1.0 (Commit: ad64ddb)

---

## Critical Architecture Preserved

### 1. Screenshot Capture Method
- **Implementation:** `/usr/sbin/screencapture` via Process
- **Location:** `textcliper/OCRService.swift`
- **Why Critical:** This approach is NOT sandbox-compatible but works perfectly for notarized website distribution

### 2. Build Configuration
```
ENABLE_APP_SANDBOX = NO
GENERATE_INFOPLIST_FILE = NO
INFOPLIST_FILE = textcliper/Info.plist
```
- **Location:** `textcliper.xcodeproj/project.pbxproj`
- **Why Critical:** Sandbox disabled to allow screencapture execution

### 3. Required Permissions
- Screen Recording (NSScreenCaptureUsageDescription)
- Accessibility (NSAccessibilityUsageDescription)
- **Location:** `textcliper/Info.plist`

### 4. Entitlements
- No App Sandbox
- Hardened Runtime enabled (for notarization)
- **Location:** `textcliper/textcliper.entitlements`

---

## What This Backup Contains

### Source Code
- `/textcliper/` - All Swift source files
  - `textcliperApp.swift` - App entry point
  - `AppDelegate.swift` - Main coordinator
  - `OCRService.swift` - **Critical: screencapture implementation**
  - `HotkeyManager.swift` - Global hotkey (⌘⇧8)
  - `ClipboardManager.swift` - Pasteboard access
  - `TextEditorWindow.swift` - Edit UI
  - `APIKeysView.swift` - API configuration UI
  - Other supporting files

### Configuration Files
- `textcliper.xcodeproj/` - Complete Xcode project
- `textcliper/Info.plist` - **Critical: Permission strings**
- `textcliper/textcliper.entitlements` - **Critical: No sandbox**
- `.gitignore`

### Documentation
- `CLAUDE.md` - Comprehensive project guide
- `XCODE_IMPLEMENTATION_GUIDE.md` - Build configuration details
- All other `.md` documentation files

### Build Scripts
- `build_and_sign.sh` - Signing script
- `run_textcliper.sh` - Launch script
- `test_permissions.sh` - Permission testing
- `check_accessibility.swift` - Accessibility check

### Tests
- `/textcliperTests/` - Unit tests
- `/textcliperUITests/` - UI tests

---

## NOT Included (By Design)

These are excluded to keep backup clean and portable:
- `/build/` - Build artifacts (regenerated)
- `.DS_Store` - System files
- `DerivedData/` - Xcode cache
- `/functions/node_modules/` - Firebase dependencies (reinstallable)
- `firebase-debug.log` - Temporary logs

---

## How to Restore This Backup

### Option 1: Fresh Start (Recommended)
```bash
# 1. Extract backup archive
tar -xzf textcliper-website-distribution-backup-20251024.tar.gz

# 2. Open in Xcode
open textcliper.xcodeproj

# 3. Verify critical settings
xcodebuild -showBuildSettings -project textcliper.xcodeproj -scheme textcliper | grep -E "ENABLE_APP_SANDBOX|INFOPLIST_FILE"

# Expected output:
#   ENABLE_APP_SANDBOX = NO
#   INFOPLIST_FILE = textcliper/Info.plist

# 4. Build and run
# Press Cmd+R in Xcode
```

### Option 2: Selective File Restoration
```bash
# Restore specific critical files:
cp backup/textcliper/OCRService.swift textcliper/OCRService.swift
cp backup/textcliper/Info.plist textcliper/Info.plist
cp backup/textcliper/textcliper.entitlements textcliper/textcliper.entitlements

# Restore build settings:
cp backup/textcliper.xcodeproj/project.pbxproj textcliper.xcodeproj/project.pbxproj
```

### Option 3: Compare Against App Store Version
```bash
# Use diff to see what changed:
diff -r backup/textcliper/ current/textcliper/
```

---

## Verification Checklist

After restoring, verify these critical elements:

- [ ] App Sandbox is DISABLED in build settings
- [ ] Info.plist contains NSScreenCaptureUsageDescription
- [ ] OCRService.swift uses `/usr/sbin/screencapture`
- [ ] App builds without sandbox errors
- [ ] Screenshot capture works (grants Screen Recording permission)
- [ ] Global hotkey works (⌘⇧8)

---

## Why This Backup Matters

### For Website Distribution (Notarized)
This version can be:
1. Built with Xcode
2. Signed with Developer ID
3. Notarized by Apple
4. Distributed directly via website download
5. Works on all macOS versions (13.0+)

### What Changes for App Store
The App Store version will require:
- App Sandbox ENABLED
- Replace `/usr/sbin/screencapture` with CGWindowListCreateImage or similar
- Possibly different entitlements
- Different signing (App Store distribution)
- Different permission flow

### When to Use This Backup
- If App Store submission is rejected or delayed
- To maintain website distribution option
- To compare implementation approaches
- As reference for notarization-only distribution

---

## Contact & Support

For questions about this backup or restoration:
1. Refer to `CLAUDE.md` for complete architecture documentation
2. Check `XCODE_IMPLEMENTATION_GUIDE.md` for build configuration details
3. Review commit history around ad64ddb for recent changes

---

## Backup Archive Contents

This manifest is included in the backup archive along with:
- Complete source code
- Xcode project files
- Configuration files
- Documentation
- Build scripts
- Test suites

**Total backup size:** ~2-5 MB (excluding build artifacts)
**Restoration time:** < 5 minutes
**Compatibility:** macOS 13.0+ development environment with Xcode 14+
