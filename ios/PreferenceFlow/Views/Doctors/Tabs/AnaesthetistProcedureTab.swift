//
//  AnaesthetistProcedureTab.swift
//  PreferenceFlow
//
//  Read-mode tab for one anaesthetist operation card (e.g. "CABG",
//  "Craniotomy", "C-section"): this consultant's monitoring, IV access,
//  airway, lines, infusions and equipment for that specific operation.
//  Printable as its own one-page card via the print button — the anaesthetic
//  parallel of the surgeon operation tab.
//

import SwiftUI

/// Read-only view of a single anaesthetist operation preference card.
struct AnaesthetistProcedureTab: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor
    let procedure: ProcedureTemplate
    /// Hospital used for the printed card's context (resolved by parent).
    var hospitalID: UUID? = nil

    @State private var editing = false
    @State private var sharePayload: SharePayload?
    @State private var printError: String?

    private var hospital: Hospital? {
        store.hospital(id: hospitalID ?? doctor.hospitalId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !procedure.specialNotes.isBlank {
                    procedureNotesCallout
                }
                if !procedure.timeline.isEmpty {
                    timelineCard
                }
                monitoringCard
                ivAccessCard
                setupCard
                if !procedure.equipmentChecklist.isEmpty {
                    checklistCard
                }
                SafetyBanner()
            }
            .padding(16)
        }
        .sheet(isPresented: $editing) {
            ProcedureEditView(doctor: doctor, procedure: procedure)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
        }
        .alert("Print Failed", isPresented: .constant(printError != nil)) {
            Button("OK") { printError = nil }
        } message: {
            Text(printError ?? "")
        }
        .sensoryFeedback(.success, trigger: sharePayload?.id) { _, newValue in newValue != nil }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.cornerMedium, style: .continuous)
                        .fill(Theme.accent.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "cross.case.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(procedure.displayName)
                        .font(.title2.weight(.bold))
                    Text("\(doctor.displayName) · operation card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        if !procedure.typicalStartTime.isBlank {
                            Label(procedure.typicalStartTime, systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if !procedure.typicalLocation.isBlank {
                            Label(procedure.typicalLocation, systemImage: "mappin")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    printProcedure()
                } label: {
                    Label("Print This Operation", systemImage: "printer.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    editing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemFill), in: .capsule)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 16)
    }

    /// The operation-specific notes surfaced first — usually the "have X ready
    /// before induction" detail a technician needs most.
    private var procedureNotesCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text("FOR THIS OPERATION")
                    .font(.caption2.weight(.bold)).tracking(0.6)
                    .foregroundStyle(.orange)
                Text(procedure.specialNotes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.orange.opacity(0.10), in: .rect(cornerRadius: Theme.cornerMedium))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.orange)
                .frame(width: 4)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Sections

    private var timelineCard: some View {
        DetailSection(title: "Preparation Timeline", icon: "timeline.selection") {
            VStack(spacing: 0) {
                ForEach(Array(procedure.timeline.enumerated()), id: \.element.id) { index, entry in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(Theme.accent).frame(width: 10, height: 10)
                            if index < procedure.timeline.count - 1 {
                                Rectangle().fill(Theme.accent.opacity(0.3)).frame(width: 2)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if !entry.time.isBlank {
                                Text(entry.time).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
                            }
                            Text(entry.event).font(.subheadline)
                        }
                        .padding(.bottom, 14)
                        Spacer()
                    }
                }
            }
        }
    }

    private var monitoringCard: some View {
        DetailSection(title: "Monitoring", icon: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 10) {
                if !procedure.monitoring.isEmpty {
                    PrefChecklist(
                        items: procedure.monitoring.map { $0.rawValue }.sorted(),
                        tint: PrefGroup.monitoring.tint
                    )
                } else {
                    incompleteNudge("No monitoring recorded for this operation")
                }
                CardEditButton(title: "Monitoring") { editing = true }
            }
        }
    }

    private var ivAccessCard: some View {
        DetailSection(title: "IV Access", icon: "syringe") {
            VStack(alignment: .leading, spacing: 10) {
                if hasIVContent {
                    VStack(spacing: 8) {
                        PrefRow(label: "Number", value: procedure.ivCount)
                        PrefRow(label: "Size", value: procedure.ivSize)
                        PrefRow(label: "Location", value: procedure.ivLocation)
                    }
                } else {
                    incompleteNudge("No IV access recorded for this operation")
                }
                CardEditButton(title: "IV Access") { editing = true }
            }
        }
    }

    private var hasIVContent: Bool {
        !(procedure.ivCount.isBlank && procedure.ivSize.isBlank && procedure.ivLocation.isBlank)
    }

    private var setupCard: some View {
        DetailSection(title: "Airway, Lines & Infusions", icon: "lungs.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if hasSetupContent {
                    if !procedure.airwayNotes.isBlank {
                        PrefNote(label: "Airway", text: procedure.airwayNotes, tint: PrefGroup.technique.tint)
                    }
                    if !procedure.lineSetup.isBlank {
                        PrefNote(label: "Line setup", text: procedure.lineSetup, tint: PrefGroup.technique.tint)
                    }
                    if !procedure.infusions.isBlank {
                        PrefNote(label: "Infusions", text: procedure.infusions, tint: PrefGroup.technique.tint)
                    }
                } else {
                    incompleteNudge("No airway, line or infusion setup recorded")
                }
                CardEditButton(title: "Airway, Lines & Infusions") { editing = true }
            }
        }
    }

    private var hasSetupContent: Bool {
        !(procedure.airwayNotes.isBlank && procedure.lineSetup.isBlank && procedure.infusions.isBlank)
    }

    private var checklistCard: some View {
        DetailSection(title: "Equipment Checklist", icon: "checklist") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(procedure.equipmentChecklist) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
                            Text(item.text).font(.subheadline)
                            Spacer()
                        }
                    }
                }
                CardEditButton(title: "Equipment Checklist") { editing = true }
            }
        }
    }

    // MARK: - Building blocks

    private func incompleteNudge(_ text: String) -> some View {
        Button { editing = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text("\(text) — tap to add")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accentDeep)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func printProcedure() {
        do {
            let url = try AnaesthetistProcedurePDF.writeFile(
                procedure: procedure,
                doctor: doctor,
                hospital: hospital
            )
            sharePayload = SharePayload(url: url)
        } catch {
            printError = error.localizedDescription
        }
    }
}
