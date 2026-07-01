//
//  ProfilePDF.swift
//  PreferenceFlow
//

import UIKit
import SwiftUI
import CoreImage.CIFilterBuiltins

/// Which parts of the consultant profile to include in the exported card. Shaped
/// as an `OptionSet` so the export sheet can offer per-section toggles and so the
/// generator can later support broader document types (department books,
/// orientation manuals, induction packs) without a redesign.
nonisolated struct PreferenceCardOptions: OptionSet, Hashable {
    let rawValue: Int

    static let consultant = PreferenceCardOptions(rawValue: 1 << 0)
    static let standardSetup = PreferenceCardOptions(rawValue: 1 << 1)
    static let specialty = PreferenceCardOptions(rawValue: 1 << 2)
    static let regional = PreferenceCardOptions(rawValue: 1 << 3)
    static let neuraxial = PreferenceCardOptions(rawValue: 1 << 4)
    static let hospitalInfo = PreferenceCardOptions(rawValue: 1 << 5)
    static let notes = PreferenceCardOptions(rawValue: 1 << 6)

    /// Sensible default — a complete consultant card without the hospital appendix.
    static let standard: PreferenceCardOptions = [
        .consultant, .standardSetup, .specialty, .regional, .neuraxial, .notes
    ]
    /// Everything, including the optional hospital orientation appendix.
    static let everything: PreferenceCardOptions = [
        .consultant, .standardSetup, .specialty, .regional, .neuraxial, .hospitalInfo, .notes
    ]
}

/// Renders a consultant's preference profile into a polished, printable A4
/// "Consultant Preference Card" — a digital version of a laminated theatre
/// reference card. Pure layout code with no clinical recommendations; mirrors
/// what the app shows on screen.
@MainActor
enum ProfilePDF {
    // A4 at 72 dpi.
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 44

