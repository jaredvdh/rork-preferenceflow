//
//  HospitalEditView.swift
//  PreferenceFlow
//

import SwiftUI

/// Create / edit a hospital.
struct HospitalEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Hospital
    private let isNew: Bool

    init(hospital: Hospital) {
        _draft = State(initialValue: hospital)
        self.isNew = hospital.name.isBlank && hospital.city.isBlank
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hospital") {
                    LabeledField(label: "Name", text: $draft.name, placeholder: "Christchurch Hospital", icon: "building.2")
                    LabeledField(label: "City", text: $draft.city, placeholder: "Christchurch", icon: "mappin.and.ellipse")
                    LabeledField(label: "Country", text: $draft.country, placeholder: "New Zealand", icon: "globe")
                    LabeledField(label: "Department", text: $draft.department, placeholder: "Anaesthesia", icon: "cross.case")
                }
                Section("Notes") {
                    NotesField(label: "Notes", text: $draft.notes)
                }
            }
            .navigationTitle(isNew ? "New Hospital" : "Edit Hospital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(draft.name.isBlank)
                }
            }
        }
    }
}
