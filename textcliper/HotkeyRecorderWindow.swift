//
//  HotkeyRecorderWindow.swift
//  textcliper
//
//  Created by Claude on 07/10/2025.
//

import SwiftUI
import Carbon

struct HotkeyRecorderWindow: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @State private var recording = false
    @State private var displayText = "Press a key combination..."
    var onSave: (UInt32, UInt32) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Configure Hotkey")
                .font(.headline)

            Text(displayText)
                .font(.system(.title2, design: .monospaced))
                .padding()
                .frame(minWidth: 300, minHeight: 80)
                .background(recording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(recording ? Color.blue : Color.gray, lineWidth: 2)
                )

            HStack(spacing: 12) {
                Button(recording ? "Stop Recording" : "Record Hotkey") {
                    recording.toggle()
                    if recording {
                        displayText = "Press keys now..."
                        startRecording()
                    }
                }
                .keyboardShortcut(.defaultAction)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    onSave(keyCode, modifiers)
                    dismiss()
                }
                .disabled(keyCode == 0)
            }
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 200)
    }

    private func startRecording() {
        // Use NSEvent to capture key presses
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if self.recording {
                self.handleKeyEvent(event)
                return nil // Consume the event
            }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let newModifiers = event.modifierFlags.carbonModifiers()
        let newKeyCode = UInt32(event.keyCode)

        // Only accept if we have modifiers
        if newModifiers != 0 && event.type == .keyDown {
            keyCode = newKeyCode
            modifiers = newModifiers
            displayText = formatHotkey(keyCode: newKeyCode, modifiers: newModifiers)
            recording = false
        }
    }

    private func formatHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
        var result = ""

        if modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }

        result += keyCodeToString(keyCode)

        return result
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // Map common key codes to characters
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        default: return "[\(keyCode)]"
        }
    }
}

extension NSEvent.ModifierFlags {
    func carbonModifiers() -> UInt32 {
        var modifiers: UInt32 = 0

        if contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        return modifiers
    }
}
