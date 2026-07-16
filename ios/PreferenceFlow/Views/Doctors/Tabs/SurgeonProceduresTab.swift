//
//  SurgeonProceduresTab.swift
//  PreferenceFlow
//
//  Surgeon edit tab: manages the per-operation preference cards (e.g. Lap
//  Chole, Hemicolectomy, CABG). Each card holds this surgeon's exact trays,
//  sutures, energy settings, positioning and notes for that operation, gets
//  its own read-mode tab, and prints as a separate one-page card.
//

import SwiftUI

/// Procedures — the list of per-operation preference cards for a surgeon.
struct SurgeonProceduresTab: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor

    @State private var editing: SurgeonProcedure?
    @State private var creatingNew = false

    /// Always read the live profile so the list refreshes after edits.
    private var procedures: [SurgeonProcedure] {
        store.doctor(id: doctor.id)?.surgicalProcedures ?? doctor.surgicalProcedures
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button { creatingNew = true } label: {
                    Label("Add Operation", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                if procedures.isEmpty {
                    EmptyStateView(
                        icon: "cross.case",
                        title: "No operation cards yet",
                        message: "Add the operations this surgeon does — e.g. Lap Chole, Hemicolectomy, Trauma Laparotomy — each with its own trays, sutures, positioning and extras. Every card prints as its own one-page printout.",
                        actionTitle: "Add Operation",
                        action: { creatingNew = true }
                    )
                    .card()
                } else {
                    ForEach(procedures) { procedure in
                        Button { editing = procedure } label: {
                            SurgeonProcedureRowCard(procedure: procedure)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editing = procedure } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) { delete(procedure) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $editing) { procedure in
            SurgeonProcedureEditView(doctor: doctor, procedure: procedure, isNew: false)
        }
        .sheet(isPresented: $creatingNew) {
            SurgeonProcedureEditView(doctor: doctor, procedure: SurgeonProcedure(), isNew: true)
        }
    }

    private func delete(_ procedure: SurgeonProcedure) {
        guard var updated = store.doctor(id: doctor.id) else { return }
        var surgical = updated.surgical ?? SurgicalPreferences()
        surgical.procedures.removeAll { $0.id == procedure.id }
        updated.surgical = surgical
        withAnimation(.spring(response: 0.3)) { store.upsert(updated) }
    }
}

/// One row in the procedures list: name plus a compact content summary.
struct SurgeonProcedureRowCard: View {
    let procedure: SurgeonProcedure

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(Color(hex: "2E7DD1"))
                Text(procedure.displayName)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !procedure.summaryLine.isEmpty {
                Text(procedure.summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !procedure.hasContent {
                Text("Empty — tap to fill in this operation's setup")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .card()
    }
}

/// Sheet editor for one operation card. Edits a local draft and saves the
/// whole procedure back into the surgeon's profile on Save.
struct SurgeonProcedureEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let doctor: Doctor
    let isNew: Bool

    @State private var draft: SurgeonProcedure
    @State private var confirmingDelete = false

    init(doctor: Doctor, procedure: SurgeonProcedure, isNew: Bool) {
        self.doctor = doctor
        self.isNew = isNew
        _draft = State(initialValue: procedure)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                positioningSection
                traysSection
                suturesSection
                energySection
                notesSection
                if !isNew {
                    deleteSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "New Operation" : draft.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(draft.name.isBlank)
                }
            }
            .confirmationDialog(
                "Delete this operation card?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Operation", role: .destructive) { deleteProcedure() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes \(draft.displayName) and its setup preferences.")
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            SuggestionField(
                label: "Operation",
                text: $draft.name,
                suggestions: SurgeonProcedure.suggestions,
                placeholder: "e.g. Lap Cholecystectomy",
                icon: "cross.case"
            )
        } header: {
            Label("Operation Name", systemImage: "cross.case.fill")
        } footer: {
            Text("The specific operation this card describes. Tap a suggestion or type your own.")
        }
    }

    private var positioningSection: some View {
        Section {
            OptionPicker(label: "Position", selection: $draft.positioning.patientPosition,
                         options: SurgicalOptions.positions, icon: "bed.double")
            VStack(alignment: .leading, spacing: 8) {
                Text("Table setup")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.positioning.tableAttachments,
                                options: SurgicalOptions.tableAttachments)
                CustomListEditor(items: $draft.positioning.tableAttachments,
                                 curated: SurgicalOptions.tableAttachments,
                                 addLabel: "Add table item")
            }
            .padding(.vertical, 4)
            OptionPicker(label: "Prep solution", selection: $draft.positioning.prepSolution,
                         options: SurgicalOptions.prepSolutions, icon: "drop")
            OptionPicker(label: "Draping", selection: $draft.positioning.drapingStyle,
                         options: SurgicalOptions.drapingStyles, icon: "square.3.layers.3d")
            OptionPicker(label: "Catheter", selection: $draft.positioning.catheter,
                         options: SurgicalOptions.catheters, icon: "circle.bottomthird.split")
            NotesField(label: "Positioning notes", text: $draft.positioning.notes, minHeight: 60)
            SetupPhotoField(
                label: "Positioning photo (optional)",
                help: "A photo of the finished positioning for this operation.",
                photoData: $draft.positioning.setupPhoto
            )
        } header: {
            Label("Positioning & Prep", systemImage: "bed.double.fill")
        }
    }

    private var traysSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trays / sets to open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.trays.traysToOpen,
                                options: SurgicalOptions.trays)
                CustomListEditor(items: $draft.trays.traysToOpen,
                                 curated: SurgicalOptions.trays,
                                 addLabel: "Add custom tray / set")
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Extras opened for this operation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.trays.favouriteExtras,
                                options: SurgicalOptions.instrumentExtras)
                CustomListEditor(items: $draft.trays.favouriteExtras,
                                 curated: SurgicalOptions.instrumentExtras,
                                 addLabel: "Add custom extra")
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Available unopened")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.trays.haveAvailableUnopened,
                                options: SurgicalOptions.standbyInstruments)
                CustomListEditor(items: $draft.trays.haveAvailableUnopened,
                                 curated: SurgicalOptions.standbyInstruments,
                                 addLabel: "Add standby item")
            }
            .padding(.vertical, 4)
            NotesField(label: "Instrument notes", text: $draft.trays.notes, minHeight: 60)
            SetupPhotoField(
                label: "Back-table photo (optional)",
                help: "The preferred back-table layout for this operation.",
                photoData: $draft.trays.setupPhoto
            )
        } header: {
            Label("Trays & Instruments", systemImage: "tray.2.fill")
        }
    }

    private var suturesSection: some View {
        Section {
            SuggestionField(label: "Fascia / deep", text: $draft.sutures.fascia,
                            suggestions: SurgicalOptions.fasciaSutures)
            SuggestionField(label: "Subcutaneous", text: $draft.sutures.subcutaneous,
                            suggestions: SurgicalOptions.subcutaneousSutures)
            SuggestionField(label: "Skin", text: $draft.sutures.skin,
                            suggestions: SurgicalOptions.skinClosure)
            VStack(alignment: .leading, spacing: 8) {
                Text("Staplers & loads")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.sutures.staplers,
                                options: SurgicalOptions.staplers)
                CustomListEditor(items: $draft.sutures.staplers,
                                 curated: SurgicalOptions.staplers,
                                 addLabel: "Add stapler / load")
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Drains")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.sutures.drains,
                                options: SurgicalOptions.drains)
                CustomListEditor(items: $draft.sutures.drains,
                                 curated: SurgicalOptions.drains,
                                 addLabel: "Add drain")
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Dressings")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.sutures.dressings,
                                options: SurgicalOptions.dressings)
                CustomListEditor(items: $draft.sutures.dressings,
                                 curated: SurgicalOptions.dressings,
                                 addLabel: "Add dressing")
            }
            .padding(.vertical, 4)
            NotesField(label: "Closure notes", text: $draft.sutures.notes, minHeight: 60)
        } header: {
            Label("Sutures & Closure", systemImage: "bandage.fill")
        }
    }

    private var energySection: some View {
        Section {
            SuggestionField(label: "Diathermy cut", text: $draft.energy.diathermyCut,
                            suggestions: SurgicalOptions.diathermySettings)
            SuggestionField(label: "Diathermy coag", text: $draft.energy.diathermyCoag,
                            suggestions: SurgicalOptions.diathermySettings)
            VStack(alignment: .leading, spacing: 8) {
                Text("Energy devices")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.energy.energyDevices,
                                options: SurgicalOptions.energyDevices)
                CustomListEditor(items: $draft.energy.energyDevices,
                                 curated: SurgicalOptions.energyDevices,
                                 addLabel: "Add energy device")
            }
            .padding(.vertical, 4)
            SuggestionField(label: "Tourniquet", text: $draft.energy.tourniquetPressure,
                            suggestions: SurgicalOptions.tourniquetPressures)
            OptionPicker(label: "Irrigation", selection: $draft.energy.irrigation,
                         options: SurgicalOptions.irrigation, icon: "drop.circle")
            VStack(alignment: .leading, spacing: 8) {
                Text("Imaging & equipment in room")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $draft.energy.imaging,
                                options: SurgicalOptions.imaging)
                CustomListEditor(items: $draft.energy.imaging,
                                 curated: SurgicalOptions.imaging,
                                 addLabel: "Add equipment")
            }
            .padding(.vertical, 4)
            NotesField(label: "Equipment notes", text: $draft.energy.notes, minHeight: 60)
        } header: {
            Label("Energy & Equipment", systemImage: "bolt.fill")
        }
    }

    private var notesSection: some View {
        Section {
            NotesField(
                label: "Notes for this operation",
                text: $draft.notes,
                minHeight: 90
            )
        } header: {
            Label("Operation Notes", systemImage: "note.text")
        } footer: {
            Text("What must be ready before knife to skin, order of events, or anything specific to this operation. Shown highlighted at the top of the card.")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete Operation Card", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        guard var updated = store.doctor(id: doctor.id) else { dismiss(); return }
        var surgical = updated.surgical ?? SurgicalPreferences()
        if let index = surgical.procedures.firstIndex(where: { $0.id == draft.id }) {
            surgical.procedures[index] = draft
        } else {
            surgical.procedures.append(draft)
        }
        updated.surgical = surgical
        store.upsert(updated)
        dismiss()
    }

    private func deleteProcedure() {
        guard var updated = store.doctor(id: doctor.id) else { dismiss(); return }
        var surgical = updated.surgical ?? SurgicalPreferences()
        surgical.procedures.removeAll { $0.id == draft.id }
        updated.surgical = surgical
        store.upsert(updated)
        dismiss()
    }
}
