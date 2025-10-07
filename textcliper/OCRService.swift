//
//  OCRService.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//

import Foundation
import AppKit
import Vision

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

    /// Captures a screenshot with interactive selection
    /// - Parameter completion: Called with the temporary file URL or error
    func captureScreenshot(completion: @escaping (Result<URL, OCRError>) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("screenshot_\(UUID().uuidString).png")

        print("📸 Starting screenshot capture...")
        print("   Temp file: \(tempURL.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tempURL.path] // -i for interactive selection

        // Capture stderr to see permission errors
        let errorPipe = Pipe()
        process.standardError = errorPipe

        process.terminationHandler = { process in
            // Read any error output
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8) {
                print("⚠️ screencapture stderr: \(errorString)")
            }

            DispatchQueue.main.async {
                print("   Termination status: \(process.terminationStatus)")
                print("   File exists: \(FileManager.default.fileExists(atPath: tempURL.path))")

                if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: tempURL.path) {
                    print("✅ Screenshot captured successfully")
                    completion(.success(tempURL))
                } else {
                    print("❌ Screenshot failed (user cancelled or permission denied)")
                    // User cancelled or screenshot failed
                    completion(.failure(.screenshotFailed))
                }
            }
        }

        do {
            try process.run()
        } catch {
            print("❌ Failed to launch screencapture: \(error)")
            DispatchQueue.main.async {
                completion(.failure(.screenshotFailed))
            }
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

        // Perform OCR on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("OCR error: \(error.localizedDescription)")
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

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if recognizedText.isEmpty {
                    DispatchQueue.main.async {
                        completion(.failure(.noTextDetected))
                    }
                    return
                }

                // Clean the text
                let cleaned = self.cleanText(recognizedText)

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

            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Vision request error: \(error.localizedDescription)")
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
                    print("Barcode detection error: \(error.localizedDescription)")
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
                print("Vision barcode request error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.ocrFailed))
                }
            }
        }
    }

    /// Cleans OCR text by removing artifact lines
    /// - Parameter text: Raw OCR text
    /// - Returns: Cleaned text
    private func cleanText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let cleaned = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Keep empty lines and short lines
            if trimmed.count < 3 {
                return true
            }

            // Remove lines with repeated single characters (e.g., "eee", "|||")
            let uniqueChars = Set(trimmed)
            return uniqueChars.count > 1
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
}
