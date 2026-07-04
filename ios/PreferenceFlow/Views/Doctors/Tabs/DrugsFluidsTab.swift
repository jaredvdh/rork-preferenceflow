//
//  DrugsFluidsTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Drugs & Fluids — a direct inline editor with the Adult / Paediatric cohort
/// picker pinned at the top. Each cohort is fully independent; selections come
/// from curated lists and only notes are free text. This tab is only reachable
/// from Edit mode — the read presentation lives on the Overview card.
struct DrugsFluidsTab: View {
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor

    @State private var cohort: Cohort = .adult

    enum Cohort: String, CaseIterable, Identifiable {
        case adult, paediatric
        var id: String { rawValue }
    }

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            VStack(spacing: 0) {
                Picker("Cohort", selection: $cohort) {
                    Text("Adult").tag(Cohort.adult)
                    Text(settings.region.paediatric).tag(Cohort.paediatric)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Form {
                    DrugsFluidsFormSections(setup: setupBinding($draft), cohort: cohort)
                    MonitoringFormSection(monitoring: monitoringBinding($draft))
                    Section {
                    } footer: {
                        InlineEditFooter()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemGroupedBackground))
            .sensoryFeedback(.selection, trigger: cohort)
        }
    }

    /// Binds the doctor-level monitoring preferences on the session draft,
    /// materialising the optional on first edit. Monitoring is shared across
    /// both cohorts, so the section appears identically under each.
    private func monitoringBinding(_ draft: Binding<Doctor>) -> Binding<MonitoringPreferences> {
        Binding(
            get: { draft.wrappedValue.monitoring ?? MonitoringPreferences() },
            set: { draft.wrappedValue.monitoring = $0 }
        )
    }

    /// Binds the selected cohort's structured setup on the session draft,
    /// materialising the optional on first edit.
    private func setupBinding(_ draft: Binding<Doctor>) -> Binding<DrugsFluidsSetup> {
        switch cohort {
        case .adult:
            return Binding(
                get: { draft.wrappedValue.adultDrugs ?? DrugsFluidsSetup() },
                set: { draft.wrappedValue.adultDrugs = $0 }
            )
        case .paediatric:
            return Binding(
                get: { draft.wrappedValue.paediatricDrugs ?? DrugsFluidsSetup() },
                set: { draft.wrappedValue.paediatricDrugs = $0 }
            )
        }
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

/// The drugs & fluids form fields for one cohort, bound to the Edit-mode
/// session draft. Rendered inline inside the Drugs & Fluids tab's Form — no
/// modal chrome, no separate Save step.
struct DrugsFluidsFormSections: View {
    @Environment(AppSettings.self) private var settings
    @Binding var setup: DrugsFluidsSetup
    let cohort: DrugsFluidsTab.Cohort

    var body: some View {
        if cohort == .adult {
            maintenanceSection
        }
        categorySection(.induction, binding: $setup.induction)
        categorySection(.opioid, binding: $setup.opioid)
        categorySection(.vasopressor, binding: $setup.vasopressor)
        categorySection(.muscleRelaxant, binding: $setup.muscleRelaxant)
        fluidsSection
        emergencySection

        if cohort == .paediatric {
            gasInductionSection
        }

        Section("Overall Notes") {
            NotesField(label: "Special notes", text: $setup.notes)
        }
    }

    private var maintenanceBinding: Binding<MaintenanceTechnique> {
        Binding(
            get: { setup.maintenanceTechnique },
            set: { setup.maintenance = $0 }
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
                OptionPicker(label: "TCI agent", selection: $setup.tciAgent,
                             options: MaintenanceTechnique.tciAgentOptions, icon: "ivfluid.bag")
                OptionPicker(label: "TCI model", selection: $setup.tciModel,
                             options: MaintenanceTechnique.tciModelOptions, icon: "function")
            case .volatile, .balanced:
                OptionPicker(label: "Volatile agent", selection: $setup.maintenanceVolatileAgent,
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
            get: { setup.gasInduction ?? GasInductionPreferences() },
            set: { setup.gasInduction = $0 }
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
        let fluids = $setup.fluids
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
        let emergency = $setup.emergency
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

/// The Monitoring editor section — ECG leads, depth of anaesthesia, TOF
/// neuromuscular monitoring, curated extras and notes. Standard ASA monitoring
/// is the assumed baseline and is not itself a toggle. Doctor-level (shared
/// across adult and paediatric cohorts).
struct MonitoringFormSection: View {
    @Environment(AppSettings.self) private var settings
    @Binding var monitoring: MonitoringPreferences

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("ECG leads", systemImage: "waveform.path.ecg")
                Picker("ECG leads", selection: $monitoring.ecgLeads) {
                    ForEach(ECGLeads.allCases) { Text($0.shortLabel).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
            Picker(selection: $monitoring.depthMonitoring) {
                ForEach(DepthMonitoring.allCases) { Text($0.rawValue).tag($0) }
            } label: {
                Label("Depth monitoring", systemImage: "brain.head.profile")
            }
            Picker(selection: $monitoring.tofMonitoring) {
                ForEach(TOFMonitoring.allCases) { Text($0.rawValue).tag($0) }
            } label: {
                Label("TOF monitoring", systemImage: "bolt.badge.clock")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Additional")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: $monitoring.additional,
                                options: MonitoringPreferences.additionalOptions)
                CustomAgentEditor(custom: $monitoring.customAdditional)
            }
            .padding(.vertical, 4)
            NotesField(label: "Notes", text: $monitoring.notes, minHeight: 60)
        } header: {
            Label("Monitoring", systemImage: "waveform.path.ecg")
        } footer: {
            Text("Standard ASA monitoring (SpO\u{2082}, NIBP, ECG, EtCO\u{2082}, temperature) is always assumed \u{2014} record only what this consultant sets up beyond it. Shared across adult and \(settings.region.paediatric.lowercased()) cases.")
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
