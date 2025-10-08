//
//  CloudSyncService.swift
//  textcliper
//
//  Created by Michael on 08/10/2025.
//

import Foundation
import CloudKit
import Combine

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case error(String)
}

class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published var iCloudSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled")
            if iCloudSyncEnabled {
                startAutoSync()
            } else {
                stopAutoSync()
            }
        }
    }

    private var container: CKContainer?
    private var database: CKDatabase?
    private var syncTimer: Timer?
    private let autoSyncInterval: TimeInterval = 300 // 5 minutes
    private var isCloudKitAvailable = false

    private init() {
        // Disable iCloud sync by default since it requires proper signing
        self.iCloudSyncEnabled = false

        // Don't try to initialize CloudKit in development mode
        // It will crash without proper entitlements and signing
        // Users can enable this feature after signing the app with Apple Developer account
        print("ℹ️ CloudKit disabled - requires code signing with Apple Developer account")
        self.isCloudKitAvailable = false
    }

    // MARK: - Public Methods

    func syncNow() {
        guard iCloudSyncEnabled, isCloudKitAvailable else { return }

        Task {
            await performSync()
        }
    }

    func uploadItem(_ item: HistoryItem) async throws {
        guard iCloudSyncEnabled, let database = database else { return }

        let record = item.toCKRecord()

        do {
            let savedRecord = try await database.save(record)
            HistoryService.shared.markAsSynced(itemID: item.id, cloudRecordID: savedRecord.recordID.recordName)
            print("✅ Uploaded item to iCloud: \(item.preview)")
        } catch {
            print("❌ Failed to upload item: \(error.localizedDescription)")
            throw error
        }
    }

    func downloadNewItems() async throws -> [HistoryItem] {
        guard iCloudSyncEnabled, let database = database else { return [] }

        let query = CKQuery(recordType: "CaptureHistory", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 50)

            var newItems: [HistoryItem] = []
            let existingIDs = Set(HistoryService.shared.items.map { $0.cloudRecordID })

            for (_, result) in results {
                switch result {
                case .success(let record):
                    if let item = HistoryItem(from: record),
                       !existingIDs.contains(record.recordID.recordName) {
                        newItems.append(item)
                    }
                case .failure(let error):
                    print("❌ Failed to process record: \(error.localizedDescription)")
                }
            }

            return newItems
        } catch {
            print("❌ Failed to download items: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private Methods

    private func performSync() async {
        await MainActor.run {
            syncStatus = .syncing
        }

        do {
            // Upload unsynced items
            let unsyncedItems = HistoryService.shared.getUnsyncedItems()
            for item in unsyncedItems {
                try await uploadItem(item)
            }

            // Download new items from other devices
            let newItems = try await downloadNewItems()
            for item in newItems {
                await MainActor.run {
                    HistoryService.shared.addItem(item)
                }
            }

            await MainActor.run {
                syncStatus = .success
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")

                // Reset to idle after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    if case .success = self?.syncStatus {
                        self?.syncStatus = .idle
                    }
                }
            }

            print("✅ Sync completed: \(unsyncedItems.count) uploaded, \(newItems.count) downloaded")
        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
                print("❌ Sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func startAutoSync() {
        stopAutoSync() // Clear any existing timer

        // Sync now
        syncNow()

        // Schedule periodic sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            self?.syncNow()
        }
    }

    private func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - iCloud Account Check

    func checkiCloudStatus() async -> Bool {
        guard let container = container else { return false }

        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            print("❌ Failed to check iCloud status: \(error.localizedDescription)")
            return false
        }
    }

    var lastSyncText: String {
        guard let date = lastSyncDate ?? UserDefaults.standard.object(forKey: "lastSyncDate") as? Date else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
