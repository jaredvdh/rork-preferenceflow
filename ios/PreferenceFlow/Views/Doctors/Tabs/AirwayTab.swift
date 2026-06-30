//
//  AirwayTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Airway management — adult and paediatric preferences behind a segmented
/// control, presented as the same calm card language as Drugs & Fluids.
struct AirwayTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor

    @State private var cohort: Cohort = .adult
    @State private var editing = false
    @State private var paed = PaediatricPatient()

    enum Cohort: String, CaseIterable, Identifiable {
        case adult, paediatric
        var id: String { rawValue }
    }

    private var a: AirwayPreferences { doctor.airway }
    private var hospital: Hospital? { store.hospital(id: doctor.hospitalId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Cohort", selection: $cohort) {
                    Text("Adult").tag(Cohort.adult)
                    Text(settings.region.paediatric).tag(Cohort.paediatric)
                }
                .pickerStyle(.segmented)

                PrefSummaryHeader(
                    icon: "lungs.fill",
                    title: "Airway",
                    status: status,
                    chips: cohort == .adult ? highlightChips : []
                )

                if cohort == .adult {
                    adultCards
                } else {
                    paediatricCards
                }

                if !hospitalItems.isEmpty {
                    PrefHospitalCard(items: hospitalItems)
                }

                EditSectionButton(title: "Edit Airway Preferences") { editing = true }
                PrefDisclaimer()
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.25), value: cohort)
        }
        .sheet(isPresented: $editing) {
            AirwayEditView(doctor: doctor)
        }
    }

    // MARK: - Status & highlights

    private var status: PrefStatus {
        .custom(text: "Standard airway setup", icon: "lungs.fill", color: Theme.accent)
    }

    private var highlightChips: [String] {
        var chips: [String] = []
        let m = a.adultMale
        let f = a.adultFemale
        if m.primaryTechnique == .video, m.videoSystem != .none { chips.append(m.videoSystem.rawValue) }
        // Blade — show both when male and female differ, otherwise a single chip.
        chips.append(contentsOf: splitChips(male: bladeValue(m), female: bladeValue(f)))
        // ETT — show both when male and female differ, otherwise a single chip.
        chips.append(contentsOf: splitChips(prefix: "ETT ", male: m.tubeSize, female: f.tubeSize))
        if !m.bougiePreference.isBlank { chips.append("Bougie \(m.bougiePreference)") }
        if isModified { chips.append(contentsOf: a.supraglottic.summaryChips.map { "SGA \($0)" }) }
        return Array(chips.prefix(6))
    }

    /// Builds summary chips for a male/female parameter pair: a single chip when
    /// the values match (or only one is present), or two gender-labelled chips
    /// when they differ. Never silently drops the female value.
    private func splitChips(prefix: String = "", male: String, female: String) -> [String] {
        let m = male.isBlank ? nil : male
        let f = female.isBlank ? nil : female
        switch (m, f) {
        case let (mv?, fv?):
            if mv == fv { return ["\(prefix)\(mv)"] }
            return ["\(prefix)\(mv) (M)", "\(prefix)\(fv) (F)"]
        case let (mv?, nil): return ["\(prefix)\(mv)"]
        case let (nil, fv?): return ["\(prefix)\(fv)"]
        default: return []
        }
    }

    private var isModified: Bool {
        if case .modified = status { return true }
        return false
    }

    // MARK: - Shared emptiness helpers

    private func ettEmpty(_ s: AirwaySetup) -> Bool {
        s.tubeSize.isBlank && s.cuffedPreference.isBlank && s.styletPreference.isBlank
            && s.bougiePreference.isBlank && s.tubeSecuring.isBlank
    }

    private func laryngoscopyEmpty(_ s: AirwaySetup) -> Bool {
        bladeValue(s).isBlank && !(s.primaryTechnique == .video)
    }

    private var supraglotticEmpty: Bool {
        let s = a.supraglottic
        return s.adultFemale.isEmpty && s.adultMale.isEmpty && s.largeAdult.isEmpty
    }

    private var primarySupraglottic: SupraglotticChoice? {
        let s = a.supraglottic
        for choice in [s.adultMale, s.adultFemale, s.largeAdult] where !choice.isEmpty {
            return choice
        }
        return nil
    }

    private var difficultEmpty: Bool {
        let d = a.difficultAirway
        return d.backupPlan.isBlank && d.fibreopticPreference.isBlank
            && d.surgicalAirwayNotes.isBlank && d.specialEquipment.isBlank
    }

    // MARK: - Adult cards

    private var adultEttEmpty: Bool { ettEmpty(a.adultMale) && ettEmpty(a.adultFemale) }
    private var adultLaryngoscopyEmpty: Bool { laryngoscopyEmpty(a.adultMale) && laryngoscopyEmpty(a.adultFemale) }
    private var adultNotes: [(label: String, text: String)] {
        var out: [(String, String)] = []
        if !a.adultMale.notes.isBlank { out.append(("Adult Male", a.adultMale.notes)) }
        if !a.adultFemale.notes.isBlank { out.append(("Adult Female", a.adultFemale.notes)) }
        if !a.supraglottic.notes.isBlank { out.append(("Supraglottic", a.supraglottic.notes)) }
        return out.map { (label: $0.0, text: $0.1) }
    }

    @ViewBuilder private var adultCards: some View {
        if adultEttEmpty && adultLaryngoscopyEmpty && supraglotticEmpty && difficultEmpty && adultNotes.isEmpty {
            emptyState
        } else {
            if !adultEttEmpty { ettCard }
            if !adultLaryngoscopyEmpty { laryngoscopyCard }
            if !supraglotticEmpty { supraglotticCard }
            if !difficultEmpty { difficultCard }
            if !adultNotes.isEmpty { notesCard(adultNotes) }
        }
    }

    private var ettCard: some View {
        var tokens: [String] = []
        if !a.adultMale.tubeSize.isBlank { tokens.append("M \(a.adultMale.tubeSize)") }
        if !a.adultFemale.tubeSize.isBlank { tokens.append("F \(a.adultFemale.tubeSize)") }
        let summary = tokens.isEmpty ? "Tube, cuff, stylet & bougie" : "ETT " + tokens.joined(separator: " · ")
        return PrefCollapsibleCard(group: .equipment, title: "Endotracheal Tube", icon: "lungs.fill", collapsedSummary: summary) {
            ettSubgroup("Adult Male", a.adultMale)
            ettSubgroup("Adult Female", a.adultFemale)
        }
    }

    @ViewBuilder private func ettSubgroup(_ title: String, _ s: AirwaySetup) -> some View {
        if !ettEmpty(s) {
            PrefSubgroup(title: title, tint: PrefGroup.equipment.tint) {
                PrefRow(label: "Tube size", value: s.tubeSize)
                PrefRow(label: "Cuff", value: s.cuffedPreference)
                PrefRow(label: "Stylet", value: s.styletPreference)
                PrefRow(label: "Bougie", value: s.bougiePreference)
                PrefRow(label: "Securing", value: s.tubeSecuring)
            }
        }
    }

    private var laryngoscopyCard: some View {
        return PrefCollapsibleCard(group: .technique, title: "Laryngoscopy", icon: "scope", collapsedSummary: adultLaryngoscopySummary) {
            laryngoscopySubgroup("Adult Male", a.adultMale)
            laryngoscopySubgroup("Adult Female", a.adultFemale)
        }
    }

    /// Collapsed-row subtitle for adult laryngoscopy. Shows a single line when
    /// male and female parameters match (or only one is set), and a combined
    /// "M: … / F: …" line when they differ so the female value is never dropped.
    private var adultLaryngoscopySummary: String {
        let m = a.adultMale
        let f = a.adultFemale
        let mEmpty = laryngoscopyEmpty(m)
        let fEmpty = laryngoscopyEmpty(f)
        if fEmpty { return laryngoscopySummary(m) }
        if mEmpty { return laryngoscopySummary(f) }
        let mSummary = laryngoscopySummary(m)
        let fSummary = laryngoscopySummary(f)
        if mSummary == fSummary { return mSummary }
        return "M: \(mSummary) / F: \(fSummary)"
    }

    @ViewBuilder private func laryngoscopySubgroup(_ title: String, _ s: AirwaySetup) -> some View {
        if !laryngoscopyEmpty(s) {
            PrefSubgroup(title: title, tint: PrefGroup.technique.tint) {
                PrefRow(label: "Technique", value: techniqueValue(s))
                PrefRow(label: "Blade", value: bladeValue(s))
            }
        }
    }

    private func laryngoscopySummary(_ s: AirwaySetup) -> String {
        var tokens: [String] = []
        tokens.append(techniqueValue(s))
        let blade = bladeValue(s)
        if !blade.isBlank { tokens.append(blade) }
        return tokens.joined(separator: " · ")
    }

    private var supraglotticCard: some View {
        let s = a.supraglottic
        let summary = (primarySupraglottic?.summary).flatMap { $0.isBlank ? nil : $0 } ?? "Backup supraglottic airway"
        return PrefCollapsibleCard(group: .equipment, title: "Supraglottic Airways", icon: "lungs", collapsedSummary: summary) {
            PrefRow(label: "Adult female", value: s.adultFemale.summary)
            PrefRow(label: "Adult male", value: s.adultMale.summary)
            PrefRow(label: "Large adult / high IBW", value: s.largeAdult.summary)
        }
    }

    private var difficultCard: some View {
        let d = a.difficultAirway
        let summary = [d.backupPlan, d.fibreopticPreference].first { !$0.isBlank } ?? "Backup plan & equipment"
        return PrefCollapsibleCard(group: .workflow, title: "Difficult Airway", icon: "exclamationmark.triangle.fill", collapsedSummary: summary) {
            PrefRow(label: "Backup plan", value: d.backupPlan)
            PrefRow(label: "Fibreoptic", value: d.fibreopticPreference)
            PrefRow(label: "Surgical airway", value: d.surgicalAirwayNotes)
            PrefRow(label: "Special equipment", value: d.specialEquipment)
        }
    }

    private func notesCard(_ notes: [(label: String, text: String)]) -> some View {
        PrefCollapsibleCard(
            group: .consultantNotes,
            title: "Notes",
            collapsedSummary: notes.map(\.label).joined(separator: " • ")
        ) {
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                PrefNote(label: note.label, text: note.text, tint: PrefGroup.consultantNotes.tint)
            }
        }
    }

    // MARK: - Paediatric cards

    @ViewBuilder private var paediatricCards: some View {
        PaediatricPatientCard(patient: $paed)
        PaediatricETTCard(ageYears: paed.ageYears, cuffedPreference: a.paediatric.cuffedPreference)
        PaediatricSupraglotticCard(weightKg: paed.effectiveWeightKg, usingActual: paed.useActualWeight, device: primarySupraglottic?.device ?? .none)
        gasInductionLinkCard
        if !laryngoscopyEmpty(a.paediatric) { paedLaryngoscopyCard }
        PaediatricBladeCard()
        if !difficultEmpty { difficultCard }
        if !a.paediatric.notes.isBlank {
            notesCard([(label: settings.region.paediatric, text: a.paediatric.notes)])
        }
    }

    private var gasInductionLinkCard: some View {
        let gas = doctor.paediatricDrugs?.gasInduction
        let configured = gas?.enabled == true
        let summary: String = configured
            ? [gas!.headlineSummary, gas!.sequenceSummary].filter { !$0.isEmpty }.joined(separator: " · ")
            : "Set in Drugs & Fluids → \(settings.region.paediatric)"
        return PrefCollapsibleCard(group: .medications, title: "Mask / Gas Induction", icon: "wind", collapsedSummary: summary) {
            if let gas, gas.enabled {
                PrefRow(label: "Volatile", value: gas.volatileAgent)
                PrefRow(label: "Carrier", value: gas.carrierShort)
                PrefRow(label: "Step-up", value: gas.sequenceSummary)
                PrefNote(label: "Notes", text: gas.notes, tint: PrefGroup.medications.tint)
            } else {
                Text("Gas induction preference is recorded in Drugs & Fluids → \(settings.region.paediatric).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var paedLaryngoscopyCard: some View {
        let s = a.paediatric
        return PrefCollapsibleCard(group: .technique, title: "Video / Direct Laryngoscopy", icon: "scope", collapsedSummary: laryngoscopySummary(s)) {
            PrefRow(label: "Technique", value: techniqueValue(s))
            PrefRow(label: "Blade", value: bladeValue(s))
        }
    }

    // MARK: - Value helpers

    private func techniqueValue(_ s: AirwaySetup) -> String {
        if s.primaryTechnique == .video {
            return s.videoSystem == .none ? "Video" : "Video — \(s.videoSystem.rawValue)"
        }
        return "Direct"
    }

    private func bladeValue(_ s: AirwaySetup) -> String {
        switch s.blade {
        case .macintosh: return s.bladeSize.isBlank ? "" : "Mac \(s.bladeSize)"
        case .miller: return s.bladeSize.isBlank ? "" : "Miller \(s.bladeSize)"
        case .other, .none: return s.bladeSize
        }
    }

    // MARK: - Hospital information

    private var hospitalItems: [PrefHospitalItem] {
        PrefHospital.items(for: hospital, kinds: [
            .difficultIntubationTrolley, .emergencyAirway, .videoLaryngoscopes,
            .paediatricTrolley, .anaestheticWorkroom
        ])
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "lungs",
            title: "No airway setup yet",
            message: "Add the standard airway preferences this consultant uses.",
            actionTitle: "Set Up",
            action: { editing = true }
        )
        .card()
    }
}

/// The shared “Paediatric Patient” summary card. Age is the primary input and
/// drives an estimated weight via the standard formula; an optional actual
/// weight overrides it. This single profile feeds every paediatric calculation
/// on the page (ETT, supraglottic, gas induction).
struct PaediatricPatientCard: View {
    @Binding var patient: PaediatricPatient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Paediatric Patient", icon: "figure.child")
            VStack(spacing: 14) {
                HStack {
                    Text("Age").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(patient.ageLabel)
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .contentTransition(.numericText())
                    Stepper("", value: $patient.ageYears, in: 1...16, step: 1)
                        .labelsHidden()
                }

                Divider()

                HStack {
                    Text("Estimated Weight").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(patient.estimatedWeightLabel)
                        .font(patient.useActualWeight ? .subheadline.weight(.medium) : .headline)
                        .foregroundStyle(patient.useActualWeight ? .secondary : Theme.accentDeep)
                        .contentTransition(.numericText())
                }

                Toggle("Use Actual Patient Weight", isOn: $patient.useActualWeight.animation(.easeInOut(duration: 0.2)))
                    .font(.subheadline)
                    .tint(Theme.accent)

                if patient.useActualWeight {
                    HStack {
                        Text("Actual Weight").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(patient.actualWeightKg.rounded())) kg")
                            .font(.headline)
                            .foregroundStyle(Theme.accentDeep)
                            .contentTransition(.numericText())
                        Stepper("", value: $patient.actualWeightKg, in: 2...120, step: 1)
                            .labelsHidden()
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: patient.useActualWeight ? "scalemass.fill" : "function")
                        .font(.caption2)
                    Text(patient.usingLabel)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 10))

                Text("Estimated weight = (age × 2) + 10. Reference estimate only — confirm against the patient and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
        }
    }
}