    /// Builds the PDF data for a single consultant.
    static func data(
        for doctor: Doctor,
        hospital: Hospital?,
        region: TerminologyRegion,
        options: PreferenceCardOptions = .standard,
        includeQRCode: Bool = false
    ) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        return renderer.pdfData { context in
            var ctx = DrawContext(context: context, pageSize: pageSize, margin: margin)
            ctx.beginPage()
            drawCover(&ctx, doctor: doctor, hospital: hospital, region: region)

            if options.contains(.consultant) { drawGeneral(&ctx, doctor.general) }
            if options.contains(.standardSetup) { drawStandardSetup(&ctx, doctor, region: region) }
            if options.contains(.specialty) { drawSpecialty(&ctx, doctor.activeSpecialtySetups) }
            if options.contains(.regional) { drawRegional(&ctx, doctor.regionalBlocks) }
            if options.contains(.neuraxial) { drawNeuraxial(&ctx, doctor.neuraxial) }
            if options.contains(.notes) { drawNotes(&ctx, doctor) }
            if options.contains(.hospitalInfo), let hospital, hospital.orientationOrEmpty.hasContent {
                drawHospitalAppendix(&ctx, hospital)
            }

            if includeQRCode { drawQRCode(&ctx, doctor: doctor) }
        }
    }

    /// Writes the PDF to a temporary file and returns the URL for sharing.
    static func writeFile(
        for doctor: Doctor,
        hospital: Hospital?,
        region: TerminologyRegion,
        options: PreferenceCardOptions = .standard,
        includeQRCode: Bool = false
    ) throws -> URL {
        let pdf = data(for: doctor, hospital: hospital, region: region, options: options, includeQRCode: includeQRCode)
        let safeName = doctor.fullName.isEmpty
            ? "Consultant"
            : doctor.fullName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)_PreferenceCard.pdf")
        try pdf.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Cover

    private static func drawCover(_ ctx: inout DrawContext, doctor: Doctor, hospital: Hospital?, region: TerminologyRegion) {
        let bandHeight: CGFloat = 132
        let band = CGRect(x: 0, y: 0, width: pageSize.width, height: bandHeight)
        // Gradient band.
        let cg = ctx.context.cgContext
        cg.saveGState()
        cg.addRect(band)
        cg.clip()
        let colors = [UIColor(Theme.accentBright).cgColor, UIColor(Theme.accentDeep).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: pageSize.width, y: bandHeight), options: [])
        }
        cg.restoreGState()

        // Avatar.
        let avatarSize: CGFloat = 72
        let avatarRect = CGRect(x: margin, y: 30, width: avatarSize, height: avatarSize)
        if let data = doctor.photoData, let image = UIImage(data: data) {
            cg.saveGState()
            UIBezierPath(ovalIn: avatarRect).addClip()
            let aspect = max(avatarSize / image.size.width, avatarSize / image.size.height)
            let drawSize = CGSize(width: image.size.width * aspect, height: image.size.height * aspect)
            let drawOrigin = CGPoint(x: avatarRect.midX - drawSize.width / 2, y: avatarRect.midY - drawSize.height / 2)
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
            cg.restoreGState()
            UIColor.white.withAlphaComponent(0.7).setStroke()
            let ring = UIBezierPath(ovalIn: avatarRect)
            ring.lineWidth = 2
            ring.stroke()
        } else {
            UIColor.white.withAlphaComponent(0.18).setFill()
            UIBezierPath(ovalIn: avatarRect).fill()
            let initials = doctor.initials.isEmpty ? "?" : doctor.initials
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let size = initials.size(withAttributes: attrs)
            initials.draw(at: CGPoint(x: avatarRect.midX - size.width / 2, y: avatarRect.midY - size.height / 2), withAttributes: attrs)
        }

        let textLeft = margin + avatarSize + 18
        let textWidth = pageSize.width - margin - textLeft

        "CONSULTANT PREFERENCE CARD".draw(
            at: CGPoint(x: textLeft, y: 32),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .kern: 1.4
            ]
        )

        doctor.displayName.draw(
            in: CGRect(x: textLeft, y: 46, width: textWidth, height: 34),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )

        var subtitleParts: [String] = []
        if !doctor.role.isEmpty { subtitleParts.append(doctor.role) }
        if let hospital, !hospital.name.isEmpty { subtitleParts.append(hospital.name) }
        let dept = doctor.department.isEmpty ? (hospital?.department ?? "") : doctor.department
        if !dept.isEmpty { subtitleParts.append(dept) }
        let subtitle = subtitleParts.joined(separator: "  ·  ")
        if !subtitle.isEmpty {
            subtitle.draw(
                in: CGRect(x: textLeft, y: 82, width: textWidth, height: 18),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9)
                ]
            )
        }
        if doctor.isHospitalVersion {
            "Hospital-specific profile".draw(
                at: CGPoint(x: textLeft, y: 102),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                ]
            )
        }

        ctx.cursorY = bandHeight + 22

        // Specialty chips.
        let specialties = doctor.subspecialties.map { "\(specialtyEmoji($0)) \($0.rawValue)" }
        if !specialties.isEmpty { ctx.drawPills(specialties) }

        // Quick summary badges.
        let badges = summaryBadges(for: doctor)
        if !badges.isEmpty { ctx.drawPills(badges, filled: true) }

        // General notes.
        if !doctor.general.generalNotes.isBlank {
            ctx.cursorY += 4
            ctx.drawNote(doctor.general.generalNotes)
        }

        ctx.cursorY += 6
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        ctx.drawMuted("Generated \(formatter.string(from: Date()))")
        ctx.cursorY += 2
        ctx.drawDisclaimer("Preference reference only — not clinical advice. Always confirm against the patient and local policy.")
        ctx.cursorY += 12
    }

    /// Capability badges summarising what this consultant's card contains.
    private static func summaryBadges(for doctor: Doctor) -> [String] {
        var badges: [String] = []
        if hasAirwayContent(doctor.airway) { badges.append("Airway") }
        if (doctor.adultDrugs?.hasContent ?? false) || (doctor.paediatricDrugs?.hasContent ?? false) { badges.append("Drugs") }
        if doctor.regionalBlocks.contains(where: { !$0.name.isBlank }) { badges.append("Regional") }
        if neuraxialHasContent(doctor.neuraxial) { badges.append("Neuraxial") }
        for s in doctor.activeSpecialtySetups { badges.append("\(specialtyEmoji(s.specialty)) \(s.specialty.rawValue)") }
        if !doctor.general.coffeePreference.isBlank { badges.append("Coffee ☕") }
        return badges
    }

    private static func specialtyEmoji(_ s: Subspecialty) -> String {
        switch s {
        case .cardiac: return "❤️"
        case .paediatrics: return "👶"
        case .neuro: return "🧠"
        case .trauma: return "🚑"
        case .obstetrics: return "🤰"
        case .vascular: return "🩸"
        case .ent: return "👂"
        case .plastics: return "✋"
        case .regional: return "🎯"
        case .icu: return "🛏️"
        case .thoracic: return "🫁"
        case .transplant: return "♻️"
        case .mri: return "🧲"
        case .general: return "🩺"
        case .other: return "🔹"
        }
    }

    // MARK: - Consultant preferences

    private static func drawGeneral(_ ctx: inout DrawContext, _ g: GeneralPreferences) {
        var rows: [(String, String)] = []
        rows.append(("Sterile gloves", g.sterileGloveDisplay))
        rows.append(("Non-sterile gloves", g.nonSterileGloveDisplay))
        rows.append(("Gown size", g.gownSize))
        rows.append(("Mask", g.maskPreference))
        rows.append(("Theatre shoe size", g.theatreShoeSize))
        rows.append(("Room temperature", g.roomTemperature))
        rows.append(("Coffee", g.coffeePreference))
        rows.append(("Tea", g.teaPreference))
        rows.append(("Favourite snacks", g.favouriteSnacks))
        rows.append(("Contact preferences", g.contactPreferences))
        rows.append(("Briefing style", g.briefingStyle))

        var workflow: [String] = []
        if g.arriveBeforePatient { workflow.append("Arrives before patient") }
        if g.prepareOwnMedications { workflow.append("Prepares own medications") }
        if g.assistantMayPrepareMedications { workflow.append("Assistant may prepare medications") }

        let filtered = rows.filter { !$0.1.isBlank }
        guard !filtered.isEmpty || !workflow.isEmpty else { return }

        ctx.drawSectionTitle("Consultant Preferences", icon: "person.text.rectangle")
        for row in filtered { ctx.drawValueRow(label: row.0, value: row.1) }
        if !workflow.isEmpty { ctx.drawValueRow(label: "Workflow", value: workflow.joined(separator: ", ")) }
        ctx.endSection()
    }

    // MARK: - Standard theatre setup (hero)

    private static func drawStandardSetup(_ ctx: inout DrawContext, _ doctor: Doctor, region: TerminologyRegion) {
        let hasAirway = hasAirwayContent(doctor.airway)
        let hasDrugs = (doctor.adultDrugs?.hasContent ?? false) || (doctor.paediatricDrugs?.hasContent ?? false)
        guard hasAirway || hasDrugs else { return }

        ctx.drawSectionTitle("Standard Setup", icon: "checklist")
        ctx.drawCaption("The default setup used for most operating lists.")

        if hasAirway {
            ctx.drawGroupLabel("Airway")
            drawAirwayBody(&ctx, doctor.airway, region: region)
        }
        if hasDrugs {
            ctx.drawGroupLabel("Induction & Drugs")
            drawDrugsBody(&ctx, doctor, region: region)
        }
        ctx.endSection()
    }

    private static func hasAirwayContent(_ a: AirwayPreferences) -> Bool {
        let setups = [a.adultMale, a.adultFemale, a.paediatric]
        if setups.contains(where: { !airwaySetupLines($0).isEmpty }) { return true }
        let sg = a.supraglottic
        if !sg.adultFemale.isEmpty || !sg.adultMale.isEmpty || !sg.largeAdult.isEmpty
            || !sg.notes.isBlank { return true }
        let da = a.difficultAirway
        return !da.backupPlan.isBlank || !da.fibreopticPreference.isBlank
            || !da.surgicalAirwayNotes.isBlank || !da.specialEquipment.isBlank
    }

    private static func drawAirwayBody(_ ctx: inout DrawContext, _ a: AirwayPreferences, region: TerminologyRegion) {
        let setups: [(String, AirwaySetup)] = [
            ("Adult male", a.adultMale),
            ("Adult female", a.adultFemale),
            (region.paediatric, a.paediatric)
        ]
        for (title, setup) in setups {
            let lines = airwaySetupLines(setup)
            guard !lines.isEmpty else { continue }
            ctx.drawSubheading(title)
            for line in lines { ctx.drawBullet(line) }
            if !setup.notes.isBlank { ctx.drawNote(setup.notes) }
        }

        let sg = a.supraglottic
        let hasSupraglottic = !sg.adultFemale.isEmpty || !sg.adultMale.isEmpty
            || !sg.largeAdult.isEmpty || !sg.notes.isBlank
        if hasSupraglottic {
            ctx.drawSubheading("Supraglottic")
            if !sg.adultFemale.isEmpty { ctx.drawBullet("Adult female: \(sg.adultFemale.summary)") }
            if !sg.adultMale.isEmpty { ctx.drawBullet("Adult male: \(sg.adultMale.summary)") }
            if !sg.largeAdult.isEmpty { ctx.drawBullet("Large adult / high IBW: \(sg.largeAdult.summary)") }
            if !sg.notes.isBlank { ctx.drawNote(sg.notes) }
        }

        let da = a.difficultAirway
        let hasDifficult = !da.backupPlan.isBlank || !da.fibreopticPreference.isBlank
            || !da.surgicalAirwayNotes.isBlank || !da.specialEquipment.isBlank
        if hasDifficult {
            ctx.drawSubheading("Difficult Airway")
            if !da.backupPlan.isBlank { ctx.drawValueRow(label: "Backup plan", value: da.backupPlan) }
            if !da.fibreopticPreference.isBlank { ctx.drawValueRow(label: "Fibreoptic", value: da.fibreopticPreference) }
            if !da.surgicalAirwayNotes.isBlank { ctx.drawValueRow(label: "Surgical airway", value: da.surgicalAirwayNotes) }
            if !da.specialEquipment.isBlank { ctx.drawValueRow(label: "Special equipment", value: da.specialEquipment) }
        }

        drawPaediatricReference(&ctx, region: region)
    }

    /// A fixed age/weight paediatric airway lookup, included on every export since
    /// a printed card cannot respond to a live age input. Reference only.
    private static func drawPaediatricReference(_ ctx: inout DrawContext, region: TerminologyRegion) {
        ctx.drawSubheading("\(region.paediatric) reference")
        ctx.drawCaption("Reference estimate only — confirm against the patient and local policy.")
        ctx.drawBullet("ETT internal diameter: cuffed = age ÷ 4 + 3.5 mm · uncuffed = age ÷ 4 + 4 mm")
        ctx.drawValueRow(label: "Age", value: "Cuffed · Uncuffed (mm ID)")
        for age in [1, 2, 4, 6, 8, 10] {
            let cuffed = PaediatricETT.formatted(ageYears: Double(age), cuffed: true)
            let uncuffed = PaediatricETT.formatted(ageYears: Double(age), cuffed: false)
            ctx.drawValueRow(label: "\(age) yr", value: "\(cuffed) · \(uncuffed)")
        }
        ctx.drawBullet("Laryngoscope blades (Miller / Macintosh):")
        for row in PaediatricBlade.rows {
            ctx.drawValueRow(label: row.ageGroup, value: "Miller \(row.miller) · Mac \(row.macintosh)")
        }
        ctx.drawBullet("Supraglottic, weight-based (i-gel / LMA):")
        for row in PaediatricSupraglottic.rows {
            ctx.drawValueRow(label: row.weightBand, value: "i-gel \(row.igel) · LMA \(row.lma)")
        }
    }

    private static func airwaySetupLines(_ s: AirwaySetup) -> [String] {
        var lines: [String] = []
        if !s.tubeSize.isBlank { lines.append("Tube size: \(s.tubeSize)") }
        if s.tubeType != .standard {
            var tt = "Tube type: \(s.tubeType.rawValue)"
            if !s.tubeTypeNote.isBlank { tt += " (\(s.tubeTypeNote))" }
            lines.append(tt)
        }
        if !s.styletPreference.isBlank { lines.append("Stylet: \(s.styletPreference)") }
        if !s.bougiePreference.isBlank { lines.append("Bougie: \(s.bougiePreference)") }
        if !s.tubeSecuring.isBlank { lines.append("Securing: \(s.tubeSecuring)") }
        if !s.tapingTape.isBlank { lines.append("Tape: \(s.tapingTape)") }
        if !s.tapingTechnique.isBlank { lines.append("Taping technique: \(s.tapingTechnique)") }
        if s.tapingTechniquePhoto != nil { lines.append("Taping technique photo saved in app") }
        var laryngoscopy = "Laryngoscopy: \(s.primaryTechnique.rawValue)"
        if s.primaryTechnique == .video, s.videoSystem != .none { laryngoscopy += " (\(s.videoSystem.rawValue))" }
        if s.blade != .none {
            laryngoscopy += " · \(s.blade.rawValue)"
            if !s.bladeSize.isBlank { laryngoscopy += " \(s.bladeSize)" }
        }
        lines.append(laryngoscopy)
        return lines
    }

    private static func drawDrugsBody(_ ctx: inout DrawContext, _ doctor: Doctor, region: TerminologyRegion) {
        let cohorts: [(String, DrugsFluidsSetup?)] = [
            ("Adult", doctor.adultDrugs),
            (region.paediatric, doctor.paediatricDrugs)
        ]
        for (title, setupOpt) in cohorts {
            guard let setup = setupOpt, setup.hasContent else { continue }
            ctx.drawSubheading(title)
            if title == "Adult", setup.hasMaintenance {
                var value = setup.maintenanceTechnique.rawValue
                if !setup.maintenanceDetail.isBlank { value += "  (\(setup.maintenanceDetail))" }
                ctx.drawValueRow(label: "Maintenance", value: value)
            }
            for category in DrugCategory.allCases {
                let sel = setup.selection(for: category)
                guard !sel.isEmpty else { continue }
                var value = sel.allAgents.joined(separator: ", ")
                if sel.preparedBy != .caseDependent { value += "  (\(sel.preparedBy.rawValue))" }
                if value.isBlank, !sel.notes.isBlank { value = sel.notes }
                ctx.drawValueRow(label: category.rawValue, value: value)
                if !sel.notes.isBlank, !sel.selected.isEmpty { ctx.drawNote(sel.notes) }
            }
            if !setup.notes.isBlank { ctx.drawNote(setup.notes) }
        }
    }

    // MARK: - Specialty setups

    private static func drawSpecialty(_ ctx: inout DrawContext, _ setups: [SpecialtySetup]) {
        guard !setups.isEmpty else { return }
        ctx.drawSectionTitle("Specialty Setups", icon: "square.grid.2x2")
        ctx.drawCaption("Only what changes compared with the Standard Setup.")
        for (index, setup) in setups.enumerated() {
            if index > 0 { ctx.drawDivider() }
            ctx.drawSubheading("\(specialtyEmoji(setup.specialty)) \(setup.specialty.rawValue)")
            if !setup.additionalMonitoring.isEmpty { ctx.drawBullet("Additional monitoring: \(setup.additionalMonitoring.joined(separator: ", "))") }
            if !setup.linesAndAccess.isEmpty { ctx.drawBullet("Lines & access: \(setup.linesAndAccess.joined(separator: ", "))") }
            if !setup.equipment.isEmpty { ctx.drawBullet("Equipment: \(setup.equipment.joined(separator: ", "))") }
            if !setup.drugChanges.isBlank { ctx.drawBullet("Drug changes: \(setup.drugChanges)") }
            if !setup.specialNotes.isBlank { ctx.drawNote(setup.specialNotes) }
        }
        ctx.endSection()
    }

    // MARK: - Regional

    private static func drawRegional(_ ctx: inout DrawContext, _ blocks: [RegionalBlock]) {
        let named = blocks.filter { !$0.name.isBlank }
        guard !named.isEmpty else { return }

        ctx.drawSectionTitle("Regional Anaesthesia", icon: "scope")
        for (index, block) in named.enumerated() {
            if index > 0 { ctx.drawDivider() }
            ctx.drawSubheading(block.name)
            var la: [String] = []
            if !block.drug.isBlank { la.append(block.drug) }
            if !block.concentration.isBlank { la.append(block.concentration) }
            if !block.typicalVolume.isBlank { la.append(block.typicalVolume) }
            if !la.isEmpty { ctx.drawBullet("Local anaesthetic: \(la.joined(separator: " · "))") }
            var equip: [String] = []
            if !block.needleType.isBlank { equip.append(block.needleType) }
            if !block.needleLength.isBlank { equip.append(block.needleLength) }
            if !block.ultrasoundProbe.isBlank { equip.append(block.ultrasoundProbe) }
            if !equip.isEmpty { ctx.drawBullet("Equipment: \(equip.joined(separator: " · "))") }
            if !block.positioningNotes.isBlank { ctx.drawBullet("Positioning: \(block.positioningNotes)") }
            if !block.assistantNotes.isBlank { ctx.drawBullet("Assistant: \(block.assistantNotes)") }
            if !block.safetyNotes.isBlank { ctx.drawBullet("Safety: \(block.safetyNotes)") }
            if !block.setupNotes.isBlank { ctx.drawNote(block.setupNotes) }
            if !block.specialNotes.isBlank { ctx.drawNote(block.specialNotes) }
        }
        ctx.endSection()
    }

    // MARK: - Neuraxial

    private static func neuraxialHasContent(_ n: NeuraxialPreferences) -> Bool {
        if !NeuraxialSummary.configured(n).isEmpty { return true }
        return !neuraxialSpinal(n).isEmpty || !neuraxialEpidural(n).isEmpty || !neuraxialCSE(n).isEmpty
    }

    private static func neuraxialSpinal(_ n: NeuraxialPreferences) -> [String] {
        var l: [String] = []
        let s = n.spinal
        if !s.preferredPack.isBlank { l.append("Pack: \(s.preferredPack)") }
        if !s.position.isBlank { l.append("Position: \(s.position)") }
        if !s.topicalSkinAnaesthetic.isBlank { l.append("Topical skin anaesthetic: \(s.topicalSkinAnaesthetic)") }
        if !s.intrathecalAgent.isBlank { l.append("Intrathecal agent: \(s.intrathecalAgent)") }
        if !s.additives.isBlank { l.append("Additives: \(s.additives)") }
        var needle: [String] = []
        if !s.needleType.isBlank { needle.append(s.needleType) }
        if !s.needleGauge.isBlank { needle.append(s.needleGauge) }
        if !needle.isEmpty { l.append("Needle: \(needle.joined(separator: " "))") }
        if !s.introducerPreference.isBlank { l.append("Introducer: \(s.introducerPreference)") }
        if !s.specialNotes.isBlank { l.append("Notes: \(s.specialNotes)") }
        return l
    }

    private static func neuraxialEpidural(_ n: NeuraxialPreferences) -> [String] {
        var l: [String] = []
        let e = n.epidural
        if !e.epiduralKit.isBlank { l.append("Kit: \(e.epiduralKit)") }
        if e.lossOfResistanceMethod != .notSpecified { l.append("Loss of resistance: \(e.lossOfResistanceMethod.rawValue)") }
        if !e.catheterSetup.isBlank { l.append("Catheter: \(e.catheterSetup)") }
        if !e.testDosePreference.isBlank { l.append("Test dose: \(e.testDosePreference)") }
        if !e.dressingPreference.isBlank { l.append("Dressing: \(e.dressingPreference)") }
        if !e.specialNotes.isBlank { l.append("Notes: \(e.specialNotes)") }
        return l
    }

    private static func neuraxialCSE(_ n: NeuraxialPreferences) -> [String] {
        var l: [String] = []
        let c = n.combinedSpinalEpidural
        if !c.preferredKit.isBlank { l.append("Kit: \(c.preferredKit)") }
        if !c.needleThroughNeedlePreference.isBlank { l.append("Technique: \(c.needleThroughNeedlePreference)") }
        if !c.spinalSetupNotes.isBlank { l.append("Spinal: \(c.spinalSetupNotes)") }
        if !c.epiduralSetupNotes.isBlank { l.append("Epidural: \(c.epiduralSetupNotes)") }
        if !c.dressingPreference.isBlank { l.append("Dressing: \(c.dressingPreference)") }
        if !c.assistantNotes.isBlank { l.append("Assistant: \(c.assistantNotes)") }
        // Never silently omit the intrathecal agent: the legacy struct never stored
        // it, so flag it as incomplete rather than absent.
        if !l.isEmpty { l.insert("Intrathecal agent: Not recorded", at: 0) }
        return l
    }

    private static func drawNeuraxial(_ ctx: inout DrawContext, _ n: NeuraxialPreferences) {
        // Prefer the live, template-driven workflow data — the same source the
        // on-screen profile and dedicated neuraxial screens use. The full detail
        // is exported regardless of on-screen expand state.
        let configured = NeuraxialSummary.configured(n)
        guard !configured.isEmpty else {
            drawLegacyNeuraxial(&ctx, n)
            return
        }
        ctx.drawSectionTitle("Neuraxial", icon: "figure.walk.motion")
        for (index, item) in configured.enumerated() {
            if index > 0 { ctx.drawDivider() }
            ctx.drawSubheading(item.definition.title)
            for line in NeuraxialSummary.lines(for: item) {
                ctx.drawBullet("\(line.label): \(line.value)")
            }
        }
        ctx.endSection()
    }

    /// Fallback rendering for older profiles whose neuraxial data only exists in
    /// the legacy structs (pre-workflow).
    private static func drawLegacyNeuraxial(_ ctx: inout DrawContext, _ n: NeuraxialPreferences) {
        let spinal = neuraxialSpinal(n)
        let epidural = neuraxialEpidural(n)
        let cse = neuraxialCSE(n)
        guard !spinal.isEmpty || !epidural.isEmpty || !cse.isEmpty else { return }

        ctx.drawSectionTitle("Neuraxial", icon: "figure.walk.motion")
        if !spinal.isEmpty {
            ctx.drawSubheading("Spinal")
            for line in spinal { ctx.drawBullet(line) }
        }
        if !epidural.isEmpty {
            if !spinal.isEmpty { ctx.drawDivider() }
            ctx.drawSubheading("Epidural")
            for line in epidural { ctx.drawBullet(line) }
        }
        if !cse.isEmpty {
            ctx.drawDivider()
            ctx.drawSubheading("Combined Spinal Epidural")
            for line in cse { ctx.drawBullet(line) }
        }
        ctx.endSection()
    }

    // MARK: - Notes

    private static func drawNotes(_ ctx: inout DrawContext, _ doctor: Doctor) {
        let hasBio = !doctor.biography.isBlank
        let hasNotes = !doctor.personalNotes.isBlank
        guard hasBio || hasNotes else { return }
        ctx.drawSectionTitle("Notes", icon: "note.text")
        if hasBio { ctx.drawNote(doctor.biography) }
        if hasNotes { ctx.drawNote(doctor.personalNotes) }
        ctx.endSection()
    }

    // MARK: - Hospital appendix

    private static func drawHospitalAppendix(_ ctx: inout DrawContext, _ hospital: Hospital) {
        let o = hospital.orientationOrEmpty
        // Start the appendix on a fresh page so it reads as a distinct guide.
        ctx.beginPage()
        ctx.drawSectionTitle("Hospital Information — \(hospital.name)", icon: "building.2")
        ctx.drawCaption("Orientation appendix for locums and new staff.")

        if !o.equipmentLocations.isEmpty {
            ctx.drawGroupLabel("Equipment Locations")
            for item in o.equipmentLocations {
                ctx.drawSubheading(item.title)
                let located = item.locatedSpots
                if located.isEmpty {
                    if !item.accessInstructions.isBlank { ctx.drawBullet("Access: \(item.accessInstructions)") }
                } else if located.count == 1, let only = located.first {
                    ctx.drawBullet("Location: \(only.location)")
                    if !only.accessInstructions.isBlank { ctx.drawBullet("Access: \(only.accessInstructions)") }
                } else {
                    for (index, spot) in located.enumerated() {
                        ctx.drawBullet("Location \(index + 1): \(spot.location)")
                        if !spot.accessInstructions.isBlank { ctx.drawBullet("   Access: \(spot.accessInstructions)") }
                    }
                }
                if !item.notes.isBlank { ctx.drawNote(item.notes) }
            }
        }

        if !o.contacts.isEmpty {
            ctx.drawGroupLabel("Important Contacts")
            for contact in o.contacts {
                var lead = contact.roleTitle
                if !contact.name.isBlank { lead += " — \(contact.name)" }
                ctx.drawSubheading(lead)
                var lines: [String] = []
                if !contact.phone.isBlank { lines.append("Phone \(contact.phone)") }
                if !contact.extensionNumber.isBlank { lines.append("Ext \(contact.extensionNumber)") }
                if !contact.pager.isBlank { lines.append("Pager \(contact.pager)") }
                if !contact.email.isBlank { lines.append(contact.email) }
                if !lines.isEmpty { ctx.drawBullet(lines.joined(separator: " · ")) }
                if !contact.notes.isBlank { ctx.drawNote(contact.notes) }
            }
        }

        if o.sickCall.hasContent {
            ctx.drawGroupLabel("Sick Call / Illness Reporting")
            let sc = o.sickCall
            if !sc.whoToContact.isBlank { ctx.drawValueRow(label: "Who to contact", value: sc.whoToContact) }
            if !sc.phone.isBlank { ctx.drawValueRow(label: "Phone", value: sc.phone) }
            if !sc.noticePeriod.isBlank { ctx.drawValueRow(label: "Notice period", value: sc.noticePeriod) }
            if !sc.backupContact.isBlank { ctx.drawValueRow(label: "Backup contact", value: sc.backupContact) }
            if !sc.notes.isBlank { ctx.drawNote(sc.notes) }
        }

        if !o.policies.isEmpty {
            ctx.drawGroupLabel("Policies & Workflows")
            for policy in o.policies where !policy.title.isBlank {
                ctx.drawSubheading(policy.title)
                if !policy.body.isBlank { ctx.drawNote(policy.body) }
            }
        }
        ctx.endSection()
    }

    // MARK: - QR code (architected; disabled until deep-linking ships)

    private static func drawQRCode(_ ctx: inout DrawContext, doctor: Doctor) {
        let qrSize: CGFloat = 96
        ctx.ensureSpace(qrSize + 24)
        ctx.drawDivider()
        ctx.cursorY += 6
        let link = ProfileDeepLink.url(for: doctor)
        if let image = QRCodeRenderer.image(from: link, size: qrSize) {
            image.draw(in: CGRect(x: margin, y: ctx.cursorY, width: qrSize, height: qrSize))
        } else {
            UIColor(Theme.accent).withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: ctx.cursorY, width: qrSize, height: qrSize), cornerRadius: 8).fill()
        }
        let textX = margin + qrSize + 16
        let textWidth = ctx.contentWidth - qrSize - 16
        "Open in ORPrep".draw(
            at: CGPoint(x: textX, y: ctx.cursorY + 8),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor(Theme.accentDeep)
            ]
        )
        let caption = "Scan to open this consultant's profile in the app. Deep-linking arrives in a future update."
        caption.draw(
            in: CGRect(x: textX, y: ctx.cursorY + 28, width: textWidth, height: 48),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        ctx.cursorY += qrSize + 12
    }
}

