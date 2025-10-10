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

        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ API Network Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let data = data else {
                print("❌ API No data received")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 API Response: \(responseString)")
            }

            // Parse response
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ API Invalid JSON response")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                // Check for API error first
                if let error = json["error"] as? [String: Any],
                   let errorMessage = error["message"] as? String {
                    print("❌ API Error: \(errorMessage)")
                    DispatchQueue.main.async {
                        completion(.failure(.apiError(errorMessage)))
                    }
                    return
                }

                // Extract content
                guard let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    print("❌ API Could not extract content from response")
                    print("   Response structure: \(json)")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                print("✅ API Extracted text: \(content.prefix(100))...")
                DispatchQueue.main.async {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } catch {
                print("❌ API JSON parsing error: \(error)")
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
