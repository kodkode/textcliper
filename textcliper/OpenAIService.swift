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
    private let model = "gpt-5" // GPT-5 full model for best accuracy

    private init() {}

    /// Extract text from image using OpenAI Vision API
    /// - Parameters:
    ///   - image: NSImage to process
    ///   - completion: Result with extracted text or error
    func extractTextFromImage(_ image: NSImage, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        // Start timing
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get API key from keychain
        guard let apiKey = KeychainService.shared.getOpenAIKey(), !apiKey.isEmpty else {
            completion(.failure(.noAPIKey))
            return
        }

        // Convert image to base64
        guard let base64Image = image.base64EncodedString() else {
            completion(.failure(.invalidImage))
            return
        }

        // Prepare API request
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Extract all text from this image. Return ONLY the extracted text with no additional commentary, explanations, or formatting. Preserve the original line breaks and spacing as much as possible."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_completion_tokens": 100000  // High token limit for complex handwriting extraction
            // Reasoning enabled by default for better accuracy
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(.invalidResponse))
            return
        }

        // Create request
        guard let url = URL(string: apiEndpoint) else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 180  // 3 minutes for GPT-5 with reasoning

        print("⏱️ [OpenAI] API request started...")

        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            if let error = error {
                print("❌ [OpenAI] Network Error: \(error.localizedDescription)")
                print("⏱️ [OpenAI] Failed after: \(String(format: "%.2f", timeElapsed))s")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let data = data else {
                print("❌ [OpenAI] No data received")
                print("⏱️ [OpenAI] Failed after: \(String(format: "%.2f", timeElapsed))s")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            // Parse response
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ [OpenAI] Invalid JSON response")
                    print("⏱️ [OpenAI] Failed after: \(String(format: "%.2f", timeElapsed))s")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                // Check for API error first
                if let error = json["error"] as? [String: Any],
                   let errorMessage = error["message"] as? String {
                    print("❌ [OpenAI] API Error: \(errorMessage)")
                    print("⏱️ [OpenAI] Failed after: \(String(format: "%.2f", timeElapsed))s")
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
                    print("❌ [OpenAI] Could not extract content from response")
                    print("   Response structure: \(json)")
                    print("⏱️ [OpenAI] Failed after: \(String(format: "%.2f", timeElapsed))s")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                // Log success with detailed metrics
                print("✅ [OpenAI] OCR completed successfully")
                print("⏱️ [OpenAI] Response time: \(String(format: "%.2f", timeElapsed))s")
                print("📊 [OpenAI] Token Usage:")
                print("   • Prompt tokens:     \(promptTokens)")
                print("   • Completion tokens: \(completionTokens)")
                print("   • Total tokens:      \(totalTokens)")
                print("📝 [OpenAI] Extracted text: \(content.prefix(100))...")

                DispatchQueue.main.async {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } catch {
                print("❌ [OpenAI] JSON parsing error: \(error)")
                print("⏱️ [OpenAI] Failed after: \(String(format: "%.2f", timeElapsed))s")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
            }
        }

        task.resume()
    }
}

// MARK: - NSImage Extension

extension NSImage {
    /// Convert NSImage to base64 encoded string
    func base64EncodedString() -> String? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // Convert to PNG
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData.base64EncodedString()
    }
}
