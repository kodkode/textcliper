//
//  HUDManager.swift
//  textclipper
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

    func showHUD(message: String, characterCount: Int, wordCount: Int, fullText: String = "", showActions: Bool = false, isAdditive: Bool = false, duration: TimeInterval = 2.5) {
        DispatchQueue.main.async { [weak self] in
            self?.showHUDOnMain(message: message, characterCount: characterCount, wordCount: wordCount, fullText: fullText, showActions: showActions, isAdditive: isAdditive, duration: duration)
        }
    }

    func showLoadingHUD() {
        DispatchQueue.main.async { [weak self] in
            self?.showLoadingHUDOnMain()
        }
    }

    func dismissHUD() {
        DispatchQueue.main.async { [weak self] in
            self?.hideTimer?.cancel()
            self?.hideHUDAnimated()
        }
    }

    private func showHUDOnMain(message: String, characterCount: Int, wordCount: Int, fullText: String, showActions: Bool, isAdditive: Bool, duration: TimeInterval) {
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
            isAdditive: isAdditive
        )

        // Create window with dynamic height based on content
        let hostingView = NSHostingView(rootView: hudView)
        let fittingSize = hostingView.fittingSize
        let windowWidth: CGFloat = 360
        let windowHeight = max(fittingSize.height + 40, 240) // Add padding and ensure minimum height

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
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
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.midY - windowHeight / 2
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
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

    private func showLoadingHUDOnMain() {
        // Close existing HUD if present
        hideTimer?.cancel()
        if let existing = currentWindow {
            existing.close()
            currentWindow = nil
        }

        // Create loading view
        let loadingView = LoadingHUDView()

        // Create window
        let hostingView = NSHostingView(rootView: loadingView)
        let windowWidth: CGFloat = 360
        let windowHeight: CGFloat = 120

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = true // No interaction for loading
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false

        // Position at center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.midY - windowHeight / 2
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }

        // Store strong reference before showing
        currentWindow = window

        // Show with animation
        window.alphaValue = 0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        })
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

}
