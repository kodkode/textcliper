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
        guard iCloudSyncEnabled, let database = database else {
            print("⚠️ CloudKit not enabled or database not available")
            return []
        }

        print("🔍 CloudKit download - Starting paginated download...")

        var allFetchedRecords: [CKRecord] = []
        let existingCloudRecordNames = Set(HistoryService.shared.items.compactMap { $0.cloudRecordID })

        // Initial query
        let query = CKQuery(recordType: "CaptureHistory", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)] // Newest first

        var cursor: CKQueryOperation.Cursor? = nil
        var batchNumber = 1

        // Fetch all pages using cursor-based pagination
        repeat {
            print("📄 Fetching batch \(batchNumber)...")

            let (records, nextCursor) = try await fetchBatch(query: query, cursor: cursor, database: database)

            allFetchedRecords.append(contentsOf: records)
            cursor = nextCursor

            print("   ✅ Batch \(batchNumber): Fetched \(records.count) records")
            if nextCursor != nil {
                print("   ➡️  More records available, fetching next batch...")
            } else {
                print("   🏁 No more records to fetch")
            }

            batchNumber += 1

        } while cursor != nil

        print("✅ Total records fetched from iCloud: \(allFetchedRecords.count)")

        // Process all fetched records
        var newItems: [HistoryItem] = []

        for record in allFetchedRecords {
            let recordName = record.recordID.recordName

            if !existingCloudRecordNames.contains(recordName),
               let item = HistoryItem(from: record) {
                newItems.append(item)
                print("📥 Downloaded new item from iCloud: \(item.preview)")
            }
        }

        if newItems.isEmpty && !allFetchedRecords.isEmpty {
            print("ℹ️ All \(allFetchedRecords.count) cloud items already exist locally")
        }

        let sortedItems = newItems.sorted { $0.timestamp > $1.timestamp }
        print("✅ Download complete, returning \(sortedItems.count) new items")

        return sortedItems
    }

    /// Fetch a single batch of records (up to 50 items per batch)
    private func fetchBatch(query: CKQuery, cursor: CKQueryOperation.Cursor?, database: CKDatabase) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            let operation: CKQueryOperation
            if let cursor = cursor {
                // Continue from cursor
                operation = CKQueryOperation(cursor: cursor)
            } else {
                // Initial query
                operation = CKQueryOperation(query: query)
            }

            operation.resultsLimit = 50 // Fetch 50 items per batch

            var fetchedRecords: [CKRecord] = []

            // Handle each record as it arrives
            operation.recordMatchedBlock = { recordID, recordResult in
                switch recordResult {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    print("   ❌ Failed to fetch record \(recordID.recordName): \(error.localizedDescription)")
                }
            }

            // Handle batch completion
            operation.queryResultBlock = { result in
                guard !hasResumed else {
                    print("⚠️ Continuation already resumed, ignoring")
                    return
                }
                hasResumed = true

                switch result {
                case .success(let cursor):
                    // Return records and cursor for next batch
                    continuation.resume(returning: (fetchedRecords, cursor))

                case .failure(let error):
                    print("❌ Batch query failed: \(error.localizedDescription)")
                    if let ckError = error as? CKError {
                        print("   CKError code: \(ckError.code.rawValue)")
                    }
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
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
            // Make this non-fatal - if download fails, upload still succeeded
            var downloadedCount = 0
            print("🔄 Starting download from iCloud...")
            do {
                let newItems = try await downloadNewItems()
                print("📊 Download result: received \(newItems.count) items from iCloud")
                for item in newItems {
                    await MainActor.run {
                        HistoryService.shared.addItem(item)
                    }
                }
                downloadedCount = newItems.count
            } catch {
                // Download failed but upload succeeded - log and continue
                print("⚠️ Download failed (upload succeeded): \(error.localizedDescription)")
                // Don't throw - we want to mark sync as successful if upload worked
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

            print("✅ Sync completed: \(unsyncedItems.count) uploaded, \(downloadedCount) downloaded")
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
