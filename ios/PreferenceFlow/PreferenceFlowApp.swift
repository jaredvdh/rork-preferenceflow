//
//  PreferenceFlowApp.swift
//  PreferenceFlow
//
//  Created by Rork on June 24, 2026.
//

import SwiftUI

@main
struct PreferenceFlowApp: App {
    @State private var settings = AppSettings()
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(store)
                .tint(Theme.accent)
        }
    }
}
