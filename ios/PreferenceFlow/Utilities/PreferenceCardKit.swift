//
//  PreferenceCardKit.swift
//  PreferenceFlow
//
//  The shared visual language for "consultant preference cards" — the read-only,
//  scannable summaries used across every clinical section (Airway, Drugs & Fluids,
//  Regional, Neuraxial, General, Specialty Setups). Each section presents a
//  summary header, a small set of colour-coded collapsible cards, and an Edit
//  affordance that launches the unchanged structured editor.
//
//  Design philosophy: optimise for rapid retrieval, not data entry. A technician
//  or registrar should glance for ten seconds and know exactly what to prepare.
//

import SwiftUI

// MARK: - Shared palette

/// The human-meaningful groupings preference cards are read in, each with a
/// consistent colour and icon across every section so the whole app feels like a
/// single family of cards.
enum PrefGroup {
    case equipment, monitoring, medications, technique, workflow, consultantNotes, personal, hospital

    var tint: Color {
        switch self {
        case .equipment: return Color(hex: "3CA55C")        // green
        case .monitoring: return Color(hex: "D1576E")       // rose
        case .medications: return Color(hex: "2E7DD1")      // blue
        case .technique: return Color(hex: "E0883B")        // orange
        case .workflow: return Color(hex: "47808F")         // slate
        case .consultantNotes: return Color(hex: "7A5CD6")  // purple
        case .personal: return Color(hex: "C0489B")         // magenta
        case .hospital: return Color(hex: "5B6470")         // graphite
        }
    }

    var icon: String {
        switch self {
        case .equipment: return "shippingbox.fill"
        case .monitoring: return "waveform.path.ecg"
        case .medications: return "cross.vial.fill"
        case .technique: return "scope"
        case .workflow: return "arrow.triangle.branch"
        case .consultantNotes: return "star.fill"
        case .personal: return "cup.and.saucer.fill"
        case .hospital: return "building.2.fill"
        }
    }
}

// MARK: - Summary header

/// The hero header at the top of every preference card: an accent icon, the
/// title, a status line (Department Standard / Modified), optional highlight
/// chips and an optional consultant-modification count.
struct PrefSummaryHeader: View {
    let icon: String
    let title: String
    var caption: String? = nil
    var status: PrefStatus = .none
    var chips: [String] = []
    /// nil hides the modification line; otherwise renders the standard/modified label.
    var modificationCount: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.14)).frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.weight(.bold))
                    if let caption {
                        Text(caption)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if status != .none {
                        status.view
                    }
                }
                Spacer(minLength: 0)
            }

            if !chips.isEmpty {
                Divider()
                PrefChecklist(items: chips, tint: Theme.accent)
            }

            if let modificationCount {
                PrefModificationLabel(count: modificationCount)
            }
        }
        .card()
    }
}

/// A status descriptor shown under a preference card title.
enum PrefStatus: Equatable {
    case none
    case modified(String)
    case custom(text: String, icon: String, color: Color)

    @ViewBuilder var view: some View {
        switch self {
        case .none:
            EmptyView()
        case .modified(let who):
            badge(text: who, icon: "person.fill.checkmark", color: .orange)
        case .custom(let text, let icon, let color):
            badge(text: text, icon: icon, color: color)
        }
    }

    private func badge(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
    }
}

/// "Department Standard" (green) or "N Consultant Modifications" (orange).
struct PrefModificationLabel: View {
    let count: Int
    var body: some View {
        Label(
            count <= 0 ? "Department Standard" : "^[\(count) Consultant Modification](inflect: true)",
            systemImage: count <= 0 ? "checkmark.seal.fill" : "slider.horizontal.3"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(count <= 0 ? Theme.accent : .orange)
    }
}

// MARK: - Card edit footer

/// The standard "Edit …" footer action used at the bottom of preference boxes —
/// the exact affordance introduced on the Arterial Line / CVC expandable rows,
/// shared so every box on the consultant card edits the same way.
struct CardEditButton: View {
    let title: String
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Label("Edit \(title)", systemImage: "slider.horizontal.3")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

// MARK: - Collapsible card

/// A colour-coded, collapsible preference card. Collapsed it shows a one-line
/// summary; expanded it reveals the detail content. Self-manages its expansion.
struct PrefCollapsibleCard<Content: View>: View {
    let group: PrefGroup
    var title: String
    var iconOverride: String?
    var modified: Bool = false
    var collapsedSummary: String
    var startExpanded: Bool = false
    /// When set, an "Edit …" footer (matching the Arterial/CVC rows) renders at
    /// the bottom of the expanded content so the box is editable in one tap.
    var onEdit: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @State private var expanded: Bool

