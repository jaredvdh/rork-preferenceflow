//
//  ProfileMigrationView.swift
//  PreferenceFlow
//

import SwiftUI

/// Copies a provider's profile to another hospital, keeping the original
/// untouched. The user picks the destination hospital and which preference
/// sections carry over — full clone, selected sections, or a blank version.
struct ProfileMigrationView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let source: Doctor
    /// Called with the new profile's id after a successful copy.
    var onCopied: (UUID) -> Void = { _ in }

    @State private var destinationHospitalID: UUID?
    @State private var preset: CopyPreset = .full
    @State private var sections: MigrationScope = .full

    private enum CopyPreset: String, CaseIterable, Identifiable {
        case full = "Full profile"
        case selected = "Choose sections"
        case blank = "Blank version"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                clinicianSection
                destinationSection
                scopeSection
                if preset == .selected { sectionToggles }
            }
            .navigationTitle("Copy to Hospital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") { copy() }.disabled(!canCopy)
                }
            }
        }
    }

    private var clinicianSection: some View {
        Section {
            HStack(spacing: 14) {
                DoctorAvatar(doctor: source, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.displayName).font(.headline)
                    Text("Original profile stays unchanged")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Creates a linked hospital-specific version of the same clinician. Equipment, medication, procedure and setup preferences can then be adjusted independently for the new site.")
        }
    }

    private var destinationSection: some View {
        Section("Destination hospital") {
            if availableHospitals.isEmpty {
                Text("Add another hospital first to copy this profile across sites.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Picker(selection: $destinationHospitalID) {
                    Text("Select hospital").tag(UUID?.none)
                    ForEach(availableHospitals) { h in
                        Text(h.name).tag(UUID?.some(h.id))
                    }
                } label: {
                    Label("Hospital", systemImage: "building.2")
                }
            }
        }
    }

    private var scopeSection: some View {
        Section("What to copy") {
            Picker("Copy", selection: $preset) {
                ForEach(CopyPreset.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: preset) { _, newValue in
                switch newValue {
                case .full: sections = .full
                case .blank: sections = .blank
                case .selected: break
                }
            }
        }
    }

    private var sectionToggles: some View {
        Section("Sections") {
            toggle("General preferences", .general, "checklist")
            toggle("Airway preferences", .airway, "lungs")
            toggle("Drugs & fluids", .drugs, "syringe")
            toggle("Regional & neuraxial", .regionalNeuraxial, "scope")
            toggle("Procedure templates", .procedures, "cross.case")
        }
    }

    private func toggle(_ label: String, _ option: MigrationScope, _ icon: String) -> some View {
        Toggle(isOn: Binding(
            get: { sections.contains(option) },
            set: { isOn in
                if isOn { sections.insert(option) } else { sections.remove(option) }
            }
        )) {
            Label(label, systemImage: icon)
        }
        .tint(Theme.accent)
    }

    private var availableHospitals: [Hospital] {
        // Don't offer the source's current hospital as a destination.
        store.hospitals.filter { $0.id != source.hospitalId }
    }

    private var canCopy: Bool {
        guard destinationHospitalID != nil else { return false }
        return preset != .selected || !sections.isEmpty
    }

    private func copy() {
        let newID = store.copyProfile(source, toHospital: destinationHospitalID, scope: sections)
        onCopied(newID)
        dismiss()
    }
}