/// Age-based paediatric ETT size reference. The patient age is supplied by the
/// shared Paediatric Patient card; sizing uses the consultant's cuffed/uncuffed
/// preference. ETT sizing stays age-based by design.
struct PaediatricETTCard: View {
    let ageYears: Double
    let cuffedPreference: String

    private var prefersUncuffed: Bool { cuffedPreference == "Uncuffed" }

    private var ageLabel: String {
        ageYears < 1 ? "<1 yr" : "\(Int(ageYears)) yr\(ageYears >= 2 ? "s" : "")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Endotracheal Tube", icon: "lungs.fill")
            VStack(spacing: 16) {
                HStack {
                    Text("For age").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(ageLabel)
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .contentTransition(.numericText())
                }
                HStack(spacing: 12) {
                    ettTile("Cuffed", size: PaediatricETT.formatted(ageYears: ageYears, cuffed: true), preferred: !prefersUncuffed)
                    ettTile("Uncuffed", size: PaediatricETT.formatted(ageYears: ageYears, cuffed: false), preferred: prefersUncuffed)
                }
                Text("Cuffed = age ÷ 4 + 3.5 · Uncuffed = age ÷ 4 + 4 (mm ID). Age-based reference estimate only — confirm against the patient and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
        }
    }

    private func ettTile(_ title: String, size: String, preferred: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                if preferred {
                    Image(systemName: "star.fill").font(.system(size: 8))
                }
            }
            .foregroundStyle(preferred ? Theme.accentDeep : .secondary)
            Text(size)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(preferred ? Theme.accentDeep : .primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            (preferred ? Theme.accent.opacity(0.12) : Color(.tertiarySystemFill)),
            in: .rect(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(preferred ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}

/// Age/weight-based laryngoscope blade size reference for paediatric airways.
struct PaediatricBladeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Paediatric Blade Sizes", icon: "rectangle.portrait.on.rectangle.portrait")
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Age / Weight")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Miller")
                        .frame(width: 84, alignment: .leading)
                    Text("Macintosh")
                        .frame(width: 84, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accentDeep)
                .padding(.bottom, 8)

                ForEach(Array(PaediatricBlade.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider() }
                    HStack(spacing: 8) {
                        Text(row.ageGroup)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.miller)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 84, alignment: .leading)
                        Text(row.macintosh)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 84, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                }

