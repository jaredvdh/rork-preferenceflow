//
//  CrisisGuidesView.swift
//  PreferenceFlow
//

import SwiftUI

/// Crisis-box colour tokens, mapped from the manual's red/yellow/green legend.
private enum CrisisColor {
    static let red = Color(hex: "D1576E")
    static let yellow = Color(hex: "C7902B")
    static let green = Color(hex: "2E9E5B")
}

// MARK: - Crisis Guides list (grouped by section)

/// The full structured crisis manual, grouped by section with each section's
/// short tag shown as a badge. Loads the region-appropriate file offline. The
/// 33 cards are surfaced here and from the emergency shortcuts above the list.
struct CrisisGuidesListView: View {
    let manual: CrisisManual

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(CrisisManual.sectionOrder, id: \.self) { key in
                let cards = manual.cards(in: key)
                if let section = manual.sections[key], !cards.isEmpty {
                    sectionBlock(section: section, cards: cards)
                }
            }
        }
    }

    private func sectionBlock(section: CrisisSection, cards: [CrisisCard]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(section.tag)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Theme.accent, in: .circle)
                Text(section.label.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(cards.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    NavigationLink(value: card) {
                        CrisisCardRow(card: card)
                    }
                    .buttonStyle(.plain)
                    if index < cards.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerLarge))
        }
    }
}

/// A single crisis card row in the grouped list.
struct CrisisCardRow: View {
    let card: CrisisCard

