//
//  iCloudSyncService.swift
//  textclipper
//
//  Created for Mac App Store distribution with iCloud sync
//

import Foundation
import CloudKit

/// Manages iCloud sync for OCR history and settings
class iCloudSyncService {
    static let shared = iCloudSyncService()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default

    // Record types
    private let ocrHistoryRecordType = "OCRHistory"
    private let settingsRecordType = "Settings"

    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase

        // Set up notification for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )

        // Start monitoring iCloud changes
        ubiquitousStore.synchronize()
    }

    // MARK: - iCloud Availability

    /// Check if iCloud is available and user is signed in
    func checkiCloudStatus(completion: @escaping (Bool, Error?) -> Void) {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    completion(true, nil)
                case .noAccount:
                    completion(false, NSError(domain: "iCloud", code: 1, userInfo: [NSLocalizedDescriptionKey: "No iCloud account. Please sign in to Settings."]))
                case .restricted:
                    completion(false, NSError(domain: "iCloud", code: 2, userInfo: [NSLocalizedDescriptionKey: "iCloud access is restricted."]))
                case .couldNotDetermine:
                    completion(false, NSError(domain: "iCloud", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not determine iCloud status."]))
                case .temporarilyUnavailable:
                    completion(false, NSError(domain: "iCloud", code: 4, userInfo: [NSLocalizedDescriptionKey: "iCloud is temporarily unavailable."]))
                @unknown default:
                    completion(false, NSError(domain: "iCloud", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown iCloud status."]))
                }
            }
        }
    }

    // MARK: - Settings Sync (NSUbiquitousKeyValueStore)

    /// Sync a setting to iCloud (for simple key-value pairs)
    func syncSetting(key: String, value: Any) {
        ubiquitousStore.set(value, forKey: key)
        ubiquitousStore.synchronize()
    }

    /// Get a setting from iCloud
    func getSetting(key: String) -> Any? {
        ubiquitousStore.synchronize()
        return ubiquitousStore.object(forKey: key)
    }

    /// Remove a setting from iCloud
    func removeSetting(key: String) {
        ubiquitousStore.removeObject(forKey: key)
        ubiquitousStore.synchronize()
    }

    @objc private func iCloudStoreDidChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        if let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange:
                NotificationCenter.default.post(name: .iCloudSettingsChanged, object: nil)
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                break // Initial sync completed
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                break // Quota exceeded
            case NSUbiquitousKeyValueStoreAccountChange:
                break // Account changed
            default:
                break
            }
        }
    }

    // MARK: - OCR History Sync (CloudKit)

    /// Save OCR history item to iCloud
    func saveOCRHistory(text: String, timestamp: Date, completion: @escaping (Bool, Error?) -> Void) {
        let record = CKRecord(recordType: ocrHistoryRecordType)
        record["text"] = text as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        record["deviceName"] = Host.current().localizedName as CKRecordValue?

        privateDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    /// Fetch OCR history from iCloud
    func fetchOCRHistory(limit: Int = 50, completion: @escaping ([OCRHistoryItem], Error?) -> Void) {
        let query = CKQuery(recordType: ocrHistoryRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let queryOperation = CKQueryOperation(query: query)
        queryOperation.resultsLimit = limit

        var historyItems: [OCRHistoryItem] = []

        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                if let text = record["text"] as? String,
                   let timestamp = record["timestamp"] as? Date {
                    let deviceName = record["deviceName"] as? String
                    let item = OCRHistoryItem(
                        id: record.recordID.recordName,
                        text: text,
                        timestamp: timestamp,
                        deviceName: deviceName
                    )
                    historyItems.append(item)
                }
            case .failure(let error):
                break // Ignore individual record errors
            }
        }

        queryOperation.queryResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(historyItems, nil)
                case .failure(let error):
                    completion([], error)
                }
            }
        }

        privateDatabase.add(queryOperation)
    }

    /// Delete OCR history item from iCloud
    func deleteOCRHistory(recordID: String, completion: @escaping (Bool, Error?) -> Void) {
        let recordID = CKRecord.ID(recordName: recordID)

        privateDatabase.delete(withRecordID: recordID) { deletedRecordID, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    /// Clear all OCR history from iCloud
    func clearAllOCRHistory(completion: @escaping (Bool, Error?) -> Void) {
        fetchOCRHistory(limit: 1000) { items, error in
            if let error = error {
                completion(false, error)
                return
            }

            let recordIDs = items.map { CKRecord.ID(recordName: $0.id) }

            guard !recordIDs.isEmpty else {
                completion(true, nil)
                return
            }

            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)

            deleteOperation.modifyRecordsResultBlock = { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, nil)
                    case .failure(let error):
                        completion(false, error)
                    }
                }
            }

            self.privateDatabase.add(deleteOperation)
        }
    }
}

// MARK: - Data Models

struct OCRHistoryItem: Identifiable, Codable {
    let id: String
    let text: String
    let timestamp: Date
    let deviceName: String?
}

// MARK: - Notifications

extension Notification.Name {
    static let iCloudSettingsChanged = Notification.Name("iCloudSettingsChanged")
    static let iCloudHistoryChanged = Notification.Name("iCloudHistoryChanged")
}
