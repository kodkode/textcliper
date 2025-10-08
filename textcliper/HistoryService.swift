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
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }

        items = decoded
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
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
