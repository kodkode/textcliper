//
//  HistoryItem.swift
//  textclipper
//
//  Created by Michael on 08/10/2025.
//

import Foundation
import CloudKit

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let characterCount: Int
    let wordCount: Int
    let deviceName: String
    var isSynced: Bool
    var cloudRecordID: String?
    var isEncrypted: Bool = false // Track if text is stored encrypted

    enum CodingKeys: String, CodingKey {
        case id, text, timestamp, characterCount, wordCount, deviceName, isSynced, cloudRecordID, isEncrypted
    }

    init(text: String, timestamp: Date = Date(), deviceName: String = Host.current().localizedName ?? "Unknown") {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.characterCount = text.count
        self.wordCount = text.split(separator: " ").count
        self.deviceName = deviceName
        self.isSynced = false
        self.cloudRecordID = nil
    }

    // Create from CloudKit record
    init?(from record: CKRecord) {
        guard let text = record["text"] as? String,
              let timestamp = record["timestamp"] as? Date,
              let characterCount = record["characterCount"] as? Int,
              let wordCount = record["wordCount"] as? Int,
              let deviceName = record["deviceName"] as? String,
              let uuidString = record["id"] as? String,
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }

        self.id = uuid
        self.text = text
        self.timestamp = timestamp
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.deviceName = deviceName
        self.isSynced = true
        self.cloudRecordID = record.recordID.recordName
    }

    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let recordID: CKRecord.ID
        if let cloudID = cloudRecordID {
            recordID = CKRecord.ID(recordName: cloudID)
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString)
        }

        let record = CKRecord(recordType: "CaptureHistory", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["text"] = text as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        record["characterCount"] = characterCount as CKRecordValue
        record["wordCount"] = wordCount as CKRecordValue
        record["deviceName"] = deviceName as CKRecordValue

        return record
    }

    var preview: String {
        String(text.prefix(50))
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
