//
//  HotkeyRecorderWindow.swift
//  textcliper
//
//  Created by Claude on 07/10/2025.
//  Rewritten by Claude on 15/10/2025 for sequence support
//

import SwiftUI
import Carbon

struct HotkeyRecorderWindow: View {
    @Binding var sequence: KeySequence
    @State private var recording = false
    @State private var recordedPresses: [KeyPress] = []
    @State private var displayText = "Press 'Record' to start..."
    @State private var eventMonitor: Any?
    @State private var finalizationTimer: DispatchWorkItem?

    var onSave: (KeySequence) -> Void
    @Environment(\.dismiss) var dismiss

    private let maxPresses = 5
    private let finalizationDelay: TimeInterval = 2.0

    var body: some View {
        VStack(spacing: 20) {
            Text("Configure Hotkey Sequence")
                .font(.headline)

            // Sequence display area
            VStack(spacing: 8) {
                Text(displayText)
                    .font(.system(.title2, design: .monospaced))
                    .padding()
                    .frame(minWidth: 400, minHeight: 100)
                    .background(recording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(recording ? Color.blue : Color.gray, lineWidth: 2)
                    )

                // Key counter
                if recording {
                    Text("\(recordedPresses.count) of \(maxPresses) keys recorded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Instructions
            if recording {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Press up to \(maxPresses) keys in sequence")
                    Text("• Recording will stop 2 seconds after last keypress")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Buttons
            HStack(spacing: 12) {
                if !recording {
                    Button("Record Hotkey") {
                        startRecording()
                    }
                    .keyboardShortcut(.defaultAction)
                }

                if recording {
                    Button("Clear") {
                        clearRecording()
                    }
                }

                Button("Cancel") {
                    stopRecording()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if !recording && !recordedPresses.isEmpty {
                    Button("Save") {
                        saveSequence()
                    }
                    .keyboardShortcut(.return)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 280)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        recording = true
        recordedPresses = []
        displayText = "Waiting for keypresses..."

        // Set up event monitor
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            self.handleKeyEvent(event)
            return nil // Consume the event
        }
    }

    private func stopRecording() {
        recording = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        finalizationTimer?.cancel()
        finalizationTimer = nil

        updateDisplay()
    }

    private func clearRecording() {
        recordedPresses = []
        displayText = "Waiting for keypresses..."
        finalizationTimer?.cancel()
        finalizationTimer = nil
    }

    private func saveSequence() {
        if recordedPresses.isEmpty {
            return
        }

        let newSequence = KeySequence(presses: recordedPresses, maxTimeBetweenKeys: 0.5)
        onSave(newSequence)
        dismiss()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard recording && recordedPresses.count < maxPresses else {
            return
        }

        let modifiers = event.modifierFlags.carbonModifiers()

        if event.type == .keyDown {
            // Regular key pressed - this might complete a combo
            // Check if we have recent modifier-only presses that should be merged
            mergeModifiersIntoCombo(regularKeyCode: UInt32(event.keyCode), finalModifiers: modifiers)

            // Record the key press with current modifiers
            let keyPress = KeyPress(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            recordedPresses.append(keyPress)
            print("🔵 Recorded keyDown: keyCode=\(event.keyCode), modifiers=\(modifiers)")

            updateDisplay()
            scheduleFinalization()

            // Auto-stop if max presses reached
            if recordedPresses.count >= maxPresses {
                stopRecording()
            }

        } else if event.type == .flagsChanged {
            // Modifier key pressed or released
            if isModifierKeyCode(UInt32(event.keyCode)) {
                // Check if this is a press (modifiers increased) or release (modifiers decreased)
                let previousModifiers = recordedPresses.last?.modifiers ?? 0

                if modifiers > previousModifiers {
                    // Modifier key was PRESSED - record it temporarily
                    // (might get merged later if part of a combo)
                    let keyPress = KeyPress(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                    recordedPresses.append(keyPress)
                    print("🟡 Recorded modifier press: keyCode=\(event.keyCode), modifiers=\(modifiers)")

                    updateDisplay()
                    scheduleFinalization()

                    // Auto-stop if max presses reached
                    if recordedPresses.count >= maxPresses {
                        stopRecording()
                    }
                }
                // If modifiers decreased, it's a release - ignore it
            }
        }
    }

    private func mergeModifiersIntoCombo(regularKeyCode: UInt32, finalModifiers: UInt32) {
        // Remove any trailing modifier-only presses that were part of this combo
        // A modifier press is "part of the combo" if it's a modifier key being recorded
        // and the final modifiers include that modifier

        var indicesToRemove: [Int] = []

        // Look backwards through recent presses
        for i in stride(from: recordedPresses.count - 1, through: 0, by: -1) {
            let press = recordedPresses[i]

            // Is this a modifier key?
            if isModifierKeyCode(press.keyCode) {
                // Mark for removal - this was part of the combo
                indicesToRemove.append(i)
                print("🔀 Merging modifier: keyCode=\(press.keyCode)")
            } else {
                // Hit a non-modifier key, stop looking
                break
            }
        }

        // Remove the modifier-only presses (they're now represented in finalModifiers)
        for index in indicesToRemove {
            recordedPresses.remove(at: index)
        }

        if !indicesToRemove.isEmpty {
            print("✅ Merged \(indicesToRemove.count) modifiers into combo")
        }
    }

    private func scheduleFinalization() {
        // Cancel any existing timer
        finalizationTimer?.cancel()

        // Schedule auto-stop after delay
        let timer = DispatchWorkItem {
            self.stopRecording()
        }
        finalizationTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + finalizationDelay, execute: timer)
    }

    private func updateDisplay() {
        if recordedPresses.isEmpty {
            if recording {
                displayText = "Waiting for keypresses..."
            } else {
                displayText = "Press 'Record' to start..."
            }
        } else {
            let sequence = KeySequence(presses: recordedPresses)
            displayText = sequence.displayString()
        }
    }

    private func isModifierKeyCode(_ keyCode: UInt32) -> Bool {
        let modifierKeyCodes: [UInt32] = [
            59,  // Left Control
            62,  // Right Control
            58,  // Left Option
            61,  // Right Option
            56,  // Left Shift
            60,  // Right Shift
            55,  // Left Command
            54   // Right Command
        ]
        return modifierKeyCodes.contains(keyCode)
    }
}

// Preview provider for development
#Preview {
    @Previewable @State var sequence = KeySequence(presses: [])

    HotkeyRecorderWindow(
        sequence: $sequence,
        onSave: { newSequence in
            print("Saved sequence: \(newSequence.displayString())")
        }
    )
}
