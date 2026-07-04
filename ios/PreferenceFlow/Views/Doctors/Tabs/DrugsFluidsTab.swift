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
                    ForEach(DrugCategory.drugCases) { category in
                        let selection = setup.selection(for: category)
                        if !selection.isEmpty {
                            DrugCategoryCollapsibleCard(category: category, selection: selection)
                        }
                    }
                    if !setup.fluids.isEmpty {
                        FluidSetupCard(fluids: setup.fluids)
                    }
                    if !setup.emergency.isEmpty {
                        EmergencyDrugsCard(emergency: setup.emergency)
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
        if !setup.fluids.primary.isBlank { chips.append(setup.fluids.primary) }
        return Array(chips.prefix(5))
    }

}

/// The maintenance technique headline shown prominently at the top of the adult
/// Drugs & Fluids section — the single most operationally important thing a
/// technician needs to know before the patient arrives. Renders a chip-style
/// indicator for the technique and, where set, the agent/model detail below.
struct MaintenanceHeadline: View {
    let setup: DrugsFluidsSetup

    var body: some View {
        let tint = PrefGroup.medications.tint
        let technique = setup.maintenanceTechnique
        let detail = setup.maintenanceDetail
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: technique.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(tint, in: .rect(cornerRadius: 8, style: .continuous))
                Text(technique.rawValue)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text("Maintenance")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: .capsule)
            }
            if !detail.isBlank {
                Text(detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
            PrefChecklist(items: selection.allAgents, tint: tint)
            if category != .fluid {
                PrefRow(label: "Prepared by", value: selection.preparedBy.shortLabel)
            }
            PrefNote(label: "Notes", text: selection.notes, tint: tint)
        }
    }

    /// One-line collapsed summary: the first agents plus an "Assistant may prepare"
    /// flag, or a notes hint when nothing is selected.
    static func collapsedSummary(_ category: DrugCategory, _ selection: DrugSelection) -> String {
        let agents = selection.allAgents
        if agents.isEmpty {
            return selection.notes.isBlank ? "Tap to view" : "See notes"
        }
        var summary = agents.prefix(3).joined(separator: ", ")
        if category != .fluid, selection.preparedBy == .assistant {
            summary += " • Assistant may prepare"
        }
        return summary
    }
}

/// The routine intraoperative drug categories (induction, opioid, vasopressor,
/// muscle relaxant, reversal) grouped behind a single collapsible header — used
/// on the main consultant card so drugs a technician only needs when drawing up
/// medications are one tap away instead of always taking up scroll space.
/// Fluids and Emergency Drugs deliberately stay outside this group.
struct AnaestheticDrugsGroup: View {
    let setup: DrugsFluidsSetup

    @State private var expanded = false

    private var filledCategories: [DrugCategory] {
        DrugCategory.drugCases.filter { !setup.selection(for: $0).isEmpty }
    }

    /// e.g. "Propofol, Ketamine · Fentanyl, Remifentanil · Phenylephrine · Rocuronium".
    private var collapsedSummary: String {
        filledCategories
            .map { setup.selection(for: $0).allAgents.prefix(2).joined(separator: ", ") }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        let tint = PrefGroup.medications.tint
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.16))
                            .frame(width: 38, height: 38)
                        Image(systemName: "syringe.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("Anaesthetic Drugs")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            PrefCountBadge(count: filledCategories.count, noun: "category")
                        }
                        if !expanded {
                            Text(collapsedSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .card()

            if expanded {
                VStack(spacing: 10) {
                    ForEach(filledCategories) { category in
                        DrugCategoryCollapsibleCard(category: category, selection: setup.selection(for: category))
                    }
                }
                .padding(.leading, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sensoryFeedback(.selection, trigger: expanded)
    }
}

/// The structured IV Fluids read card — primary/secondary fluid and giving set.
/// Always visible (never inside the collapsible drugs group) because fluid and
/// giving-set choice affects what is primed before the case starts.
struct FluidSetupCard: View {
    let fluids: FluidSetup

    var body: some View {
        let tint = PrefGroup.equipment.tint
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: "drop.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text("IV Fluids")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                PrefRow(label: "Primary", value: fluids.primary)
                if !fluids.secondary.isBlank {
                    PrefRow(label: "Secondary", value: fluids.secondary)
                }
                PrefRow(label: "Giving set", value: fluids.givingSet.rawValue)
                PrefNote(label: "Notes", text: fluids.notes, tint: tint)
            }
        }
        .card()
    }
}

/// The Emergency Drugs read card — drugs the consultant wants drawn up or
/// readily available for emergencies during the case. Always visible at a
/// glance, never collapsed. Renders only the fields that are actually set.
struct EmergencyDrugsCard: View {
    let emergency: EmergencyDrugSetup

    var body: some View {
        let tint = PrefGroup.monitoring.tint
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: "cross.case.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text("Emergency Drugs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if emergency.preparedBy != .caseDependent {
                    PrefBadge(emergency.preparedBy.shortLabel + " prepares", tint)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if !emergency.allAgents.isEmpty {
                    PrefChecklist(items: emergency.allAgents, tint: tint)
                }
                if emergency.hasPushDose {
                    PrefRow(label: "Push-dose adrenaline", value: emergency.pushDoseAdrenalineDilution)
                }
                if emergency.paediatricSuxamethonium {
                    PrefRow(label: "Paediatric", value: "Sux kept drawn up")
                }
                PrefNote(label: "Notes", text: emergency.notes, tint: tint)
            }
        }
        .card()
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
                PrefChecklist(items: selection.allAgents)
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
                if cohort == .adult {
                    maintenanceSection
                }
                categorySection(.induction, binding: setupBinding.induction)
                categorySection(.opioid, binding: setupBinding.opioid)
                categorySection(.vasopressor, binding: setupBinding.vasopressor)
                categorySection(.muscleRelaxant, binding: setupBinding.muscleRelaxant)
                fluidsSection
                emergencySection

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

