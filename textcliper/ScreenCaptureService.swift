//
//  ScreenCaptureService.swift
//  textcliper
//
//  Sandbox-compatible screenshot capture using ScreenCaptureKit
//  Requires macOS 14.0+ (Sonoma) and Screen Recording permission
//

import Foundation
import ScreenCaptureKit
import AppKit

@available(macOS 14.0, *)
class ScreenCaptureService: NSObject {
    static let shared = ScreenCaptureService()

    private override init() {
        super.init()
    }

    /// Captures a screenshot of the entire main display
    /// Requires Screen Recording permission (user will be prompted by macOS on first use)
    func captureWithPicker(completion: @escaping (Result<CGImage, Error>) -> Void) {
        print("📸 Starting ScreenCaptureKit screenshot capture...")

        Task {
            do {
                // Get available shareable content
                // This will trigger permission prompt if not already granted
                print("🔍 Fetching shareable content...")
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                print("📋 Found \(content.displays.count) displays, \(content.windows.count) windows")

                // Get the main display
                guard let mainDisplay = content.displays.first else {
                    throw NSError(domain: "ScreenCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
                }

                print("🖥️  Capturing display: \(mainDisplay.width)x\(mainDisplay.height)")

                // Create filter for full display
                let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])

                // Create configuration
                let config = SCStreamConfiguration()
                config.width = mainDisplay.width * 2  // Retina resolution
                config.height = mainDisplay.height * 2
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false

                // Capture the screenshot
                print("📷 Capturing image...")
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                print("✅ Screenshot captured successfully!")
                print("   Size: \(image.width)×\(image.height)")

                await MainActor.run {
                    completion(.success(image))
                }

            } catch {
                print("❌ Screenshot capture failed: \(error.localizedDescription)")
                print("   Error details: \(error)")

                // Check if it's a permission error
                if error.localizedDescription.contains("not authorized") ||
                   error.localizedDescription.contains("permission") {
                    print("⚠️  Screen Recording permission is required!")
                    print("   Please grant permission in System Settings > Privacy & Security > Screen Recording")
                }

                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}
