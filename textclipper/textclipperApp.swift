//
//  textclipperApp.swift
//  textclipper
//
//  Created by Michael on 06/10/2025.
//

import SwiftUI

@main
struct textclipperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
