//
//  OCRSpaceService.swift
//  textclipper
//
//  Created by Claude on 23/10/2025.
//

import Foundation
import AppKit

class OCRSpaceService {
    static let shared = OCRSpaceService()

    private let apiEndpoint = "https://api.ocr.space/parse/image"

    private init() {}

    /// Extract text from an image using OCR.space API
    /// - Parameters:
    ///   - image: The NSImage to process
    ///   - completion: Called with extracted text or error
    func extractTextFromImage(_ image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        // Get API key from Keychain
        guard let apiKey = KeychainService.shared.getOCRSpaceKey() else {
            completion(.failure(NSError(domain: "OCRSpaceService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "OCR.space API key not found. Please add it in Settings."
            ])))
            return
        }

        // Convert NSImage to JPEG data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            completion(.failure(NSError(domain: "OCRSpaceService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert image to JPEG"
            ])))
            return
        }

        // Create multipart form data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n".data(using: .utf8)!)

        // Add OCR engine parameter (engine 2 is better for most use cases)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"OCREngine\"\r\n\r\n".data(using: .utf8)!)
        body.append("2\r\n".data(using: .utf8)!)

        // Add language parameter (auto-detect)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("eng\r\n".data(using: .utf8)!)

        // Add isOverlayRequired parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"isOverlayRequired\"\r\n\r\n".data(using: .utf8)!)
        body.append("false\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Make API request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OCRSpaceService", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "No data received from API"
                    ])))
                }
                return
            }

            do {
                // Parse JSON response
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                // Check for errors
                if let errorMessage = json?["ErrorMessage"] as? [String], !errorMessage.isEmpty {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "OCRSpaceService", code: 4, userInfo: [
                            NSLocalizedDescriptionKey: errorMessage.joined(separator: ", ")
                        ])))
                    }
                    return
                }

                // Extract text from response
                if let parsedResults = json?["ParsedResults"] as? [[String: Any]],
                   let firstResult = parsedResults.first,
                   let parsedText = firstResult["ParsedText"] as? String {

                    let cleanedText = parsedText.trimmingCharacters(in: .whitespacesAndNewlines)

                    DispatchQueue.main.async {
                        if cleanedText.isEmpty {
                            completion(.failure(NSError(domain: "OCRSpaceService", code: 5, userInfo: [
                                NSLocalizedDescriptionKey: "No text detected in image"
                            ])))
                        } else {
                            completion(.success(cleanedText))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "OCRSpaceService", code: 6, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to parse API response"
                        ])))
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
