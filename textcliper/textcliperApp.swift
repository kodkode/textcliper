//
//  textcliperApp.swift
//  textcliper
//
//  Created by Michael on 06/10/2025.
//

import SwiftUI

@main
struct textcliperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
