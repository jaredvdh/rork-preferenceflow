//
//  DrugsFluidsTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Drugs & Fluids — adult and paediatric structured preferences behind a toggle.
/// Each cohort is fully independent. Selections come from curated lists; only the
/// per-category notes are free text.
struct DrugsFluidsTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor

    @State private var cohort: Cohort = .adult
    @State private var editing = false

    enum Cohort: String, CaseIterable, Identifiable {
        case adult, paediatric
        var id: String { rawValue }
    }

    private var setup: DrugsFluidsSetup {
        switch cohort {
        case .adult: return doctor.adultDrugs ?? DrugsFluidsSetup()
        case .paediatric: return doctor.paediatricDrugs ?? DrugsFluidsSetup()
        }
    }


    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Cohort", selection: $cohort) {
                    Text("Adult").tag(Cohort.adult)
                    Text(settings.region.paediatric).tag(Cohort.paediatric)
                }
                .pickerStyle(.segmented)

                PrefSummaryHeader(
                    icon: "syringe.fill",
                    title: "Drugs & Fluids",
                    caption: "\(cohortLabel) — standard theatre drugs",
                    chips: highlightChips
                )

                if cohort == .paediatric, let gas = setup.gasInduction, gas.enabled {
                    GasInductionCard(prefs: gas)
                }

                if setup.hasContent {
                    ForEach(DrugCategory.allCases) { category in
                        let selection = setup.selection(for: category)
                        if !selection.isEmpty {
                            DrugCategoryCollapsibleCard(category: category, selection: selection)
                        }
                    }
                    if !setup.notes.isBlank {
                        DrugsConsultantNotesCard(notes: setup.notes)
                    }
                } else if !(cohort == .paediatric && setup.gasInduction?.enabled == true) {
                    EmptyStateView(
                        icon: "syringe",
                        title: "No \(cohortLabel.lowercased()) drugs set",
                        message: "Pick induction agents, opioids, vasopressors, relaxants and fluids from curated lists.",
                        actionTitle: "Set Up",
                        action: { editing = true }
                    )
                    .card()
                }

                EditSectionButton(title: "Edit \(cohortLabel) Drugs & Fluids") { editing = true }
                PrefDisclaimer()
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.25), value: cohort)
        }
        .sheet(isPresented: $editing) {
            DrugsFluidsEditView(doctor: doctor, cohort: cohort)
        }
    }

    private var cohortLabel: String {
        cohort == .adult ? "Adult" : settings.region.paediatric
    }

    private var highlightChips: [String] {
        var chips: [String] = []
        chips.append(contentsOf: setup.induction.selected)
        chips.append(contentsOf: setup.opioid.selected.prefix(1))
        chips.append(contentsOf: setup.vasopressor.selected.prefix(1))
        chips.append(contentsOf: setup.fluids.selected.prefix(1))
        return Array(chips.prefix(5))
    }

}

/// A collapsible read card for one drug category — the shared component used by
/// both the Drugs & Fluids tab and the main consultant card so the collapsed
/// summary and expanded detail (checklist, "Prepared by", notes) are identical in
/// both places. Reads from the same `DrugSelection` the editor writes.
struct DrugCategoryCollapsibleCard: View {
    let category: DrugCategory
    let selection: DrugSelection

    private var group: PrefGroup { category == .fluid ? .equipment : .medications }

    var body: some View {
        let tint = group.tint
        return PrefCollapsibleCard(
            group: group,
            title: category.rawValue,
            icon: category.symbol,
            collapsedSummary: Self.collapsedSummary(category, selection)
        ) {
            PrefChecklist(items: selection.selected, tint: tint)
            if category != .fluid {
                PrefRow(label: "Prepared by", value: selection.preparedBy.shortLabel)
            }
            PrefNote(label: "Notes", text: selection.notes, tint: tint)
        }
    }

    /// One-line collapsed summary: the first agents plus an "Assistant may prepare"
    /// flag, or a notes hint when nothing is selected.
    static func collapsedSummary(_ category: DrugCategory, _ selection: DrugSelection) -> String {
        if selection.selected.isEmpty {
            return selection.notes.isBlank ? "Tap to view" : "See notes"
        }
        var summary = selection.selected.prefix(3).joined(separator: ", ")
        if category != .fluid, selection.preparedBy == .assistant {
            summary += " • Assistant may prepare"
        }
        return summary
    }
}

/// The overall Drugs & Fluids consultant notes as a collapsible card — shared so
/// the tab and the main card render it identically.
struct DrugsConsultantNotesCard: View {
    let notes: String

    var body: some View {
        PrefCollapsibleCard(
            group: .consultantNotes,
            collapsedSummary: notes
        ) {
            PrefNote(label: "", text: notes, tint: PrefGroup.consultantNotes.tint)
        }
    }
}

