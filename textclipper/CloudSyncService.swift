//
//  CloudSyncService.swift
//  textclipper
//
//  Created by Michael on 08/10/2025.
//

import Foundation
import CloudKit
import Combine

enum SyncError: LocalizedError {
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Uploaded, but downloading from iCloud failed: \(reason)"
        }
    }
}

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
                // Re-check availability when enabling
                Task {
                    let available = await checkiCloudStatus()
                    await MainActor.run {
                        self.isCloudKitAvailable = available
                        if available {
                            self.startAutoSync()
                        } else {
                           self.syncStatus = .error("iCloud not available or user not signed in")
                        }
                    }
                }
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

        // Explicitly use the container ID from entitlements to avoid lookup errors in Production
        self.container = CKContainer(identifier: "iCloud.L5774582ZK.MIT.textcliper")
        self.database = container?.privateCloudDatabase

        // Check if CloudKit is available
        Task {
            let available = await checkiCloudStatus()
            await MainActor.run {
                self.isCloudKitAvailable = available
                if available {
                    if self.iCloudSyncEnabled {
                        self.startAutoSync()
                    }
                } else {
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

            // The user may have deleted the item while the upload was in flight
            if !HistoryService.shared.contains(itemID: item.id) {
                pendingDeletions.insert(savedRecord.recordID.recordName)
                try? await flushPendingDeletions()
            }
        } catch let error as CKError {
            // Handle duplicate record error gracefully
            if error.code == .serverRecordChanged || error.code == .batchRequestFailed {
                // Mark as synced anyway since it exists in cloud
                HistoryService.shared.markAsSynced(itemID: item.id, cloudRecordID: record.recordID.recordName)
            } else {
                throw error
            }
        } catch {
            throw error
        }
    }

    func downloadNewItems() async throws -> [HistoryItem] {
        guard iCloudSyncEnabled, let database = database else {
            return []
        }

        var allFetchedRecords: [CKRecord] = []
        let localRecordNames = Set(HistoryService.shared.items.map(\.cloudRecordName))
        let deleted = pendingDeletions

        // Only fetch records within the retention window ("timestamp" is Queryable),
        // so expired items aren't re-downloaded and re-purged on every sync.
        let predicate: NSPredicate
        if let cutoff = HistoryService.shared.retentionCutoff {
            predicate = NSPredicate(format: "timestamp >= %@", cutoff as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        let query = CKQuery(recordType: "CaptureHistory", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)] // Newest first

        var cursor: CKQueryOperation.Cursor? = nil

        // Fetch all pages using cursor-based pagination
        repeat {
            let (records, nextCursor) = try await fetchBatch(query: query, cursor: cursor, database: database)
            allFetchedRecords.append(contentsOf: records)
            cursor = nextCursor
        } while cursor != nil

        return allFetchedRecords
            .filter {
                HistoryMerge.shouldImport(recordName: $0.recordID.recordName,
                                          localRecordNames: localRecordNames,
                                          pendingDeletions: deleted)
            }
            .compactMap { HistoryItem(from: $0) }
    }

    // MARK: - Deletions

    private let pendingDeletionsKey = "cloudPendingDeletions"

    /// Record names deleted locally that still have to be removed from iCloud.
    /// Persisted so deletions survive being offline, sync being off, or a quit.
    private var pendingDeletions: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: pendingDeletionsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: pendingDeletionsKey) }
    }

    /// Called when the user deletes history so it isn't downloaded back.
    /// Only items that are (or may be) in iCloud are recorded; with sync off, purely
    /// local items never reach iCloud, so tracking them would only grow the list.
    /// An item deleted mid-upload is handled in `uploadItem`.
    func recordDeletion(of items: [HistoryItem]) {
        let cloudItems = items.filter { iCloudSyncEnabled || $0.isSynced || $0.cloudRecordID != nil }
        guard !cloudItems.isEmpty else { return }
        pendingDeletions.formUnion(cloudItems.map(\.cloudRecordName))

        guard iCloudSyncEnabled, isCloudKitAvailable else { return }
        Task {
            do {
                try await flushPendingDeletions()
            } catch {
                NSLog("iCloud deletion will be retried on next sync: \(error.localizedDescription)")
            }
        }
    }

    /// Deletes pending records from iCloud. A record that no longer exists counts as deleted.
    private func flushPendingDeletions() async throws {
        guard let database = database else { return }
        let names = Array(pendingDeletions)
        guard !names.isEmpty else { return }

        // CloudKit accepts at most 400 records per modify request
        for start in stride(from: 0, to: names.count, by: 400) {
            let ids = names[start..<min(start + 400, names.count)].map { CKRecord.ID(recordName: $0) }
            let (_, deleteResults) = try await database.modifyRecords(saving: [], deleting: ids, atomically: false)

            var completed = Set<String>()
            for (id, result) in deleteResults {
                switch result {
                case .success:
                    completed.insert(id.recordName)
                case .failure(let error):
                    if (error as? CKError)?.code == .unknownItem {
                        completed.insert(id.recordName)
                    }
                }
            }
            pendingDeletions.subtract(completed)
        }
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
                case .failure:
                    break // Ignore individual record fetch errors
                }
            }

            // Handle batch completion
            operation.queryResultBlock = { result in
                guard !hasResumed else {
                    return
                }
                hasResumed = true

                switch result {
                case .success(let cursor):
                    // Return records and cursor for next batch
                    continuation.resume(returning: (fetchedRecords, cursor))

                case .failure(let error):
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
            // Remove deleted items from iCloud first so they can't come back
            try await flushPendingDeletions()

            // Upload unsynced items
            let unsyncedItems = HistoryService.shared.getUnsyncedItems()
            for item in unsyncedItems {
                try await uploadItem(item)
            }

            // Download new items from other devices, merged in one batch
            let newItems: [HistoryItem]
            do {
                newItems = try await downloadNewItems()
            } catch {
                NSLog("iCloud download failed: \(error)")
                throw SyncError.downloadFailed(error.localizedDescription)
            }
            HistoryService.shared.addItems(newItems)

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

        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
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
