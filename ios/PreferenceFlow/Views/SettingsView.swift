//
//  SettingsView.swift
//  PreferenceFlow
//

import SwiftUI

/// Settings — terminology, location, safety and about.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DataStore.self) private var store

    @State private var showSafety = false
    @State private var showRemoveDemoConfirm = false
    @State private var showBackupTip = false
    @State private var showDemoAddedConfirm = false
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

                Section("Terminology") {
                    Picker(selection: $settings.region) {
                        ForEach(TerminologyRegion.allCases) { Text($0.displayName).tag($0) }
                    } label: {
                        Label("Region", systemImage: "globe")
                    }
                    LabeledRow(label: "Provider term", value: settings.region.provider)
                    LabeledRow(label: "Assistant term", value: settings.region.assistant)
                    LabeledRow(label: "Spelling", value: settings.region.discipline)
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
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)).frame(width: 36, height: 36)
                            Image(systemName: "icloud")
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cloud sync").foregroundStyle(.primary)
                            Text("Share one source of truth across your whole department")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Coming soon")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.12), in: .capsule)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Sync")
                } footer: {
                    Text("A future version will sync profiles to a central hospital database so every technician shares one source of truth. For now, everything stays on this device and sharing is peer-to-peer.")
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
                    Text("All data is stored locally on this device. No accounts. No servers.")
                }
            }
        .navigationTitle("Settings")
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
