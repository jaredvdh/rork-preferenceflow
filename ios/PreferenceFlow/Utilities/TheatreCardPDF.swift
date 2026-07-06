//
//  TheatreCardPDF.swift
//  PreferenceFlow
//

import UIKit
import SwiftUI

/// Renders a consultant's profile into a single-page, laminate-ready preference
/// card — the kind that lives in a folder by the anaesthetic machine. One A4
/// page: dark teal header with name and initials, a tidy two-column body
/// (Airway · Drugs on the left, Equipment · Notes on the right), a condensed
/// specialty setups band beneath, and a QR code that re-opens the live profile
/// in the app. Pure layout; mirrors the on-screen card and carries the same
/// "reference only" disclaimer.
@MainActor
enum TheatreCardPDF {
    // A4 at 72 dpi.
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 36
    private static let gutter: CGFloat = 22

    /// One row inside a card: a bold line and an optional muted sub-line
    /// (used for drug concentrations / preparation detail).
    private struct CardItem {
        let text: String
        var subtext: String? = nil
    }

    // MARK: - Public API

    static func data(for doctor: Doctor, hospital: Hospital?, region: TerminologyRegion) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let headerBottom = drawHeader(doctor: doctor, hospital: hospital)
            let columnsBottom = drawColumns(doctor: doctor, region: region, top: headerBottom + 18)
            let specialtyBottom = drawSpecialty(doctor.activeSpecialtySetups, top: columnsBottom + 14)
            drawFooter(doctor: doctor, from: specialtyBottom)
        }
    }

    static func writeFile(for doctor: Doctor, hospital: Hospital?, region: TerminologyRegion) throws -> URL {
        let pdf = data(for: doctor, hospital: hospital, region: region)
        let safeName = doctor.fullName.isEmpty
            ? "Consultant"
            : doctor.fullName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)_TheatreCard.pdf")
        try pdf.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Header

    private static func drawHeader(doctor: Doctor, hospital: Hospital?) -> CGFloat {
        let bandHeight: CGFloat = 116
        let band = CGRect(x: 0, y: 0, width: pageSize.width, height: bandHeight)
        let cg = UIGraphicsGetCurrentContext()
        cg?.saveGState()
        cg?.addRect(band)
        cg?.clip()
        let colors = [UIColor(Theme.accentBright).cgColor, UIColor(Theme.accentDeep).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            cg?.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: pageSize.width, y: bandHeight), options: [])
        }
        cg?.restoreGState()

        // Initials / photo medallion.
        let avatarSize: CGFloat = 70
        let avatarRect = CGRect(x: margin, y: (bandHeight - avatarSize) / 2, width: avatarSize, height: avatarSize)
        if let data = doctor.photoData, let image = UIImage(data: data) {
            cg?.saveGState()
            UIBezierPath(ovalIn: avatarRect).addClip()
            let aspect = max(avatarSize / image.size.width, avatarSize / image.size.height)
            let drawSize = CGSize(width: image.size.width * aspect, height: image.size.height * aspect)
            image.draw(in: CGRect(x: avatarRect.midX - drawSize.width / 2, y: avatarRect.midY - drawSize.height / 2, width: drawSize.width, height: drawSize.height))
            cg?.restoreGState()
            UIColor.white.withAlphaComponent(0.8).setStroke()
            let ring = UIBezierPath(ovalIn: avatarRect); ring.lineWidth = 2.5; ring.stroke()
        } else {
            UIColor.white.withAlphaComponent(0.18).setFill()
            UIBezierPath(ovalIn: avatarRect).fill()
            UIColor.white.withAlphaComponent(0.55).setStroke()
            let ring = UIBezierPath(ovalIn: avatarRect); ring.lineWidth = 2; ring.stroke()
            let initials = doctor.initials.isEmpty ? "?" : doctor.initials
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let size = initials.size(withAttributes: attrs)
            initials.draw(at: CGPoint(x: avatarRect.midX - size.width / 2, y: avatarRect.midY - size.height / 2), withAttributes: attrs)
        }

        let textLeft = avatarRect.maxX + 16
        let textWidth = pageSize.width - margin - textLeft

        // App branding small and secondary to the consultant's name.
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .heavy),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            .kern: 1.4
        ]
        let brand = "ORPrep"
        brand.draw(at: CGPoint(x: textLeft, y: 24), withAttributes: brandAttrs)
        let brandWidth = brand.size(withAttributes: brandAttrs).width
        " · PREFERENCE CARD".draw(
            at: CGPoint(x: textLeft + brandWidth, y: 24),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .kern: 1.4
            ]
        )
        doctor.displayName.draw(
            in: CGRect(x: textLeft, y: 37, width: textWidth, height: 32),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 25, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )

        var parts: [String] = []
        if !doctor.role.isEmpty { parts.append(doctor.role) }
        if let hospital, !hospital.name.isEmpty { parts.append(hospital.name) }
        let dept = doctor.department.isEmpty ? (hospital?.department ?? "") : doctor.department
        if !dept.isEmpty { parts.append(dept) }
        let subtitle = parts.joined(separator: "  ·  ")
        if !subtitle.isEmpty {
            subtitle.draw(
                in: CGRect(x: textLeft, y: 71, width: textWidth, height: 16),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11.5, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.92)
                ]
            )
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let updated = "Updated \(formatter.string(from: doctor.updatedAt))"
        updated.draw(
            at: CGPoint(x: textLeft, y: 90),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
        )
        return bandHeight
    }

    // MARK: - Two-column body

    private static func drawColumns(doctor: Doctor, region: TerminologyRegion, top: CGFloat) -> CGFloat {
        let colWidth = (pageSize.width - margin * 2 - gutter) / 2
        let leftX = margin
        let rightX = margin + colWidth + gutter

        var leftY = top
        leftY = drawCard(title: "Airway", icon: "lungs.fill", items: airwayItems(doctor.airway, region: region), x: leftX, y: leftY, width: colWidth)
        leftY = drawCard(title: "Drugs", icon: "syringe.fill", items: drugItems(doctor, region: region), x: leftX, y: leftY + 10, width: colWidth)

        var rightY = top
        rightY = drawCard(title: "Equipment & Monitoring", icon: "waveform.path.ecg", items: equipmentItems(doctor), x: rightX, y: rightY, width: colWidth)
        rightY = drawCard(title: "Notes & Comfort", icon: "note.text", items: notesItems(doctor), x: rightX, y: rightY + 10, width: colWidth)
        rightY = drawCard(title: "\(region.paediatric) Reference", icon: "figure.child", items: paediatricReferenceItems(), x: rightX, y: rightY + 10, width: colWidth)

        return max(leftY, rightY)
    }

    /// Draws one rounded "card" (title strip + item list) and returns its bottom Y.
    private static func drawCard(title: String, icon: String, items: [CardItem], x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let isEmpty = items.isEmpty
        let displayItems: [CardItem] = isEmpty ? [CardItem(text: "Not specified")] : items
        let titleH: CGFloat = 26
        let itemFont = UIFont.systemFont(ofSize: 10.5, weight: .regular)
        let subFont = UIFont.systemFont(ofSize: 9, weight: .regular)
        let textInset: CGFloat = 22
        let itemWidth = width - textInset - 12

        // Measure body.
        var bodyH: CGFloat = 8
        for item in displayItems {
            bodyH += itemHeight(item.text, font: itemFont, width: itemWidth) + 5
            if let sub = item.subtext, !sub.isBlank {
                bodyH += itemHeight(sub, font: subFont, width: itemWidth) + 2
            }
        }
        bodyH += 4
        let cardH = titleH + bodyH

        // Background.
        let cardRect = CGRect(x: x, y: y, width: width, height: cardH)
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: cardRect, cornerRadius: 12).fill()
        UIColor(Theme.accent).withAlphaComponent(0.18).setStroke()
        let border = UIBezierPath(roundedRect: cardRect, cornerRadius: 12); border.lineWidth = 0.75; border.stroke()

        // Title strip.
        var titleX = x + 12
        if let image = UIImage(systemName: icon)?.withTintColor(UIColor(Theme.accentDeep), renderingMode: .alwaysOriginal) {
            let s: CGFloat = 13
            let aspect = image.size.width / max(image.size.height, 1)
            image.draw(in: CGRect(x: titleX, y: y + 8, width: s * aspect, height: s))
            titleX += s * aspect + 6
        }
        title.uppercased().draw(
            at: CGPoint(x: titleX, y: y + 8),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
                .foregroundColor: UIColor(Theme.accentDeep),
                .kern: 0.6
            ]
        )

        // Items.
        var itemY = y + titleH
        for item in displayItems {
            let dotAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: isEmpty ? UIColor.tertiaryLabel : UIColor(Theme.accent)
            ]
            "•".draw(at: CGPoint(x: x + 12, y: itemY), withAttributes: dotAttrs)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: itemFont,
                .foregroundColor: isEmpty ? UIColor.tertiaryLabel : UIColor.label
            ]
            let h = itemHeight(item.text, font: itemFont, width: itemWidth)
            item.text.draw(in: CGRect(x: x + textInset, y: itemY, width: itemWidth, height: h + 2), withAttributes: attrs)
            itemY += h + 5
            if let sub = item.subtext, !sub.isBlank {
                let subAttrs: [NSAttributedString.Key: Any] = [
                    .font: subFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let sh = itemHeight(sub, font: subFont, width: itemWidth)
                sub.draw(in: CGRect(x: x + textInset, y: itemY, width: itemWidth, height: sh + 2), withAttributes: subAttrs)
                itemY += sh + 2
            }
        }
        return y + cardH
    }

    private static func itemHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let h = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil
        ).height
        return ceil(h)
    }

    // MARK: - Specialty setups (full width, condensed)

    private static func drawSpecialty(_ setups: [SpecialtySetup], top: CGFloat) -> CGFloat {
        guard !setups.isEmpty else { return top }
        var y = top
        let width = pageSize.width - margin * 2

        "SPECIALTY SETUPS".draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
                .foregroundColor: UIColor(Theme.accentDeep),
                .kern: 0.8
            ]
        )
        y += 20

        let columns = 2
        let colW = (width - gutter) / CGFloat(columns)
        var col = 0
        var rowTopY = y
        var rowMaxY = y
        for setup in setups {
            let x = margin + CGFloat(col) * (colW + gutter)
            let bottom = drawCard(
                title: "\(specialtyEmoji(setup.specialty)) \(setup.specialty.rawValue)",
                icon: "square.grid.2x2.fill",
                items: specialtyItems(setup),
                x: x, y: rowTopY, width: colW
            )
            rowMaxY = max(rowMaxY, bottom)
            col += 1
            if col == columns {
                col = 0
                rowTopY = rowMaxY + 10
                rowMaxY = rowTopY
            }
        }
        return col == 0 ? rowMaxY : max(rowMaxY, rowTopY)
    }

    // MARK: - Footer (QR + disclaimer)

    private static func drawFooter(doctor: Doctor, from contentBottom: CGFloat) {
        let qrSize: CGFloat = 74
        let bottomLineH: CGFloat = 14
        let footerTop = pageSize.height - margin - qrSize - bottomLineH
        let y = max(contentBottom + 16, footerTop)

        // Hairline divider.
        UIColor.separator.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y - 12, width: pageSize.width - margin * 2, height: 0.5)).fill()

        let qrRect = CGRect(x: margin, y: y, width: qrSize, height: qrSize)
        let link = ProfileDeepLink.url(for: doctor)
        if let image = QRCodeRenderer.image(from: link, size: qrSize) {
            image.draw(in: qrRect)
        } else {
            UIColor(Theme.accent).withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: qrRect, cornerRadius: 8).fill()
        }

        let textX = qrRect.maxX + 14
        let textWidth = pageSize.width - margin - textX
        "Open in ORPrep".draw(
            at: CGPoint(x: textX, y: y + 4),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor(Theme.accentDeep)
            ]
        )
        let scanName = doctor.displayName.isEmpty ? "this consultant" : "\(doctor.displayName)'s"
        "Scan to open \(scanName) live profile in ORPrep — always up to date."
            .draw(
                in: CGRect(x: textX, y: y + 22, width: textWidth, height: 32),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        let verification = doctor.isVerifiedProfile
            ? "Verified — preferences confirmed with the consultant."
            : "UNVERIFIED — created from memory / second-hand. Confirm with the consultant before relying on this card."
        verification.draw(
            in: CGRect(x: textX, y: y + 44, width: textWidth, height: 12),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: doctor.isVerifiedProfile ? UIColor.secondaryLabel : UIColor(Color(hex: "E0883B"))
            ]
        )
        "Preference reference only — not clinical advice. Always confirm against the patient and local policy."
            .draw(
                in: CGRect(x: textX, y: y + 58, width: textWidth, height: 22),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 8.5, weight: .medium),
                    .foregroundColor: UIColor(Theme.accentDeep)
                ]
            )

        // Centered generation credit at the very bottom of the page.
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        let credit = "Generated by ORPrep · \(formatter.string(from: Date()))"
        let creditAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: UIColor.tertiaryLabel,
            .kern: 0.3
        ]
        let creditSize = credit.size(withAttributes: creditAttrs)
        credit.draw(
            at: CGPoint(x: (pageSize.width - creditSize.width) / 2, y: pageSize.height - margin + 2),
            withAttributes: creditAttrs
        )
    }

    // MARK: - Content extraction

    private static func airwayItems(_ a: AirwayPreferences, region: TerminologyRegion) -> [CardItem] {
        var items: [CardItem] = []
        if !a.adultMale.tubeSize.isBlank { items.append(CardItem(text: "ETT \(a.adultMale.tubeSize) (M)")) }
        if !a.adultFemale.tubeSize.isBlank { items.append(CardItem(text: "ETT \(a.adultFemale.tubeSize) (F)")) }
        if a.adultMale.tubeType != .standard { items.append(CardItem(text: "Tube: \(a.adultMale.tubeType.rawValue) (M)")) }
        if a.adultFemale.tubeType != .standard { items.append(CardItem(text: "Tube: \(a.adultFemale.tubeType.rawValue) (F)")) }

        // Laryngoscopy — show both male and female when they differ, otherwise a
        // single line. Never silently drop the female parameter.
        let mBlank = airwaySetupBlank(a.adultMale)
        let fBlank = airwaySetupBlank(a.adultFemale)
        let mLaryn = laryngoscopyLine(a.adultMale)
        let fLaryn = laryngoscopyLine(a.adultFemale)
        if !mBlank && !fBlank {
            if mLaryn == fLaryn {
                if !mLaryn.isBlank { items.append(CardItem(text: mLaryn)) }
            } else {
                if !mLaryn.isBlank { items.append(CardItem(text: "M: \(mLaryn)")) }
                if !fLaryn.isBlank { items.append(CardItem(text: "F: \(fLaryn)")) }
            }
        } else {
            let line = !mBlank ? mLaryn : fLaryn
            if !line.isBlank { items.append(CardItem(text: line)) }
        }

        let sg = a.supraglottic
        if !sg.adultFemale.isEmpty || !sg.adultMale.isEmpty {
            var sgParts: [String] = []
            if !sg.adultFemale.isEmpty { sgParts.append("F \(sg.adultFemale.summary)") }
            if !sg.adultMale.isEmpty { sgParts.append("M \(sg.adultMale.summary)") }
            items.append(CardItem(text: "SGA: \(sgParts.joined(separator: " / "))"))
        }

        if !a.adultMale.styletPreference.isBlank { items.append(CardItem(text: "Stylet: \(a.adultMale.styletPreference)")) }
        if !a.adultMale.bougiePreference.isBlank { items.append(CardItem(text: "Bougie: \(a.adultMale.bougiePreference)")) }

        let paed = a.paediatric
        if !paed.tapingTechnique.isBlank {
            var taping = "Paed taping: \(paed.tapingTechnique)"
            if !paed.tapingTape.isBlank { taping += " (\(paed.tapingTape))" }
            items.append(CardItem(text: taping))
        }
        if paed.tapingTechniquePhoto != nil { items.append(CardItem(text: "Paed taping photo in app")) }

        let da = a.difficultAirway
        if !da.backupPlan.isBlank { items.append(CardItem(text: "Backup: \(da.backupPlan)")) }
        return items
    }

    /// One-line laryngoscopy summary for a single airway setup (technique, video
    /// system and blade).
    private static func laryngoscopyLine(_ setup: AirwaySetup) -> String {
        var laryngoscopy = setup.primaryTechnique.rawValue
        if setup.primaryTechnique == .video, setup.videoSystem != .none { laryngoscopy += " · \(setup.videoSystem.rawValue)" }
        if setup.blade != .none {
            laryngoscopy += " · \(setup.blade.rawValue)"
            if !setup.bladeSize.isBlank { laryngoscopy += " \(setup.bladeSize)" }
        }
        return laryngoscopy
    }

    private static func airwaySetupBlank(_ s: AirwaySetup) -> Bool {
        s.tubeSize.isBlank && s.blade == .none && s.videoSystem == .none
    }

    /// A fixed age/weight paediatric airway lookup. Included on every printed card
    /// since it cannot respond to a live age input. Reference only.
    private static func paediatricReferenceItems() -> [CardItem] {
        var items: [CardItem] = [
            CardItem(text: "ETT (mm ID)", subtext: "Cuffed = age÷4+3.5 · Uncuffed = age÷4+4")
        ]
        let ettAges = [1, 2, 4, 6, 8, 10]
        let ettLine = ettAges.map { age in
            "\(age)y \(PaediatricETT.formatted(ageYears: Double(age), cuffed: true))/\(PaediatricETT.formatted(ageYears: Double(age), cuffed: false))"
        }.joined(separator: "  ")
        items.append(CardItem(text: ettLine))
        items.append(CardItem(
            text: "Blades (Miller / Mac)",
            subtext: PaediatricBlade.rows.map { "\($0.ageGroup): M \($0.miller) / Mac \($0.macintosh)" }.joined(separator: "\n")
        ))
        items.append(CardItem(
            text: "SGA by weight (i-gel / LMA)",
            subtext: PaediatricSupraglottic.rows.map { "\($0.weightBand): i-gel \($0.igel) / LMA \($0.lma)" }.joined(separator: "\n")
        ))
        items.append(CardItem(text: "Reference estimate only — confirm against the patient and local policy."))
        return items
    }

    private static func drugItems(_ doctor: Doctor, region: TerminologyRegion) -> [CardItem] {
        if let setup = doctor.adultDrugs, setup.hasContent {
            return drugLines(setup)
        }
        if let p = doctor.paediatricDrugs, p.hasContent {
            return drugLines(p)
        }
        return []
    }

    /// One row per drug category: the agent(s) on the bold line, and any
    /// concentration / preparation detail as muted sub-text. Pulls from the same
    /// selection data the Export PDF uses (selected agents, preparedBy, notes).
    private static func drugLines(_ setup: DrugsFluidsSetup) -> [CardItem] {
        var items: [CardItem] = []
        if setup.hasMaintenance {
            let detail = setup.maintenanceDetail
            items.append(CardItem(text: "Maintenance: \(setup.maintenanceTechnique.rawValue)",
                                  subtext: detail.isBlank ? nil : detail))
        }
        for category in DrugCategory.drugCases {
            let sel = setup.selection(for: category)
            guard !sel.allAgents.isEmpty else { continue }
            let main = "\(category.rawValue): \(sel.allAgents.joined(separator: ", "))"
            var subParts: [String] = []
            if !sel.notes.isBlank { subParts.append(sel.notes) }
            if sel.preparedBy != .caseDependent { subParts.append(sel.preparedBy.rawValue) }
            let sub = subParts.isEmpty ? nil : subParts.joined(separator: " · ")
            items.append(CardItem(text: main, subtext: sub))
        }
        let fluids = setup.fluids
        if !fluids.isEmpty {
            var main = "IV Fluids: \(fluids.primary)"
            if !fluids.secondary.isBlank { main += " → \(fluids.secondary)" }
            var subParts: [String] = ["Giving set: \(fluids.givingSet.rawValue)"]
            if !fluids.notes.isBlank { subParts.append(fluids.notes) }
            items.append(CardItem(text: main, subtext: subParts.joined(separator: " · ")))
        }
        let emergency = setup.emergency
        if !emergency.isEmpty {
            let agents = emergency.allAgents.joined(separator: ", ")
            let main = agents.isEmpty ? "Emergency drugs" : "Emergency drugs: \(agents)"
            var subParts: [String] = []
            if emergency.hasPushDose { subParts.append("Push-dose adrenaline \(emergency.pushDoseAdrenalineDilution)") }
            if emergency.paediatricSuxamethonium { subParts.append("Paediatric: Sux kept drawn up") }
            if emergency.preparedBy != .caseDependent { subParts.append(emergency.preparedBy.rawValue) }
            if !emergency.notes.isBlank { subParts.append(emergency.notes) }
            items.append(CardItem(text: main, subtext: subParts.isEmpty ? nil : subParts.joined(separator: " · ")))
        }
        return items
    }

    private static func equipmentItems(_ doctor: Doctor) -> [CardItem] {
        var items: [CardItem] = []
        // Monitoring — same conditional logic as the on-screen card: the
        // standard ASA baseline alone, or baseline plus each genuine addition.
        let monitoring = doctor.monitoringPreferences
        items.append(CardItem(
            text: "Monitoring: \(monitoring.displayItems.joined(separator: ", "))",
            subtext: monitoring.notes.isBlank ? nil : monitoring.notes
        ))
        // Regional equipment highlights. (IV fluids belong in Drugs only.)
        for block in doctor.regionalBlocks where !block.name.isBlank {
            var equip: [String] = []
            if !block.ultrasoundProbe.isBlank { equip.append(block.ultrasoundProbe) }
            if !block.needleType.isBlank { equip.append(block.needleType) }
            let detail = equip.isEmpty ? "" : " (\(equip.joined(separator: ", ")))"
            items.append(CardItem(
                text: "\(block.name)\(detail)",
                subtext: block.setupPhoto != nil ? "See app for setup photo" : nil
            ))
        }
        // Arterial & central lines — pulled from the live workflow data (same
        // source as the on-screen "Arterial & Central Lines" section).
        for item in ProceduralSummary.configured(doctor.proceduralPreferences) {
            var detailParts = ProceduralSummary.lines(for: item)
                .filter { !$0.isNote }
                .prefix(4)
                .map { "\($0.label): \($0.value)" }
            if item.resolved.customization.setupPhoto != nil { detailParts.append("See app for setup photo") }
            let detail = detailParts.joined(separator: " · ")
            items.append(CardItem(text: item.definition.title, subtext: detail.isBlank ? nil : detail))
        }
        // Neuraxial — pulled from the live workflow data (same source as the
        // on-screen profile), with a legacy fallback for older profiles.
        let n = doctor.neuraxial
        let configured = NeuraxialSummary.configured(n)
        if !configured.isEmpty {
            for item in configured {
                var detailParts = NeuraxialSummary.lines(for: item)
                    .prefix(4)
                    .map { "\($0.label): \($0.value)" }
                if item.resolved.customization.setupPhoto != nil { detailParts.append("See app for setup photo") }
                let detail = detailParts.joined(separator: " · ")
                items.append(CardItem(text: item.definition.title, subtext: detail.isBlank ? nil : detail))
            }
        } else {
            if !n.spinal.preferredPack.isBlank { items.append(CardItem(text: "Spinal pack: \(n.spinal.preferredPack)")) }
            if !n.spinal.topicalSkinAnaesthetic.isBlank { items.append(CardItem(text: "Spinal skin LA: \(n.spinal.topicalSkinAnaesthetic)")) }
            if !n.spinal.intrathecalAgent.isBlank { items.append(CardItem(text: "Intrathecal agent: \(n.spinal.intrathecalAgent)")) }
            if !n.epidural.epiduralKit.isBlank { items.append(CardItem(text: "Epidural kit: \(n.epidural.epiduralKit)")) }
            // Legacy CSE struct never stored an intrathecal agent — surface CSE as
            // incomplete rather than omitting it silently.
            if n.legacyCSEHasContent {
                let c = n.combinedSpinalEpidural
                var parts: [String] = ["Intrathecal agent: Not recorded"]
                if !c.preferredKit.isBlank { parts.append("Kit: \(c.preferredKit)") }
                items.append(CardItem(text: "Combined Spinal Epidural", subtext: parts.joined(separator: " · ")))
            }
        }
        return items
    }

    private static func notesItems(_ doctor: Doctor) -> [CardItem] {
        var items: [CardItem] = []
        let g = doctor.general
        // Sterile and non-sterile gloves are distinct items; show whichever are set.
        if !g.sterileGloveDisplay.isBlank {
            items.append(CardItem(text: "Sterile gloves: \(g.sterileGloveDisplay)"))
        }
        if !g.nonSterileGloveDisplay.isBlank {
            items.append(CardItem(text: "Non-sterile gloves: \(g.nonSterileGloveDisplay)"))
        }
        items.append(CardItem(text: "Gown: \(g.gownSize.isBlank ? "—" : g.gownSize)"))
        if !g.coffeePreference.isBlank { items.append(CardItem(text: "Coffee: \(g.coffeePreference)")) }
        if !g.contactPreferences.isBlank { items.append(CardItem(text: "Comms: \(g.contactPreferences)")) }

        // Workflow summary: arrival, assistant medication prep, briefing style.
        var workflow: [String] = []
        if g.arriveBeforePatient { workflow.append("Arrives before patient") }
        if g.assistantMayPrepareMedications {
            workflow.append("Assistant may prepare meds")
        } else if g.prepareOwnMedications {
            workflow.append("Prepares own meds")
        }
        if !g.briefingStyle.isBlank { workflow.append("\(g.briefingStyle) briefing") }
        if !workflow.isEmpty { items.append(CardItem(text: "Workflow: \(workflow.joined(separator: " · "))")) }

        if !g.generalNotes.isBlank { items.append(CardItem(text: g.generalNotes)) }
        if !doctor.personalNotes.isBlank { items.append(CardItem(text: doctor.personalNotes)) }
        return items
    }

    /// Condensed to one or two lines per specialty.
    private static func specialtyItems(_ setup: SpecialtySetup) -> [CardItem] {
        var parts: [String] = []
        if !setup.additionalMonitoring.isEmpty { parts.append("Monitoring: \(setup.additionalMonitoring.joined(separator: ", "))") }
        if !setup.linesAndAccess.isEmpty { parts.append("Access: \(setup.linesAndAccess.joined(separator: ", "))") }
        if !setup.equipment.isEmpty { parts.append("Equipment: \(setup.equipment.joined(separator: ", "))") }
        if !setup.drugChanges.isBlank { parts.append("Drugs: \(setup.drugChanges)") }
        if !setup.specialNotes.isBlank { parts.append(setup.specialNotes) }
        if setup.setupPhoto != nil { parts.append("See app for setup photo") }
        guard !parts.isEmpty else { return [] }
        return [CardItem(text: parts.joined(separator: "  ·  "))]
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
}
