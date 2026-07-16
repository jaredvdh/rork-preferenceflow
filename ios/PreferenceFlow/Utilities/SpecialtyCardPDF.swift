//
//  SpecialtyCardPDF.swift
//  PreferenceFlow
//

import UIKit
import SwiftUI

/// Renders one specialty setup (e.g. "Cardiac", "Neuro", "Obstetrics") into a
/// single, laminate-ready A4 page — the anaesthetic parallel of the surgeon
/// operation card. Header carries the specialty and consultant, a standing
/// band reminds that the standard setup still applies, then a two-column body
/// (Monitoring · Lines & Access on the left, Equipment · Drug Changes on the
/// right), a highlighted specialty-notes band, and the standard verification
/// and reference-only footer. Pure layout; mirrors the on-screen specialty tab.
@MainActor
enum SpecialtyCardPDF {
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

    static func data(setup: SpecialtySetup, doctor: Doctor, hospital: Hospital?) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let headerBottom = drawHeader(setup: setup, doctor: doctor, hospital: hospital)
            var y = drawStandingBand(setup: setup, doctor: doctor, top: headerBottom + 16) + 12
            if !setup.specialNotes.isBlank {
                y = drawNotesBand(setup.specialNotes, top: y) + 12
            }
            let columnsBottom = drawColumns(setup: setup, top: y)
            drawFooter(doctor: doctor, from: columnsBottom)
        }
    }

    static func writeFile(setup: SpecialtySetup, doctor: Doctor, hospital: Hospital?) throws -> URL {
        let pdf = data(setup: setup, doctor: doctor, hospital: hospital)
        let specialtyPart = setup.specialty.rawValue.replacingOccurrences(of: " ", with: "_")
        let namePart = doctor.fullName.isEmpty
            ? "Consultant"
            : doctor.fullName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(namePart)_\(specialtyPart)_Card.pdf")
        try pdf.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Header

    private static func drawHeader(setup: SpecialtySetup, doctor: Doctor, hospital: Hospital?) -> CGFloat {
        let bandHeight: CGFloat = 108
        let band = CGRect(x: 0, y: 0, width: pageSize.width, height: bandHeight)
        let cg = UIGraphicsGetCurrentContext()
        cg?.saveGState()
        cg?.addRect(band)
        cg?.clip()
        let base = UIColor(setup.specialty.color)
        let colors = [base.cgColor, darkened(base, by: 0.28).cgColor]
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
        " · SPECIALTY CARD".draw(
            at: CGPoint(x: textLeft + brandWidth, y: 18),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .kern: 1.4
            ]
        )
        setup.specialty.rawValue.draw(
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

    /// Darkens a colour for the header gradient's trailing stop.
    private static func darkened(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        return UIColor(hue: h, saturation: min(s * 1.1, 1), brightness: max(b - amount, 0), alpha: a)
    }

    // MARK: - Standing band

    /// Grey reminder band: this card lists only what changes vs the standard
    /// setup — mirrors the standing note on the on-screen specialty tab.
    private static func drawStandingBand(setup: SpecialtySetup, doctor: Doctor, top: CGFloat) -> CGFloat {
        let width = pageSize.width - margin * 2
        let font = UIFont.systemFont(ofSize: 10, weight: .medium)
        let text = doctor.isSurgeon
            ? "The surgeon's standard setup still applies. This card lists only the additional requirements for \(setup.specialty.rawValue) cases — read with the main theatre card."
            : "Standard airway, drugs and monitoring still apply. This card lists only the additional requirements for \(setup.specialty.rawValue) cases — read with the main theatre card."
        let textWidth = width - 24
        let textH = itemHeight(text, font: font, width: textWidth)
        let bandH = textH + 20

        let rect = CGRect(x: margin, y: top, width: width, height: bandH)
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        if let image = UIImage(systemName: "info.circle.fill")?
            .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal) {
            image.draw(in: CGRect(x: margin + 10, y: top + 10, width: 11, height: 11))
        }
        text.draw(
            in: CGRect(x: margin + 26, y: top + 9, width: textWidth - 14, height: textH + 4),
            withAttributes: [.font: font, .foregroundColor: UIColor.secondaryLabel]
        )
        return top + bandH
    }

    // MARK: - Specialty notes band

    /// The consultant's special notes for this list, highlighted like the
    /// on-screen callout.
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

        "FOR THIS SPECIALTY".draw(
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

    private static func drawColumns(setup: SpecialtySetup, top: CGFloat) -> CGFloat {
        let colWidth = (pageSize.width - margin * 2 - gutter) / 2
        let leftX = margin
        let rightX = margin + colWidth + gutter

        var leftY = top
        leftY = drawCard(title: "Additional Monitoring", icon: "waveform.path.ecg",
                         items: setup.additionalMonitoring.map { CardItem(text: $0) },
                         x: leftX, y: leftY, width: colWidth)
        leftY = drawCard(title: "Lines & Access", icon: "ivfluid.bag",
                         items: setup.linesAndAccess.map { CardItem(text: $0) },
                         x: leftX, y: leftY + 10, width: colWidth)

        var rightY = top
        rightY = drawCard(title: "Equipment", icon: "wrench.and.screwdriver.fill",
                          items: equipmentItems(setup), x: rightX, y: rightY, width: colWidth)
        rightY = drawCard(title: "Drug Changes", icon: "pills.fill",
                          items: drugItems(setup), x: rightX, y: rightY + 10, width: colWidth)

        return max(leftY, rightY)
    }

    private static func equipmentItems(_ setup: SpecialtySetup) -> [CardItem] {
        var items = setup.equipment.map { CardItem(text: $0) }
        if setup.setupPhoto != nil { items.append(CardItem(text: "See app for setup photo")) }
        return items
    }

    private static func drugItems(_ setup: SpecialtySetup) -> [CardItem] {
        setup.drugChanges.isBlank ? [] : [CardItem(text: setup.drugChanges)]
    }

    /// Draws one rounded "card" (title strip + item list) and returns its bottom Y.
    private static func drawCard(title: String, icon: String, items: [CardItem], x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let isEmpty = items.isEmpty
        let displayItems: [CardItem] = isEmpty ? [CardItem(text: "No changes — standard setup")] : items
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
        let provider = doctor.isSurgeon ? "surgeon" : "consultant"
        let scanName = doctor.displayName.isEmpty ? "this \(provider)" : "\(doctor.displayName)'s"
        "Scan to open \(scanName) live profile in ORPrep — always up to date."
            .draw(
                in: CGRect(x: textX, y: y + 22, width: textWidth, height: 32),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
        let verification = doctor.isVerifiedProfile
            ? "Verified — preferences confirmed with the \(provider)."
            : "UNVERIFIED — created from memory / second-hand. Confirm with the \(provider) before relying on this card."
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
}
