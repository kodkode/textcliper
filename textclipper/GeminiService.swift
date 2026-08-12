//
//  GeminiService.swift
//  textclipper
//
//  Google Gemini API integration for fast handwriting recognition
//

import Foundation
import AppKit

enum GeminiError: Error {
    case noAPIKey
    case invalidImage
    case networkError(String)
    case apiError(String)
    case invalidResponse
}

class GeminiService {
    static let shared = GeminiService()

    private var apiEndpoint: String {
        let model = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.5-flash"
        return "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    }

    private init() {}

    /// Extract text from image using Gemini Flash API
    /// - Parameters:
    ///   - image: NSImage to process
    ///   - completion: Result with extracted text or error
    func extractTextFromImage(_ image: NSImage, completion: @escaping (Result<String, GeminiError>) -> Void) {
        // Check cache first
        if let cachedText = OCRCacheService.shared.getCachedResult(for: image) {
            completion(.success(cachedText))
            return
        }

        // Get API key from keychain
        guard let apiKey = KeychainService.shared.getGeminiKey(), !apiKey.isEmpty else {
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

            // Prepare API request - Gemini uses different format than OpenAI
            let payload: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            [
                                "text": "Extract all text from this image exactly as it appears. If the text is in multiple columns, read left-to-right, top-to-bottom. DO NOT convert to tables or add markdown formatting. DO NOT add headers or structure. Return ONLY the plain extracted text, preserving paragraph breaks but treating this as prose/document text, not tabular data."
                            ],
                            [
                                "inline_data": [
                                    "mime_type": "image/jpeg",  // Changed from PNG to JPEG
                                    "data": base64Image
                                ]
                            ]
                        ]
                    ]
                ],
                "generationConfig": [
                    "temperature": 0,  // Deterministic output for faster processing
                    "maxOutputTokens": 2048  // Limit output tokens for speed
                ]
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            // Send the API key via header, not the URL — query strings end up in
            // proxy/server logs
            guard let url = URL(string: self.apiEndpoint) else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = jsonData
            request.timeoutInterval = 60  // Gemini Flash is very fast


            // Send request
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
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

                    // Extract content from Gemini's response format
                    guard let candidates = json["candidates"] as? [[String: Any]],
                          let firstCandidate = candidates.first,
                          let content = firstCandidate["content"] as? [String: Any],
                          let parts = content["parts"] as? [[String: Any]],
                          let firstPart = parts.first,
                          let text = firstPart["text"] as? String else {
                        DispatchQueue.main.async {
                            completion(.failure(.invalidResponse))
                        }
                        return
                    }

                    // Log success with detailed metrics

                    let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

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
