//
//  SettingsView.swift
//  PreferenceFlow
//

import SwiftUI

/// Settings — terminology, location, safety and about.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DataStore.self) private var store
    @Environment(CloudBackupManager.self) private var cloudBackup

    @State private var showSafety = false
    @State private var showRemoveDemoConfirm = false
    @State private var showBackupTip = false
    @State private var showDemoAddedConfirm = false
    @State private var showLockUnavailable = false
    @State private var cloudMessage: String?
    @State private var isCloudError = false
    var embedInStack: Bool = true

    var body: some View {
        if embedInStack {
            NavigationStack { formContent }
        } else {
            formContent
        }
    }

    private var formContent: some View {
        @Bindable var settings = settings
        return Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(Theme.heroGradient).frame(width: 52, height: 52)
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ORPrep").font(.headline)
                            Text("\(store.doctors.count) providers · \(store.hospitals.count) hospitals")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker(selection: $settings.region) {
                        ForEach(TerminologyRegion.allCases) { Text($0.displayName).tag($0) }
                    } label: {
                        Label("Region", systemImage: "globe")
                    }
                    LabeledRow(label: "Provider term", value: settings.region.provider)
                    LabeledRow(label: "Assistant term", value: settings.region.assistant)
                    LabeledRow(label: "Spelling", value: settings.region.discipline)
                } header: {
                    Text("Terminology")
                } footer: {
                    Text("Choose whichever set of titles and spelling matches how your team talks. You can change this anytime — it doesn't affect any saved preference data.")
                }

                Section {
                    Picker(selection: $settings.appTextSize) {
                        ForEach(AppTextSize.allCases) { Text($0.label).tag($0) }
                    } label: {
                        Label("Text Size", systemImage: "textformat.size")
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Text("A").font(.footnote)
                        Text("Aa Bb Cc — preview")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("A").font(.title2.weight(.semibold))
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Scales text throughout the app on top of your iOS system text size (Settings \u{2192} Accessibility \u{2192} Display & Text Size). For a single emergency boost, double-tap any Crisis Card.")
                }

                Section("Location") {
                    LabeledField(label: "Country", text: $settings.country, icon: "mappin.and.ellipse")
                    LabeledField(label: "Region", text: $settings.regionName, icon: "map")
                }

                Section {
                    LabeledField(label: "Your name", text: $settings.userName, icon: "person")
                    Picker(selection: $settings.dailyContextMode) {
                        ForEach(DailyContextMode.allCases) { Text($0.rawValue).tag($0) }
                    } label: {
                        Label("Daily start prompt", systemImage: "sun.max")
                    }
                } header: {
                    Text("Daily Context")
                } footer: {
                    Text(settings.dailyContextMode.explanation)
                }

                Section {
                    Toggle(isOn: appLockBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Require \(AppLockManager.biometryLabel.name)", systemImage: AppLockManager.biometryLabel.icon)
                            Text("Lock the app when it opens or returns from the background.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Unlocks with \(AppLockManager.biometryLabel.name), falling back to your device passcode. Turning this off requires verifying it's you.")
                }

                Section("Data") {
                    NavigationLink {
                        ImportsView(embedInStack: false)
                            .navigationTitle("Import & Export")
                    } label: {
                        Label("Import & Export", systemImage: "square.and.arrow.down.on.square")
                    }
                }

                Section {
                    Toggle(isOn: demoModeBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Demo Mode", systemImage: "wand.and.stars")
                            Text("Load sample hospitals and consultants to explore the app.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Demo")
                } footer: {
                    Text("Sample records are clearly marked with a Demo badge and never mix with your own data. Turning Demo Mode off removes them cleanly.")
                }

                Section {
                    if cloudBackup.availability == .noAccount {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)).frame(width: 36, height: 36)
                                Image(systemName: "icloud.slash")
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iCloud not available")
                                Text("Sign in to iCloud in the Settings app to back up your profiles.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    } else {
                        Toggle(isOn: $settings.isCloudAutoBackupEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Automatic backup", systemImage: "icloud.and.arrow.up")
                                Text("Backs up every profile whenever you leave the app.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button(action: backUpNow) {
                            HStack {
                                Label("Back Up Now", systemImage: "arrow.clockwise.icloud")
                                Spacer()
                                if cloudBackup.isWorking { ProgressView() }
                            }
                        }
                        .disabled(cloudBackup.isWorking || store.doctors.isEmpty)
                        LabeledRow(label: "Last backup", value: lastBackupText)
                        NavigationLink {
                            CloudRestoreView()
                        } label: {
                            Label("Restore from iCloud", systemImage: "icloud.and.arrow.down")
                        }
                    }
                } header: {
                    Text("iCloud Backup")
                } footer: {
                    Text("Backups go to your own private iCloud Drive \u{2014} no accounts, no third-party servers. The newest 10 backups are kept, and they appear automatically on any device signed in to the same iCloud account.")
                }

                Section("Safety") {
                    Button { showSafety = true } label: {
                        Label("Reference Tool Disclaimer", systemImage: "exclamationmark.shield")
                    }
                }

                Section {
                    LabeledRow(label: "Data storage", value: "On device only")
                    LabeledRow(label: "Export format", value: "JSON v\(PreferenceExport.currentSchemaVersion)")
                    LabeledRow(label: "Version", value: "1.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("All data is stored locally on this device. Optional backups go to your own private iCloud \u{2014} no accounts, no third-party servers.")
                }
            }
        .navigationTitle("Settings")
        .sensoryFeedback(.selection, trigger: settings.isAppLockEnabled)
        .sensoryFeedback(.selection, trigger: settings.isCloudAutoBackupEnabled)
        .sensoryFeedback(.selection, trigger: settings.isDemoMode)
        .sensoryFeedback(.success, trigger: cloudMessage) { _, newValue in newValue != nil && !isCloudError }
        .sensoryFeedback(.error, trigger: cloudMessage) { _, newValue in newValue != nil && isCloudError }
        .onAppear { cloudBackup.refreshAvailability() }
        .alert(isCloudError ? "Backup failed" : "Backed up", isPresented: .constant(cloudMessage != nil)) {
            Button("OK") { cloudMessage = nil }
        } message: {
            Text(cloudMessage ?? "")
        }
        .sheet(isPresented: $showSafety) {
            SafetyDisclaimerSheet()
        }
        .confirmationDialog(
            "Remove demo data?",
            isPresented: $showRemoveDemoConfirm,
            titleVisibility: .visible
        ) {
            if store.hasEditedDemoData {
                Button("Remove Unedited Demo Data") {
                    store.removeDemoData(preserveEdited: true)
                    finishRemovalIfClear()
                }
                Button("Remove All Demo Data", role: .destructive) {
                    store.removeDemoData()
                    settings.isDemoMode = false
                }
            } else {
                Button("Remove Demo Data", role: .destructive) {
                    store.removeDemoData()
                    settings.isDemoMode = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if store.hasEditedDemoData {
                Text("Some demo profiles have been edited. “Remove All” also deletes those changes. “Remove Unedited” keeps the ones you’ve explored. Your own data is untouched either way.")
            } else {
                Text("This will delete the sample hospitals and consultants. Your own data is untouched.")
            }
        }
        .alert("Demo data removed", isPresented: $showDemoAddedConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your real profiles are untouched.")
        }
        .alert("Can't enable app lock", isPresented: $showLockUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Set a device passcode (Settings \u{2192} Face ID & Passcode) to use the app lock.")
        }
        .alert("Back up first?", isPresented: $showBackupTip) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tip: you can export your real profiles via Settings → Import & Export before exploring Demo Mode. Demo data is clearly marked and removed cleanly when you turn Demo Mode off.")
        }
    }

    /// After a partial (unedited-only) removal, keep the toggle in sync with what
    /// actually remains in the store rather than the persisted flag.
    private func finishRemovalIfClear() {
        settings.isDemoMode = store.hasDemoData
    }

    private var lastBackupText: String {
        guard let date = cloudBackup.lastBackupDate else { return "Never" }
        return date.formatted(.relative(presentation: .named))
    }

    /// Backs up all profiles to the user's iCloud Drive immediately.
    private func backUpNow() {
        let export = store.makeExport(region: settings.region)
        Task {
            do {
                try await cloudBackup.backUp(export)
                isCloudError = false
                cloudMessage = "Backed up \(export.doctors.count) profile(s) and \(export.hospitals.count) hospital(s) to your iCloud Drive."
            } catch {
                isCloudError = true
                cloudMessage = error.localizedDescription
            }
        }
    }

    /// Drives the app-lock toggle. Enabling checks the device can authenticate
    /// at all; disabling requires a successful identity check first so someone
    /// picking up an unlocked phone can't quietly remove the lock.
    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { settings.isAppLockEnabled },
            set: { newValue in
                if newValue {
                    if AppLockManager.canUseDeviceAuthentication {
                        settings.isAppLockEnabled = true
                    } else {
                        showLockUnavailable = true
                    }
                } else {
                    Task {
                        if await AppLockManager.verifyIdentity(reason: "Confirm it's you to turn off the app lock.") {
                            settings.isAppLockEnabled = false
                        }
                    }
                }
            }
        )
    }

    /// Drives the Demo Mode toggle. The displayed state reflects what's actually in
    /// the store (not just the persisted flag) so it stays honest even if demo data
    /// was partially removed. Turning on installs idempotently and, the very first
    /// time ever, offers a one-time backup tip when real data already exists.
    private var demoModeBinding: Binding<Bool> {
        Binding(
            get: { store.hasDemoData },
            set: { newValue in
                if newValue {
                    let hasRealData = store.doctors.contains { !DemoData.allDemoDoctorIDs.contains($0.id) }
                        || store.hospitals.contains { !DemoData.allDemoHospitalIDs.contains($0.id) }
                    let firstEnable = !settings.hasEnabledDemoModeBefore
                    settings.isDemoMode = true
                    settings.hasEnabledDemoModeBefore = true
                    store.installDemoData()
                    if firstEnable && hasRealData {
                        showBackupTip = true
                    }
                } else {
                    showRemoveDemoConfirm = true
                }
            }
        )
    }
}

struct LabeledRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

struct SafetyDisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.12)).frame(width: 88, height: 88)
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 36)).foregroundStyle(Theme.accent)
                    }
                    Text("Reference Tool Only").font(.title2.weight(.bold))
                    Text(SafetyText.disclaimer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        safetyLine("No dose calculations")
                        safetyLine("No clinical recommendations")
                        safetyLine("No treatment algorithms")
                        safetyLine("Stores user-entered preferences only")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Safety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func safetyLine(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            Text(text).font(.subheadline)
        }
    }
}