/// Builds the (future) deep link for a consultant profile. Architected now so the
/// QR code is stable; deep-link handling can be wired later without changing URLs.
nonisolated enum ProfileDeepLink {
    static let scheme = "preferenceflow"
    static let host = "consultant"

    static func url(for doctor: Doctor) -> String {
        "\(scheme)://\(host)/\(doctor.id.uuidString)"
    }

    /// Parses a scanned/opened deep link back into a consultant id.
    static func doctorID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let last = url.pathComponents.last { $0 != "/" }
        return last.flatMap(UUID.init)
    }
}

/// Renders a QR code image from a string using CoreImage.
@MainActor
enum QRCodeRenderer {
    static func image(from string: String, size: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage, output.extent.width > 0 else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Mutable drawing cursor that lays out content top-to-bottom and paginates.
@MainActor
private struct DrawContext {
    let context: UIGraphicsPDFRendererContext
    let pageSize: CGSize
    let margin: CGFloat
    var cursorY: CGFloat = 0
    private(set) var pageCount: Int = 0

    var contentWidth: CGFloat { pageSize.width - margin * 2 }
    private var bottomLimit: CGFloat { pageSize.height - margin - 18 }

    init(context: UIGraphicsPDFRendererContext, pageSize: CGSize, margin: CGFloat) {
        self.context = context
        self.pageSize = pageSize
        self.margin = margin
    }

    mutating func beginPage() {
        context.beginPage()
        pageCount += 1
        cursorY = margin
        drawFooter()
    }

    /// Ensures `needed` vertical points are available, starting a new page if not.
    mutating func ensureSpace(_ needed: CGFloat) {
        if cursorY + needed > bottomLimit {
            beginPage()
        }
    }

    private func drawFooter() {
        let footer = "ORPrep · Preference reference only — not clinical advice"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        let y = pageSize.height - margin + 6
        footer.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        let page = "\(pageCount)"
        let size = page.size(withAttributes: attrs)
        page.draw(at: CGPoint(x: pageSize.width - margin - size.width, y: y), withAttributes: attrs)
    }

    // MARK: Drawing primitives

    mutating func drawSectionTitle(_ title: String, icon: String? = nil) {
        // Keep the heading with at least one following line.
        ensureSpace(54)
        cursorY += 6
        let ruleRect = CGRect(x: margin, y: cursorY, width: 30, height: 3)
        UIColor(Theme.accent).setFill()
        UIBezierPath(roundedRect: ruleRect, cornerRadius: 1.5).fill()
        cursorY += 9
        var titleX = margin
        if let icon, let image = UIImage(systemName: icon)?
            .withTintColor(UIColor(Theme.accentDeep), renderingMode: .alwaysOriginal) {
            let iconSize: CGFloat = 17
            let aspect = image.size.width / max(image.size.height, 1)
            image.draw(in: CGRect(x: margin, y: cursorY + 1, width: iconSize * aspect, height: iconSize))
            titleX = margin + iconSize * aspect + 8
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: UIColor(Theme.accentDeep)
        ]
        title.draw(at: CGPoint(x: titleX, y: cursorY), withAttributes: attrs)
        cursorY += 26
    }

    mutating func drawCaption(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let height = text.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs, context: nil
        ).height
        ensureSpace(ceil(height) + 6)
        text.draw(in: CGRect(x: margin, y: cursorY, width: contentWidth, height: ceil(height) + 2), withAttributes: attrs)
        cursorY += ceil(height) + 8
    }

    mutating func drawGroupLabel(_ text: String) {
        ensureSpace(28)
        cursorY += 6
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
            .foregroundColor: UIColor(Theme.accent),
            .kern: 0.8
        ]
        text.uppercased().draw(at: CGPoint(x: margin, y: cursorY), withAttributes: attrs)
        cursorY += 18
    }

