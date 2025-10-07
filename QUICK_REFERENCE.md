# 🚀 Quick Reference: macOS Permission Issues

## The 60-Second Diagnostic

### 1. Check Built App (Not Source!)
```bash
# Check if permission strings are ACTUALLY embedded
plutil -p ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/YourApp.app/Contents/Info.plist | grep Usage
```
**Looking for**: NSScreenCaptureUsageDescription, NSAccessibilityUsageDescription, etc.
**Problem if**: Missing or not showing up

### 2. Check Sandbox Status
```bash
xcodebuild -showBuildSettings -project X.xcodeproj -scheme Y | grep ENABLE_APP_SANDBOX
```
**Should be**: `NO` if using system tools like screencapture
**Problem if**: `YES` when trying to use system executables

### 3. Check Entitlements
```bash
codesign -d --entitlements - path/to/built/app.app 2>&1
```
**Problem if**: Contains `com.apple.security.app-sandbox` when you disabled it

### 4. Reset Permissions
```bash
tccutil reset ScreenCapture
killall YourApp
```
**When**: Testing permission fixes from scratch

---

## Common Issues → Quick Fixes

### ❌ "Permission strings not in built app"
**Cause**: `GENERATE_INFOPLIST_FILE = YES` ignoring your Info.plist
**Fix**: In project.pbxproj:
```
GENERATE_INFOPLIST_FILE = NO;
INFOPLIST_FILE = YourApp/Info.plist;
```

### ❌ "App Sandbox blocking system tools"
**Cause**: `ENABLE_APP_SANDBOX = YES`
**Fix**: In project.pbxproj:
```
ENABLE_APP_SANDBOX = NO;
```

### ❌ "Permission prompts loop forever"
**Cause**: Manual permission checking code
**Fix**: Remove `CGPreflightScreenCaptureAccess()` and let macOS handle it

### ❌ "Xcode vs App permission confusion"
**Cause**: Running from Xcode grants permissions to Xcode, not your app
**Solution**: This is normal for development. For release builds, permissions go to the app.

---

## Essential Commands

### Build & Inspect
```bash
# Clean build
xcodebuild clean build -project X.xcodeproj -scheme Y

# Check what's in built app
plutil -p /path/to/app.app/Contents/Info.plist

# Check entitlements
codesign -d --entitlements - /path/to/app.app
```

### Permission Management
```bash
# Reset ALL screen capture permissions
tccutil reset ScreenCapture

# Reset for specific app
tccutil reset ScreenCapture com.bundle.id
```

### Process Control
```bash
# Kill everything
killall Xcode && killall YourApp

# Find derived data
ls -la ~/Library/Developer/Xcode/DerivedData/
```

---

## Testing Protocol

1. `killall Xcode && killall YourApp`
2. `tccutil reset ScreenCapture`
3. `xcodebuild clean build`
4. Run in Xcode (Cmd+R)
5. Test permission flow
6. Verify in Console.app

---

## File Locations

```
Project Root/
├── YourApp.xcodeproj/
│   └── project.pbxproj          ← Build settings
├── YourApp/
│   ├── Info.plist               ← Permission strings
│   └── YourApp.entitlements     ← Capabilities
└── ~/Library/Developer/Xcode/DerivedData/
    └── YourApp-*/Build/Products/Debug/
        └── YourApp.app          ← ACTUAL BUILT APP (check this!)
```

---

## The Golden Rule

**Always verify the BUILT app, not the source files.**

Source files can be perfect, but build settings might ignore them.

---

## When Stuck

1. Read [DEBUGGING_METHODOLOGY.md](DEBUGGING_METHODOLOGY.md)
2. Check each layer: Source → Build → Bundle → Runtime
3. Verify assumptions with commands, not gut feelings
4. Consider multiple simultaneous bugs
5. Test with clean state (reset TCC, clean build)

---

## Red Flags 🚩

- [ ] Permission prompt shows generic message (missing usage description)
- [ ] Same permission asked repeatedly (possible loop)
- [ ] App works in Xcode but not as standalone (signing/entitlements)
- [ ] Changes to Info.plist don't affect built app (auto-generation enabled)
- [ ] System Settings shows permission granted but app disagrees (sandbox or TCC issue)

---

## Success Indicators ✅

- [ ] Single permission prompt with your custom message
- [ ] Permission persists across app launches
- [ ] No console errors about missing keys
- [ ] System Settings shows correct app name
- [ ] Functionality works after granting permission

---

**Bookmark This**: Keep this file open when debugging permissions.
