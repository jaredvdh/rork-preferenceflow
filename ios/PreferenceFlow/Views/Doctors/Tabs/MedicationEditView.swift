//
//  MedicationEditView.swift
//  PreferenceFlow
//

import SwiftUI

/// Add / edit a single medication within an adult or paediatric setup.
struct MedicationEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var doctor: Doctor
    @State private var med: Medication
    let kind: MedicationKind
    private let isExisting: Bool

    init(doctor: Doctor, kind: MedicationKind, medication: Medication) {
        _doctor = State(initialValue: doctor)
        _med = State(initialValue: medication)
        self.kind = kind
        let list = kind == .adult ? doctor.adult.medications : doctor.paediatric.medications
        self.isExisting = list.contains { $0.id == medication.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $med.category) {
                        ForEach(MedicationCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if !med.category.examples.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(med.category.examples, id: \.self) { example in
                                    Button { med.name = example } label: { Chip(text: example) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                Section("Medication") {
                    LabeledField(label: "Name", text: $med.name)
                    LabeledField(label: "Preparation", text: $med.preparation)
                    LabeledField(label: "Concentration", text: $med.concentration)
                }
                Section("Notes") {
                    NotesField(label: "Draw-up notes", text: $med.drawUpNotes)
                    NotesField(label: "Labelling notes", text: $med.labellingNotes)
                }
                Section("Preparation Preference") {
                    Picker("Prepared by", selection: $med.preparedBy) {
                        ForEach(PreparedBy.allCases) { Text($0.rawValue).tag($0) }
                    }
                    NotesField(label: "Special notes", text: $med.specialNotes)
                }
                if isExisting {
                    Section {
                        Button("Delete Medication", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isExisting ? "Edit Medication" : "New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(med.name.isBlank)
                }
            }
        }
    }

    private func save() {
        applyMutation { list in
            if let index = list.firstIndex(where: { $0.id == med.id }) {
                list[index] = med
            } else {
                list.append(med)
            }
        }
    }

    private func delete() {
        applyMutation { list in list.removeAll { $0.id == med.id } }
    }

    private func applyMutation(_ mutate: (inout [Medication]) -> Void) {
        var updated = doctor
        if kind == .adult { mutate(&updated.adult.medications) }
        else { mutate(&updated.paediatric.medications) }
        store.upsert(updated)
        dismiss()
    }
}

/// Edit IV fluid preferences for an adult/paediatric setup.
struct FluidsEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Doctor
    let kind: MedicationKind

    init(doctor: Doctor, kind: MedicationKind) {
        _draft = State(initialValue: doctor)
        self.kind = kind
    }

    private var fluids: Binding<IVFluidPreferences> {
        kind == .adult ? $draft.adult.fluids : $draft.paediatric.fluids
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("IV Fluids") {
                    LabeledField(label: "Crystalloid", text: fluids.preferredCrystalloid)
                    LabeledField(label: "Balanced", text: fluids.balancedCrystalloid)
                    LabeledField(label: "Saline", text: fluids.salinePreference)
                    LabeledField(label: "Pressure bag", text: fluids.pressureBagUse)
                    LabeledField(label: "Fluid warmer", text: fluids.fluidWarmer)
                    LabeledField(label: "Blood setup", text: fluids.bloodSetup)
                }
                Section("Notes") {
                    NotesField(label: "Special notes", text: fluids.specialNotes)
                }
            }
            .navigationTitle("IV Fluids")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.upsert(draft); dismiss() }
                }
            }
        }
    }
}

/// Generic single free-text note editor bound to a writable key path on Doctor.
struct SingleNoteEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State private var draft: Doctor
    let keyPath: WritableKeyPath<Doctor, String>

    init(title: String, doctor: Doctor, keyPath: WritableKeyPath<Doctor, String>) {
        self.title = title
        _draft = State(initialValue: doctor)
        self.keyPath = keyPath
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("Notes", text: Binding(
                        get: { draft[keyPath: keyPath] },
                        set: { draft[keyPath: keyPath] = $0 }
                    ), axis: .vertical)
                    .lineLimit(5...20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.upsert(draft); dismiss() }
                }
            }
        }
    }
}