    init(
        group: PrefGroup,
        title: String? = nil,
        icon: String? = nil,
        modified: Bool = false,
        collapsedSummary: String,
        startExpanded: Bool = false,
        onEdit: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.group = group
        self.title = title ?? PrefCollapsibleCard.defaultTitle(group)
        self.iconOverride = icon
        self.modified = modified
        self.collapsedSummary = collapsedSummary
        self.startExpanded = startExpanded
        self.onEdit = onEdit
        self.content = content
        _expanded = State(initialValue: startExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(group.tint.opacity(0.16))
                            .frame(width: 38, height: 38)
                        Image(systemName: iconOverride ?? group.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(group.tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if modified { PrefBadge("Updated by you", .orange) }
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
                Divider().padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 16) {
                    content()
                    if let onEdit {
                        CardEditButton(title: title, action: onEdit)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: expanded)
        .card()
    }

    private static func defaultTitle(_ group: PrefGroup) -> String {
        switch group {
        case .equipment: return "Equipment"
        case .monitoring: return "Monitoring"
        case .medications: return "Medications"
        case .technique: return "Technique"
        case .workflow: return "Workflow"
        case .consultantNotes: return "Consultant Notes"
        case .personal: return "Personal"
        case .hospital: return "Hospital Information"
        }
    }
}

// MARK: - Content building blocks

/// A clean checklist — the primary way setup items, equipment and medications
/// are presented across the app, replacing pill chips. Reads top-to-bottom like a
/// theatre preparation checklist: a tinted marker, the item, generous line height.
struct PrefChecklist: View {
    let items: [String]
    var tint: Color = Theme.accent
    /// When set, shows a tappable footer ("View Full Setup") with a chevron.
    var footer: String? = nil

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Divider().padding(.leading, 24)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 16)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 9)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A small neutral count badge ("5 items") shown on checklist card headers.
struct PrefCountBadge: View {
    let count: Int
    var noun: String = "item"
    var body: some View {
        Text("^[\(count) \(noun)](inflect: true)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: .capsule)
            .foregroundStyle(.secondary)
    }
}

/// A small tinted pill used for inline status markers.
struct PrefBadge: View {
    let text: String
    let color: Color
    init(_ text: String, _ color: Color) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: .capsule)
            .foregroundStyle(color)
    }
}

/// A label/value detail row, hidden when the value is blank.
struct PrefRow: View {
    let label: String
    let value: String
    var modified: Bool = false

    var body: some View {
        if !value.isBlank {
            HStack(alignment: .top, spacing: 12) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if modified { PrefBadge("Updated", .orange) }
                Spacer(minLength: 12)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
            }
        }
    }
}

/// A titled subgroup inside a card (e.g. "Primary Airway"). The title is tinted
/// to the card's group colour.
struct PrefSubgroup<Content: View>: View {
    let title: String
    let tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(tint)
            content()
        }
    }
}

/// A wrapping set of value chips, hidden when empty.
struct PrefChips: View {
    let values: [String]
    var tint: Color = Theme.accentDeep

    var body: some View {
        if !values.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Text(value)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.14), in: .capsule)
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A single bulleted line, hidden when blank.
struct PrefBullet: View {
    let text: String
    var body: some View {
        if !text.isBlank {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// A labelled free-text note block, hidden when blank.
struct PrefNote: View {
    let label: String
    let text: String
    var tint: Color = .secondary

    var body: some View {
        if !text.isBlank {
            VStack(alignment: .leading, spacing: 6) {
                if !label.isBlank {
                    Text(label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(tint)
                }
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Hospital information card

/// One row of hospital equipment / location info.
struct PrefHospitalItem: Hashable {
    let title: String
    let detail: String
    let icon: String
}

/// A reusable, collapsible Hospital Information card shared across sections.
struct PrefHospitalCard: View {
    let items: [PrefHospitalItem]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PrefGroup.hospital.tint.opacity(0.16))
                            .frame(width: 38, height: 38)
                        Image(systemName: PrefGroup.hospital.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PrefGroup.hospital.tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("Hospital Information")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            PrefBadge("Hospital Specific", PrefGroup.hospital.tint)
                        }
                        if !expanded {
                            Text(items.prefix(3).map(\.title).joined(separator: " • "))
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
                Divider().padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            Text(item.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 12)
                            Text(item.detail)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: expanded)
        .card()
    }
}

/// Resolves hospital equipment locations relevant to a section, for the optional
/// Hospital Information card.
enum PrefHospital {
    static func items(for hospital: Hospital?, kinds: Set<EquipmentKind>) -> [PrefHospitalItem] {
        guard let orientation = hospital?.orientation else { return [] }
        return orientation.equipmentLocations
            .filter { kinds.contains($0.kind) && !$0.location.isBlank }
            .map { PrefHospitalItem(title: $0.title, detail: $0.location, icon: $0.symbol) }
    }
}

/// A light-weight section disclaimer used at the foot of preference cards.
struct PrefDisclaimer: View {
    var body: some View {
        Text(SafetyText.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}
