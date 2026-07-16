//
//  SurgeonProcedureTab.swift
//  PreferenceFlow
//
//  Read-mode tab for one surgeon operation card (e.g. "Lap Cholecystectomy"):
//  the exact trays, sutures, energy settings, positioning and notes this
//  surgeon wants for this specific operation. Printable as its own one-page
//  card via the print button.
//

import SwiftUI

/// Read-only view of a single surgeon procedure preference card.
struct SurgeonProcedureTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor
    let procedure: SurgeonProcedure
    /// Hospital used for context (resolved by parent).
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
                if !procedure.notes.isBlank {
                    procedureNotesCallout
                }
                positioningCard
                traysCard
                suturesCard
                energyCard
                SafetyBanner()
            }
            .padding(16)
        }
        .sheet(isPresented: $editing) {
            SurgeonProcedureEditView(doctor: doctor, procedure: procedure, isNew: false)
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
                        .fill(Color(hex: "2E7DD1").opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "cross.case.fill")
                        .font(.title3)
                        .foregroundStyle(Color(hex: "2E7DD1"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(procedure.displayName)
                        .font(.title2.weight(.bold))
                    Text("\(doctor.displayName) · procedure card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    printProcedure()
                } label: {
                    Label("Print This Procedure", systemImage: "printer.fill")
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

    /// The operation-specific notes surfaced first — this is usually the "have
    /// X ready before knife to skin" detail a scrub nurse needs most.
    private var procedureNotesCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text("FOR THIS OPERATION")
                    .font(.caption2.weight(.bold)).tracking(0.6)
                    .foregroundStyle(.orange)
                Text(procedure.notes)
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

    private var positioningCard: some View {
        DetailSection(title: "Positioning & Prep", icon: "bed.double.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if procedure.positioning.hasContent {
                    VStack(spacing: 8) {
                        PrefRow(label: "Position", value: procedure.positioning.patientPosition)
                        PrefRow(label: "Prep", value: procedure.positioning.prepSolution)
                        PrefRow(label: "Draping", value: procedure.positioning.drapingStyle)
                        PrefRow(label: "Catheter", value: procedure.positioning.catheter)
                    }
                    ChipValueRow(label: "Table setup", values: procedure.positioning.tableAttachments)
                    notesLine(procedure.positioning.notes)
                    if let photo = procedure.positioning.setupPhoto {
                        SetupPhotoDisplay(data: photo, caption: "Positioning photo")
                    }
                } else {
                    incompleteNudge("No positioning recorded for this operation")
                }
                CardEditButton(title: "Positioning & Prep") { editing = true }
            }
        }
    }

    private var traysCard: some View {
        DetailSection(title: "Trays & Instruments", icon: "tray.2.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if procedure.trays.hasContent {
                    ChipValueRow(label: "Open", values: procedure.trays.traysToOpen)
                    ChipValueRow(label: "Extras", values: procedure.trays.favouriteExtras)
                    ChipValueRow(label: "Available unopened", values: procedure.trays.haveAvailableUnopened, accent: false)
                    notesLine(procedure.trays.notes)
                    if let photo = procedure.trays.setupPhoto {
                        SetupPhotoDisplay(data: photo, caption: "Back-table photo")
                    }
                } else {
                    incompleteNudge("No trays recorded for this operation")
                }
                CardEditButton(title: "Trays & Instruments") { editing = true }
            }
        }
    }

    private var suturesCard: some View {
        DetailSection(title: "Sutures & Closure", icon: "bandage.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if procedure.sutures.hasContent {
                    VStack(spacing: 8) {
                        PrefRow(label: "Fascia / deep", value: procedure.sutures.fascia)
                        PrefRow(label: "Subcutaneous", value: procedure.sutures.subcutaneous)
                        PrefRow(label: "Skin", value: procedure.sutures.skin)
                    }
                    ChipValueRow(label: "Staplers & loads", values: procedure.sutures.staplers)
                    ChipValueRow(label: "Drains", values: procedure.sutures.drains)
                    ChipValueRow(label: "Dressings", values: procedure.sutures.dressings, accent: false)
                    notesLine(procedure.sutures.notes)
                } else {
                    incompleteNudge("No closure preferences recorded for this operation")
                }
                CardEditButton(title: "Sutures & Closure") { editing = true }
            }
        }
    }

    private var energyCard: some View {
        DetailSection(title: "Energy & Equipment", icon: "bolt.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if procedure.energy.hasContent {
                    VStack(spacing: 8) {
                        PrefRow(label: "Diathermy", value: procedure.energy.diathermyDisplay)
                        PrefRow(label: "Tourniquet", value: tourniquetSummary)
                        PrefRow(label: "Irrigation", value: procedure.energy.irrigation)
                    }
                    ChipValueRow(label: "Energy devices", values: procedure.energy.energyDevices)
                    ChipValueRow(label: "Imaging & equipment", values: procedure.energy.imaging, accent: false)
                    notesLine(procedure.energy.notes)
                } else {
                    incompleteNudge("No energy settings recorded for this operation")
                }
                CardEditButton(title: "Energy & Equipment") { editing = true }
            }
        }
    }

    private var tourniquetSummary: String {
        [procedure.energy.tourniquetPressure, procedure.energy.tourniquetNotes]
            .filter { !$0.isBlank }
            .joined(separator: " · ")
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func notesLine(_ text: String) -> some View {
        if !text.isBlank {
            PrefNote(label: "Notes", text: text, tint: PrefGroup.equipment.tint)
        }
    }

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
            let url = try SurgeonProcedurePDF.writeFile(
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
