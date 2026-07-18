//
//  OverviewTab.swift
//  PreferenceFlow
//

import SwiftUI
import UIKit

/// The consultant **Card view** — the read-only, single scrollable page that
/// mirrors a traditional laminated theatre preference card. It is the default
/// when opening a profile to look something up; the tabbed editor (reached via
/// the toolbar "Edit") remains the place to change data.
///
/// Order, top to bottom: identity header, prominent specialty chips, important
/// notes callout, General, Airway, Drugs, Monitoring, Additional equipment &
/// notes — then hospital links, knowledge and the safety banner.
struct OverviewTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor
    /// Switches the parent profile to another section tab (used by the editor).
    var onNavigate: (ProfileTab) -> Void = { _ in }
    /// Selects a specialty setup's dedicated read-mode tab from the chip shortcuts.
    var onSelectSpecialty: (SpecialtySetup) -> Void = { _ in }
    /// Opens an operation card's dedicated read-mode tab.
    var onSelectProcedure: (ProcedureTemplate) -> Void = { _ in }
    /// Hospital used for the Hospital Information quick links (resolved by parent).
    var hospitalID: UUID? = nil
    /// True when the profile is in Edit Mode (unused by the read-only card).
    var editMode: Bool = false
    /// Department standard this consultant inherits from (reserved for future use).
    var template: DepartmentTemplate? = nil

    @State private var editingSpecialty: SpecialtySetup?
    @State private var addingSpecialty = false
    @State private var viewingReferencePhoto = false
    /// The procedural workflow (Arterial Line, CVC) being created or edited via
    /// the guided workflow editor.
    @State private var addingProcedural: WorkflowDefinition?
    /// The neuraxial workflow (Spinal, Epidural, CSE) being edited in place from
    /// its expandable row — routes to the same guided editor the Neuraxial tab uses.
    @State private var editingNeuraxial: WorkflowDefinition?
    /// The regional block being edited in place from its expandable row — routes
    /// to the same structured editor the Regional tab uses.
    @State private var editingBlock: RegionalBlock?

    private var hospital: Hospital? {
        store.hospital(id: hospitalID ?? doctor.hospitalId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                operationsSection
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
        .sheet(item: $addingProcedural) { definition in
            WorkflowGuideView(
                doctorID: doctor.id,
                definition: definition,
                existing: doctor.proceduralPreferences.customization(for: definition.id)
            )
        }
        .sheet(item: $editingNeuraxial) { definition in
            WorkflowGuideView(
                doctorID: doctor.id,
                definition: definition,
                existing: doctor.neuraxial.customization(for: definition.id)
            )
        }
        .sheet(item: $editingBlock) { block in
            RegionalBlockEditView(doctor: doctor, block: block)
        }
        .fullScreenCover(isPresented: $viewingReferencePhoto) {
            if let data = doctor.referencePhotoData, let image = UIImage(data: data) {
                ReferencePhotoViewer(image: image)
            }
        }
    }

    // MARK: - 1. Header

    /// The consultant's primary specialty colour, used for the avatar ring so a
    /// cardiac consultant reads differently from a paediatric one at a glance.
    private var ringColor: Color {
        doctor.subspecialties.first { $0 != .general }?.color
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

    // MARK: - 2. Operation cards

    /// Per-operation anaesthetic setups (e.g. CABG, Craniotomy, C-section) —
    /// each opens its own read tab and prints as a separate one-page card,
    /// mirroring the surgeon operation cards.
    private var operationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Operations", icon: "cross.case.fill")
            if doctor.operations.isEmpty {
                Button { onNavigate(.procedures) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add operation cards (e.g. CABG, Craniotomy, C-section)")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(doctor.operations) { procedure in
                    Button { onSelectProcedure(procedure) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cross.case.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "2E7DD1"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(procedure.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if !procedure.summaryLine.isEmpty {
                                    Text(procedure.summaryLine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(hex: "2E7DD1").opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
                    }
                    .buttonStyle(.plain)
                }
                Button { onNavigate(.procedures) } label: {
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

    // MARK: - 3. Specialty setups (prominent tappable chips)

    private var activeSpecialties: [SpecialtySetup] { doctor.activeSpecialtySetups }

    private var specialtySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Specialty Setups", icon: "square.grid.2x2.fill")
            if activeSpecialties.isEmpty {
                Button { addingSpecialty = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add a specialty setup (e.g. Cardiac, Paediatric)")
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

    // MARK: - Setup section (3–8)

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 3. Important notes callout at the very top of the setup section.
            if !importantNotes.isEmpty {
                ImportantNotesCallout(notes: importantNotes)
            }
            generalCard       // 4
            AirwayCardSection(doctor: doctor, onNavigate: onNavigate)  // 5
            drugsCard         // 6
            monitoringCard    // 7
            proceduralCard    // 8 — always present: configured rows and/or "+ Add" buttons
            if hasAdditional {
                additionalCard // 9
            }
        }
    }

    // 4. General — the four most-used fields are always visible; everything else
    // the editor knows about expands in place below, so a technician never has to
    // switch to the General tab to read a field that has a value.
    private var g: GeneralPreferences { doctor.general }

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("General", icon: "person.text.rectangle.fill")
            VStack(spacing: 8) {
                ValueRow(label: "Sterile gloves", value: g.sterileGloveDisplay, icon: "hand.raised.fill")
                ValueRow(label: "Non-sterile gloves", value: g.nonSterileGloveDisplay, icon: "hand.raised")
                ValueRow(label: "Gown size", value: g.gownSize, icon: "tshirt")
                ValueRow(label: "Coffee", value: g.coffeePreference, icon: "cup.and.saucer")
                if isGeneralEmpty {
                    IncompleteNudge(text: "Incomplete — tap to add general preferences") { onNavigate(.general) }
                }
                CardEditButton(title: "General") { onNavigate(.general) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
            generalMoreDetail
        }
    }

    /// Expandable cards revealing every remaining General field that has a value:
    /// theatre setup extras, personal touches, workflow expectations, contact
    /// preferences and general notes. Each card renders only when it has content.
    @ViewBuilder
    private var generalMoreDetail: some View {
        if hasGeneralTheatreExtras {
            PrefCollapsibleCard(
                group: .equipment,
                title: "Theatre Setup",
                icon: "tshirt.fill",
                collapsedSummary: [g.maskPreference, g.theatreShoeSize, g.roomTemperature]
                    .filter { !$0.isBlank }.prefix(2).joined(separator: " • "),
                onEdit: { onNavigate(.general) }
            ) {
                PrefRow(label: "Mask", value: g.maskPreference)
                PrefRow(label: "Shoe size", value: g.theatreShoeSize)
                PrefRow(label: "Room temp", value: g.roomTemperature)
            }
        }
        if hasGeneralPersonalExtras {
            PrefCollapsibleCard(
                group: .personal,
                title: "Personal",
                collapsedSummary: [g.teaPreference, g.favouriteSnacks]
                    .filter { !$0.isBlank }.joined(separator: " • "),
                onEdit: { onNavigate(.general) }
            ) {
                PrefRow(label: "Tea", value: g.teaPreference)
                PrefRow(label: "Snacks", value: g.favouriteSnacks)
            }
        }
        if hasGeneralWorkflow {
            PrefCollapsibleCard(
                group: .workflow,
                title: "Workflow",
                collapsedSummary: (generalWorkflowFlags + [g.briefingStyle.isBlank ? "" : "Briefing"])
                    .filter { !$0.isEmpty }.prefix(2).joined(separator: " • "),
                onEdit: { onNavigate(.general) }
            ) {
                if !generalWorkflowFlags.isEmpty {
                    PrefChecklist(items: generalWorkflowFlags, tint: PrefGroup.workflow.tint)
                }
                PrefNote(label: "Briefing style", text: g.briefingStyle, tint: PrefGroup.workflow.tint)
            }
        }
        if !g.contactPreferences.isBlank {
            PrefCollapsibleCard(
                group: .monitoring,
                title: "Communication",
                icon: "bubble.left.and.bubble.right.fill",
                collapsedSummary: g.contactPreferences,
                onEdit: { onNavigate(.general) }
            ) {
                PrefNote(label: "", text: g.contactPreferences, tint: PrefGroup.monitoring.tint)
            }
        }
        if !g.generalNotes.isBlank {
            PrefCollapsibleCard(
                group: .consultantNotes,
                collapsedSummary: g.generalNotes,
                onEdit: { onNavigate(.general) }
            ) {
                PrefNote(label: "", text: g.generalNotes, tint: PrefGroup.consultantNotes.tint)
            }
        }
    }

    private var generalWorkflowFlags: [String] {
        var out: [String] = []
        if g.arriveBeforePatient { out.append("Arrives before patient") }
        if g.prepareOwnMedications { out.append("Prepares own medications") }
        if g.assistantMayPrepareMedications { out.append("Assistant may prepare meds") }
        return out
    }

    private var hasGeneralTheatreExtras: Bool {
        !(g.maskPreference.isBlank && g.theatreShoeSize.isBlank && g.roomTemperature.isBlank)
    }

    private var hasGeneralPersonalExtras: Bool {
        !(g.teaPreference.isBlank && g.favouriteSnacks.isBlank)
    }

    private var hasGeneralWorkflow: Bool {
        !generalWorkflowFlags.isEmpty || !g.briefingStyle.isBlank
    }

    private var isGeneralEmpty: Bool {
        g.sterileGloveDisplay.isBlank && g.nonSterileGloveDisplay.isBlank && g.gownSize.isBlank && g.coffeePreference.isBlank
    }

    // 6. Drugs
    private var adultDrugs: DrugsFluidsSetup { doctor.adultDrugs ?? DrugsFluidsSetup() }

    /// The maintenance headline stays visible (it drives equipment setup — TCI
    /// pump vs vaporiser). Routine intraoperative drugs collapse into a single
    /// "Anaesthetic Drugs" group, one tap away. IV Fluids (primary/secondary/
    /// giving set) and Emergency Drugs stay always visible — a technician needs
    /// both at a glance without any interaction.
    private var drugsCard: some View {
        let d = adultDrugs
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Drugs & Fluids", icon: "syringe.fill")
            if d.hasMaintenance {
                MaintenanceHeadline(setup: d, onEdit: { onNavigate(.drugs) })
            }
            if d.hasContent {
                if d.hasRoutineDrugs {
                    AnaestheticDrugsGroup(setup: d, onEdit: { onNavigate(.drugs) })
                }
                if !d.fluids.isEmpty {
                    FluidSetupCard(fluids: d.fluids, onEdit: { onNavigate(.drugs) })
                }
                if !d.emergency.isEmpty {
                    EmergencyDrugsCard(emergency: d.emergency, onEdit: { onNavigate(.drugs) })
                }
                if !d.notes.isBlank {
                    DrugsConsultantNotesCard(notes: d.notes, onEdit: { onNavigate(.drugs) })
                }
            } else {
                VStack(spacing: 8) {
                    IncompleteNudge(text: "Incomplete — tap to add drugs & fluids") { onNavigate(.drugs) }
                }
                .card()
            }
        }
    }

    // 7. Monitoring — the spelled-out ASA baseline alone when nothing extra is
    // configured, or the baseline plus each genuine addition (depth, TOF, BP
    // cuff, extras — 5-lead folds into the baseline line). Consultant notes
    // sit in a tap-to-expand card so they never clutter the checklist. A
    // cross-reference links to any specialty carrying case-specific monitoring
    // so "always applies" vs "applies for this specialty" is explicit.
    private var specialtiesWithCaseMonitoring: [SpecialtySetup] {
        activeSpecialties.filter { !$0.additionalMonitoring.isEmpty }
    }

    private var monitoringCard: some View {
        let m = doctor.monitoringPreferences
        return VStack(alignment: .leading, spacing: 12) {
            DetailSection(title: "Monitoring", icon: "waveform.path.ecg") {
                VStack(alignment: .leading, spacing: 10) {
                    PrefChecklist(items: m.displayItems, tint: PrefGroup.monitoring.tint)
                    ForEach(specialtiesWithCaseMonitoring) { setup in
                        Button { onSelectSpecialty(setup) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2.weight(.semibold))
                                Text("See \(setup.specialty.rawValue) for case-specific monitoring (e.g. cardiac output, additional lines)")
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                    .underline()
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    CardEditButton(title: "Monitoring") { onNavigate(.monitoring) }
                }
            }
            if !m.notes.isBlank {
                PrefCollapsibleCard(
                    group: .monitoring,
                    title: "Monitoring Notes",
                    icon: "note.text",
                    collapsedSummary: m.notes,
                    onEdit: { onNavigate(.monitoring) }
                ) {
                    PrefNote(label: "", text: m.notes, tint: PrefGroup.monitoring.tint)
                }
            }
        }
    }

    // 8. Additional equipment & notes
    private var namedRegionalBlocks: [RegionalBlock] {
        doctor.regionalBlocks.filter { !$0.name.isBlank }
    }

    private var configuredNeuraxial: [ConfiguredNeuraxial] {
        NeuraxialSummary.configured(doctor.neuraxial)
    }

    private var configuredProcedural: [ConfiguredProcedural] {
        ProceduralSummary.configured(doctor.proceduralPreferences)
    }

    /// Procedural workflows (Arterial Line, CVC) not yet configured — each gets
    /// a "+ Add" affordance so preferences can be created from scratch.
    private var unconfiguredProcedural: [WorkflowDefinition] {
        WorkflowLibrary.procedural.filter { !doctor.proceduralPreferences.isConfigured($0.id) }
    }

    private var specialInterests: [String] {
        doctor.subspecialties.filter { $0 != .general }.map { $0.rawValue }
    }

    private var hasAdditional: Bool {
        !namedRegionalBlocks.isEmpty || !configuredNeuraxial.isEmpty
            || !specialInterests.isEmpty || !doctor.biography.isBlank
    }

    /// Procedural workflows (Arterial Line, CVC): configured ones render as
    /// tappable, expand-in-place rows (same inline pattern as Regional and
    /// Neuraxial, with an Edit action inside); unconfigured ones get a "+ Add"
    /// button — the creation entry point — matching the "+ Add" pattern used by
    /// Specialty Setups on this same card.
    private var proceduralCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Arterial & Central Lines", icon: "waveform.path.ecg")
            ForEach(configuredProcedural, id: \.definition.id) { item in
                ProceduralExpandableRow(item: item) {
                    addingProcedural = item.definition
                }
            }
            ForEach(unconfiguredProcedural) { definition in
                Button { addingProcedural = definition } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add \(proceduralShortTitle(definition)) preferences")
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

    /// Friendly short names for the add buttons ("Central Venous Catheter" →
    /// "Central Line").
    private func proceduralShortTitle(_ definition: WorkflowDefinition) -> String {
        definition.id == "cvc" ? "Central Line" : definition.title
    }

    /// Each Regional block and Neuraxial item is a tappable row that expands in
    /// place to reveal the same detail as its dedicated screen, pulled from the
    /// same underlying data source. Multiple rows can be open at once.
    private var additionalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Additional Equipment & Notes", icon: "cross.case.fill")

            if !namedRegionalBlocks.isEmpty {
                subgroupHeader("Regional Blocks")
                ForEach(namedRegionalBlocks) { block in
                    RegionalBlockExpandableRow(block: block) {
                        editingBlock = block
                    }
                }
            }

            if !configuredNeuraxial.isEmpty {
                subgroupHeader("Neuraxial")
                ForEach(configuredNeuraxial, id: \.definition.id) { item in
                    NeuraxialExpandableRow(item: item) {
                        editingNeuraxial = item.definition
                    }
                }
            }

            if !specialInterests.isEmpty || !doctor.biography.isBlank {
                VStack(alignment: .leading, spacing: 12) {
                    ChipValueRow(label: "Special interests", values: specialInterests)
                    PrefNote(label: "Notes", text: doctor.biography, tint: PrefGroup.consultantNotes.tint)
                }
                .card()
            }
        }
    }

    private func subgroupHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(PrefGroup.technique.tint)
            .padding(.top, 2)
    }

    /// The free-text the technician most needs to see first, surfaced as a single
    /// highlighted callout above the setup cards.
    private var importantNotes: [String] {
        var notes: [String] = []
        if !doctor.personalNotes.isBlank { notes.append(doctor.personalNotes) }
        if !doctor.general.generalNotes.isBlank { notes.append(doctor.general.generalNotes) }
        if !adultDrugs.notes.isBlank { notes.append(adultDrugs.notes) }
        return notes
    }

    // MARK: - Reference photo (backup of the physical card)

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
                Text("Photo of the physical theatre card — reference only.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Hospital equipment locations relevant to specialist lists, for the
    /// optional Hospital Information card on a specialty preference card.
    private var specialtyHospitalItems: [PrefHospitalItem] {
        PrefHospital.items(for: hospital, kinds: [
            .belmont, .rapidInfuser, .ultrasound, .bloodFridge,
            .crashCart, .paediatricTrolley, .theatreStores, .anaestheticWorkroom
        ])
    }

    /// A sensible default specialty for a new setup (first not already used).
    private var nextSpecialty: Subspecialty {
        let used = Set((doctor.specialtySetups ?? []).map { $0.specialty })
        let order: [Subspecialty] = [.cardiac, .paediatrics, .neuro, .trauma, .obstetrics, .vascular, .thoracic, .ent]
        return order.first { !used.contains($0) } ?? .other
    }

}

// MARK: - Card building blocks

/// A clearly highlighted callout for the consultant's most important notes,
/// placed at the top of the setup section.
private struct ImportantNotesCallout: View {
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

/// A tappable "Incomplete — tap to add" nudge that guides the technician straight
/// to the relevant editor section instead of leaving an empty card.
private struct IncompleteNudge: View {
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

/// The Airway block on the read-only consultant card. An Adult / Paediatric
/// segmented control switches only this section's display. Adult shows the
/// consultant's fixed adult preferences; Paediatric surfaces the age/weight
/// calculated ETT & supraglottic references plus the consultant's fixed
/// paediatric preferences and a blade-size lookup. The toggle always defaults to
/// Adult on open; the dialled age/weight is remembered for the session.
private struct AirwayCardSection: View {
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor
    var onNavigate: (ProfileTab) -> Void = { _ in }

    @State private var cohort: Cohort = .adult

    enum Cohort: String, CaseIterable, Identifiable {
        case adult, paediatric
        var id: String { rawValue }
    }

    private var a: AirwayPreferences { doctor.airway }

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Airway", icon: "lungs.fill")
            Picker("Cohort", selection: $cohort.animation(.easeInOut(duration: 0.2))) {
                Text("Adult").tag(Cohort.adult)
                Text(settings.region.paediatric).tag(Cohort.paediatric)
            }
            .pickerStyle(.segmented)

            if cohort == .adult {
                adultCard
            } else {
                paediatricContent(patient: $settings.airwayPaedReference)
            }
        }
    }

    // MARK: - Adult

    private var adultCard: some View {
        VStack(spacing: 8) {
            PrefRow(label: "ETT (Male)", value: a.adultMale.tubeSize)
            PrefRow(label: "ETT (Female)", value: a.adultFemale.tubeSize)
            laryngoscopeRows
            PrefRow(label: "Supraglottic", value: sgaSummary)
            PrefRow(label: "Bougie", value: a.adultMale.bougiePreference)
            if isAirwayEmpty {
                IncompleteNudge(text: "Incomplete — tap to add airway setup") { onNavigate(.airway) }
            }
            CardEditButton(title: "Airway") { onNavigate(.airway) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    /// Laryngoscope rows for the card view. Shows one row when male and female
    /// parameters match (or only one is set), and two gender-labelled rows when
    /// they differ so the female value is never silently dropped.
    @ViewBuilder private var laryngoscopeRows: some View {
        let mEmpty = laryngoscopyEmpty(a.adultMale)
        let fEmpty = laryngoscopyEmpty(a.adultFemale)
        let mSummary = laryngoscopySummary(a.adultMale)
        let fSummary = laryngoscopySummary(a.adultFemale)
        if mEmpty && fEmpty {
            PrefRow(label: "Laryngoscope", value: "")
        } else if fEmpty {
            PrefRow(label: "Laryngoscope", value: mSummary)
        } else if mEmpty {
            PrefRow(label: "Laryngoscope", value: fSummary)
        } else if mSummary == fSummary {
            PrefRow(label: "Laryngoscope", value: mSummary)
        } else {
            PrefRow(label: "Laryngoscope (M)", value: mSummary)
            PrefRow(label: "Laryngoscope (F)", value: fSummary)
        }
    }

    private var sgaSummary: String {
        a.supraglottic.summaryChips.joined(separator: ", ")
    }

    private var isAirwayEmpty: Bool {
        a.adultMale.tubeSize.isBlank && a.adultFemale.tubeSize.isBlank
            && sgaSummary.isBlank && a.adultMale.bougiePreference.isBlank
            && a.adultMale.videoSystem == .none && a.adultMale.blade == .none
    }

    // MARK: - Paediatric

    @ViewBuilder
    private func paediatricContent(patient: Binding<PaediatricPatient>) -> some View {
        VStack(spacing: 16) {
            PaediatricPatientCard(patient: patient)
            PaediatricETTCard(
                ageYears: patient.wrappedValue.ageYears,
                cuffedPreference: a.paediatric.cuffedPreference
            )
            PaediatricSupraglotticCard(
                weightKg: patient.wrappedValue.effectiveWeightKg,
                usingActual: patient.wrappedValue.useActualWeight,
                device: primarySupraglottic?.device ?? .none
            )
            if !paedFixedEmpty { paedFixedCard }
            PaediatricBladeCard()
        }
    }

    private var primarySupraglottic: SupraglotticChoice? {
        let s = a.supraglottic
        for choice in [s.adultMale, s.adultFemale, s.largeAdult] where !choice.isEmpty {
            return choice
        }
        return nil
    }

    private var paedFixedEmpty: Bool {
        let s = a.paediatric
        return laryngoscopyEmpty(s) && s.cuffedPreference.isBlank
            && s.tubeSecuring.isBlank && s.notes.isBlank
    }

    private var paedFixedCard: some View {
        DetailSection(title: "Consultant Paediatric Preferences", icon: "stethoscope") {
            PrefRow(label: "Laryngoscopy", value: laryngoscopySummary(a.paediatric))
            PrefRow(label: "Cuff preference", value: a.paediatric.cuffedPreference)
            PrefRow(label: "Securing", value: a.paediatric.tubeSecuring)
            PrefNote(label: "Notes", text: a.paediatric.notes, tint: PrefGroup.technique.tint)
            CardEditButton(title: "Paediatric Airway") { onNavigate(.airway) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Shared helpers

    private func laryngoscopySummary(_ s: AirwaySetup) -> String {
        var parts: [String] = []
        if s.primaryTechnique == .video {
            parts.append(s.videoSystem != .none ? "\(s.videoSystem.rawValue) (video)" : "Video")
        } else {
            parts.append("Direct")
        }
        let blade = bladeValue(s)
        if !blade.isBlank { parts.append(blade) }
        return parts.joined(separator: " · ")
    }

    private func bladeValue(_ s: AirwaySetup) -> String {
        switch s.blade {
        case .macintosh: return s.bladeSize.isBlank ? "" : "Mac \(s.bladeSize)"
        case .miller: return s.bladeSize.isBlank ? "" : "Miller \(s.bladeSize)"
        case .other, .none: return s.bladeSize
        }
    }

    private func laryngoscopyEmpty(_ s: AirwaySetup) -> Bool {
        bladeValue(s).isBlank && s.primaryTechnique != .video
    }
}

/// A full-screen, pinch-to-zoom viewer for the reference card photo.
private struct ReferencePhotoViewer: View {
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

// MARK: - Expandable detail rows (Regional & Neuraxial)

/// The small status pill carried through to a collapsed profile row so a
/// technician can tell at a glance whether a block is the department default or
/// has been customised — without expanding first.
private enum ProfileRowBadge {
    case none
    case updatedByYou

    @ViewBuilder var view: some View {
        switch self {
        case .none: EmptyView()
        case .updatedByYou: PrefBadge("Updated by you", .orange)
        }
    }
}

/// A tappable row that expands in place to reveal full detail. Each row owns its
/// own expansion state, so several can be open simultaneously. Visual language
/// matches the rest of the preference cards (tinted icon tile, chevron, summary).
private struct ExpandableProfileRow<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    var badge: ProfileRowBadge = .none
    let collapsedSummary: String
    @ViewBuilder var content: () -> Content

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                        Image(systemName: icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            badge.view
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
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.vertical, 12)
                    VStack(alignment: .leading, spacing: 14) {
                        content()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sensoryFeedback(.selection, trigger: expanded)
        .card()
    }
}

/// A configured neuraxial workflow as a tappable, expand-in-place row on the
/// consultant profile. Content is pulled from the same workflow data the
/// dedicated guided screen uses.
private struct NeuraxialExpandableRow: View {
    let item: ConfiguredNeuraxial
    /// Opens the guided editor for this workflow — the same one-tap edit action
    /// ProceduralExpandableRow exposes, so the whole zone behaves identically.
    var onEdit: (() -> Void)? = nil

    private var lines: [NeuraxialSummaryLine] {
        NeuraxialSummary.lines(for: item)
    }

    var body: some View {
        ExpandableProfileRow(
            title: item.definition.title,
            icon: item.definition.icon,
            tint: PrefGroup.technique.tint,
            badge: item.modified ? .updatedByYou : .none,
            collapsedSummary: NeuraxialSummary.collapsedSummary(for: item)
        ) {
            ForEach(Array(lines.filter { !$0.isNote }.enumerated()), id: \.offset) { _, line in
                if line.isWarning {
                    IncompleteFieldNudge(label: line.label)
                } else {
                    PrefRow(label: line.label, value: line.value)
                }
            }
            if let photo = item.resolved.customization.setupPhoto {
                SetupPhotoDisplay(data: photo)
            }
            ForEach(Array(lines.filter { $0.isNote }.enumerated()), id: \.offset) { _, line in
                PrefNote(label: line.label, text: line.value, tint: PrefGroup.technique.tint)
            }
            if let onEdit {
                Button(action: onEdit) {
                    Label("Edit \(item.definition.title)", systemImage: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
}

/// A configured procedural workflow (Arterial Line, CVC) as a tappable,
/// expand-in-place row on the consultant profile. Content is pulled from the
/// same workflow data the guided workflow screen edits.
private struct ProceduralExpandableRow: View {
    let item: ConfiguredProcedural
    /// Opens the guided editor for this workflow — without it, a configured
    /// arterial line / CVC would be creatable once and then locked forever.
    var onEdit: (() -> Void)? = nil

    private var lines: [NeuraxialSummaryLine] {
        ProceduralSummary.lines(for: item)
    }

    var body: some View {
        ExpandableProfileRow(
            title: item.definition.title,
            icon: item.definition.icon,
            tint: PrefGroup.technique.tint,
            badge: item.modified ? .updatedByYou : .none,
            collapsedSummary: ProceduralSummary.collapsedSummary(for: item)
        ) {
            ForEach(Array(lines.filter { !$0.isNote }.enumerated()), id: \.offset) { _, line in
                PrefRow(label: line.label, value: line.value)
            }
            if let photo = item.resolved.customization.setupPhoto {
                SetupPhotoDisplay(data: photo)
            }
            ForEach(Array(lines.filter { $0.isNote }.enumerated()), id: \.offset) { _, line in
                PrefNote(label: line.label, text: line.value, tint: PrefGroup.technique.tint)
            }
            if let onEdit {
                Button(action: onEdit) {
                    Label("Edit \(item.definition.title)", systemImage: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
}

/// A visible "field not recorded" callout. Surfaces a genuinely incomplete
/// preference (e.g. a migrated CSE with no intrathecal agent) so a technician can
/// tell the difference between "not configured" and "data missing" — it is never
/// silently omitted.
struct IncompleteFieldNudge: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Not recorded — tap Edit to add")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.30), lineWidth: 1)
        )
    }
}

/// A regional block as a tappable, expand-in-place row on the consultant profile.
private struct RegionalBlockExpandableRow: View {
    let block: RegionalBlock
    /// Opens the structured block editor — the same one-tap edit action
    /// ProceduralExpandableRow exposes, so the whole zone behaves identically.
    var onEdit: (() -> Void)? = nil

    private var localAnaesthetic: String {
        [block.drug, block.concentration, block.typicalVolume]
            .filter { !$0.isBlank }
            .joined(separator: " · ")
    }

    private var equipment: String {
        var parts: [String] = []
        if !block.needleType.isBlank { parts.append(block.needleType) }
        if !block.needleLength.isBlank { parts.append(block.needleLength) }
        if !block.ultrasoundProbe.isBlank { parts.append("\(block.ultrasoundProbe) probe") }
        if !block.sterileCover.isBlank { parts.append(block.sterileCover) }
        return parts.joined(separator: " · ")
    }

    private var collapsedSummary: String {
        var tokens: [String] = []
        if !block.drug.isBlank {
            var token = block.drug
            if !block.concentration.isBlank { token += " \(block.concentration)" }
            tokens.append(token)
        }
        if !block.needleType.isBlank { tokens.append(block.needleType) }
        return tokens.isEmpty ? "Tap to view" : tokens.prefix(2).joined(separator: " · ")
    }

    var body: some View {
        ExpandableProfileRow(
            title: block.name.isBlank ? "Block" : block.name,
            icon: "scope",
            tint: PrefGroup.technique.tint,
            badge: .none,
            collapsedSummary: collapsedSummary
        ) {
            PrefRow(label: "Local anaesthetic", value: localAnaesthetic)
            if !block.adjuvant.isBlank {
                PrefRow(label: "Adjuvant", value: block.adjuvant)
            }
            PrefNote(label: "Equipment", text: equipment, tint: PrefGroup.technique.tint)
            PrefNote(label: "Positioning", text: block.positioningNotes, tint: PrefGroup.technique.tint)
            PrefNote(label: "Ultrasound / setup", text: block.setupNotes, tint: PrefGroup.technique.tint)
            if let photo = block.setupPhoto {
                SetupPhotoDisplay(data: photo)
            }
            PrefNote(label: "Assistant", text: block.assistantNotes, tint: PrefGroup.technique.tint)
            PrefNote(label: "Safety", text: block.safetyNotes, tint: PrefGroup.technique.tint)
            PrefNote(label: "Special notes", text: block.specialNotes, tint: PrefGroup.technique.tint)
            if let onEdit {
                Button(action: onEdit) {
                    Label("Edit \(block.name.isBlank ? "Block" : block.name)", systemImage: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }
}

/// A specialty setup as a tappable, expand-in-place row on the consultant
/// profile — matching the Regional / Neuraxial inline pattern so a technician
/// meets one consistent "tap to see more" behaviour. Uses the accent tint to stay
/// visually distinct as its own category. Reads from the same SpecialtySetup data
/// shown on the dedicated detail screen.
/// A square quick-link tile used in the Hospital Information grid.
private struct QuickLinkTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: tint)).frame(width: 42, height: 42)
                Image(systemName: icon).font(.headline).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.cornerLarge))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

/// Shows where a profile came from — "Local — created by you" or "Imported from
/// [name]" — plus a "Locally modified" flag when an imported profile has been
/// edited. Forward-compatible vocabulary for a future hospital-database sync.
struct SourceBadge: View {
    let doctor: Doctor

    var body: some View {
        HStack(spacing: 8) {
            Label(doctor.resolvedSource.label, systemImage: doctor.resolvedSource.symbol)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color(.tertiarySystemFill), in: .capsule)
                .foregroundStyle(.secondary)
            if doctor.hasLocalEdits {
                Label("Locally modified", systemImage: "pencil")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15), in: .capsule)
                    .foregroundStyle(.orange)
            }
        }
    }
}

/// A specialty pill with a leading icon, tinted with the specialty's identity
/// colour so different interests are distinguishable before reading the text.
struct SpecialtyBadge: View {
    let specialty: Subspecialty

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: specialty.symbol).font(.caption2)
            Text(specialty.rawValue).font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(specialty.color.opacity(0.14), in: .capsule)
        .foregroundStyle(specialty.color)
    }
}

/// A simple wrapping chip layout.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { Chip(text: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Prominent safety disclaimer banner. Shows the full text for the first few
/// sightings, then collapses to a one-line reminder that expands on tap.
/// Expanded state is per-session; the sighting counter persists.
struct SafetyBanner: View {
    /// Forces the full banner regardless of view count (crisis cards,
    /// onboarding, exported/printed material).
    var alwaysExpanded: Bool = false

    @Environment(AppSettings.self) private var settings

    private var isCollapsible: Bool { !alwaysExpanded && settings.shouldCollapseSafetyBanner }

    var body: some View {
        Group {
            if isCollapsible {
                collapsibleBanner
            } else {
                fullBanner
            }
        }
        .onAppear { settings.recordSafetyBannerView() }
    }

    private var fullBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Theme.accent)
            Text(SafetyText.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
    }

    private var collapsibleBanner: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.isSafetyBannerExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                    Text("Preference reference only — tap for details")
                        .font(.caption)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(settings.isSafetyBannerExpanded ? 180 : 0))
                }
                .foregroundStyle(.tertiary)

                if settings.isSafetyBannerExpanded {
                    Text(SafetyText.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.05), in: .rect(cornerRadius: Theme.cornerMedium))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: settings.isSafetyBannerExpanded)
    }
}
