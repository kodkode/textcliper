//
//  HistoryService.swift
//  textclipper
//
//  Created by Michael on 08/10/2025.
//

import Foundation
import Combine

class HistoryService: ObservableObject {
    static let shared = HistoryService()

    @Published private(set) var items: [HistoryItem] = []
    private let storageKey = "captureHistory"
    private let encryptedStorageKey = "captureHistoryEncrypted"
    private let encryptionEnabled = true // Enable encryption by default

    // User-configurable limits (managed in Settings). 0 retention days = never delete.
    private var retentionDays: Int {
        let value = UserDefaults.standard.object(forKey: "autoDeleteAfterDays") as? Int
        return value ?? 30
    }

    private var maxItems: Int {
        let value = UserDefaults.standard.object(forKey: "maxHistoryItems") as? Int ?? 500
        return value > 0 ? value : 500
    }

    /// Set when stored history exists but the keychain could not be read, so this
    /// session must not overwrite it.
    private var persistenceBlocked = false
    private let unreadableBackupKey = "captureHistoryEncrypted.unreadable"

    private init() {
        loadHistory()
        cleanupOldItems()
    }

    /// Retention cutoff from Settings; nil when auto-delete is set to "Never".
    var retentionCutoff: Date? {
        HistoryMerge.cutoff(retentionDays: retentionDays)
    }

    // MARK: - Public Methods

    func addItem(_ item: HistoryItem) {
        addItems([item])
    }

    /// Adds several items in one pass (one sort, one save) — used for iCloud downloads.
    func addItems(_ newItems: [HistoryItem]) {
        guard !newItems.isEmpty else { return }
        // Existing items win on duplicate ids (they carry the local sync state)
        let merged = HistoryMerge.merge(existing: items, incoming: newItems, cutoff: retentionCutoff, maxItems: maxItems)

        // Downloads beyond the cap merge to the same list; skip the re-encrypt and save
        guard merged.map(\.id) != items.map(\.id) else { return }
        items = merged
        saveHistory()
    }

    func deleteItem(_ item: HistoryItem) {
        CloudSyncService.shared.recordDeletion(of: [item])
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearAll() {
        CloudSyncService.shared.recordDeletion(of: items)
        items.removeAll()
        saveHistory()
    }

    func contains(itemID: UUID) -> Bool {
        items.contains { $0.id == itemID }
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

    // MARK: - Cleanup

    private func cleanupOldItems() {
        // Sorted newest first, so the cap always drops the oldest entries
        items = HistoryMerge.merge(existing: items, incoming: [], cutoff: retentionCutoff, maxItems: maxItems)
    }

    // MARK: - Storage

    private func loadHistory() {
        // Try to load encrypted history first
        if encryptionEnabled, let encryptedData = UserDefaults.standard.data(forKey: encryptedStorageKey) {
            do {
                let decryptedData = try EncryptionService.shared.decrypt(encryptedData)
                let decoded = try JSONDecoder().decode([HistoryItem].self, from: decryptedData)
                items = decoded.sorted { $0.timestamp > $1.timestamp }
                return
            } catch EncryptionError.keyRetrievalFailed {
                // Keychain temporarily unavailable: don't overwrite history we can't read yet
                NSLog("History key unavailable; history will not be saved this session")
                persistenceBlocked = true
                return
            } catch {
                // Data can't be decrypted with the current key. Keep a copy for recovery
                // rather than silently overwriting it, then start fresh.
                NSLog("Stored history is unreadable (\(error)); keeping a backup copy")
                if UserDefaults.standard.data(forKey: unreadableBackupKey) == nil {
                    UserDefaults.standard.set(encryptedData, forKey: unreadableBackupKey)
                }
                UserDefaults.standard.removeObject(forKey: encryptedStorageKey)
            }
        }

        // Fallback to unencrypted (for migration from old version)
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded.sorted { $0.timestamp > $1.timestamp }

            // Migrate to encrypted storage
            if encryptionEnabled {
                saveHistory()
            }
            return
        }

    }

    private func saveHistory() {
        guard !persistenceBlocked else { return }

        if encryptionEnabled {
            // Save encrypted
            do {
                let encoded = try JSONEncoder().encode(items)
                let encrypted = try EncryptionService.shared.encrypt(encoded)
                UserDefaults.standard.set(encrypted, forKey: encryptedStorageKey)

                // Remove old unencrypted data
                UserDefaults.standard.removeObject(forKey: storageKey)

            } catch {
                // Do NOT fall back to writing plaintext — captured text can contain
                // anything visible on screen. Keep the last good encrypted copy on
                // disk; current items remain available in memory for this session.
                NSLog("History encryption failed; skipping persist to avoid writing plaintext: \(error)")
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