    private var maintenanceBinding: Binding<MaintenanceTechnique> {
        Binding(
            get: { setupBinding.wrappedValue.maintenanceTechnique },
            set: { setupBinding.wrappedValue.maintenance = $0 }
        )
    }

    @ViewBuilder private var maintenanceSection: some View {
        let technique = maintenanceBinding
        Section {
            Picker(selection: technique) {
                ForEach(MaintenanceTechnique.allCases) { Text($0.rawValue).tag($0) }
            } label: {
                Label("Technique", systemImage: "cross.vial")
            }

            switch technique.wrappedValue {
            case .tiva:
                OptionPicker(label: "TCI agent", selection: setupBinding.tciAgent,
                             options: MaintenanceTechnique.tciAgentOptions, icon: "ivfluid.bag")
                OptionPicker(label: "TCI model", selection: setupBinding.tciModel,
                             options: MaintenanceTechnique.tciModelOptions, icon: "function")
            case .volatile, .balanced:
                OptionPicker(label: "Volatile agent", selection: setupBinding.maintenanceVolatileAgent,
                             options: MaintenanceTechnique.volatileAgentOptions, icon: "aqi.medium")
            case .notSpecified:
                EmptyView()
            }
        } header: {
            Label("Maintenance", systemImage: "waveform.path")
        } footer: {
            Text("Determines what the technician prepares — TCI pump and infusions for TIVA, or a calibrated vaporiser with the preferred agent for volatile.")
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

    /// Structured IV fluids editor: primary and secondary fluid (curated chips
    /// plus free text for anything unusual), giving set, and notes.
    @ViewBuilder private var fluidsSection: some View {
        let fluids = setupBinding.fluids
        Section {
            SuggestionField(label: "Primary", text: fluids.primary,
                            suggestions: FluidSetup.fluidOptions,
                            placeholder: "e.g. Hartmann's", icon: "drop.fill")
            SuggestionField(label: "Secondary", text: fluids.secondary,
                            suggestions: FluidSetup.fluidOptions,
                            placeholder: "None", icon: "drop")
            Picker(selection: fluids.givingSet) {
                ForEach(GivingSetType.allCases) { Text($0.rawValue).tag($0) }
            } label: {
                Label("Giving set", systemImage: "ivfluid.bag")
            }
            NotesField(label: "Notes", text: fluids.notes, minHeight: 60)
        } header: {
            Label("IV Fluids", systemImage: "drop.fill")
        } footer: {
            Text("Secondary is optional — e.g. a saline bag run first, then switching to the primary balanced fluid. Leave blank if not used.")
        }
    }

    /// Emergency drugs editor — drugs kept drawn up or readily available during
    /// the case, distinct from routine induction/maintenance drugs.
    @ViewBuilder private var emergencySection: some View {
        let emergency = setupBinding.emergency
        Section {
            ChipMultiSelect(selected: emergency.selected, options: EmergencyDrugSetup.drugOptions)
                .padding(.vertical, 4)
            CustomAgentEditor(custom: emergency.custom)
            OptionPicker(label: "Push-dose adrenaline", selection: emergency.pushDoseAdrenalineDilution,
                         options: EmergencyDrugSetup.dilutionOptions, icon: "syringe", allowClear: false)
            Toggle(isOn: emergency.paediatricSuxamethonium) {
                Label("Sux drawn up for \(settings.region.paediatric.lowercased()) cases", systemImage: "figure.child")
            }
            Picker(selection: emergency.preparedBy) {
                ForEach(PreparedBy.allCases) { Text($0.shortLabel).tag($0) }
            } label: {
                Label("Prepared by", systemImage: "hand.raised")
            }
            NotesField(label: "Notes", text: emergency.notes, minHeight: 60)
        } header: {
            Label("Emergency Drugs", systemImage: "cross.case.fill")
        } footer: {
            Text("Drugs the consultant wants drawn up or immediately available for emergencies — separate from routine drugs. Stored preference only.")
        }
    }

    private func categorySection(_ category: DrugCategory, binding: Binding<DrugSelection>) -> some View {
        Section {
            ChipMultiSelect(selected: binding.selected, options: category.options)
                .padding(.vertical, 4)
            CustomAgentEditor(custom: binding.custom)
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

/// Lets the user add custom agents not present in the curated list (e.g.
/// Methohexital, Ketofol). Shows existing custom agents as removable chips plus
/// an inline "+ Add custom agent" text field. Reference name only — no dose.
struct CustomAgentEditor: View {
    @Binding var custom: [String]
    @State private var isAdding = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !custom.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(custom, id: \.self) { agent in
                        Button { remove(agent) } label: {
                            HStack(spacing: 4) {
                                Text(agent)
                                Image(systemName: "xmark.circle.fill")
                            }
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.14), in: .capsule)
                            .foregroundStyle(Theme.accentDeep)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if isAdding {
                HStack(spacing: 8) {
                    TextField("Custom agent name", text: $draft)
                        .textInputAutocapitalization(.words)
                        .focused($focused)
                        .onSubmit(commit)
                    Button("Add", action: commit)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Button {
                    isAdding = true
                    focused = true
                } label: {
                    Label("Add custom agent", systemImage: "plus.circle.fill")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func commit() {
        let value = draft.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        if !custom.contains(value) { custom.append(value) }
        draft = ""
        isAdding = false
        focused = false
    }

    private func remove(_ agent: String) {
        custom.removeAll { $0 == agent }
    }
}
