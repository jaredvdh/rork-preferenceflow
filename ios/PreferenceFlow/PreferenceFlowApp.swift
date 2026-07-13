//
//  PreferenceFlowApp.swift
//  PreferenceFlow
//
//  Created by Rork on June 24, 2026.
//

import SwiftUI

@main
struct PreferenceFlowApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = AppSettings()
    @State private var store = DataStore()
    @State private var cloudBackup = CloudBackupManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(store)
                .environment(cloudBackup)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Automatic iCloud backup on leaving the app, when enabled.
            guard newPhase == .background,
                  settings.isCloudAutoBackupEnabled,
                  !store.doctors.isEmpty else { return }
            let export = store.makeExport(region: settings.region)
            Task { try? await cloudBackup.backUp(export) }
        }
    }
}
