# Permission Setup Guide for textcliper

## Current Status
✅ Build succeeded
✅ Debug logging added
✅ Permission checker menu item added

## Issues Fixed
1. ✅ Removed screen recording permission loop
2. ✅ Added debug menu to check permission status
3. ✅ Added detailed logging for hotkey registration

## Step-by-Step Setup

### 1. Completely Quit the App
```bash
# In Xcode, click Stop button
# OR press Cmd+. to stop the app
```

### 2. Open System Settings
Go to: **System Settings > Privacy & Security**

### 3. Grant Accessibility Permission
1. Click on **Accessibility** (left sidebar)
2. Look for **"Xcode"** in the list (when running from Xcode)
   - If you don't see "Xcode", you may see "textcliper"
3. **Toggle it ON** (checkmark should appear)
4. If you still don't see it, click the **+** button and navigate to:
   - `/Applications/Xcode.app`

### 4. Grant Screen Recording Permission
1. Click on **Screen Recording** (left sidebar)
2. Look for **"Xcode"** or **"textcliper"**
3. **Toggle it ON**

### 5. Restart the App
1. In Xcode, click the **Run** button (or press Cmd+R)
2. Wait for the app to launch

### 6. Check Status
1. Click the menu bar icon (🔍)
2. Click **"Check Permissions"**
3. Verify both show as ✅ Granted

## Testing

### Test Hotkey
1. Press **⌘⇧8**
2. You should see in Xcode console: `🔥 Hotkey triggered!`
3. Select an area to capture

### Test Manual Capture
1. Click menu bar icon
2. Click "Capture Screenshot"
3. Select an area
4. Text should be copied to clipboard

## Troubleshooting

### "Waiting for accessibility permission"
- Make sure you toggled **Xcode** ON in Accessibility
- **Quit** and **restart** the app completely

### Screenshot permission keeps asking
- This should be fixed now
- The `/usr/sbin/screencapture` tool handles it automatically
- First use: macOS will prompt
- After granting: should work silently

### Hotkey not working
1. Click "Check Permissions" in menu
2. If Accessibility shows ✅ but Hotkey shows ❌:
   - Quit and restart the app
3. Check Xcode console for error messages

## Console Output

When everything works, you should see:
```
🔍 Accessibility permission check: true
✅ Hotkey successfully registered (⌘⇧8)
```

When hotkey is pressed:
```
🔥 Hotkey triggered!
```

## Known Issues

When running from Xcode:
- Permissions are granted to **Xcode**, not textcliper
- This is normal for development
- When you build a standalone app, it will have its own permissions
