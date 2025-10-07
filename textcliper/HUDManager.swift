//
//  HUDManager.swift
//  textcliper
//
//  Created by Michael on 07/10/2025.
//

import AppKit
import SwiftUI

class HUDManager {
    static let shared = HUDManager()
    private var currentWindow: NSWindow?

    private init() {}

    func showHUD(message: String, characterCount: Int, wordCount: Int, duration: TimeInterval = 2.5) {
        DispatchQueue.main.async { [weak self] in
            self?.showHUDOnMain(message: message, characterCount: characterCount, wordCount: wordCount, duration: duration)
        }
    }

    private func showHUDOnMain(message: String, characterCount: Int, wordCount: Int, duration: TimeInterval) {
        // Close existing HUD if present
        if let existing = currentWindow {
            existing.close()
            currentWindow = nil
        }

        // Create SwiftUI view
        let hudView = HUDView(
            message: message,
            characterCount: characterCount,
            wordCount: wordCount
        )

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: hudView)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false // Keep window alive

        // Position at center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            window.setFrame(NSRect(x: x, y: y, width: windowFrame.width, height: windowFrame.height), display: true)
        }

        // Store strong reference before showing
        currentWindow = window

        // Show with animation (don't make it key, just order front)
        window.alphaValue = 0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        })

        // Auto-hide after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, let window = self.currentWindow else { return }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                window.orderOut(nil)
                window.close()
                self?.currentWindow = nil
            })
        }
    }
}
