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
    private let finalizationDelay: TimeInterval = 1.0 // 1 second after last keypress

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
                    Text("• Sequence will auto-save 1 second after last keypress")
                    Text("• Or click 'Accept' to save immediately")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Buttons
            HStack(spacing: 12) {
                Button(recording ? "Stop Recording" : "Record Hotkey") {
                    toggleRecording()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(recording && recordedPresses.isEmpty)

                if recording && !recordedPresses.isEmpty {
                    Button("Accept Sequence") {
                        acceptSequence()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
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

                if !recording {
                    Button("Save") {
                        saveSequence()
                    }
                    .disabled(recordedPresses.isEmpty)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 280)
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if recording {
            stopRecording()
        } else {
            startRecording()
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

    private func acceptSequence() {
        stopRecording()
        updateDisplay()
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
        var keyPress: KeyPress?

        if event.type == .keyDown {
            // Regular key pressed
            let keyCode = UInt32(event.keyCode)
            keyPress = KeyPress(keyCode: keyCode, modifiers: modifiers)
        } else if event.type == .flagsChanged {
            // Modifier key pressed/released
            if isModifierKeyCode(UInt32(event.keyCode)) {
                let currentModifiers = modifiers
                let previousModifiers: UInt32

                if let lastPress = recordedPresses.last {
                    previousModifiers = lastPress.modifiers
                } else {
                    previousModifiers = 0
                }

                // Only record when modifier is PRESSED (not released)
                if currentModifiers > previousModifiers {
                    keyPress = KeyPress(keyCode: UInt32(event.keyCode), modifiers: previousModifiers)
                }
            }
        }

        guard let press = keyPress else {
            return
        }

        // Add to recorded sequence
        recordedPresses.append(press)
        updateDisplay()

        // Cancel previous timer
        finalizationTimer?.cancel()

        // Auto-finalize after delay if we have at least one keypress
        if recordedPresses.count > 0 {
            let timer = DispatchWorkItem {
                // Using implicit self capture is fine in SwiftUI View structs
                self.acceptSequence()
            }
            finalizationTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + finalizationDelay, execute: timer)
        }

        // Auto-accept if max presses reached
        if recordedPresses.count >= maxPresses {
            acceptSequence()
        }
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
