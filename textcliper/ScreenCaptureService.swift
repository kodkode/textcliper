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

        Task {
            do {
                // Get available shareable content
                // This will trigger permission prompt if not already granted
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)


                // Get the main display
                guard let mainDisplay = content.displays.first else {
                    throw NSError(domain: "ScreenCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
                }


                // Create filter for full display
                let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])

                // Create configuration
                let config = SCStreamConfiguration()
                config.width = mainDisplay.width * 2  // Retina resolution
                config.height = mainDisplay.height * 2
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false

                // Capture the screenshot
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)


                await MainActor.run {
                    completion(.success(image))
                }

            } catch {

                // Check if it's a permission error
                if error.localizedDescription.contains("not authorized") ||
                   error.localizedDescription.contains("permission") {
                }

                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}
