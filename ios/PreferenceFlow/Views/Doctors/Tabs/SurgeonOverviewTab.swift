//
//  SurgeonOverviewTab.swift
//  PreferenceFlow
//
//  The surgeon **Card view** — the read-only, single scrollable page mirroring
//  a traditional laminated surgeon preference card. Order, top to bottom:
//  identity header, specialty setups, important notes, Gloves & Personal,
//  Trays & Instruments, Sutures & Closure, Energy & Equipment, Positioning &
//  Prep — then additional notes, reference photo and the safety banner.
//

import SwiftUI
import UIKit

/// Read-only surgeon preference card. The tabbed editor (toolbar "Edit")
/// remains the place to change data — every box carries an edit affordance
/// routing to its edit tab, matching the anaesthetic Overview card.
struct SurgeonOverviewTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor
    /// Switches the parent profile to another section tab (used by the editor).
    var onNavigate: (ProfileTab) -> Void = { _ in }
    /// Selects a specialty setup's dedicated read-mode tab from the chip shortcuts.
    var onSelectSpecialty: (SpecialtySetup) -> Void = { _ in }
    /// Hospital used for context (resolved by parent).
    var hospitalID: UUID? = nil
    /// True when the profile is in Edit Mode (hides the inline Edit shortcut).
    var editMode: Bool = false

    @State private var editingSpecialty: SpecialtySetup?
    @State private var addingSpecialty = false
    @State private var viewingReferencePhoto = false

    private var hospital: Hospital? {
        store.hospital(id: hospitalID ?? doctor.hospitalId)
    }

    private var s: SurgicalPreferences { doctor.surgicalPreferences }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                specialtySection
                setupSection
                referencePhotoSection
                SafetyBanner()
            }
            .padding(16)
        }
        .sheet(isPresented: $addingSpecialty) {
            SpecialtySetupEditView(doctor: doctor, setup: SpecialtySetup(specialty: nextSpecialty), isNew: true)
        }
        .sheet(item: $editingSpecialty) { setup in
            SpecialtySetupEditView(doctor: doctor, setup: setup, isNew: false)
        }
        .fullScreenCover(isPresented: $viewingReferencePhoto) {
            if let data = doctor.referencePhotoData, let image = UIImage(data: data) {
                SurgeonReferencePhotoViewer(image: image)
            }
        }
    }

    // MARK: - 1. Header

    /// The surgeon's primary specialty colour for the avatar ring.
    private var ringColor: Color {
        doctor.subspecialties.first { $0 != .generalSurgery }?.color
            ?? doctor.subspecialties.first?.color
            ?? Theme.accent
    }

    private var hero: some View {
        VStack(spacing: 14) {
            DoctorAvatar(doctor: doctor, size: 96)
                .overlay(
                    Circle().stroke(ringColor.opacity(0.35), lineWidth: 4)
                        .frame(width: 108, height: 108)
                )
            VStack(spacing: 6) {
                Text(doctor.displayName).font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                if !doctor.role.isBlank {
                    Text(doctor.role).font(.subheadline).foregroundStyle(.secondary)
                }
                if let hospital {
                    Label(hospital.name, systemImage: "building.2.fill")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.12), in: .capsule)
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.top, 2)
                }
                Text("Last updated \(doctor.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                SourceBadge(doctor: doctor)
                    .padding(.top, 4)
            }
            if !editMode {
                Button {
                    onNavigate(.details)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: .capsule)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if !doctor.subspecialties.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(doctor.subspecialties) { SpecialtyBadge(specialty: $0) }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - 2. Specialty setups

    private var activeSpecialties: [SpecialtySetup] { doctor.activeSpecialtySetups }

    private var specialtySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Specialty Setups", icon: "square.grid.2x2.fill")
            if activeSpecialties.isEmpty {
                Button { addingSpecialty = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add a specialty setup (e.g. Cath Lab, Endoscopy)")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(activeSpecialties) { setup in
                    Button { onSelectSpecialty(setup) } label: {
                        SpecialtySetupCard(setup: setup)
                    }
                    .buttonStyle(.plain)
                }
                Button { addingSpecialty = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill), in: .capsule)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Setup section

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !importantNotes.isEmpty {
                SurgeonImportantNotesCallout(notes: importantNotes)
            }
            glovesCard
            traysCard
            suturesCard
            energyCard
            positioningCard
            if hasAdditional {
                additionalCard
            }
        }
    }

    // MARK: - Gloves & Personal

    private var glovesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Gloves & Personal", icon: "hand.raised.fill")
            VStack(spacing: 8) {
                ValueRow(label: "Gloves", value: s.gloves.gloveDisplay, icon: "hand.raised.fill")
                ValueRow(label: "Gown", value: s.gloves.gownPreference, icon: "tshirt")
                ValueRow(label: "Wearables", value: wearablesSummary, icon: "eyeglasses")
                ValueRow(label: "Music", value: s.gloves.musicPreference, icon: "music.note")
                if !s.gloves.hasContent {
                    SurgeonIncompleteNudge(text: "Incomplete — tap to add gloves & personal preferences") { onNavigate(.gloves) }
                }
                CardEditButton(title: "Gloves & Personal") { onNavigate(.gloves) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
            if !s.gloves.communicationStyle.isBlank {
                PrefCollapsibleCard(
                    group: .workflow,
                    title: "Communication",
                    icon: "bubble.left.and.bubble.right.fill",
                    collapsedSummary: s.gloves.communicationStyle,
                    onEdit: { onNavigate(.gloves) }
                ) {
                    PrefNote(label: "", text: s.gloves.communicationStyle, tint: PrefGroup.workflow.tint)
                }
            }
            if !s.gloves.notes.isBlank {
                PrefCollapsibleCard(
                    group: .consultantNotes,
                    collapsedSummary: s.gloves.notes,
                    onEdit: { onNavigate(.gloves) }
                ) {
                    PrefNote(label: "", text: s.gloves.notes, tint: PrefGroup.consultantNotes.tint)
                }
            }
        }
    }

    private var wearablesSummary: String {
        var parts: [String] = []
        if s.gloves.wearsLoupes { parts.append("Loupes") }
        if s.gloves.wearsHeadlight { parts.append("Headlight") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Trays & Instruments

    private var traysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSection(title: "Trays & Instruments", icon: "tray.2.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    if s.trays.hasContent {
                        ChipValueRow(label: "Open", values: s.trays.traysToOpen)
                        ChipValueRow(label: "Favourite extras", values: s.trays.favouriteExtras)
                        ChipValueRow(label: "Available unopened", values: s.trays.haveAvailableUnopened, accent: false)
                        if let photo = s.trays.setupPhoto {
                            SetupPhotoDisplay(data: photo, caption: "Back-table photo")
                        }
                    } else {
                        SurgeonIncompleteNudge(text: "Incomplete — tap to add trays & instruments") { onNavigate(.trays) }
                    }
                    CardEditButton(title: "Trays & Instruments") { onNavigate(.trays) }
                }
            }
            if !s.trays.notes.isBlank {
                PrefCollapsibleCard(
                    group: .equipment,
                    title: "Instrument Notes",
                    icon: "note.text",
                    collapsedSummary: s.trays.notes,
                    onEdit: { onNavigate(.trays) }
                ) {
                    PrefNote(label: "", text: s.trays.notes, tint: PrefGroup.equipment.tint)
                }
            }
        }
    }

    // MARK: - Sutures & Closure

    private var suturesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSection(title: "Sutures & Closure", icon: "bandage.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    if s.sutures.hasContent {
                        VStack(spacing: 8) {
                            PrefRow(label: "Fascia / deep", value: s.sutures.fascia)
                            PrefRow(label: "Subcutaneous", value: s.sutures.subcutaneous)
                            PrefRow(label: "Skin", value: s.sutures.skin)
                        }
                        ChipValueRow(label: "Staplers & loads", values: s.sutures.staplers)
                        ChipValueRow(label: "Drains", values: s.sutures.drains)
                        ChipValueRow(label: "Dressings", values: s.sutures.dressings, accent: false)
                    } else {
                        SurgeonIncompleteNudge(text: "Incomplete — tap to add sutures & closure") { onNavigate(.sutures) }
                    }
                    CardEditButton(title: "Sutures & Closure") { onNavigate(.sutures) }
                }
            }
            if !s.sutures.notes.isBlank {
                PrefCollapsibleCard(
                    group: .technique,
                    title: "Closure Notes",
                    icon: "note.text",
                    collapsedSummary: s.sutures.notes,
                    onEdit: { onNavigate(.sutures) }
                ) {
                    PrefNote(label: "", text: s.sutures.notes, tint: PrefGroup.technique.tint)
                }
            }
        }
    }

    // MARK: - Energy & Equipment

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSection(title: "Energy & Equipment", icon: "bolt.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    if s.energy.hasContent {
                        VStack(spacing: 8) {
                            PrefRow(label: "Diathermy", value: s.energy.diathermyDisplay)
                            PrefRow(label: "Tourniquet", value: tourniquetSummary)
                            PrefRow(label: "Irrigation", value: s.energy.irrigation)
                        }
                        ChipValueRow(label: "Energy devices", values: s.energy.energyDevices)
                        ChipValueRow(label: "Imaging & equipment", values: s.energy.imaging, accent: false)
                    } else {
                        SurgeonIncompleteNudge(text: "Incomplete — tap to add energy & equipment") { onNavigate(.energy) }
                    }
                    CardEditButton(title: "Energy & Equipment") { onNavigate(.energy) }
                }
            }
            if !s.energy.notes.isBlank {
                PrefCollapsibleCard(
                    group: .equipment,
                    title: "Equipment Notes",
                    icon: "note.text",
                    collapsedSummary: s.energy.notes,
                    onEdit: { onNavigate(.energy) }
                ) {
                    PrefNote(label: "", text: s.energy.notes, tint: PrefGroup.equipment.tint)
                }
            }
        }
    }

    private var tourniquetSummary: String {
        [s.energy.tourniquetPressure, s.energy.tourniquetNotes]
            .filter { !$0.isBlank }
            .joined(separator: " · ")
    }

    // MARK: - Positioning & Prep

    private var positioningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSection(title: "Positioning & Prep", icon: "bed.double.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    if s.positioning.hasContent {
                        VStack(spacing: 8) {
                            PrefRow(label: "Position", value: s.positioning.patientPosition)
                            PrefRow(label: "Prep", value: s.positioning.prepSolution)
                            PrefRow(label: "Draping", value: s.positioning.drapingStyle)
                            PrefRow(label: "Catheter", value: s.positioning.catheter)
                        }
                        ChipValueRow(label: "Table setup", values: s.positioning.tableAttachments)
                        if let photo = s.positioning.setupPhoto {
                            SetupPhotoDisplay(data: photo, caption: "Positioning photo")
                        }
                    } else {
                        SurgeonIncompleteNudge(text: "Incomplete — tap to add positioning & prep") { onNavigate(.positioning) }
                    }
                    CardEditButton(title: "Positioning & Prep") { onNavigate(.positioning) }
                }
            }
            if !s.positioning.notes.isBlank {
                PrefCollapsibleCard(
                    group: .workflow,
                    title: "Positioning Notes",
                    icon: "note.text",
                    collapsedSummary: s.positioning.notes,
                    onEdit: { onNavigate(.positioning) }
                ) {
                    PrefNote(label: "", text: s.positioning.notes, tint: PrefGroup.workflow.tint)
                }
            }
        }
    }

    // MARK: - Additional

    private var specialInterests: [String] {
        doctor.subspecialties.filter { $0 != .generalSurgery }.map { $0.rawValue }
    }

    private var hasAdditional: Bool {
        !specialInterests.isEmpty || !doctor.biography.isBlank
    }

    private var additionalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Additional Notes", icon: "cross.case.fill")
            VStack(alignment: .leading, spacing: 12) {
                ChipValueRow(label: "Special interests", values: specialInterests)
                PrefNote(label: "Notes", text: doctor.biography, tint: PrefGroup.consultantNotes.tint)
            }
            .card()
        }
    }

    /// The free-text a nurse most needs to see first, surfaced as a single
    /// highlighted callout above the setup cards.
    private var importantNotes: [String] {
        var notes: [String] = []
        if !doctor.personalNotes.isBlank { notes.append(doctor.personalNotes) }
        return notes
    }

    // MARK: - Reference photo

    @ViewBuilder
    private var referencePhotoSection: some View {
        if let data = doctor.referencePhotoData, let image = UIImage(data: data) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Reference Photo", icon: "photo")
                Button { viewingReferencePhoto = true } label: {
                    Color(.secondarySystemGroupedBackground)
                        .frame(height: 220)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: Theme.cornerLarge))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.45), in: .circle)
                                .padding(10)
                        }
                }
                .buttonStyle(.plain)
                Text("Photo of the physical preference card — reference only.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A sensible default specialty for a new surgical setup (first not already used).
    private var nextSpecialty: Subspecialty {
        let used = Set((doctor.specialtySetups ?? []).map { $0.specialty })
        let order: [Subspecialty] = [
            .generalSurgery, .orthopaedics, .cathLab, .endoscopy,
            .cardiothoracic, .urology, .gynaecology, .vascular
        ]
        return order.first { !used.contains($0) } ?? .other
    }
}

// MARK: - Building blocks

/// A clearly highlighted callout for the surgeon's most important notes.
private struct SurgeonImportantNotesCallout: View {
    let notes: [String]
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text("IMPORTANT")
                    .font(.caption2.weight(.bold)).tracking(0.6)
                    .foregroundStyle(.orange)
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
}

/// A tappable "Incomplete — tap to add" nudge routing to the relevant editor.
private struct SurgeonIncompleteNudge: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text(text)
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
}

/// A full-screen viewer for the reference card photo.
private struct SurgeonReferencePhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: .circle)
            }
            .padding(16)
        }
    }
}
