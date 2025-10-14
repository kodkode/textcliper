//
//  GeminiService.swift
//  textcliper
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
        let model = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-1.5-pro"
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

        // Start timing
        let startTime = CFAbsoluteTimeGetCurrent()

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

            // Log encoding time
            let encodingTime = CFAbsoluteTimeGetCurrent() - startTime
            print("📦 [Gemini] Image encoded in \(String(format: "%.2f", encodingTime))s")

            // Prepare API request - Gemini uses different format than OpenAI
            let payload: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            [
                                "text": "Extract all text from this image. Return ONLY the extracted text with no additional commentary, explanations, or formatting. Preserve the original line breaks and spacing as much as possible."
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

            // Create request with API key in URL
            guard let url = URL(string: "\(self.apiEndpoint)?key=\(apiKey)") else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 60  // Gemini Flash is very fast

            print("⏱️ [Gemini] API request started...")

            // Send request
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                if let error = error {
                    print("❌ [Gemini] Network Error: \(error.localizedDescription)")
                    print("⏱️ [Gemini] Failed after: \(String(format: "%.2f", timeElapsed))s")
                    DispatchQueue.main.async {
                        completion(.failure(.networkError(error.localizedDescription)))
                    }
                    return
                }

                guard let data = data else {
                    print("❌ [Gemini] No data received")
                    print("⏱️ [Gemini] Failed after: \(String(format: "%.2f", timeElapsed))s")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                // Parse response
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("❌ [Gemini] Invalid JSON response")
                        print("⏱️ [Gemini] Failed after: \(String(format: "%.2f", timeElapsed))s")
                        DispatchQueue.main.async {
                            completion(.failure(.invalidResponse))
                        }
                        return
                    }

                    // Check for API error first
                    if let error = json["error"] as? [String: Any],
                       let errorMessage = error["message"] as? String {
                        print("❌ [Gemini] API Error: \(errorMessage)")
                        print("⏱️ [Gemini] Failed after: \(String(format: "%.2f", timeElapsed))s")
                        DispatchQueue.main.async {
                            completion(.failure(.apiError(errorMessage)))
                        }
                        return
                    }

                    // Extract token usage metadata
                    var inputTokens = 0
                    var outputTokens = 0
                    var totalTokens = 0

                    if let usageMetadata = json["usageMetadata"] as? [String: Any] {
                        inputTokens = usageMetadata["promptTokenCount"] as? Int ?? 0
                        outputTokens = usageMetadata["candidatesTokenCount"] as? Int ?? 0
                        totalTokens = usageMetadata["totalTokenCount"] as? Int ?? 0
                    }

                    // Extract content from Gemini's response format
                    guard let candidates = json["candidates"] as? [[String: Any]],
                          let firstCandidate = candidates.first,
                          let content = firstCandidate["content"] as? [String: Any],
                          let parts = content["parts"] as? [[String: Any]],
                          let firstPart = parts.first,
                          let text = firstPart["text"] as? String else {
                        print("❌ [Gemini] Could not extract content from response")
                        print("   Response structure: \(json)")
                        print("⏱️ [Gemini] Failed after: \(String(format: "%.2f", timeElapsed))s")
                        DispatchQueue.main.async {
                            completion(.failure(.invalidResponse))
                        }
                        return
                    }

                    // Log success with detailed metrics
                    print("✅ [Gemini] OCR completed successfully")
                    print("⏱️ [Gemini] Response time: \(String(format: "%.2f", timeElapsed))s")
                    print("📊 [Gemini] Token Usage:")
                    print("   • Input tokens:  \(inputTokens)")
                    print("   • Output tokens: \(outputTokens)")
                    print("   • Total tokens:  \(totalTokens)")
                    print("📝 [Gemini] Extracted text: \(text.prefix(100))...")

                    let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Cache the result for future use
                    OCRCacheService.shared.cacheResult(cleanedText, for: image)

                    DispatchQueue.main.async {
                        completion(.success(cleanedText))
                    }
                } catch {
                    print("❌ [Gemini] JSON parsing error: \(error)")
                    print("⏱️ [Gemini] Failed after: \(String(format: "%.2f", timeElapsed))s")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                }
            }

            task.resume()
        }
    }
}
