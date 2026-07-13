//
//  CloudRestoreView.swift
//  PreferenceFlow
//

import SwiftUI

/// Lists the backups in the user's private iCloud Drive and restores one on
/// request. Restoring merges the backup into the current data: matching
/// profiles are replaced, everything else is left untouched. Backups that
/// haven't downloaded to this device yet (e.g. right after moving to a new
/// phone) are downloaded automatically when restored.
struct CloudRestoreView: View {
    @Environment(CloudBackupManager.self) private var cloudBackup
    @Environment(DataStore.self) private var store

    @State private var items: [CloudBackupItem] = []
    @State private var isLoading = true
    @State private var pendingRestore: CloudBackupItem?
    @State private var isRestoring = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        List {
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Checking iCloud…").foregroundStyle(.secondary)
                }
            } else if items.isEmpty {
                ContentUnavailableView(
                    "No backups yet",
                    systemImage: "icloud",
                    description: Text("Back up from Settings → iCloud Backup and your backups will appear here — including on a new device signed in to the same iCloud account.")
                )
            } else {
                Section {
                    ForEach(items) { item in
                        Button { pendingRestore = item } label: {
                            backupRow(item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("Tap a backup to restore it. Restoring merges the backup into your current data — matching profiles are replaced, nothing else is removed.")
                }
            }
        }
        .navigationTitle("Restore from iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .overlay {
            if isRestoring {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Restoring…").font(.subheadline.weight(.medium))
                    }
                    .padding(24)
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
        .confirmationDialog(
            "Restore this backup?",
            isPresented: .init(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore") {
                if let item = pendingRestore { restore(item) }
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            if let item = pendingRestore {
                Text("Backup from \(displayDate(item)). Matching profiles will be replaced with the backup's version; profiles not in the backup are kept.")
            }
        }
        .alert(isError ? "Restore failed" : "Restored", isPresented: .constant(message != nil)) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func backupRow(_ item: CloudBackupItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: item.isDownloaded ? "icloud.and.arrow.down" : "icloud")
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(displayDate(item))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(item.isDownloaded ? "On this device" : "In iCloud — downloads when restored")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }

    private func displayDate(_ item: CloudBackupItem) -> String {
        guard let date = item.date else { return "Unknown date" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await cloudBackup.loadBackups()
        } catch {
            items = []
        }
    }

    private func restore(_ item: CloudBackupItem) {
        pendingRestore = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                let export = try await cloudBackup.readBackup(item)
                guard export.schemaVersion <= PreferenceExport.currentSchemaVersion else {
                    isError = true
                    message = "This backup was made by a newer version of the app. Please update the app first."
                    return
                }
                store.restoreBackup(export)
                isError = false
                message = "Restored \(export.doctors.count) profile(s) and \(export.hospitals.count) hospital(s)."
            } catch {
                isError = true
                message = error.localizedDescription
            }
        }
    }

    private func delete(_ item: CloudBackupItem) {
        Task {
            try? await cloudBackup.deleteBackup(item)
            await load()
        }
    }
}
