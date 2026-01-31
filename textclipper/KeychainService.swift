//
//  KeychainService.swift
//  textclipper
//
//  Secure storage for API keys using macOS Keychain
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.textclipper.apikeys"
    private let openAIKeyAccount = "openai-api-key"
    private let geminiKeyAccount = "gemini-api-key"
    private let ocrSpaceKeyAccount = "ocrspace-api-key"

    private init() {}

    // MARK: - OpenAI API Key

    func saveOpenAIKey(_ key: String) -> Bool {
        return save(key: key, account: openAIKeyAccount)
    }

    func getOpenAIKey() -> String? {
        return retrieve(account: openAIKeyAccount)
    }

    func deleteOpenAIKey() -> Bool {
        return delete(account: openAIKeyAccount)
    }

    // MARK: - Gemini API Key

    func saveGeminiKey(_ key: String) -> Bool {
        return save(key: key, account: geminiKeyAccount)
    }

    func getGeminiKey() -> String? {
        return retrieve(account: geminiKeyAccount)
    }

    func deleteGeminiKey() -> Bool {
        return delete(account: geminiKeyAccount)
    }

    // MARK: - OCR.space API Key

    func saveOCRSpaceKey(_ key: String) -> Bool {
        return save(key: key, account: ocrSpaceKeyAccount)
    }

    func getOCRSpaceKey() -> String? {
        return retrieve(account: ocrSpaceKeyAccount)
    }

    func deleteOCRSpaceKey() -> Bool {
        return delete(account: ocrSpaceKeyAccount)
    }

    // MARK: - Generic Keychain Operations

    private func save(key: String, account: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        // Delete existing item if any
        _ = delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false  // Prevent iCloud Keychain sync
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func retrieve(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny  // Match both synced and non-synced
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    private func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny  // Delete both synced and non-synced
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
