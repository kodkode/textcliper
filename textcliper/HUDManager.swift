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
    private var hideTimer: DispatchWorkItem?

    private init() {}

    func showHUD(message: String, characterCount: Int, wordCount: Int, fullText: String = "", showActions: Bool = false, duration: TimeInterval = 2.5) {
        DispatchQueue.main.async { [weak self] in
            self?.showHUDOnMain(message: message, characterCount: characterCount, wordCount: wordCount, fullText: fullText, showActions: showActions, duration: duration)
        }
    }

    func dismissHUD() {
        DispatchQueue.main.async { [weak self] in
            self?.hideTimer?.cancel()
            self?.hideHUDAnimated()
        }
    }

    private func showHUDOnMain(message: String, characterCount: Int, wordCount: Int, fullText: String, showActions: Bool, duration: TimeInterval) {
        // Close existing HUD if present
        hideTimer?.cancel()
        if let existing = currentWindow {
            existing.close()
            currentWindow = nil
        }

        // Create SwiftUI view
        let hudView = HUDView(
            message: message,
            characterCount: characterCount,
            wordCount: wordCount,
            fullText: fullText,
            showActions: showActions,
            onShare: { [weak self] destination in
                self?.handleShare(text: fullText, destination: destination)
            }
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
        window.ignoresMouseEvents = !showActions // Allow interaction if showing actions
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

        // Auto-hide after duration (if not showing actions, or with longer duration if showing actions)
        let actualDuration = showActions ? duration * 2 : duration
        let timer = DispatchWorkItem { [weak self] in
            self?.hideHUDAnimated()
        }
        hideTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + actualDuration, execute: timer)
    }

    private func hideHUDAnimated() {
        guard let window = currentWindow else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.close()
            self?.currentWindow = nil
        })
    }

    private func handleShare(text: String, destination: ShareDestination) {
        // Dismiss HUD immediately when user clicks share button
        dismissHUD()

        // Perform share action
        ShareService.shared.share(text: text, to: destination) { result in
            switch result {
            case .success:
                print("✅ Successfully shared to \(destination)")
            case .failure(let error):
                print("❌ Failed to share: \(error)")
                // Could show an error HUD here if needed
            }
        }
    }
}
