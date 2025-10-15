//
//  KeySequence.swift
//  textcliper
//
//  Created by Claude on 15/10/2025.
//

import Foundation
import Carbon

/// Represents a single keypress in a sequence
struct KeyPress: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Check if this keypress matches another (ignoring extra modifiers like CapsLock, Function keys)
    func matches(_ other: KeyPress) -> Bool {
        // Filter out non-essential modifiers for matching
        let essentialModifierMask: UInt32 = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        let thisModifiers = self.modifiers & essentialModifierMask
        let otherModifiers = other.modifiers & essentialModifierMask

        return self.keyCode == other.keyCode && thisModifiers == otherModifiers
    }
}

/// Represents a sequence of keypresses that form a hotkey
struct KeySequence: Codable, Equatable {
    let presses: [KeyPress]
    let maxTimeBetweenKeys: TimeInterval // Maximum time allowed between consecutive keys

    init(presses: [KeyPress], maxTimeBetweenKeys: TimeInterval = 0.5) {
        self.presses = presses
        self.maxTimeBetweenKeys = maxTimeBetweenKeys
    }

    /// Create a legacy single-key hotkey (for backward compatibility)
    init(legacyKeyCode: UInt32, legacyModifiers: UInt32) {
        self.presses = [KeyPress(keyCode: legacyKeyCode, modifiers: legacyModifiers)]
        self.maxTimeBetweenKeys = 0.5
    }

    var isEmpty: Bool {
        return presses.isEmpty
    }

    var count: Int {
        return presses.count
    }

    /// Returns a human-readable display string for the sequence
    func displayString() -> String {
        if presses.isEmpty {
            return "No hotkey set"
        }

        return presses.map { formatKeyPress($0) }.joined(separator: " → ")
    }

    /// Returns a compact display string (no arrows, for menu items)
    func compactDisplayString() -> String {
        if presses.isEmpty {
            return ""
        }

        if presses.count == 1 {
            return formatKeyPress(presses[0])
        }

        return presses.map { formatKeyPress($0) }.joined(separator: " ")
    }

    private func formatKeyPress(_ press: KeyPress) -> String {
        var result = ""

        // Add modifier symbols in standard macOS order
        if press.modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if press.modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if press.modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if press.modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }

        result += keyCodeToString(press.keyCode)

        return result
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // Map modifier key codes first
        switch keyCode {
        case 59: return "⌃"  // Left Control
        case 62: return "⌃"  // Right Control
        case 58: return "⌥"  // Left Option
        case 61: return "⌥"  // Right Option
        case 56: return "⇧"  // Left Shift
        case 60: return "⇧"  // Right Shift
        case 55: return "⌘"  // Left Command
        case 54: return "⌘"  // Right Command
        default: break
        }

        // Map regular key codes
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
        case kVK_Space: return "␣"
        case kVK_Return: return "⏎"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_F1...kVK_F20:
            let fNumber = Int(keyCode) - kVK_F1 + 1
            return "F\(fNumber)"
        default: return "[\(keyCode)]"
        }
    }

    /// Serialize to JSON string for persistence
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }

    /// Deserialize from JSON string
    static func fromJSONString(_ jsonString: String) -> KeySequence? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(KeySequence.self, from: data)
    }
}

/// Extension for matching key sequences
extension KeySequence {
    /// Check if a buffer of recent keypresses matches this sequence
    /// - Parameter buffer: Array of (KeyPress, Date) tuples representing recent keypresses
    /// - Returns: True if the buffer matches this sequence (considering timing)
    func matches(buffer: [(press: KeyPress, time: Date)]) -> Bool {
        // Need at least as many presses in buffer as in sequence
        guard buffer.count >= presses.count else {
            return false
        }

        // Get the last N presses from buffer (where N = sequence length)
        let relevantPresses = Array(buffer.suffix(presses.count))

        // Check each press matches
        for i in 0..<presses.count {
            if !presses[i].matches(relevantPresses[i].press) {
                return false
            }
        }

        // Check timing constraints (each press must be within maxTimeBetweenKeys of previous)
        for i in 1..<relevantPresses.count {
            let timeDiff = relevantPresses[i].time.timeIntervalSince(relevantPresses[i-1].time)
            if timeDiff > maxTimeBetweenKeys {
                return false
            }
        }

        return true
    }
}