                Text("Straight (Miller) blades are commonly preferred in infants. Reference estimate only — confirm against the patient and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .card()
        }
    }
}

/// Weight-based paediatric supraglottic (i-gel / LMA) size reference. The weight
/// comes from the shared Paediatric Patient card (estimated or actual) — never
/// from age. Highlights the provider's selected device family and shows the
/// manufacturer weight range for the recommended size.
struct PaediatricSupraglotticCard: View {
    let weightKg: Double
    var usingActual: Bool = false
    let device: SupraglotticDevice

    private var prefersIgel: Bool { device == .igel }
    private var prefersLma: Bool {
        switch device {
        case .lmaClassic, .lmaProSeal, .lmaSupreme, .auraGain: return true
        default: return false
        }
    }

    /// Whichever device family the consultant prefers drives the headline.
    private var recommended: (name: String, size: String, range: String) {
        if prefersLma {
            return ("LMA", PaediatricSupraglottic.lmaSize(weightKg: weightKg), PaediatricSupraglottic.lmaRange(weightKg: weightKg))
        }
        return ("i-gel", PaediatricSupraglottic.igelSize(weightKg: weightKg), PaediatricSupraglottic.igelRange(weightKg: weightKg))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Supraglottic Airway", icon: "lungs")
            VStack(spacing: 16) {
                HStack {
                    Text("For weight").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(weightKg.rounded())) kg")
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .contentTransition(.numericText())
                    Text(usingActual ? "actual" : "est.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    sgTile("i-gel", size: PaediatricSupraglottic.igelSize(weightKg: weightKg), preferred: prefersIgel)
                    sgTile("LMA", size: PaediatricSupraglottic.lmaSize(weightKg: weightKg), preferred: prefersLma)
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.caption)
                    Text("Recommended: \(recommended.name) Size \(recommended.size)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(recommended.range)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 12))

                Text("Sizes are weight-based per the manufacturer table — never calculated from age. Reference estimate only; confirm against the patient, device packaging and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
        }
    }

    private func sgTile(_ title: String, size: String, preferred: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                if preferred {
                    Image(systemName: "star.fill").font(.system(size: 8))
                }
            }
            .foregroundStyle(preferred ? Theme.accentDeep : .secondary)
            Text(size)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(preferred ? Theme.accentDeep : .primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            (preferred ? Theme.accent.opacity(0.12) : Color(.tertiarySystemFill)),
            in: .rect(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(preferred ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}

/// A compact stat row used on airway cards; hidden when the value is empty.
struct AirwayStatRow: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        if !value.isBlank {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(accent ? .headline : .subheadline.weight(.medium))
                    .foregroundStyle(accent ? Theme.accentDeep : .primary)
            }
            .padding(.vertical, 6)
        }
    }
}

/// A standard "Edit …" pill button used at the top of preference tabs.
struct EditSectionButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.accent.opacity(0.12), in: .capsule)
                .foregroundStyle(Theme.accent)
        }
    }
}
