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
        // Load saved preference
        self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        // Use the actual container created by Apple (with Team ID prefix)
        self.container = CKContainer(identifier: "iCloud.L5774582ZK.MIT.textcliper")
        self.database = container?.privateCloudDatabase

        print("📦 Using CloudKit container: iCloud.L5774582ZK.MIT.textcliper")

        // Check if CloudKit is available
        Task {
            let available = await checkiCloudStatus()
            await MainActor.run {
                self.isCloudKitAvailable = available
                if available {
                    print("☁️ CloudKit is available and ready!")
                    if self.iCloudSyncEnabled {
                        self.startAutoSync()
                    }
                } else {
                    print("⚠️ CloudKit is not available. Please sign in to iCloud in System Settings.")
                }
            }
        }
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
        } catch let error as CKError {
            // Handle duplicate record error gracefully
            if error.code == .serverRecordChanged || error.code == .batchRequestFailed {
                print("⚠️ Record already exists in iCloud, skipping: \(item.preview)")
                // Mark as synced anyway since it exists in cloud
                HistoryService.shared.markAsSynced(itemID: item.id, cloudRecordID: record.recordID.recordName)
            } else {
                print("❌ Failed to upload item: \(error.localizedDescription)")
                throw error
            }
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
