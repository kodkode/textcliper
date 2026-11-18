//
//  HistoryMerge.swift
//  textclipper
//
//  Pure helpers for combining local and synced history. Kept free of
//  singletons and storage so they can be unit-tested.
//

import Foundation

enum HistoryMerge {
    /// Combines items, keeping the first occurrence of each id, newest first,
    /// dropping anything older than `cutoff` and keeping at most `maxItems`.
    static func merge(existing: [HistoryItem], incoming: [HistoryItem], cutoff: Date?, maxItems: Int) -> [HistoryItem] {
        var seen = Set<UUID>()
        var combined: [HistoryItem] = []
        for item in existing + incoming where seen.insert(item.id).inserted {
            if let cutoff = cutoff, item.timestamp < cutoff { continue }
            combined.append(item)
        }
        combined.sort { $0.timestamp > $1.timestamp }
        return Array(combined.prefix(max(maxItems, 0)))
    }

    /// Whether a record downloaded from iCloud should be added locally: not already
    /// present, and not something the user deleted (pending cloud deletion).
    static func shouldImport(recordName: String, localRecordNames: Set<String>, pendingDeletions: Set<String>) -> Bool {
        !localRecordNames.contains(recordName) && !pendingDeletions.contains(recordName)
    }

    /// Retention cutoff for a "delete after N days" setting; nil when retention is off (0).
    static func cutoff(retentionDays: Int, now: Date = Date()) -> Date? {
        guard retentionDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -retentionDays, to: now)
    }
}
