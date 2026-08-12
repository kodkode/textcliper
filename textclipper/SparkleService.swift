//
//  SparkleService.swift
//  textclipper
//
//  Created by Michael on 17/02/2026.
//

import Foundation
import AppKit

#if canImport(Sparkle)
import Sparkle
#endif

class SparkleService: NSObject {
    static let shared = SparkleService()
    
    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif
    
    private override init() {
        super.init()
        #if canImport(Sparkle)
        // Initialize the updater controller
        // This will automatically read SUFeedURL and SUPublicEDKey from Info.plist
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        #endif
    }
    
    /// Checks for updates immediately (user-initiated)
    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.checkForUpdates(nil)
        #else
        print("Sparkle framework not imported. Cannot check for updates.")
        #endif
    }
    
    /// Checks if automatic checking is enabled
    var automaticallyChecksForUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return updaterController?.updater.automaticallyChecksForUpdates ?? false
            #else
            return false
            #endif
        }
        set {
            #if canImport(Sparkle)
            updaterController?.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }
    
    /// Checks if automatic downloading is enabled
    var automaticallyDownloadsUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return updaterController?.updater.automaticallyDownloadsUpdates ?? false
            #else
            return false
            #endif
        }
        set {
            #if canImport(Sparkle)
            updaterController?.updater.automaticallyDownloadsUpdates = newValue
            #endif
        }
    }
}
