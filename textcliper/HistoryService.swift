//
//  HistoryService.swift
//  textcliper
//
//  Created by Michael on 08/10/2025.
//

import Foundation
import Combine

class HistoryService: ObservableObject {
    static let shared = HistoryService()

    @Published private(set) var items: [HistoryItem] = []
    private let maxItems = 50 // Keep last 50 items
    private let storageKey = "captureHistory"
    private let encryptedStorageKey = "captureHistoryEncrypted"
    private let encryptionEnabled = true // Enable encryption by default

    private init() {
        loadHistory()
    }

    // MARK: - Public Methods

    func addItem(_ item: HistoryItem) {
        items.insert(item, at: 0)

        // Trim to max items
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        saveHistory()
    }

    func deleteItem(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearAll() {
        items.removeAll()
        saveHistory()
    }

    func updateItem(_ item: HistoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveHistory()
        }
    }

    func markAsSynced(itemID: UUID, cloudRecordID: String) {
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            var item = items[index]
            item.isSynced = true
            item.cloudRecordID = cloudRecordID
            items[index] = item
            saveHistory()
        }
    }

    func getUnsyncedItems() -> [HistoryItem] {
        return items.filter { !$0.isSynced }
    }

    // MARK: - Storage

    private func loadHistory() {
        // Try to load encrypted history first
        if encryptionEnabled, let encryptedData = UserDefaults.standard.data(forKey: encryptedStorageKey) {
            if let decryptedData = try? EncryptionService.shared.decrypt(encryptedData),
               let decoded = try? JSONDecoder().decode([HistoryItem].self, from: decryptedData) {
                items = decoded
                print("🔓 Loaded \(items.count) encrypted history items")
                return
            }
        }

        // Fallback to unencrypted (for migration from old version)
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
            print("📦 Loaded \(items.count) unencrypted history items (will encrypt on next save)")

            // Migrate to encrypted storage
            if encryptionEnabled {
                saveHistory()
            }
            return
        }

        print("📝 No history found, starting fresh")
    }

    private func saveHistory() {
        if encryptionEnabled {
            // Save encrypted
            do {
                let encoded = try JSONEncoder().encode(items)
                let encrypted = try EncryptionService.shared.encrypt(encoded)
                UserDefaults.standard.set(encrypted, forKey: encryptedStorageKey)

                // Remove old unencrypted data
                UserDefaults.standard.removeObject(forKey: storageKey)

                print("🔐 Saved \(items.count) items (encrypted)")
            } catch {
                print("❌ Failed to encrypt history: \(error.localizedDescription)")

                // Fallback to unencrypted
                if let encoded = try? JSONEncoder().encode(items) {
                    UserDefaults.standard.set(encoded, forKey: storageKey)
                    print("⚠️ Saved unencrypted as fallback")
                }
            }
        } else {
            // Save unencrypted
            if let encoded = try? JSONEncoder().encode(items) {
                UserDefaults.standard.set(encoded, forKey: storageKey)
            }
        }
    }

    // MARK: - Statistics

    var totalCharacters: Int {
        items.reduce(0) { $0 + $1.characterCount }
    }

    var totalWords: Int {
        items.reduce(0) { $0 + $1.wordCount }
    }

    var storageSize: String {
        let bytes = items.reduce(0) { $0 + $1.text.utf8.count }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
