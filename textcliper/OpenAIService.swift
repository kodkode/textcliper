//
//  OpenAIService.swift
//  textcliper
//
//  OpenAI API integration for enhanced handwriting recognition
//

import Foundation
import AppKit

enum OpenAIError: Error {
    case noAPIKey
    case invalidImage
    case networkError(String)
    case apiError(String)
    case invalidResponse
}

class OpenAIService {
    static let shared = OpenAIService()

    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"

    private var model: String {
        return UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o"
    }

    private init() {}

    /// Extract text from image using OpenAI Vision API
    /// - Parameters:
    ///   - image: NSImage to process
    ///   - completion: Result with extracted text or error
    func extractTextFromImage(_ image: NSImage, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        // Check cache first
        if let cachedText = OCRCacheService.shared.getCachedResult(for: image) {
            completion(.success(cachedText))
            return
        }

        // Start timing
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get API key from keychain
        guard let apiKey = KeychainService.shared.getOpenAIKey(), !apiKey.isEmpty else {
            completion(.failure(.noAPIKey))
            return
        }

        // Perform image encoding on background thread to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async { [image] in
            // Convert image to base64 (optimized with compression)
            guard let base64Image = image.base64EncodedString() else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidImage))
                }
                return
            }

            // Log encoding time
            let encodingTime = CFAbsoluteTimeGetCurrent() - startTime

            // Prepare API request
            let payload: [String: Any] = [
                "model": self.model,
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "text",
                                "text": "Extract all text from this image exactly as it appears. If the text is in multiple columns, read left-to-right, top-to-bottom. DO NOT convert to tables or add markdown formatting. DO NOT add headers or structure. Return ONLY the plain extracted text, preserving paragraph breaks but treating this as prose/document text, not tabular data."
                            ],
                            [
                                "type": "image_url",
                                "image_url": [
                                    "url": "data:image/jpeg;base64,\(base64Image)"  // Changed from PNG to JPEG
                                ]
                            ]
                        ]
                    ]
                ],
                "max_completion_tokens": 2048,  // Reduced from 100000 for faster response
                "temperature": 0  // Deterministic output for faster processing
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            // Create request
            guard let url = URL(string: self.apiEndpoint) else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            request.timeoutInterval = 180  // 3 minutes for GPT-5 with reasoning


            // Send request
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(.networkError(error.localizedDescription)))
                    }
                    return
                }

                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                // Parse response
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        DispatchQueue.main.async {
                            completion(.failure(.invalidResponse))
                        }
                        return
                    }

                    // Check for API error first
                    if let error = json["error"] as? [String: Any],
                       let errorMessage = error["message"] as? String {
                        DispatchQueue.main.async {
                            completion(.failure(.apiError(errorMessage)))
                        }
                        return
                    }

                    // Extract token usage
                    var promptTokens = 0
                    var completionTokens = 0
                    var totalTokens = 0

                    if let usage = json["usage"] as? [String: Any] {
                        promptTokens = usage["prompt_tokens"] as? Int ?? 0
                        completionTokens = usage["completion_tokens"] as? Int ?? 0
                        totalTokens = usage["total_tokens"] as? Int ?? 0
                    }

                    // Extract content
                    guard let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let message = firstChoice["message"] as? [String: Any],
                          let content = message["content"] as? String else {
                        DispatchQueue.main.async {
                            completion(.failure(.invalidResponse))
                        }
                        return
                    }

                    // Log success with detailed metrics

                    let cleanedText = content.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Cache the result for future use
                    OCRCacheService.shared.cacheResult(cleanedText, for: image)

                    DispatchQueue.main.async {
                        completion(.success(cleanedText))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                }
            }

            task.resume()
        }
    }
}

// MARK: - NSImage Extension

extension NSImage {
    /// Convert NSImage to base64 encoded string with optimized compression
    func base64EncodedString() -> String? {
        // Optimize image first (resize and compress)
        guard let optimizedImage = self.optimizedForOCR() else {
            return nil
        }

        guard let tiffData = optimizedImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // Use JPEG with 0.75 quality for much smaller file size (70-80% reduction)
        // JPEG is fine for OCR and drastically reduces upload time
        guard let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) else {
            return nil
        }

        return jpegData.base64EncodedString()
    }

    /// Optimize image for OCR by resizing and preparing for compression
    func optimizedForOCR(maxDimension: CGFloat = 2048) -> NSImage? {
        let currentSize = self.size

        // If image is already small enough, return as-is
        if currentSize.width <= maxDimension && currentSize.height <= maxDimension {
            return self
        }

        // Calculate new size maintaining aspect ratio
        let scale: CGFloat
        if currentSize.width > currentSize.height {
            scale = maxDimension / currentSize.width
        } else {
            scale = maxDimension / currentSize.height
        }

        let newSize = NSSize(width: currentSize.width * scale, height: currentSize.height * scale)

        // Create resized image
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: currentSize),
                  operation: .copy,
                  fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }
}
