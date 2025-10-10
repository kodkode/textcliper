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
        // Get API key from keychain
        guard let apiKey = KeychainService.shared.getGeminiKey(), !apiKey.isEmpty else {
            completion(.failure(.noAPIKey))
            return
        }

        // Convert image to base64
        guard let base64Image = image.base64EncodedString() else {
            completion(.failure(.invalidImage))
            return
        }

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
                                "mime_type": "image/png",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(.invalidResponse))
            return
        }

        // Create request with API key in URL
        guard let url = URL(string: "\(apiEndpoint)?key=\(apiKey)") else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60  // Gemini Flash is very fast

        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Gemini Network Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let data = data else {
                print("❌ Gemini No data received")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Gemini Response: \(responseString)")
            }

            // Parse response
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ Gemini Invalid JSON response")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                // Check for API error first
                if let error = json["error"] as? [String: Any],
                   let errorMessage = error["message"] as? String {
                    print("❌ Gemini Error: \(errorMessage)")
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
                    print("❌ Gemini Could not extract content from response")
                    print("   Response structure: \(json)")
                    DispatchQueue.main.async {
                        completion(.failure(.invalidResponse))
                    }
                    return
                }

                print("✅ Gemini Extracted text: \(text.prefix(100))...")
                DispatchQueue.main.async {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            } catch {
                print("❌ Gemini JSON parsing error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
            }
        }

        task.resume()
    }
}