    mutating func drawSubheading(_ text: String) {
        ensureSpace(36)
        cursorY += 4
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12.5, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        text.draw(at: CGPoint(x: margin, y: cursorY), withAttributes: attrs)
        cursorY += 18
    }

    mutating func drawDivider() {
        ensureSpace(12)
        cursorY += 6
        let rect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 0.5)
        UIColor.separator.setFill()
        UIBezierPath(rect: rect).fill()
        cursorY += 6
    }

    mutating func drawValueRow(label: String, value: String) {
        guard !value.isBlank else { return }
        let labelWidth: CGFloat = 150
        let valueWidth = contentWidth - labelWidth - 10
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let valueHeight = value.boundingRect(
            with: CGSize(width: valueWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: valueAttrs, context: nil
        ).height
        let rowHeight = max(16, ceil(valueHeight)) + 4
        ensureSpace(rowHeight)
        label.draw(in: CGRect(x: margin, y: cursorY, width: labelWidth, height: rowHeight), withAttributes: labelAttrs)
        value.draw(
            in: CGRect(x: margin + labelWidth + 10, y: cursorY, width: valueWidth, height: ceil(valueHeight) + 2),
            withAttributes: valueAttrs
        )
        cursorY += rowHeight
    }

    mutating func drawBullet(_ text: String) {
        let textWidth = contentWidth - 16
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let height = text.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs, context: nil
        ).height
        let rowHeight = ceil(height) + 5
        ensureSpace(rowHeight)
        let dotAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .bold),
            .foregroundColor: UIColor(Theme.accent)
        ]
        "•".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: dotAttrs)
        text.draw(in: CGRect(x: margin + 14, y: cursorY, width: textWidth, height: ceil(height) + 2), withAttributes: attrs)
        cursorY += rowHeight
    }

    mutating func drawNote(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let textWidth = contentWidth - 12
        let height = text.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs, context: nil
        ).height
        let rowHeight = ceil(height) + 6
        ensureSpace(rowHeight)
        text.draw(in: CGRect(x: margin + 12, y: cursorY, width: textWidth, height: ceil(height) + 2), withAttributes: attrs)
        cursorY += rowHeight
    }

    mutating func drawMuted(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        ensureSpace(16)
        text.draw(at: CGPoint(x: margin, y: cursorY), withAttributes: attrs)
        cursorY += 16
    }

    mutating func drawDisclaimer(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: UIColor(Theme.accentDeep)
        ]
        let textWidth = contentWidth
        let height = text.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs, context: nil
        ).height
        ensureSpace(ceil(height) + 4)
        text.draw(in: CGRect(x: margin, y: cursorY, width: textWidth, height: ceil(height) + 2), withAttributes: attrs)
        cursorY += ceil(height) + 4
    }

    /// Draws a wrapping row of rounded pill badges.
    mutating func drawPills(_ items: [String], filled: Bool = false) {
        guard !items.isEmpty else { return }
        let font = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
        let hPad: CGFloat = 10
        let lineH: CGFloat = 22
        let gap: CGFloat = 6
        var x = margin
        ensureSpace(lineH + 6)
        let textColor = filled ? UIColor.white : UIColor(Theme.accentDeep)
        let bgColor = filled ? UIColor(Theme.accent) : UIColor(Theme.accent).withAlphaComponent(0.12)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        for item in items {
            let w = item.size(withAttributes: attrs).width + hPad * 2
            if x + w > margin + contentWidth {
                x = margin
                cursorY += lineH + gap
                ensureSpace(lineH + 6)
            }
            let rect = CGRect(x: x, y: cursorY, width: w, height: lineH)
            bgColor.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: lineH / 2).fill()
            let textSize = item.size(withAttributes: attrs)
            item.draw(at: CGPoint(x: x + hPad, y: cursorY + (lineH - textSize.height) / 2), withAttributes: attrs)
            x += w + gap
        }
        cursorY += lineH + 8
    }

    mutating func endSection() {
        cursorY += 12
    }
}
