#!/usr/bin/env swift
import ApplicationServices

let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
let trusted = AXIsProcessTrustedWithOptions(options)

print("Accessibility Permission Status: \(trusted ? "✅ GRANTED" : "❌ NOT GRANTED")")
print("")
print("If not granted, go to:")
print("  System Settings > Privacy & Security > Accessibility")
print("  Enable: Xcode (or textcliper)")