    private var isHighPriority: Bool { card.color == "red" }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill((isHighPriority ? CrisisColor.red : Theme.accent).opacity(0.14))
                    .frame(width: 36, height: 36)
                Text(card.id.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isHighPriority ? CrisisColor.red : Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(card.priority)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

/// A bold emergency shortcut card for the immediate-access grid.
struct CrisisShortcutCard: View {
    let shortcut: CrisisShortcut
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(CrisisColor.red.opacity(0.16)).frame(width: 42, height: 42)
                Image(systemName: shortcut.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CrisisColor.red)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Text("Open card")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CrisisColor.red)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(CrisisColor.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Crisis Card detail

/// Renders a single crisis card verbatim: permanent source attribution, the
/// red "Do now" box, yellow "Think / consider" box, any grading or paediatric
/// table, the green "Doses & equipment" table, cross-reference chips, and the
/// manual + app disclaimers. Clinical content is shown exactly as in the JSON.
struct CrisisCardDetailView: View {
    let manual: CrisisManual
    let card: CrisisCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                attribution
                header
                doingBox
                thinkingBox
                gradingTable
                pedsTable
                bloodCompatTable
                drugsBox
                crossRefChips
                disclaimer
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(card.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Attribution (permanent, top of every card)

    private var attribution: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "text.book.closed.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(manual.meta.sourceAcknowledgement)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: Theme.cornerSmall))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(card.sectionTag) · \(card.id.uppercased())")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(card.color == "red" ? CrisisColor.red : Theme.accent, in: .capsule)
                Text(card.sectionLabel.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
            Text(card.title).font(.title2.weight(.bold))
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(CrisisColor.red)
                Text(card.priority)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CrisisColor.red.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
        }
    }

    // MARK: Red "Do now" box — ordered checklist

    @ViewBuilder
    private var doingBox: some View {
        if !card.doing.isEmpty {
            CrisisBox(color: CrisisColor.red, icon: "bolt.fill", label: "Do now") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(card.doing.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(CrisisColor.red, in: .circle)
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: Yellow "Think / consider" box — hidden if empty

    @ViewBuilder
    private var thinkingBox: some View {
        if !card.thinking.isEmpty {
            CrisisBox(color: CrisisColor.yellow, icon: "lightbulb.fill", label: "Think / consider") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(card.thinking.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(CrisisColor.yellow)
                                .padding(.top, 6)
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: Grading table

    @ViewBuilder
    private var gradingTable: some View {
        if let grading = card.grading {
            CrisisBox(color: Theme.accent, icon: "tablecells", label: "Grading") {
                CrisisTableView(table: grading)
            }
        }
    }

    // MARK: Paediatric calculations table

    @ViewBuilder
    private var pedsTable: some View {
        if let peds = card.pedsTable {
            CrisisBox(color: Theme.accent, icon: "figure.child", label: "Paediatric values") {
                CrisisTableView(table: peds)
            }
        }
    }

    // MARK: Blood compatibility tables

    @ViewBuilder
    private var bloodCompatTable: some View {
        if let bc = card.bloodCompat {
            CrisisBox(color: CrisisColor.red, icon: "drop.fill", label: "Blood compatibility") {
                VStack(alignment: .leading, spacing: 14) {
                    CrisisTableView(table: CrisisTable(columns: ["Patient", "Compatible red cells"], rows: bc.rbc))
                    CrisisTableView(table: CrisisTable(columns: ["Patient", "Compatible FFP"], rows: bc.ffp))
                    Text(bc.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Green "Doses & equipment" box — table

    @ViewBuilder
    private var drugsBox: some View {
        if !card.drugs.isEmpty {
            CrisisBox(color: CrisisColor.green, icon: "cross.vial.fill", label: "Doses & equipment") {
                CrisisDrugTable(drugs: card.drugs)
            }
        }
    }

    // MARK: Cross-reference chips

    @ViewBuilder
    private var crossRefChips: some View {
        let refs = card.crossRefs.compactMap { manual.card(id: $0) }
        if !refs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Related cards", icon: "link")
                CrisisCrossRefChips(refs: refs)
            }
        }
    }

    // MARK: Disclaimer (manual + app standard)

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(CrisisColor.red)
                Text(manual.meta.disclaimer)
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text(SafetyText.disclaimer)
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CrisisColor.red.opacity(0.06), in: .rect(cornerRadius: Theme.cornerMedium))
    }
}

// MARK: - Reusable crisis components

/// A coloured crisis box with a header strip and arbitrary content.
private struct CrisisBox<Content: View>: View {
    let color: Color
    let icon: String
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.footnote.weight(.bold))
                Text(label.uppercased()).font(.caption.weight(.bold)).tracking(0.5)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(color)

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.06))
        }
        .clipShape(.rect(cornerRadius: Theme.cornerMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}

/// A horizontally scrollable comparison table (columns + rows), rendered verbatim.
private struct CrisisTableView: View {
    let table: CrisisTable

    private let minCellWidth: CGFloat = 120

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(table.columns.enumerated()), id: \.offset) { _, col in
                        Text(col)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: minCellWidth, alignment: .leading)
                            .padding(8)
                    }
                }
                .background(Color(.tertiarySystemFill))
                ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .frame(width: minCellWidth, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(8)
                        }
                    }
                    .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color(.quaternarySystemFill).opacity(0.5))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
    }
}

/// A drug/equipment table showing adult bolus, adult infusion and paediatric
/// dose columns. Columns are only shown when at least one row uses them.
private struct CrisisDrugTable: View {
    let drugs: [CrisisDrug]

    private var showBolus: Bool { drugs.contains { $0.hasBolus } }
    private var showInfusion: Bool { drugs.contains { $0.hasInfusion } }
    private var showPeds: Bool { drugs.contains { $0.hasPeds } }
    private var showNotes: Bool { drugs.contains { $0.hasNotes } }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(drugs.enumerated()), id: \.element.id) { index, drug in
                VStack(alignment: .leading, spacing: 6) {
                    Text(drug.drug)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if showBolus, let bolus = drug.bolus, !bolus.isEmpty {
                        doseLine(label: "Bolus", value: bolus)
                    }
                    if showInfusion, let infusion = drug.infusion, !infusion.isEmpty {
                        doseLine(label: "Infusion", value: infusion)
                    }
                    if showPeds, let peds = drug.peds, !peds.isEmpty {
                        doseLine(label: "Paediatric", value: peds)
                    }
                    if showNotes, let notes = drug.notes, !notes.isEmpty {
                        doseLine(label: "Notes", value: notes)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                if index < drugs.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func doseLine(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CrisisColor.green)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Tappable cross-reference chips that navigate to the related crisis card.
private struct CrisisCrossRefChips: View {
    let refs: [CrisisCard]

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(refs) { ref in
                NavigationLink(value: ref) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right").font(.caption2)
                        Text(ref.title).font(.caption.weight(.medium)).lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.12), in: .capsule)
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