/// A read card for one drug category showing the chosen agents and preparation.
struct DrugCategoryCard: View {
    let category: DrugCategory
    let selection: DrugSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(category.rawValue, icon: category.symbol)
                Spacer()
                if !selection.selected.isEmpty {
                    Text(selection.preparedBy.shortLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.15), in: .capsule)
                        .foregroundStyle(Theme.accentDeep)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                PrefChecklist(items: selection.selected)
                if !selection.notes.isBlank {
                    Text(selection.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()
        }
    }
}

/// Read card for the paediatric gas (inhalational) induction preference.
/// Stored consultant preference only — not a clinical instruction.
struct GasInductionCard: View {
    let prefs: GasInductionPreferences

    var body: some View {
        let tint = PrefGroup.medications.tint
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Gas Induction", icon: "wind")
                Spacer()
                PrefBadge("Preference only", tint)
            }
            VStack(alignment: .leading, spacing: 12) {
                if !prefs.headlineSummary.isEmpty {
                    Text(prefs.headlineSummary)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !prefs.sequenceSummary.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                        Text(prefs.sequenceSummary)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                PrefNote(label: "Notes", text: prefs.notes, tint: tint)
            }
            .card()
        }
    }
}

/// Editor for one cohort's drugs & fluids.
struct DrugsFluidsEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Doctor
    private let cohort: DrugsFluidsTab.Cohort

    init(doctor: Doctor, cohort: DrugsFluidsTab.Cohort) {
        _draft = State(initialValue: doctor)
        self.cohort = cohort
        // Ensure the optional structured setup exists for editing.
        if cohort == .adult, doctor.adultDrugs == nil {
            _draft = State(initialValue: { var d = doctor; d.adultDrugs = DrugsFluidsSetup(); return d }())
        } else if cohort == .paediatric, doctor.paediatricDrugs == nil {
            _draft = State(initialValue: { var d = doctor; d.paediatricDrugs = DrugsFluidsSetup(); return d }())
        }
    }

    private var setupBinding: Binding<DrugsFluidsSetup> {
        switch cohort {
        case .adult:
            return Binding(
                get: { draft.adultDrugs ?? DrugsFluidsSetup() },
                set: { draft.adultDrugs = $0 }
            )
        case .paediatric:
            return Binding(
                get: { draft.paediatricDrugs ?? DrugsFluidsSetup() },
                set: { draft.paediatricDrugs = $0 }
            )
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                categorySection(.induction, binding: setupBinding.induction)
                categorySection(.opioid, binding: setupBinding.opioid)
                categorySection(.vasopressor, binding: setupBinding.vasopressor)
                categorySection(.muscleRelaxant, binding: setupBinding.muscleRelaxant)
                categorySection(.fluid, binding: setupBinding.fluids)

                if cohort == .paediatric {
                    gasInductionSection
                }

                Section("Overall Notes") {
                    NotesField(label: "Special notes", text: setupBinding.notes)
                }
            }
            .navigationTitle(cohort == .adult ? "Adult" : settings.region.paediatric)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.upsert(draft); dismiss() }
                }
            }
        }
    }

    private var gasInductionBinding: Binding<GasInductionPreferences> {
        Binding(
            get: { setupBinding.wrappedValue.gasInduction ?? GasInductionPreferences() },
            set: { setupBinding.wrappedValue.gasInduction = $0 }
        )
    }

    @ViewBuilder private var gasInductionSection: some View {
        let gas = gasInductionBinding
        Section {
            Toggle(isOn: gas.enabled) {
                Label("Enable gas induction preference", systemImage: "wind")
            }
            if gas.wrappedValue.enabled {
                OptionPicker(label: "Volatile agent", selection: gas.volatileAgent,
                             options: GasInductionPreferences.volatileOptions, icon: "aqi.medium")
                OptionPicker(label: "Carrier gases", selection: gas.carrierGas,
                             options: GasInductionPreferences.carrierOptions, icon: "wind")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Typical step-up sequence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ChipMultiSelect(selected: gas.stepUpSequence, options: GasInductionPreferences.stepOptions)
                    if !gas.wrappedValue.sequenceSummary.isEmpty {
                        Text(gas.wrappedValue.sequenceSummary)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.accentDeep)
                    }
                }
                .padding(.vertical, 4)
                NotesField(label: "Notes (mask technique, parent present, IV after induction, airway adjunct)",
                           text: gas.notes, minHeight: 60)
            }
        } header: {
            Label("Gas Induction", systemImage: "wind")
        } footer: {
            Text("Stored consultant preference only — not a clinical instruction.")
        }
    }

    private func categorySection(_ category: DrugCategory, binding: Binding<DrugSelection>) -> some View {
        Section {
            ChipMultiSelect(selected: binding.selected, options: category.options)
                .padding(.vertical, 4)
            if category != .fluid {
                Picker(selection: binding.preparedBy) {
                    ForEach(PreparedBy.allCases) { Text($0.shortLabel).tag($0) }
                } label: {
                    Label("Prepared by", systemImage: "hand.raised")
                }
            }
            NotesField(label: "Notes", text: binding.notes, minHeight: 60)
        } header: {
            Label(category.rawValue, systemImage: category.symbol)
        }
    }
}
