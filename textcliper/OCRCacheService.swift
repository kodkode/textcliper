//
//  OCRCacheService.swift
//  textcliper
//
//  Smart caching service for OCR results to avoid redundant API calls
//

import Foundation
import AppKit
import CryptoKit

class OCRCacheService {
    static let shared = OCRCacheService()

    private let cache = NSCache<NSString, CacheEntry>()
    private let maxCacheAge: TimeInterval = 3600 // 1 hour

    private init() {
        // Configure cache limits
        cache.countLimit = 50 // Store up to 50 recent OCR results
        cache.totalCostLimit = 10 * 1024 * 1024 // 10 MB of text data
    }

    /// Cache entry with timestamp for expiration
    private class CacheEntry {
        let text: String
        let timestamp: Date

        init(text: String) {
            self.text = text
            self.timestamp = Date()
        }

        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > OCRCacheService.shared.maxCacheAge
        }
    }

    /// Generate a hash for an image
    private func hashForImage(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation else {
            return nil
        }

        // Use SHA256 to create a unique hash of the image
        let hash = SHA256.hash(data: tiffData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Get cached OCR result for an image
    func getCachedResult(for image: NSImage) -> String? {
        guard let hash = hashForImage(image) else {
            return nil
        }

        guard let entry = cache.object(forKey: hash as NSString) else {
            return nil
        }

        // Check if entry is expired
        if entry.isExpired {
            cache.removeObject(forKey: hash as NSString)
            return nil
        }

        return entry.text
    }

    /// Cache an OCR result for an image
    func cacheResult(_ text: String, for image: NSImage) {
        guard let hash = hashForImage(image) else {
            return
        }

        let entry = CacheEntry(text: text)
        let cost = text.utf8.count // Use text size as cost

        cache.setObject(entry, forKey: hash as NSString, cost: cost)
    }

    /// Clear all cached results
    func clearCache() {
        cache.removeAllObjects()
    }
}
