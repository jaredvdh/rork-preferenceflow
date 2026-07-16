//
//  SurgeonProcedurePDF.swift
//  PreferenceFlow
//

import UIKit
import SwiftUI

/// Renders one surgeon operation card (e.g. "Lap Cholecystectomy") into a
/// single, laminate-ready A4 page: header with the operation and surgeon,
/// two-column body (Positioning · Sutures on the left, Trays · Energy on the
/// right), a highlighted operation-notes band, and the standard verification
/// and reference-only footer. Pure layout; mirrors the on-screen procedure tab.
@MainActor
enum SurgeonProcedurePDF {
    // A4 at 72 dpi.
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 36
    private static let gutter: CGFloat = 22

    /// One row inside a card: a bold line and an optional muted sub-line.
    private struct CardItem {
        let text: String
        var subtext: String? = nil
    }

    // MARK: - Public API

    static func data(procedure: SurgeonProcedure, doctor: Doctor, hospital: Hospital?) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let headerBottom = drawHeader(procedure: procedure, doctor: doctor, hospital: hospital)
            var y = headerBottom + 16
            if !procedure.notes.isBlank {
                y = drawNotesBand(procedure.notes, top: y) + 12
            }
            let columnsBottom = drawColumns(procedure: procedure, top: y)
            drawFooter(doctor: doctor, from: columnsBottom)
        }
    }

    static func writeFile(procedure: SurgeonProcedure, doctor: Doctor, hospital: Hospital?) throws -> URL {
        let pdf = data(procedure: procedure, doctor: doctor, hospital: hospital)
        let procPart = procedure.displayName.replacingOccurrences(of: " ", with: "_")
        let namePart = doctor.fullName.isEmpty
            ? "Surgeon"
            : doctor.fullName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(namePart)_\(procPart).pdf")
        try pdf.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Header

    private static func drawHeader(procedure: SurgeonProcedure, doctor: Doctor, hospital: Hospital?) -> CGFloat {
        let bandHeight: CGFloat = 108
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

        let textLeft = margin
        let textWidth = pageSize.width - margin * 2

        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .heavy),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            .kern: 1.4
        ]
        let brand = "ORPrep"
        brand.draw(at: CGPoint(x: textLeft, y: 18), withAttributes: brandAttrs)
        let brandWidth = brand.size(withAttributes: brandAttrs).width
        " · OPERATION CARD".draw(
            at: CGPoint(x: textLeft + brandWidth, y: 18),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .kern: 1.4
            ]
        )
        procedure.displayName.draw(
            in: CGRect(x: textLeft, y: 31, width: textWidth, height: 32),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 25, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )

        var parts: [String] = [doctor.displayName]
        if !doctor.role.isEmpty { parts.append(doctor.role) }
        if let hospital, !hospital.name.isEmpty { parts.append(hospital.name) }
        parts.joined(separator: "  ·  ").draw(
            in: CGRect(x: textLeft, y: 64, width: textWidth, height: 16),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11.5, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
        )

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        "Updated \(formatter.string(from: doctor.updatedAt))".draw(
            at: CGPoint(x: textLeft, y: 84),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
        )
        return bandHeight
    }

    // MARK: - Operation notes band

    /// The "for this operation" free text, highlighted at the top like the
    /// on-screen callout — usually the must-be-ready-before-knife-to-skin line.
    private static func drawNotesBand(_ notes: String, top: CGFloat) -> CGFloat {
        let width = pageSize.width - margin * 2
        let font = UIFont.systemFont(ofSize: 10.5, weight: .medium)
        let textWidth = width - 24
        let textH = itemHeight(notes, font: font, width: textWidth)
        let bandH = textH + 34

        let rect = CGRect(x: margin, y: top, width: width, height: bandH)
        UIColor.systemOrange.withAlphaComponent(0.10).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
        UIColor.systemOrange.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: top + 8, width: 4, height: bandH - 16), cornerRadius: 2).fill()

        "FOR THIS OPERATION".draw(
            at: CGPoint(x: margin + 14, y: top + 8),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .heavy),
                .foregroundColor: UIColor.systemOrange,
                .kern: 0.8
            ]
        )
        notes.draw(
            in: CGRect(x: margin + 14, y: top + 22, width: textWidth, height: textH + 4),
            withAttributes: [.font: font, .foregroundColor: UIColor.label]
        )
        return top + bandH
    }

    // MARK: - Two-column body

    private static func drawColumns(procedure: SurgeonProcedure, top: CGFloat) -> CGFloat {
        let colWidth = (pageSize.width - margin * 2 - gutter) / 2
        let leftX = margin
        let rightX = margin + colWidth + gutter

        var leftY = top
        leftY = drawCard(title: "Positioning & Prep", icon: "bed.double.fill",
                         items: positioningItems(procedure.positioning), x: leftX, y: leftY, width: colWidth)
        leftY = drawCard(title: "Sutures & Closure", icon: "bandage.fill",
                         items: sutureItems(procedure.sutures), x: leftX, y: leftY + 10, width: colWidth)

        var rightY = top
        rightY = drawCard(title: "Trays & Instruments", icon: "tray.2.fill",
                          items: trayItems(procedure.trays), x: rightX, y: rightY, width: colWidth)
        rightY = drawCard(title: "Energy & Equipment", icon: "bolt.fill",
                          items: energyItems(procedure.energy), x: rightX, y: rightY + 10, width: colWidth)

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

        var bodyH: CGFloat = 8
        for item in displayItems {
            bodyH += itemHeight(item.text, font: itemFont, width: itemWidth) + 5
            if let sub = item.subtext, !sub.isBlank {
                bodyH += itemHeight(sub, font: subFont, width: itemWidth) + 2
            }
        }
        bodyH += 4
        let cardH = titleH + bodyH

        let cardRect = CGRect(x: x, y: y, width: width, height: cardH)
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: cardRect, cornerRadius: 12).fill()
        UIColor(Theme.accent).withAlphaComponent(0.18).setStroke()
        let border = UIBezierPath(roundedRect: cardRect, cornerRadius: 12); border.lineWidth = 0.75; border.stroke()

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

    // MARK: - Footer

    private static func drawFooter(doctor: Doctor, from contentBottom: CGFloat) {
        let qrSize: CGFloat = 74
        let bottomLineH: CGFloat = 14
        let footerTop = pageSize.height - margin - qrSize - bottomLineH
        let y = max(contentBottom + 16, footerTop)

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
        let scanName = doctor.displayName.isEmpty ? "this surgeon" : "\(doctor.displayName)'s"
        "Scan to open \(scanName) live profile in ORPrep — always up to date."
            .draw(
                in: CGRect(x: textX, y: y + 22, width: textWidth, height: 32),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        let verification = doctor.isVerifiedProfile
            ? "Verified — preferences confirmed with the surgeon."
            : "UNVERIFIED — created from memory / second-hand. Confirm with the surgeon before relying on this card."
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

    private static func positioningItems(_ p: PositioningPrep) -> [CardItem] {
        var items: [CardItem] = []
        if !p.patientPosition.isBlank { items.append(CardItem(text: "Position: \(p.patientPosition)")) }
        if !p.tableAttachments.isEmpty { items.append(CardItem(text: "Table: \(p.tableAttachments.joined(separator: ", "))")) }
        if !p.prepSolution.isBlank { items.append(CardItem(text: "Prep: \(p.prepSolution)")) }
        if !p.drapingStyle.isBlank { items.append(CardItem(text: "Draping: \(p.drapingStyle)")) }
        if !p.catheter.isBlank { items.append(CardItem(text: "Catheter: \(p.catheter)")) }
        if !p.notes.isBlank { items.append(CardItem(text: p.notes)) }
        if p.setupPhoto != nil { items.append(CardItem(text: "See app for positioning photo")) }
        return items
    }

    private static func trayItems(_ t: TraysInstruments) -> [CardItem] {
        var items: [CardItem] = []
        if !t.traysToOpen.isEmpty { items.append(CardItem(text: "Open: \(t.traysToOpen.joined(separator: ", "))")) }
        if !t.favouriteExtras.isEmpty { items.append(CardItem(text: "Extras: \(t.favouriteExtras.joined(separator: ", "))")) }
        if !t.haveAvailableUnopened.isEmpty { items.append(CardItem(text: "Unopened: \(t.haveAvailableUnopened.joined(separator: ", "))")) }
        if !t.notes.isBlank { items.append(CardItem(text: t.notes)) }
        if t.setupPhoto != nil { items.append(CardItem(text: "See app for back-table photo")) }
        return items
    }

    private static func sutureItems(_ s: SuturesClosure) -> [CardItem] {
        var items: [CardItem] = []
        if !s.fascia.isBlank { items.append(CardItem(text: "Fascia / deep: \(s.fascia)")) }
        if !s.subcutaneous.isBlank { items.append(CardItem(text: "Subcutaneous: \(s.subcutaneous)")) }
        if !s.skin.isBlank { items.append(CardItem(text: "Skin: \(s.skin)")) }
        if !s.staplers.isEmpty { items.append(CardItem(text: "Staplers: \(s.staplers.joined(separator: ", "))")) }
        if !s.drains.isEmpty { items.append(CardItem(text: "Drains: \(s.drains.joined(separator: ", "))")) }
        if !s.dressings.isEmpty { items.append(CardItem(text: "Dressings: \(s.dressings.joined(separator: ", "))")) }
        if !s.notes.isBlank { items.append(CardItem(text: s.notes)) }
        return items
    }

    private static func energyItems(_ e: EnergyEquipment) -> [CardItem] {
        var items: [CardItem] = []
        if !e.diathermyDisplay.isBlank { items.append(CardItem(text: "Diathermy: \(e.diathermyDisplay)")) }
        if !e.energyDevices.isEmpty { items.append(CardItem(text: "Devices: \(e.energyDevices.joined(separator: ", "))")) }
        let tourniquet = [e.tourniquetPressure, e.tourniquetNotes].filter { !$0.isBlank }.joined(separator: " · ")
        if !tourniquet.isBlank { items.append(CardItem(text: "Tourniquet: \(tourniquet)")) }
        if !e.irrigation.isBlank { items.append(CardItem(text: "Irrigation: \(e.irrigation)")) }
        if !e.imaging.isEmpty { items.append(CardItem(text: "Imaging: \(e.imaging.joined(separator: ", "))")) }
        if !e.notes.isBlank { items.append(CardItem(text: e.notes)) }
        return items
    }
}
