//
//  EncryptionService.swift
//  textclipper
//
//  Created by Michael on 08/10/2025.
//

import Foundation
import CryptoKit
import Security

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    case keyRetrievalFailed
    case invalidData
}

class EncryptionService {
    static let shared = EncryptionService()

    private let keychainService = "com.textclipper.encryption"
    private let keychainAccount = "master-key"
    private var cachedKey: SymmetricKey?

    private init() {
        // Try to load existing key or generate new one
        do {
            _ = try getOrCreateEncryptionKey()
        } catch {
        }
    }

    // MARK: - Public Methods

    /// Encrypt data
    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)

            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }

            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// Encrypt string
    func encrypt(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }

        return try encrypt(data)
    }

    /// Decrypt data
    func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            return decryptedData
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// Decrypt to string
    func decryptString(_ data: Data) throws -> String {
        let decryptedData = try decrypt(data)

        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }

        return string
    }

    // MARK: - Key Management

    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        // Return cached key if available
        if let key = cachedKey {
            return key
        }

        // Try to load from Keychain
        if let keyData = try? loadKeyFromKeychain() {
            let key = SymmetricKey(data: keyData)
            cachedKey = key
            return key
        }

        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        // Save to Keychain
        try saveKeyToKeychain(keyData)

        cachedKey = key

        return key
    }

    private func saveKeyToKeychain(_ keyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false  // Prevent iCloud Keychain sync
        ]

        // Delete existing key if any
        SecItemDelete(query as CFDictionary)

        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw EncryptionError.keyGenerationFailed
        }
    }

    private func loadKeyFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny  // Match both synced and non-synced
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw EncryptionError.keyRetrievalFailed
        }

        return keyData
    }

    /// Check if encryption is available
    func isAvailable() -> Bool {
        do {
            _ = try getOrCreateEncryptionKey()
            return true
        } catch {
            return false
        }
    }

    /// Reset encryption key (DANGER: will make existing data unreadable)
    func resetEncryptionKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
        cachedKey = nil

        // Generate new key
        _ = try getOrCreateEncryptionKey()

    }
}
