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
    /// Hospital used for the Hospital Information quick links (resolved by parent).
    var hospitalID: UUID? = nil
    /// True when the profile is in Edit Mode (unused by the read-only card).
    var editMode: Bool = false
    /// Department standard this consultant inherits from (reserved for future use).
    var template: DepartmentTemplate? = nil

    @State private var editingSpecialty: SpecialtySetup?
    @State private var viewingSpecialty: SpecialtySetup?
    @State private var addingSpecialty = false
    @State private var theatreCardURL: URL?
    @State private var cardError: String?
    @State private var viewingReferencePhoto = false

    private var hospital: Hospital? {
        store.hospital(id: hospitalID ?? doctor.hospitalId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                specialtySection
                printCardButton
                setupSection
                referencePhotoSection
                hospitalSection
                knowledgeSection
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
        .sheet(item: $viewingSpecialty) { setup in
            SpecialtySetupDetailView(setup: setup, hospitalItems: specialtyHospitalItems, onEdit: {
                viewingSpecialty = nil
                editingSpecialty = setup
            })
        }
        .sheet(item: Binding(get: { theatreCardURL.map { SharePayload(url: $0) } }, set: { theatreCardURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Couldn't create card", isPresented: .constant(cardError != nil)) {
            Button("OK") { cardError = nil }
        } message: {
            Text(cardError ?? "")
        }
        .fullScreenCover(isPresented: $viewingReferencePhoto) {
            if let data = doctor.referencePhotoData, let image = UIImage(data: data) {
                ReferencePhotoViewer(image: image)
            }
        }
    }

    // MARK: - 1. Header

    private var hero: some View {
        VStack(spacing: 14) {
            DoctorAvatar(doctor: doctor, size: 96)
                .overlay(
                    Circle().stroke(Theme.accent.opacity(0.25), lineWidth: 4)
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

    // MARK: - 2. Specialty setups (prominent tappable chips)

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
                FlowLayout(spacing: 10) {
                    ForEach(activeSpecialties) { setup in
                        Button { viewingSpecialty = setup } label: { specialtyChip(setup) }
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
    }

    private func specialtyChip(_ setup: SpecialtySetup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: setup.specialty.symbol).font(.subheadline.weight(.semibold))
            Text(setup.specialty.rawValue).font(.subheadline.weight(.semibold))
            if setup.changeCount > 0 {
                Text("\(setup.changeCount)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(.white.opacity(0.4), in: .capsule)
            }
            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.accent.opacity(0.14), in: .capsule)
        .foregroundStyle(Theme.accentDeep)
    }

    // MARK: - Print / share card

    /// One-tap laminate-ready theatre card — visible to everyone. Bridges
    /// departments still using physical folders: print, laminate, AirDrop or save
    /// to Files straight from the card.
    private var printCardButton: some View {
        Button(action: generateTheatreCard) {
            HStack(spacing: 12) {
                Image(systemName: "printer.fill")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Print / Share Card")
                        .font(.subheadline.weight(.semibold))
                    Text("One-page laminate-ready theatre card")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Theme.heroGradient, in: .rect(cornerRadius: Theme.cornerLarge))
            .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func generateTheatreCard() {
        do {
            theatreCardURL = try TheatreCardPDF.writeFile(for: doctor, hospital: hospital, region: settings.region)
        } catch {
            cardError = error.localizedDescription
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
            airwayCard        // 5
            drugsCard         // 6
            monitoringCard    // 7
            if hasAdditional {
                additionalCard // 8
            }
        }
    }

    // 4. General
    private var generalCard: some View {
        let g = doctor.general
        return DetailSection(title: "General", icon: "person.text.rectangle.fill") {
            ValueRow(label: "Glove size", value: g.gloveSize, icon: "hand.raised")
            ValueRow(label: "Gown size", value: g.gownSize, icon: "tshirt")
            ValueRow(label: "Coffee", value: g.coffeePreference, icon: "cup.and.saucer")
            if isGeneralEmpty {
                IncompleteNudge(text: "Incomplete — tap to add general preferences") { onNavigate(.general) }
            }
        }
    }

    private var isGeneralEmpty: Bool {
        let g = doctor.general
        return g.gloveSize.isBlank && g.gownSize.isBlank && g.coffeePreference.isBlank
    }

    // 5. Airway
    private var airwayCard: some View {
        let a = doctor.airway
        return DetailSection(title: "Airway", icon: "lungs.fill") {
            PrefRow(label: "ETT (Male)", value: a.adultMale.tubeSize)
            PrefRow(label: "ETT (Female)", value: a.adultFemale.tubeSize)
            laryngoscopeRows
            PrefRow(label: "Supraglottic", value: sgaSummary)
            PrefRow(label: "Bougie", value: a.adultMale.bougiePreference)
            if isAirwayEmpty {
                IncompleteNudge(text: "Incomplete — tap to add airway setup") { onNavigate(.airway) }
            }
        }
    }

    /// Laryngoscope rows for the card view. Shows one row when male and female
    /// parameters match (or only one is set), and two gender-labelled rows when
    /// they differ so the female value is never silently dropped.
    @ViewBuilder private var laryngoscopeRows: some View {
        let a = doctor.airway
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

    private var sgaSummary: String {
        doctor.airway.supraglottic.summaryChips.joined(separator: ", ")
    }

    private var isAirwayEmpty: Bool {
        let a = doctor.airway
        return a.adultMale.tubeSize.isBlank && a.adultFemale.tubeSize.isBlank
            && sgaSummary.isBlank && a.adultMale.bougiePreference.isBlank
            && a.adultMale.videoSystem == .none && a.adultMale.blade == .none
    }

    // 6. Drugs
    private var adultDrugs: DrugsFluidsSetup { doctor.adultDrugs ?? DrugsFluidsSetup() }

    private var drugsCard: some View {
        let d = adultDrugs
        return DetailSection(title: "Drugs & Fluids", icon: "syringe.fill") {
            PrefRow(label: "Induction", value: d.induction.selected.joined(separator: ", "))
            PrefRow(label: "Opioid", value: d.opioid.selected.joined(separator: ", "))
            PrefRow(label: "Vasopressor", value: d.vasopressor.selected.joined(separator: ", "))
            PrefRow(label: "Muscle relaxant", value: d.muscleRelaxant.selected.joined(separator: ", "))
            PrefRow(label: "IV fluids", value: d.fluids.selected.joined(separator: ", "))
            if !d.hasContent {
                IncompleteNudge(text: "Incomplete — tap to add drugs & fluids") { onNavigate(.drugs) }
            }
        }
    }

    // 7. Monitoring
    private var monitoringCard: some View {
        DetailSection(title: "Monitoring", icon: "waveform.path.ecg") {
            PrefChecklist(items: ["Standard ASA monitoring"], tint: PrefGroup.monitoring.tint)
        }
    }

    // 8. Additional equipment & notes
    private var regionalNames: [String] {
        doctor.regionalBlocks.map { $0.name.isBlank ? "Block" : $0.name }
    }

    private var neuraxialNames: [String] {
        WorkflowLibrary.neuraxial
            .filter { doctor.neuraxial.isConfigured($0.id) }
            .map { $0.title }
    }

    private var specialInterests: [String] {
        doctor.subspecialties.filter { $0 != .general }.map { $0.rawValue }
    }

    private var hasAdditional: Bool {
        !regionalNames.isEmpty || !neuraxialNames.isEmpty
            || !specialInterests.isEmpty || !doctor.biography.isBlank
    }

    private var additionalCard: some View {
        DetailSection(title: "Additional Equipment & Notes", icon: "cross.case.fill") {
            if !regionalNames.isEmpty {
                PrefSubgroup(title: "Regional blocks", tint: PrefGroup.technique.tint) {
                    PrefChecklist(items: regionalNames, tint: PrefGroup.technique.tint)
                }
            }
            if !neuraxialNames.isEmpty {
                PrefSubgroup(title: "Neuraxial", tint: PrefGroup.technique.tint) {
                    PrefChecklist(items: neuraxialNames, tint: PrefGroup.technique.tint)
                }
            }
            if !specialInterests.isEmpty {
                ChipValueRow(label: "Special interests", values: specialInterests)
            }
            PrefNote(label: "Notes", text: doctor.biography, tint: PrefGroup.consultantNotes.tint)
        }
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

    // MARK: - Hospital information

    @ViewBuilder
    private var hospitalSection: some View {
        if let hospital {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Hospital Information", icon: "building.2.fill")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    NavigationLink(value: DashboardRoute.equipment(hospital.id)) {
                        QuickLinkTile(title: "Equipment", subtitle: "Where to find it", icon: "shippingbox.fill", tint: "E0883B")
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: DashboardRoute.contacts(hospital.id)) {
                        QuickLinkTile(title: "Contacts", subtitle: "Key & emergency", icon: "phone.fill", tint: "2E7DD1")
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: DashboardRoute.contacts(hospital.id)) {
                        QuickLinkTile(title: "Emergency", subtitle: "Numbers & sick call", icon: "cross.case.fill", tint: "D1576E")
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: DashboardRoute.hospital(hospital.id)) {
                        QuickLinkTile(title: "Orientation", subtitle: "Full guide", icon: "map.fill", tint: "0E9F8E")
                    }
                    .buttonStyle(.plain)
                }
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

    // MARK: - Knowledge

    private var knowledgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Knowledge", icon: "books.vertical.fill")
            Text("Reference resources — separate from consultant preferences.")
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 10) {
                ForEach(KnowledgeCategory.allCases) { category in
                    NavigationLink(value: category) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: category.tint)).frame(width: 44, height: 44)
                                Image(systemName: category.symbol).font(.headline).foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(category.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .card(padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

/// The prominent Theatre Ready completeness card with an animated ring and a
/// breakdown of completed vs missing sections.
struct TheatreReadyCard: View {
    let doctor: Doctor
    var paediatricTerm: String = "Paediatric"

    @State private var animatedFraction: Double = 0

    private var checks: [ProfileCheck] {
        ProfileScore.checks(for: doctor, paediatricTerm: paediatricTerm)
    }
    private var percent: Int { ProfileScore.percent(for: doctor) }
    private var completed: [ProfileCheck] { checks.filter { $0.isComplete } }
    private var missing: [ProfileCheck] { checks.filter { !$0.isComplete } }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 20) {
                ring
                VStack(alignment: .leading, spacing: 6) {
                    Text("THEATRE READY")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(percent)%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("\(completed.count) of \(checks.count) sections complete")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }

            VStack(spacing: 9) {
                ForEach(completed) { check in
                    checkRow(check, done: true)
                }
                ForEach(missing) { check in
                    checkRow(check, done: false)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous)
                .fill(Theme.inkGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous)
                .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.25), radius: 16, y: 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animatedFraction = ProfileScore.fraction(for: doctor)
            }
        }
        .onChange(of: ProfileScore.fraction(for: doctor)) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) { animatedFraction = newValue }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 9)
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(
                    LinearGradient(colors: [Theme.accentBright, Theme.accent], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: percent == 100 ? "checkmark" : "stethoscope")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 86, height: 86)
    }

    private func checkRow(_ check: ProfileCheck, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Theme.accentBright : .white.opacity(0.4))
            Text(check.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(done ? .white : .white.opacity(0.6))
            Spacer()
            if !done {
                Text("Missing")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
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

/// A specialty pill with a leading icon.
struct SpecialtyBadge: View {
    let specialty: Subspecialty

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: specialty.symbol).font(.caption2)
            Text(specialty.rawValue).font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Theme.accent.opacity(0.14), in: .capsule)
        .foregroundStyle(Theme.accentDeep)
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

/// Prominent safety disclaimer banner.
struct SafetyBanner: View {
    var body: some View {
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
}
