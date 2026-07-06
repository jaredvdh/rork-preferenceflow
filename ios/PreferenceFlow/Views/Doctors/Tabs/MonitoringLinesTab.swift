//
//  MonitoringLinesTab.swift
//  PreferenceFlow
//
//  One coherent edit surface for everything related to monitoring and invasive
//  access: ECG leads, depth of anaesthesia, TOF, BP cuff, additional monitoring
//  and notes — followed by the Arterial Line and Central Line workflow
//  preferences, which reuse the same guided editor as the Overview card.
//

import SwiftUI

/// Monitoring & Lines — a direct inline editor, only reachable from Edit mode.
/// The read presentation stays on the Overview card (Monitoring card and the
/// "Arterial & Central Lines" section).
struct MonitoringLinesTab: View {
    let doctor: Doctor

    /// The procedural workflow (Arterial Line, CVC) being created or edited in
    /// the guided workflow sheet — the exact editor the Overview card presents,
    /// not a second one.
    @State private var editingProcedural: WorkflowDefinition?

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            Form {
                MonitoringFormSection(monitoring: monitoringBinding($draft))
                linesSection
                Section {
                } footer: {
                    InlineEditFooter()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            // The workflow sheet saves straight to the store. Fold that change
            // into the session draft immediately so a later monitoring autosave
            // can't overwrite the just-saved arterial line / CVC with a stale
            // copy of the profile.
            .onChange(of: doctor.procedural) { _, newValue in
                draft.procedural = newValue
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $editingProcedural) { definition in
            WorkflowGuideView(
                doctorID: doctor.id,
                definition: definition,
                existing: doctor.proceduralPreferences.customization(for: definition.id)
            )
        }
    }

    /// Binds the doctor-level monitoring preferences on the session draft,
    /// materialising the optional on first edit.
    private func monitoringBinding(_ draft: Binding<Doctor>) -> Binding<MonitoringPreferences> {
        Binding(
            get: { draft.wrappedValue.monitoring ?? MonitoringPreferences() },
            set: { draft.wrappedValue.monitoring = $0 }
        )
    }

    // MARK: - Arterial & Central Lines

    private var configuredProcedural: [ConfiguredProcedural] {
        ProceduralSummary.configured(doctor.proceduralPreferences)
    }

    /// Configured workflows render as tappable summary rows with an Edit
    /// action; unconfigured ones get a "+ Add" entry point — mirroring the
    /// Overview card's pattern so both paths lead into `WorkflowGuideView`.
    private var linesSection: some View {
        Section {
            ForEach(WorkflowLibrary.procedural) { definition in
                proceduralRow(definition)
            }
        } header: {
            Label("Arterial & Central Lines", systemImage: "waveform.path.ecg")
        } footer: {
            Text("Guided setup for invasive lines — site, cannula, technique, positioning and an optional setup photo. Grouped here with monitoring because they're set up together.")
        }
    }

    @ViewBuilder
    private func proceduralRow(_ definition: WorkflowDefinition) -> some View {
        if let item = configuredProcedural.first(where: { $0.definition.id == definition.id }) {
            Button { editingProcedural = definition } label: {
                HStack(spacing: 12) {
                    Image(systemName: definition.icon)
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(definition.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(ProceduralSummary.collapsedSummary(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text("Edit")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } else {
            Button { editingProcedural = definition } label: {
                Label("Add \(proceduralShortTitle(definition)) preferences", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    /// Friendly short names for the add buttons ("Central Venous Catheter" →
    /// "Central Line") — matching the Overview card's wording.
    private func proceduralShortTitle(_ definition: WorkflowDefinition) -> String {
        definition.id == "cvc" ? "Central Line" : definition.title
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
            Picker(selection: $monitoring.bpCuffPlacement) {
                ForEach(BPCuffPlacement.allCases) { Text($0.rawValue).tag($0) }
            } label: {
                Label("BP cuff placement", systemImage: "gauge.with.needle")
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
