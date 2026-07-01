//
//  ImportsView.swift
//  PreferenceFlow
//

import SwiftUI
import UniformTypeIdentifiers

/// Imports tab — bring in shared profiles, with duplicate resolution, and export
/// all profiles for backup.
struct ImportsView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var showFileImporter = false
    @State private var pendingImport: PreferenceExport?
    @State private var duplicates: [Doctor] = []
    @State private var showResolution = false
    @State private var fuzzyMatches: [Doctor] = []
    @State private var showFuzzyResolution = false
    @State private var message: String?
    @State private var isError = false
    @State private var backupURL: URL?
    @State private var showBackupShare = false
    var embedInStack: Bool = true

    var body: some View {
        if embedInStack {
            NavigationStack { content }
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                importCard
                backupCard
                howItWorksCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Import & Export")
        .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileResult(result)
            }
            .sheet(isPresented: $showBackupShare) {
                if let backupURL { ShareSheet(items: [backupURL]) }
            }
            .confirmationDialog(
                duplicateTitle,
                isPresented: $showResolution,
                titleVisibility: .visible
            ) {
                Button("Replace") { resolve(.replace) }
                Button("Keep both") { resolve(.saveAsCopy) }
                Button("Cancel", role: .cancel) { resolve(.cancel) }
            } message: {
                Text(duplicateMessage)
            }
            .confirmationDialog(
                fuzzyTitle,
                isPresented: $showFuzzyResolution,
                titleVisibility: .visible
            ) {
                Button("Import as new") { resolveFuzzy(replace: false) }
                Button("Replace existing") { resolveFuzzy(replace: true) }
                Button("Cancel", role: .cancel) { cancelFuzzy() }
            } message: {
                Text(fuzzyMessage)
            }
            .alert(isError ? "Import Error" : "Done", isPresented: .constant(message != nil)) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
    }

    private var importCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 76, height: 76)
                Image(systemName: "square.and.arrow.down").font(.system(size: 30)).foregroundStyle(Theme.accent)
            }
            Text("Import a shared profile")
                .font(.title3.weight(.semibold))
            Text("Open a profile a colleague shared with you via AirDrop, Messages, Mail or Files. Sharing is peer-to-peer — there is no cloud sync.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showFileImporter = true } label: {
                Label("Choose File", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.heroGradient, in: .capsule)
                    .foregroundStyle(.white)
            }
        }
        .card(padding: 24)
    }

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Backup", icon: "externaldrive")
            VStack(alignment: .leading, spacing: 10) {
                Text("Export all \(store.doctors.count) profile(s)")
                    .font(.subheadline.weight(.medium))
                Text("Save a single versioned file containing every provider and hospital — useful for backups or moving to a new device.")
                    .font(.caption).foregroundStyle(.secondary)
                Button(action: exportAll) {
                    Label("Export All Profiles", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent.opacity(0.12), in: .capsule)
                        .foregroundStyle(Theme.accent)
                }
                .disabled(store.doctors.isEmpty)
                .opacity(store.doctors.isEmpty ? 0.5 : 1)
            }
            .card()
        }
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("How sharing works", icon: "info.circle")
            VStack(alignment: .leading, spacing: 10) {
                bullet("Peer-to-peer only — profiles move device to device, never through a server.")
                bullet("All data stays on your device. No account, no cloud sync.")
                bullet("When a profile already exists, you can replace it or keep both.")
            }
            .card()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).font(.caption)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: Duplicate wording

    private var duplicateTitle: String {
        if duplicates.count == 1, let only = duplicates.first {
            return "You already have \(only.displayName)"
        }
        return "You already have these profiles"
    }

    private var duplicateMessage: String {
        if duplicates.count == 1, let only = duplicates.first {
            return "You already have a profile for \(only.displayName). Replace it, or keep both?"
        }
        return "\(duplicates.count) imported profiles match ones you already have. Replace them, or keep both?"
    }

    // MARK: Actions

    private func handleFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let parsed = try store.parseImport(from: url)
                guard parsed.schemaVersion <= PreferenceExport.currentSchemaVersion else {
                    fail("This file was created by a newer version of PreferenceFlow. Please update the app.")
                    return
                }
                pendingImport = parsed
                let exact = store.existingDoctorIDs(in: parsed)
                if !exact.isEmpty {
                    duplicates = exact
                    showResolution = true
                } else {
                    let fuzzy = store.fuzzyNameMatches(in: parsed)
                    if fuzzy.isEmpty {
                        resolve(.replace) // pure add — no conflicts
                    } else {
                        fuzzyMatches = fuzzy
                        showFuzzyResolution = true
                    }
                }
            } catch {
                fail("Couldn't read this file. Make sure it's a PreferenceFlow export.")
            }
        case .failure(let error):
            fail(error.localizedDescription)
        }
    }

    private func resolve(_ resolution: ImportResolution) {
        guard let export = pendingImport else { return }
        if resolution != .cancel {
            store.applyImport(export, resolution: resolution)
            let count = export.doctors.count
            succeed("Imported \(count) profile(s) successfully.")
        }
        pendingImport = nil
        duplicates = []
    }

    private func exportAll() {
        let export = store.makeExport(region: settings.region)
        do {
            backupURL = try store.writeExportFile(export)
            showBackupShare = true
        } catch {
            fail(error.localizedDescription)
        }
    }

    // MARK: Fuzzy (same-name, different-id) resolution

    private var fuzzyTitle: String {
        if fuzzyMatches.count == 1, let only = fuzzyMatches.first {
            return "A profile for \(only.displayName) already exists"
        }
        return "Similar profiles already exist"
    }

    private var fuzzyMessage: String {
        if fuzzyMatches.count == 1, let only = fuzzyMatches.first {
            return "You already have a profile that looks like \(only.displayName). Import as a separate new profile, or replace the existing one?"
        }
        let names = fuzzyMatches.map(\.displayName).joined(separator: ", ")
        return "These look like profiles you already have: \(names). Import as separate new profiles, or replace the existing ones?"
    }

    private func resolveFuzzy(replace: Bool) {
        guard let export = pendingImport else { return }
        if replace {
            store.applyImportReplacingNameMatches(export)
        } else {
            store.applyImport(export, resolution: .saveAsCopy)
        }
        succeed("Imported \(export.doctors.count) profile(s) successfully.")
        pendingImport = nil
        fuzzyMatches = []
    }

    private func cancelFuzzy() {
        pendingImport = nil
        fuzzyMatches = []
    }

    private func fail(_ text: String) {
        isError = true
        message = text
    }

    private func succeed(_ text: String) {
        isError = false
        message = text
    }
}
