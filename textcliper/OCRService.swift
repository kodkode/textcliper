//
//  OCRService.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//

import Foundation
import AppKit
import Vision
import UniformTypeIdentifiers
import ImageIO

enum OCRError: Error {
    case screenshotFailed
    case imageLoadFailed
    case ocrFailed
    case noTextDetected
    case permissionDenied
}

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Captures a screenshot with interactive selection using /usr/sbin/screencapture
    /// Works with sandbox using temporary-exception entitlement (like TextSniper)
    /// - Parameter completion: Called with the temporary file URL or error
    func captureScreenshot(completion: @escaping (Result<URL, OCRError>) -> Void) {

        // Use /usr/sbin/screencapture with -i (interactive) flag
        // This works in sandbox with com.apple.security.temporary-exception.mach-register.global-name entitlement
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("screenshot_\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tempURL.path]  // -i = interactive selection

        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    // Check if file was actually created (user might have cancelled)
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        completion(.success(tempURL))
                    } else {
                        NSSound.beep() // Play system beep sound
                        completion(.failure(.screenshotFailed))
                    }
                } else {
                    // Non-zero exit status - user likely cancelled (pressed ESC)
                    NSSound.beep() // Play system beep sound
                    completion(.failure(.screenshotFailed))
                }
            }
        }

        do {
            try process.run()
        } catch {
            completion(.failure(.screenshotFailed))
        }
    }

    /// Saves a CGImage to a temporary PNG file
    private func saveCGImage(_ image: CGImage, completion: @escaping (Result<URL, OCRError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("screenshot_\(UUID().uuidString).png")

            guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, kUTTypePNG, 1, nil) else {
                DispatchQueue.main.async {
                    completion(.failure(.screenshotFailed))
                }
                return
            }

            CGImageDestinationAddImage(destination, image, nil)

            if CGImageDestinationFinalize(destination) {
                DispatchQueue.main.async {
                    completion(.success(tempURL))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(.screenshotFailed))
                }
            }
        }
    }

    /// Fallback method for macOS < 14.0 (captures full screen)
    private func captureFallback(completion: @escaping (Result<URL, OCRError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: 0.5) // Allow window switching

            let displayID = CGMainDisplayID()

            guard let image = CGDisplayCreateImage(displayID) else {
                DispatchQueue.main.async {
                    completion(.failure(.screenshotFailed))
                }
                return
            }

            self.saveCGImage(image, completion: completion)
        }
    }

    /// Performs OCR on an image file
    /// - Parameters:
    ///   - imageURL: URL to the image file
    ///   - completion: Called with recognized text or error
    func performOCR(on imageURL: URL, completion: @escaping (Result<String, OCRError>) -> Void) {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            DispatchQueue.main.async {
                completion(.failure(.imageLoadFailed))
            }
            return
        }

        // Check if AI-enhanced mode is enabled
        let aiEnabled = UserDefaults.standard.bool(forKey: "aiEnhancedOCREnabled")
        let provider = UserDefaults.standard.string(forKey: "aiProvider") ?? "openai"

        let hasAPIKey: Bool
        if provider == "openai" {
            hasAPIKey = KeychainService.shared.getOpenAIKey() != nil
        } else if provider == "gemini" {
            hasAPIKey = KeychainService.shared.getGeminiKey() != nil
        } else if provider == "ocrspace" {
            hasAPIKey = KeychainService.shared.getOCRSpaceKey() != nil
        } else {
            hasAPIKey = false
        }

        if aiEnabled && hasAPIKey {
            // Show loading animation for AI-Enhanced OCR
            DispatchQueue.main.async {
                HUDManager.shared.showLoadingHUD()
            }

            // Use selected AI provider
            if provider == "openai" {
                let model = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o"
                self.performOpenAIOCR(on: image, completion: completion)
            } else if provider == "gemini" {
                let model = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.5-flash"
                self.performGeminiOCR(on: image, completion: completion)
            } else if provider == "ocrspace" {
                self.performOCRSpaceOCR(on: image, completion: completion)
            }
        } else {
            // Use standard Vision OCR
            self.performStandardOCR(on: cgImage, completion: completion)
        }
    }

    /// Perform AI-enhanced OCR using OpenAI
    private func performOpenAIOCR(on image: NSImage, completion: @escaping (Result<String, OCRError>) -> Void) {
        OpenAIService.shared.extractTextFromImage(image) { result in
            switch result {
            case .success(let text):
                if text.isEmpty {
                    completion(.failure(.noTextDetected))
                } else {
                    completion(.success(text))
                }
            case .failure(let error):
                // Fallback to standard Vision OCR if API fails
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    self.performStandardOCR(on: cgImage, completion: completion)
                } else {
                    completion(.failure(.ocrFailed))
                }
            }
        }
    }

    /// Perform AI-enhanced OCR using Gemini
    private func performGeminiOCR(on image: NSImage, completion: @escaping (Result<String, OCRError>) -> Void) {
        GeminiService.shared.extractTextFromImage(image) { result in
            switch result {
            case .success(let text):
                if text.isEmpty {
                    completion(.failure(.noTextDetected))
                } else {
                    completion(.success(text))
                }
            case .failure(let error):
                // Fallback to standard Vision OCR if API fails
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    self.performStandardOCR(on: cgImage, completion: completion)
                } else {
                    completion(.failure(.ocrFailed))
                }
            }
        }
    }

    /// Perform OCR using OCR.space API
    private func performOCRSpaceOCR(on image: NSImage, completion: @escaping (Result<String, OCRError>) -> Void) {
        OCRSpaceService.shared.extractTextFromImage(image) { result in
            switch result {
            case .success(let text):
                if text.isEmpty {
                    completion(.failure(.noTextDetected))
                } else {
                    completion(.success(text))
                }
            case .failure(let error):
                // Fallback to standard Vision OCR if API fails
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    self.performStandardOCR(on: cgImage, completion: completion)
                } else {
                    completion(.failure(.ocrFailed))
                }
            }
        }
    }

    /// Perform standard Vision OCR
    private func performStandardOCR(on cgImage: CGImage, completion: @escaping (Result<String, OCRError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(.ocrFailed))
                    }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        completion(.failure(.ocrFailed))
                    }
                    return
                }

                // Sort observations spatially for proper multi-column reading
                let sortedObservations = self.sortObservationsForReading(observations)

                let recognizedText = sortedObservations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if recognizedText.isEmpty {
                    DispatchQueue.main.async {
                        completion(.failure(.noTextDetected))
                    }
                    return
                }

                // Clean the text and fix hyphenation
                var cleaned = self.cleanText(recognizedText)
                cleaned = self.fixHyphenation(cleaned)

                // Reconstruct natural paragraphs
                cleaned = self.reconstructParagraphs(cleaned)

                DispatchQueue.main.async {
                    completion(.success(cleaned))
                }
            }

            // Use revision 3 (LiveText) for best accuracy - requires macOS 13+
            if #available(macOS 13, *) {
                request.revision = VNRecognizeTextRequestRevision3
            } else {
                request.revision = VNRecognizeTextRequestRevision1
            }

            // Only use Latin-script and Cyrillic languages for reliable recognition
            // NOTE: Mixing different script types (Latin + Thai/Arabic/Vietnamese) causes
            // Vision to fail at recognizing non-Latin scripts!
            // For Thai, Arabic, Vietnamese → use AI-Enhanced OCR instead
            request.recognitionLanguages = [
                "en-US",      // English
                "fr-FR",      // French
                "it-IT",      // Italian
                "de-DE",      // German
                "es-ES",      // Spanish
                "pt-BR",      // Portuguese (Brazilian)
                "ru-RU",      // Russian
                "uk-UA"       // Ukrainian
            ]
            // EXCLUDED (work alone but fail when mixed with Latin scripts):
            // - th-TH (Thai), vi-VT (Vietnamese), ar-SA (Arabic)
            // EXCLUDED (to avoid character confusion):
            // - zh-Hans, zh-Hant (Chinese), ja-JP (Japanese), ko-KR (Korean)
            request.usesLanguageCorrection = true
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.ocrFailed))
                }
            }
        }
    }

    /// Captures a screenshot and scans for QR codes and barcodes
    /// - Parameter completion: Called with the detected barcode data or error
    func captureAndScanBarcode(completion: @escaping (Result<String, OCRError>) -> Void) {
        captureScreenshot { result in
            switch result {
            case .success(let imageURL):
                self.performBarcodeDetection(on: imageURL, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Performs barcode detection on an image file
    /// - Parameters:
    ///   - imageURL: URL to the image file
    ///   - completion: Called with detected barcode data or error
    func performBarcodeDetection(on imageURL: URL, completion: @escaping (Result<String, OCRError>) -> Void) {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            DispatchQueue.main.async {
                completion(.failure(.imageLoadFailed))
            }
            return
        }

        // Perform barcode detection on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(.ocrFailed))
                    }
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation],
                      !observations.isEmpty else {
                    DispatchQueue.main.async {
                        completion(.failure(.noTextDetected))
                    }
                    return
                }

                // Collect all barcode payloads
                var results: [String] = []
                for observation in observations {
                    if let payload = observation.payloadStringValue {
                        results.append(payload)
                    }
                }

                // Clean up temp file
                try? FileManager.default.removeItem(at: imageURL)

                if results.isEmpty {
                    DispatchQueue.main.async {
                        completion(.failure(.noTextDetected))
                    }
                } else {
                    let finalResult = results.joined(separator: "\n")
                    DispatchQueue.main.async {
                        completion(.success(finalResult))
                    }
                }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.ocrFailed))
                }
            }
        }
    }

    /// Sorts text observations for proper reading order (handles multi-column layouts)
    /// - Parameter observations: Raw Vision text observations
    /// - Returns: Observations sorted for natural reading flow
    private func sortObservationsForReading(_ observations: [VNRecognizedTextObservation]) -> [VNRecognizedTextObservation] {
        guard !observations.isEmpty else { return observations }

        // Detect if text is in columns by analyzing horizontal positions
        let xPositions = observations.map { $0.boundingBox.origin.x }
        let avgX = xPositions.reduce(0, +) / Double(xPositions.count)

        // Group observations into left and right columns
        var leftColumn: [VNRecognizedTextObservation] = []
        var rightColumn: [VNRecognizedTextObservation] = []

        for obs in observations {
            if obs.boundingBox.origin.x < avgX {
                leftColumn.append(obs)
            } else {
                rightColumn.append(obs)
            }
        }

        // Check if we actually have two distinct columns by ensuring there is an actual gap between groups.
        let leftColumnMaxX = leftColumn.compactMap { observation in
            observation.boundingBox.maxX
        }.max() ?? 0
        let rightColumnMinX = rightColumn.compactMap { observation in
            observation.boundingBox.minX
        }.min() ?? 1
        let horizontalGap = rightColumnMinX - leftColumnMaxX
        let gapThreshold: CGFloat = 0.05
        let hasColumns = leftColumn.count > 3 &&
            rightColumn.count > 3 &&
            horizontalGap > gapThreshold

        if hasColumns {
            let gapString = String(format: "%.2f", Double(horizontalGap))

            // Sort each column top-to-bottom (Vision coordinates are flipped, so we sort descending)
            leftColumn.sort { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            rightColumn.sort { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

            // Return left column first, then right column
            return leftColumn + rightColumn
        } else {
            // Single column: just sort top-to-bottom
            return observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        }
    }

    /// Fixes hyphenation artifacts from multi-line text
    /// - Parameter text: Text with potential hyphenation issues
    /// - Returns: Text with hyphenation fixed
    private func fixHyphenation(_ text: String) -> String {
        var result = text

        // Fix words split across lines with hyphens
        // Pattern: "word-\npart" -> "wordpart"
        result = result.replacingOccurrences(
            of: "-\\s*\\n\\s*",
            with: "",
            options: .regularExpression
        )

        return result
    }

    /// Reconstructs natural paragraphs from OCR line-by-line output
    /// - Parameter text: Text with line breaks from OCR
    /// - Returns: Text with intelligent paragraph formatting
    private func reconstructParagraphs(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)

        // Detect if this is a list (file list, bullet list, etc.)
        // Lists have: short lines, many lines, similar structure
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let avgLineLength = nonEmptyLines.isEmpty ? 0 : nonEmptyLines.reduce(0) { $0 + $1.count } / nonEmptyLines.count
        let lineCount = nonEmptyLines.count

        // If we have many short lines (like a file list), don't reconstruct - keep as list
        // Criteria: 5+ lines with average length < 50 characters
        if lineCount >= 5 && avgLineLength < 50 {
            // This looks like a list - preserve line breaks
            return text
        }

        // Also check if many lines end with common file extensions or similar patterns
        let fileExtensionPattern = "\\.(swift|txt|md|js|py|java|c|cpp|h|json|xml|html|css)$"
        let linesWithExtensions = nonEmptyLines.filter { $0.range(of: fileExtensionPattern, options: .regularExpression) != nil }
        if linesWithExtensions.count > lineCount / 2 {
            // Majority are filenames - keep as list
            return text
        }

        // Otherwise, it's natural text - reconstruct paragraphs
        var paragraphs: [String] = []
        var currentParagraph: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines - they indicate paragraph breaks
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.joined(separator: " "))
                    currentParagraph = []
                }
                continue
            }

            // Check if this line should start a new paragraph
            let shouldStartNewParagraph = self.shouldStartNewParagraph(
                currentLine: trimmed,
                previousLine: index > 0 ? lines[index - 1].trimmingCharacters(in: .whitespaces) : nil,
                currentParagraph: currentParagraph
            )

            if shouldStartNewParagraph && !currentParagraph.isEmpty {
                // Finish current paragraph and start new one
                paragraphs.append(currentParagraph.joined(separator: " "))
                currentParagraph = [trimmed]
            } else {
                // Add to current paragraph
                currentParagraph.append(trimmed)
            }
        }

        // Add final paragraph if exists
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph.joined(separator: " "))
        }

        // Join paragraphs with double newline
        return paragraphs.joined(separator: "\n\n")
    }

    /// Determines if a line should start a new paragraph
    /// - Parameters:
    ///   - currentLine: The current line being processed
    ///   - previousLine: The previous line (if any)
    ///   - currentParagraph: Lines accumulated in current paragraph
    /// - Returns: True if this line should start a new paragraph
    private func shouldStartNewParagraph(currentLine: String, previousLine: String?, currentParagraph: [String]) -> Bool {
        // First line always starts a paragraph
        guard let prev = previousLine, !prev.isEmpty else {
            return currentParagraph.isEmpty
        }

        // Sentences ending with period, exclamation, or question mark likely end paragraphs
        let sentenceEnders: Set<Character> = [".", "!", "?", "\"", "'"]
        let prevEndsWithPunctuation = prev.last.map { sentenceEnders.contains($0) } ?? false

        // Lines that start with capital letters after sentence-ending punctuation
        let startsWithCapital = currentLine.first?.isUppercase ?? false

        // Check for common paragraph starters
        let paragraphStarters = ["In ", "The ", "When ", "Originally ", "However,", "Therefore,", "According to"]
        let hasParagraphStarter = paragraphStarters.contains { currentLine.hasPrefix($0) }

        // Very short previous lines might indicate list items or headers
        let prevIsShort = prev.count < 50

        // Check if previous line looks complete (ends with period/punctuation)
        if prevEndsWithPunctuation && startsWithCapital && hasParagraphStarter {
            return true
        }

        // Short previous line + capital start = likely new paragraph/section
        if prevIsShort && prevEndsWithPunctuation && startsWithCapital {
            return true
        }

        // Check for citation/reference patterns like "[14]"
        let citationPattern = "\\[\\d+\\]"
        if prev.range(of: citationPattern, options: .regularExpression) != nil {
            // Previous line has a citation, current might be new paragraph
            if startsWithCapital {
                return true
            }
        }

        return false
    }

    /// Cleans OCR text by removing artifact lines and unwanted symbols
    /// - Parameter text: Raw OCR text
    /// - Returns: Cleaned text
    private func cleanText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)

        let cleaned = lines.compactMap { line -> String? in
            var trimmed = line.trimmingCharacters(in: .whitespaces)

            // Remove empty lines
            if trimmed.isEmpty {
                return nil
            }

            // Only remove very specific UI icons that appear as single characters before text
            // Pattern: single non-word char at start followed by space, but preserve dots, hyphens, etc.
            // Only target common sidebar icons: ›, •, ▸, v (checkbox), etc.
            let iconPattern = "^[›•▸▾▴◂УЎ⌘⌥⇧⌃⏵⏴▶▼≡☰ãv=¥]+\\s+"
            trimmed = trimmed.replacingOccurrences(
                of: iconPattern,
                with: "",
                options: .regularExpression
            )

            // Remove these same icons if they appear at the end
            let trailingIconPattern = "\\s+[›•▸▾▴◂УЎ⌘⌥⇧⌃⏵⏴▶▼≡☰ãv=¥]+$"
            trimmed = trimmed.replacingOccurrences(
                of: trailingIconPattern,
                with: "",
                options: .regularExpression
            )

            // Clean up multiple spaces
            trimmed = trimmed.replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )

            // Final trim
            trimmed = trimmed.trimmingCharacters(in: .whitespaces)

            // Skip if now empty
            if trimmed.isEmpty {
                return nil
            }

            // Keep lines with reasonable content
            if trimmed.count < 2 {
                // Very short lines - check if they're just symbols
                if trimmed.rangeOfCharacter(from: CharacterSet.alphanumerics) == nil {
                    return nil // Just symbols, skip it
                }
            }

            // Remove lines with repeated single characters (e.g., "eee", "|||")
            let uniqueChars = Set(trimmed)
            if uniqueChars.count <= 1 {
                return nil
            }

            return trimmed
        }

        return cleaned.joined(separator: "\n")
    }

    /// Captures screenshot and performs OCR in one operation
    /// - Parameter completion: Called with recognized text or error
    func captureAndExtractText(completion: @escaping (Result<String, OCRError>) -> Void) {
        captureScreenshot { [weak self] result in
            switch result {
            case .success(let imageURL):
                self?.performOCR(on: imageURL) { ocrResult in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: imageURL)

                    completion(ocrResult)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Imports an image file and performs OCR
}
