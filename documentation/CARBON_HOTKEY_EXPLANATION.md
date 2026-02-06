# Carbon Event Manager Hotkey System - Technical Explanation

## Overview

textclipper uses Apple's **Carbon Event Manager API** (`RegisterEventHotKey`) for global hotkey registration. This document explains how it works, what's allowed, and why no Accessibility permission is required.

## Table of Contents

- [What is Carbon Event Manager?](#what-is-carbon-event-manager)
- [Why Carbon vs NSEvent?](#why-carbon-vs-nsevent)
- [Allowed Key Combinations](#allowed-key-combinations)
- [Reserved System Hotkeys](#reserved-system-hotkeys)
- [Security and Permissions](#security-and-permissions)
- [Technical Implementation](#technical-implementation)

---

## What is Carbon Event Manager?

**Carbon Event Manager** is Apple's official API for registering global hotkeys in macOS applications. It's part of the Carbon framework and has been the standard approach for global hotkey registration since Mac OS X.

### Key Characteristics:
- **Official Apple API** - Designed specifically for global hotkey registration
- **No special permissions required** - Works without Accessibility permission
- **System-wide** - Hotkeys work even when your app is in the background
- **App Store approved** - Safe to use in Mac App Store submissions

---

## Why Carbon vs NSEvent?

There are two main approaches to global hotkeys on macOS:

### 1. NSEvent Global Monitors (Requires Accessibility)

```swift
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
    // ❌ Sees EVERY keypress system-wide
    // ❌ Security risk: potential keylogging
    // ✅ Requires Accessibility permission
}
```

**Pros:**
- Can detect complex multi-key sequences
- Can see modifier-only presses

**Cons:**
- ⚠️ Requires Accessibility permission
- ⚠️ Shows permission prompt to users
- ⚠️ Can be used for keylogging (why permission is required)
- ⚠️ Doesn't actually receive keyDown events from other apps on modern macOS

### 2. Carbon RegisterEventHotKey (No Permission Needed)

```swift
RegisterEventHotKey(keyCode, modifiers, hotKeyID, ...)
    // ✅ Only notified for ONE specific combination
    // ✅ Cannot spy on other keypresses
    // ✅ No Accessibility permission needed
```

**Pros:**
- ✅ No permission prompts - better user experience
- ✅ True system-wide hotkeys (works reliably)
- ✅ Standard approach for global hotkeys
- ✅ Used by Apple's own apps (Spotlight, Screenshot utility)

**Cons:**
- Limited to single-key combinations (not multi-key sequences like Ctrl+K, Ctrl+C)

---

## Allowed Key Combinations

### What You CAN Register

**Any combination of:**

#### Regular Keys:
- Letters: A-Z
- Numbers: 0-9
- Function keys: F1-F20
- Special keys: Space, Return, Tab, Delete, Escape, Arrow keys
- Keypad keys

#### Modifier Keys:
- ⌘ Command (cmdKey)
- ⇧ Shift (shiftKey)
- ⌥ Option/Alt (optionKey)
- ⌃ Control (controlKey)

#### Examples of Valid Hotkeys:
```
⌘⇧8          (Command + Shift + 8)
⌘⌥F          (Command + Option + F)
⌃⌥⌘Space     (Control + Option + Command + Space)
F5           (Function key alone)
⌘K           (Command + K)
⇧⌃A          (Shift + Control + A)
```

### Important Limitation

**You can only register ONE specific combination at a time per hotkey.**

When you register ⌘⇧8:
- ✅ You get notified ONLY when ⌘⇧8 is pressed
- ❌ You DON'T see when user types "hello"
- ❌ You DON'T see when user presses ⌘C
- ❌ You DON'T see any other keypresses

**This is why no Accessibility permission is needed** - you're not monitoring the keyboard, you're just asking macOS to notify you about one specific combo.

### Analogy

It's like setting an alarm for 3:00 PM:
- You're not constantly checking the time (monitoring)
- You just get notified when it's 3:00 PM (specific event)
- You don't know what time it is otherwise

Same concept with Carbon hotkeys! 🔔

---

## Reserved System Hotkeys

Some key combinations are **reserved by macOS** and cannot be registered by third-party apps:

### Commonly Reserved Hotkeys:
- **⌘Space** - Spotlight search
- **⌘Tab** - Application switcher
- **⌘Q** - Quit application
- **⌘W** - Close window
- **⌘H** - Hide application
- **⌘M** - Minimize window
- **⌘⇧3** - Screenshot entire screen
- **⌘⇧4** - Screenshot selection
- **⌘⇧5** - Screenshot and recording options
- **Mission Control hotkeys** (user-configurable)
- **Accessibility shortcuts** (user-configurable)

### What Happens if You Try?

If you attempt to register a reserved combination:
- `RegisterEventHotKey` returns an **error status code**
- No crash or security issue
- Your app should handle it gracefully (show error to user)

### Best Practices:
1. Avoid common system shortcuts
2. Provide visual feedback if registration fails
3. Allow users to customize their hotkey
4. Check if registration succeeded and inform user

---

## Security and Permissions

### Why Carbon Hotkeys Don't Need Accessibility Permission

**Accessibility Permission** is required when an app needs to:
- Monitor arbitrary keyboard/mouse events system-wide
- Control other applications' UI elements
- Read/modify other apps' accessibility trees

**Carbon Hotkeys Are Different:**
- You only register ONE specific key combination
- macOS handles the monitoring for you
- You cannot intercept arbitrary keypresses
- You cannot spy on what the user is typing
- **No security risk = no permission needed**

### Apps That Use Carbon Hotkeys

Many reputable apps use Carbon hotkeys without Accessibility permission:
- **Apple's Spotlight** (⌘Space)
- **Apple's Screenshot utility** (⌘⇧3, ⌘⇧4, ⌘⇧5)
- **Alfred** - Launcher app
- **Raycast** - Productivity tool
- **Rectangle** - Window management
- **Many professional Mac applications**

### Mac App Store Compliance

✅ **Carbon hotkeys are fully compliant** with Mac App Store guidelines
✅ **No special entitlements needed**
✅ **No permission prompts required**
✅ **Standard, accepted practice**

---

## Technical Implementation

### How textclipper Uses Carbon Hotkeys

#### 1. Setup Event Handler (on app launch)
```swift
private func setupCarbonEventHandler() {
    var eventTypes = [
        EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                     eventKind: UInt32(kEventHotKeyPressed))
    ]

    let callback: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
        // Called when registered hotkey is pressed
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()

        DispatchQueue.main.async {
            manager.callback?()  // Trigger screenshot capture
        }

        return noErr
    }

    InstallEventHandler(GetApplicationEventTarget(), callback, ...)
}
```

#### 2. Register Specific Hotkey
```swift
private func registerCarbonHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = OSType(0x48545359)  // 'HTSY'
    hotKeyID.id = 1

    var hotKeyRef: EventHotKeyRef?
    let status = RegisterEventHotKey(
        keyCode,        // e.g., 28 for '8' key
        modifiers,      // e.g., cmdKey | shiftKey
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &hotKeyRef
    )

    return status == noErr
}
```

#### 3. Unregister on Cleanup
```swift
func unregisterHotkey() {
    if let hotKeyRef = carbonHotKeyRef {
        UnregisterEventHotKey(hotKeyRef)
        carbonHotKeyRef = nil
    }
}
```

### Smart Detection: Carbon vs NSEvent

textclipper automatically chooses the right API:

```swift
func registerHotkey(sequence: KeySequence, callback: @escaping () -> Void) -> Bool {
    // For single-key sequences: use Carbon (no permission needed)
    if sequence.count == 1 {
        let press = sequence.presses[0]
        return registerCarbonHotkey(keyCode: press.keyCode, modifiers: press.modifiers)
    }

    // For multi-key sequences: use NSEvent monitors (needs Accessibility)
    // Example: Ctrl+K, Ctrl+C (press Ctrl+K, then Ctrl+C)
    return registerNSEventMonitor(sequence: sequence)
}
```

**Result:**
- Default hotkey (⌘⇧8) uses Carbon → **no permission needed** ✅
- Multi-key sequences use NSEvent → **requests Accessibility when needed** ⚠️

---

## User Guide: Choosing a Hotkey

### Recommended Hotkey Patterns

Good hotkey choices typically include:
- **Command (⌘) + another modifier** - Less likely to conflict
- **Multiple modifiers** - More unique, less conflicts
- **Function keys** - Usually available (F1-F12)
- **Numeric keypad** - Often unused

### Examples of Good Hotkeys:
- ⌘⇧8 (default - Command + Shift + 8)
- ⌘⌥C (Command + Option + C)
- ⌃⌥⇧S (Control + Option + Shift + S)
- F6 (Function key)

### Examples to Avoid:
- ⌘C (copy - conflicts with system)
- ⌘V (paste - conflicts with system)
- ⌘Q (quit - conflicts with system)
- ⌘Space (Spotlight - conflicts with system)

### Testing Your Hotkey

After setting a custom hotkey:
1. **Test it immediately** - Make sure it triggers
2. **Check for conflicts** - Try it in different apps
3. **Verify system shortcuts** - Open System Settings → Keyboard → Keyboard Shortcuts
4. **Consider muscle memory** - Is it comfortable to press?

---

## Troubleshooting

### Hotkey Not Working?

**Possible causes:**

1. **Conflicting system shortcut**
   - Check System Settings → Keyboard → Keyboard Shortcuts
   - Disable conflicting shortcuts or choose a different hotkey

2. **App-specific shortcut conflict**
   - Some apps override global hotkeys when they're active
   - Try using the hotkey when a different app is focused

3. **Registration failed**
   - Check Xcode console for error messages
   - Status code will indicate the failure reason

4. **macOS reserved the combination**
   - Try a different modifier combination
   - Avoid single-key hotkeys without modifiers

### Debug Console Messages

Look for these in Xcode console:

```
✅ Carbon hotkey registered: keyCode=28, modifiers=768
   → Success! Hotkey is registered

❌ Failed to register Carbon hotkey: status=-9878
   → Registration failed (likely reserved by system)

🔥 Carbon hotkey triggered!
   → Your hotkey was pressed successfully
```

---

## Summary

### Key Takeaways

1. **Carbon Event Manager** is Apple's official API for global hotkeys
2. **No Accessibility permission needed** for single-key combinations
3. **You can register any combination** (that's not reserved by macOS)
4. **Each registration = ONE specific combo** (cannot spy on all keys)
5. **Better user experience** than NSEvent monitors (no permission prompts)
6. **App Store compliant** and used by major Mac apps

### Why This Matters for textclipper

- ⌘⇧8 works **immediately** without permission prompts
- Users don't need to navigate System Settings
- Better first-run experience
- Professional, polished app behavior
- Same approach used by Apple's own utilities

---

## References

- [Apple Developer Documentation: Carbon Event Manager](https://developer.apple.com/documentation/carbon/carbon_event_manager)
- [RegisterEventHotKey API Reference](https://developer.apple.com/documentation/carbon/1542343-registereventhotkey)
- [macOS Human Interface Guidelines: Keyboard](https://developer.apple.com/design/human-interface-guidelines/keyboards)

---

**Document Version:** 1.0
**Last Updated:** October 26, 2025
**Author:** textclipper development team
