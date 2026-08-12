---
description: How to release a new TextClipper update with Sparkle
---

# TextClipper Release Workflow

Complete step-by-step guide for releasing a new version after adding features or fixing bugs.

---

## Step 1: Bump the Version Number

In Xcode, open `textclipper/Info.plist` and update:

| Key | What to change | Example |
|-----|---------------|---------|
| `CFBundleShortVersionString` | Marketing version (shown to users) | `1.0` → `1.1` |
| `CFBundleVersion` | Build number (must always increase) | `2` → `3` |

> [!IMPORTANT]
> The build number (`CFBundleVersion`) **must be higher** than the previous release. Sparkle uses this to determine if an update is available.

---

## Step 2: Build & Notarize in Xcode

1. **Product → Archive** (make sure the scheme is set to "Any Mac")
2. When the Organizer window appears, click **Distribute App**
3. Choose **Developer ID** distribution
4. Let Xcode **upload for notarization** and wait for Apple to approve
5. Once approved, click **Export Notarized App**
6. Save the `.app` to: `~/Desktop/TextClipper_Release/`

---

## Step 3: Create the DMG

Open Terminal and run:

```bash
cd /Users/michaeltouboul/Desktop/SwiftUi_Programs/textclipper

# Remove old DMG if it exists
rm -f TextClipper_Installer.dmg

# Create the DMG from your notarized .app
create-dmg \
  --volname "TextClipper Installer" \
  --window-pos 200 120 \
  --window-size 600 300 \
  --icon-size 100 \
  --icon "textclipper.app" 175 120 \
  --hide-extension "textclipper.app" \
  --app-drop-link 425 120 \
  TextClipper_Installer.dmg \
  ~/Desktop/TextClipper_Release/textclipper.app
```

> [!NOTE]
> If the app name changes (e.g., `TextClipper.app` instead of `textclipper.app`), update the `--icon` flag to match.

---

## Step 4: Copy DMG to Website & Generate Appcast

```bash
# Copy DMG to website downloads folder
cp TextClipper_Installer.dmg /Users/michaeltouboul/textcliper/downloads/

# Generate appcast.xml using the official Sparkle tool
./sparkle_tools/bin/generate_appcast /Users/michaeltouboul/textcliper/downloads/

# Copy appcast to website root (the installed app reads from root URL)
cp /Users/michaeltouboul/textcliper/downloads/appcast.xml /Users/michaeltouboul/textcliper/appcast.xml
```

---

## Step 5: Deploy to Firebase

```bash
cd /Users/michaeltouboul/textcliper
firebase deploy
```

---

## Step 6: Verify

1. Open TextClipper on your Mac
2. Click the menu bar icon → **Check for Updates...**
3. You should see: *"A new version of TextClipper is available!"*
4. Click **Install Update** to confirm the full flow works

---

## Quick Reference Summary

| Step | Action | Tool |
|------|--------|------|
| 1 | Bump version in `Info.plist` | Xcode |
| 2 | Archive → Distribute → Notarize → Export | Xcode |
| 3 | `create-dmg ... TextClipper_Installer.dmg ~/Desktop/TextClipper_Release/textclipper.app` | Terminal |
| 4 | Copy DMG + `generate_appcast` + copy appcast to root | Terminal |
| 5 | `firebase deploy` | Terminal |
| 6 | Check for Updates in app | TextClipper |
