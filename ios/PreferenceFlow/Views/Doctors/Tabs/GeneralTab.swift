//
//  GeneralTab.swift
//  PreferenceFlow
//

import SwiftUI

/// General working preferences — read view plus an edit sheet.
struct GeneralTab: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor

    @State private var editing = false

    private var g: GeneralPreferences { doctor.general }
    private var template: DepartmentTemplate? { store.template(for: doctor) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PrefSummaryHeader(
                    icon: "person.text.rectangle.fill",
                    title: "General Preferences",
                    status: status,
                    chips: highlightChips
                )

                if hasTheatreSetup { theatreSetupCard }
                if hasPersonal { personalCard }
                if hasWorkflow { workflowCard }
                if !g.contactPreferences.isBlank { communicationCard }
                if !g.generalNotes.isBlank { notesCard }

                if isEverythingEmpty { emptyState }

                EditSectionButton(title: "Edit General Preferences") { editing = true }
                PrefDisclaimer()
            }
            .padding(16)
        }
        .sheet(isPresented: $editing) {
            GeneralEditView(doctor: doctor)
        }
    }

    // MARK: - Status & highlights

    private var status: PrefStatus {
        switch ProfileInheritance.status(.general, doctor: doctor, template: template) {
        case .modified: return .modified("Updated by you")
        case .inherited: return .departmentStandard
        case .standalone: return .custom(text: "How this consultant likes to work", icon: "person.fill", color: Theme.accent)
        }
    }

    private var highlightChips: [String] {
        var chips: [String] = []
        if !g.gloveSize.isBlank { chips.append("Gloves \(g.gloveSize)") }
        if !g.gownSize.isBlank { chips.append("Gown \(g.gownSize)") }
        if !g.coffeePreference.isBlank { chips.append(g.coffeePreference) }
        if g.arriveBeforePatient { chips.append("Arrives early") }
        return Array(chips.prefix(5))
    }

    // MARK: - Theatre setup

    private var hasTheatreSetup: Bool {
        !(g.gloveSize.isBlank && g.gownSize.isBlank && g.maskPreference.isBlank
            && g.theatreShoeSize.isBlank && g.roomTemperature.isBlank)
    }

    private var theatreSetupCard: some View {
        PrefCollapsibleCard(
            group: .equipment,
            title: "Theatre Setup",
            icon: "tshirt.fill",
            collapsedSummary: [g.gloveSize.isBlank ? "" : "Gloves \(g.gloveSize)",
                               g.gownSize.isBlank ? "" : "Gown \(g.gownSize)"]
                .filter { !$0.isEmpty }.joined(separator: " • ")
        ) {
            PrefRow(label: "Glove size", value: g.gloveSize)
            PrefRow(label: "Gown size", value: g.gownSize)
            PrefRow(label: "Mask", value: g.maskPreference)
            PrefRow(label: "Shoe size", value: g.theatreShoeSize)
            PrefRow(label: "Room temp", value: g.roomTemperature)
        }
    }

    // MARK: - Personal

    private var hasPersonal: Bool {
        !(g.coffeePreference.isBlank && g.teaPreference.isBlank && g.favouriteSnacks.isBlank)
    }

    private var personalCard: some View {
        PrefCollapsibleCard(
            group: .personal,
            title: "Personal",
            collapsedSummary: [g.coffeePreference, g.teaPreference, g.favouriteSnacks]
                .filter { !$0.isBlank }.prefix(2).joined(separator: " • ")
        ) {
            PrefRow(label: "Coffee", value: g.coffeePreference)
            PrefRow(label: "Tea", value: g.teaPreference)
            PrefRow(label: "Snacks", value: g.favouriteSnacks)
        }
    }

    // MARK: - Workflow

    private var workflowFlags: [String] {
        var out: [String] = []
        if g.arriveBeforePatient { out.append("Arrives before patient") }
        if g.prepareOwnMedications { out.append("Prepares own medications") }
        if g.assistantMayPrepareMedications { out.append("Assistant may prepare meds") }
        return out
    }

    private var hasWorkflow: Bool { !workflowFlags.isEmpty || !g.briefingStyle.isBlank }

    private var workflowCard: some View {
        PrefCollapsibleCard(
            group: .workflow,
            title: "Workflow",
            collapsedSummary: (workflowFlags + [g.briefingStyle.isBlank ? "" : "Briefing"])
                .filter { !$0.isEmpty }.prefix(2).joined(separator: " • ")
        ) {
            if !workflowFlags.isEmpty {
                PrefChecklist(items: workflowFlags, tint: PrefGroup.workflow.tint)
            }
            PrefNote(label: "Briefing style", text: g.briefingStyle, tint: PrefGroup.workflow.tint)
        }
    }

    // MARK: - Communication

    private var communicationCard: some View {
        PrefCollapsibleCard(
            group: .monitoring,
            title: "Communication",
            icon: "bubble.left.and.bubble.right.fill",
            collapsedSummary: g.contactPreferences
        ) {
            PrefNote(label: "", text: g.contactPreferences, tint: PrefGroup.monitoring.tint)
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        PrefCollapsibleCard(
            group: .consultantNotes,
            collapsedSummary: g.generalNotes
        ) {
            PrefNote(label: "", text: g.generalNotes, tint: PrefGroup.consultantNotes.tint)
        }
    }

    private var isEverythingEmpty: Bool {
        !hasTheatreSetup && !hasPersonal && !hasWorkflow
            && g.contactPreferences.isBlank && g.generalNotes.isBlank
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.text.rectangle",
            title: "No general preferences yet",
            message: "Add theatre setup, personal touches and workflow expectations.",
            actionTitle: "Set Up",
            action: { editing = true }
        )
        .card()
    }
}

/// A yes/no preference row.
struct BoolRow: View {
    let label: String
    let value: Bool
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(value ? Theme.accent : .secondary)
            Text(value ? "Yes" : "No")
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 2)
    }
}

/// Edit form for general preferences.
struct GeneralEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Doctor

    init(doctor: Doctor) {
        _draft = State(initialValue: doctor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Theatre Setup") {
                    LabeledField(label: "Glove size", text: $draft.general.gloveSize)
                    LabeledField(label: "Gown size", text: $draft.general.gownSize)
                    LabeledField(label: "Mask", text: $draft.general.maskPreference)
                    LabeledField(label: "Shoe size", text: $draft.general.theatreShoeSize)
                    LabeledField(label: "Room temp", text: $draft.general.roomTemperature)
                }
                Section("Personal") {
                    LabeledField(label: "Coffee", text: $draft.general.coffeePreference)
                    LabeledField(label: "Tea", text: $draft.general.teaPreference)
                    LabeledField(label: "Snacks", text: $draft.general.favouriteSnacks)
                    LabeledField(label: "Contact", text: $draft.general.contactPreferences)
                }
                Section("Workflow") {
                    Toggle("Arrives before patient", isOn: $draft.general.arriveBeforePatient)
                    Toggle("Prepares own medications", isOn: $draft.general.prepareOwnMedications)
                    Toggle("Assistant may prepare meds", isOn: $draft.general.assistantMayPrepareMedications)
                    LabeledField(label: "Briefing style", text: $draft.general.briefingStyle)
                }
                Section("General Notes") {
                    NotesField(label: "Notes", text: $draft.general.generalNotes)
                }
            }
            .navigationTitle("General")
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
