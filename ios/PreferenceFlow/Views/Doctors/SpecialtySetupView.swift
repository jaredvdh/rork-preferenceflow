//
//  SpecialtySetupView.swift
//  PreferenceFlow
//

import SwiftUI

/// Dashboard card summarising a specialty setup — the specialty, an icon and how
/// many differences from the standard setup it captures.
struct SpecialtySetupCard: View {
    let setup: SpecialtySetup

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent.opacity(0.12)).frame(width: 46, height: 46)
                Image(systemName: setup.specialty.symbol).font(.headline).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(setup.specialty.rawValue).font(.headline).foregroundStyle(.primary)
                Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("^[\(setup.changeCount) change](inflect: true)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.15), in: .capsule)
                .foregroundStyle(.orange)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
    }

    private var summary: String {
        var parts: [String] = []
        if !setup.additionalMonitoring.isEmpty { parts.append(setup.additionalMonitoring.prefix(2).joined(separator: ", ")) }
        if !setup.equipment.isEmpty { parts.append(setup.equipment.prefix(2).joined(separator: ", ")) }
        if !setup.linesAndAccess.isEmpty { parts.append(setup.linesAndAccess.prefix(1).joined()) }
        return parts.isEmpty ? "What's different vs standard" : parts.joined(separator: " · ")
    }
}

/// Read-only "consultant preference card" for a specialty setup. Mirrors the
/// neuraxial / regional philosophy: a summary header plus colour-coded,
/// collapsible cards showing only what differs from the standard setup. An Edit
/// button launches the unchanged structured editor.
struct SpecialtySetupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let setup: SpecialtySetup
    var hospitalItems: [PrefHospitalItem] = []
    var onEdit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PrefSummaryHeader(
                        icon: setup.specialty.symbol,
                        title: setup.specialty.rawValue,
                        caption: "What changes vs the standard setup",
                        chips: highlightChips,
                        modificationCount: setup.changeCount
                    )

                    if hasEquipment {
                        PrefCollapsibleCard(group: .equipment, collapsedSummary: equipmentSummary) {
                            if !setup.equipment.isEmpty {
                                PrefSubgroup(title: "Equipment", tint: PrefGroup.equipment.tint) {
                                    PrefChecklist(items: setup.equipment, tint: PrefGroup.equipment.tint)
                                }
                            }
                            if !setup.linesAndAccess.isEmpty {
                                PrefSubgroup(title: "Lines & Access", tint: PrefGroup.equipment.tint) {
                                    PrefChecklist(items: setup.linesAndAccess, tint: PrefGroup.equipment.tint)
                                }
                            }
                        }
                    }

                    if !setup.additionalMonitoring.isEmpty {
                        PrefCollapsibleCard(
                            group: .monitoring,
                            collapsedSummary: setup.additionalMonitoring.prefix(3).joined(separator: ", ")
                        ) {
                            PrefChecklist(items: setup.additionalMonitoring, tint: PrefGroup.monitoring.tint)
                        }
                    }

                    if !setup.drugChanges.isBlank {
                        PrefCollapsibleCard(
                            group: .medications,
                            title: "Drugs",
                            collapsedSummary: setup.drugChanges
                        ) {
                            PrefNote(label: "", text: setup.drugChanges, tint: PrefGroup.medications.tint)
                        }
                    }

                    if !setup.specialNotes.isBlank {
                        PrefCollapsibleCard(
                            group: .consultantNotes,
                            collapsedSummary: setup.specialNotes
                        ) {
                            PrefNote(label: "", text: setup.specialNotes, tint: PrefGroup.consultantNotes.tint)
                        }
                    }

                    if !hospitalItems.isEmpty {
                        PrefHospitalCard(items: hospitalItems)
                    }

                    PrefDisclaimer()
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(setup.specialty.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var hasEquipment: Bool {
        !setup.equipment.isEmpty || !setup.linesAndAccess.isEmpty
    }

    private var equipmentSummary: String {
        let tokens = setup.equipment + setup.linesAndAccess
        return tokens.isEmpty ? "Tap to view" : tokens.prefix(3).joined(separator: ", ")
    }

    private var highlightChips: [String] {
        var chips: [String] = []
        chips.append(contentsOf: setup.equipment.prefix(2))
        chips.append(contentsOf: setup.additionalMonitoring.prefix(2))
        return Array(chips.prefix(4))
    }
}

/// Editor for a specialty setup using a specialty picker plus curated chips.
struct SpecialtySetupEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var doctor: Doctor
    @State private var setup: SpecialtySetup
    private let isNew: Bool

    init(doctor: Doctor, setup: SpecialtySetup, isNew: Bool) {
        _doctor = State(initialValue: doctor)
        _setup = State(initialValue: setup)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Specialty") {
                    Picker("Specialty", selection: $setup.specialty) {
                        ForEach(Subspecialty.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Additional Monitoring") {
                    ChipMultiSelect(selected: $setup.additionalMonitoring, options: SpecialtySetupOptions.monitoring)
                        .padding(.vertical, 4)
                }
                Section("Lines & Access") {
                    ChipMultiSelect(selected: $setup.linesAndAccess, options: SpecialtySetupOptions.lines)
                        .padding(.vertical, 4)
                }
                Section("Equipment") {
                    ChipMultiSelect(selected: $setup.equipment, options: SpecialtySetupOptions.equipment)
                        .padding(.vertical, 4)
                }
                Section("Drug Preferences") {
                    NotesField(label: "How drugs differ for this list", text: $setup.drugChanges, minHeight: 60)
                }
                Section("Special Notes") {
                    NotesField(label: "Notes", text: $setup.specialNotes, minHeight: 60)
                }
                if !isNew {
                    Section {
                        Button("Delete Specialty Setup", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "Add Specialty" : setup.specialty.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        var updated = doctor
        var list = updated.specialtySetups ?? []
        if let index = list.firstIndex(where: { $0.id == setup.id }) {
            list[index] = setup
        } else {
            list.append(setup)
        }
        updated.specialtySetups = list
        store.upsert(updated)
        dismiss()
    }

    private func delete() {
        var updated = doctor
        updated.specialtySetups?.removeAll { $0.id == setup.id }
        store.upsert(updated)
        dismiss()
    }
}
