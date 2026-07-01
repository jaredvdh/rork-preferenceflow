//
//  RegionalTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Curated regional block options.
enum RegionalOptions {
    static let blockTypes = [
        "TAP", "ESP", "Femoral", "Fascia Iliaca", "Adductor Canal",
        "Interscalene", "Supraclavicular", "Axillary", "Popliteal Sciatic", "Other"
    ]
    static let drug = ["Ropivacaine", "Bupivacaine", "Levobupivacaine", "Lidocaine"]
    static let concentration = ["0.2%", "0.25%", "0.375%", "0.5%", "0.75%"]
    static let volume = ["10 mL", "15 mL", "20 mL", "30 mL", "40 mL"]
    static let needle = ["Short-bevel block", "Echogenic block", "Tuohy", "Other"]
    static let needleLength = ["50 mm", "80 mm", "100 mm", "120 mm"]
    static let probe = ["Linear (high-freq)", "Curvilinear", "Hockey stick"]
    static let cover = ["Sterile sleeve", "Tegaderm", "Full sterile drape"]
}

/// Regional anaesthesia — a library of reusable block templates created from a picker.
struct RegionalTab: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor

    @State private var editingBlock: RegionalBlock?
    @State private var viewingBlock: RegionalBlock?
    @State private var choosingType = false

    private var hospitalItems: [PrefHospitalItem] {
        PrefHospital.items(for: store.hospital(id: doctor.hospitalId), kinds: [
            .regionalEquipment, .ultrasound, .theatreStores, .anaestheticWorkroom, .pharmacy
        ])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button { choosingType = true } label: {
                    Label("Add Block", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(.white)
                }

                if doctor.regionalBlocks.isEmpty {
                    EmptyStateView(
                        icon: "scope",
                        title: "No regional blocks",
                        message: "Add templates like TAP, Femoral or ESP — each starts pre-structured for you to fill.",
                        actionTitle: "Add Block",
                        action: { choosingType = true }
                    )
                    .card()
                } else {
                    ForEach(doctor.regionalBlocks) { block in
                        Button { viewingBlock = block } label: {
                            RegionalBlockCard(block: block)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editingBlock = block } label: { Label("Edit", systemImage: "pencil") }
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $viewingBlock) { block in
            RegionalBlockDetailView(block: block, hospitalItems: hospitalItems) {
                viewingBlock = nil
                editingBlock = block
            }
        }
        .sheet(item: $editingBlock) { block in
            RegionalBlockEditView(doctor: doctor, block: block)
        }
        .sheet(isPresented: $choosingType) {
            BlockTypePicker { name in
                choosingType = false
                editingBlock = RegionalBlock(name: name)
            }
        }
    }
}

/// Read-only "laminated preference card" view of a regional block — the default
/// tap target. Mirrors the neuraxial summary philosophy: rather than echoing the
/// editor's field layout, it consolidates the block into a few human-meaningful,
/// colour-coded, collapsible cards so a technician can glance for ten seconds and
/// know exactly how this consultant performs the block. An Edit button launches
/// the unchanged structured editor.
struct RegionalBlockDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let block: RegionalBlock
    var hospitalItems: [PrefHospitalItem] = []
    var onEdit: () -> Void

    @State private var expanded: Set<RegionalCategory> = []

    private var categories: [RegionalCategory] {
        RegionalCategory.allCases.filter { !rows(for: $0).isEmpty || !notes(for: $0).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    if categories.isEmpty {
                        notConfiguredNote
                    } else {
                        ForEach(categories, id: \.self) { summaryCard($0) }
                    }

                    if !hospitalItems.isEmpty {
                        PrefHospitalCard(items: hospitalItems)
                    }

                    disclaimer
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(block.name.isBlank ? "Block" : block.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.14)).frame(width: 48, height: 48)
                    Image(systemName: "scope")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name.isBlank ? "Regional Block" : block.name)
                        .font(.title3.weight(.bold))
                    Text("How this consultant performs the block")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if !highlightItems.isEmpty {
                Divider()
                PrefChecklist(items: highlightItems, tint: Theme.accent)
            }
        }
        .card()
    }

    private var highlightItems: [String] {
        var items: [String] = []
        if !block.drug.isBlank {
            var token = block.drug
            if !block.concentration.isBlank { token += " \(block.concentration)" }
            items.append(token)
        }
        if !block.typicalVolume.isBlank { items.append("\(block.typicalVolume) volume") }
        if !block.needleType.isBlank { items.append(block.needleType) }
        return Array(items.prefix(4))
    }

    private var notConfiguredNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.accent)
            Text("This block hasn't been filled in yet — tap Edit to add details.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }

    // MARK: - Summary card (collapsible)

    private func summaryCard(_ category: RegionalCategory) -> some View {
        let isExpanded = expanded.contains(category)
        let valueRows = rows(for: category)
        let noteRows = notes(for: category)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    if isExpanded { expanded.remove(category) } else { expanded.insert(category) }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(category.tint.opacity(0.16))
                            .frame(width: 38, height: 38)
                        Image(systemName: category.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(category.tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !isExpanded {
                            Text(collapsedSummary(category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(valueRows, id: \.label) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Text(row.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 12)
                            Text(row.value)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.primary)
                        }
                    }
                    ForEach(noteRows, id: \.label) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.label.uppercased())
                                .font(.caption2.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(category.tint)
                            Text(note.value)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Categorisation

    private func rows(for category: RegionalCategory) -> [(label: String, value: String)] {
        var out: [(String, String)] = []
        func add(_ label: String, _ value: String) {
            if !value.isBlank { out.append((label, value)) }
        }
        switch category {
        case .medications:
            add("Drug", block.drug)
            add("Concentration", block.concentration)
            add("Typical volume", block.typicalVolume)
            add("Adjuvant", block.adjuvant)
        case .equipment:
            add("Needle type", block.needleType)
            add("Needle length", block.needleLength)
            add("US probe", block.ultrasoundProbe)
            add("Sterile cover", block.sterileCover)
        case .technique, .consultantNotes:
            break
        }
        return out.map { (label: $0.0, value: $0.1) }
    }

    private func notes(for category: RegionalCategory) -> [(label: String, value: String)] {
        var out: [(String, String)] = []
        func add(_ label: String, _ value: String) {
            if !value.isBlank { out.append((label, value)) }
        }
        switch category {
        case .technique:
            add("Positioning", block.positioningNotes)
            add("Ultrasound / Setup", block.setupNotes)
        case .consultantNotes:
            add("Assistant", block.assistantNotes)
            add("Safety", block.safetyNotes)
            add("Special Notes", block.specialNotes)
        case .medications, .equipment:
            break
        }
        return out.map { (label: $0.0, value: $0.1) }
    }

    private func collapsedSummary(_ category: RegionalCategory) -> String {
        let values = rows(for: category).map(\.value) + notes(for: category).map(\.label)
        return values.isEmpty ? "Tap to view" : values.prefix(3).joined(separator: " • ")
    }

    private var disclaimer: some View {
        Text(SafetyText.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

/// The human-meaningful groupings a regional preference card is read in.
private enum RegionalCategory: Int, CaseIterable {
    case equipment, medications, technique, consultantNotes

    var title: String {
        switch self {
        case .equipment: return "Equipment"
        case .medications: return "Medications"
        case .technique: return "Technique"
        case .consultantNotes: return "Consultant Notes"
        }
    }

    var icon: String {
        switch self {
        case .equipment: return "shippingbox.fill"
        case .medications: return "cross.vial.fill"
        case .technique: return "scope"
        case .consultantNotes: return "star.fill"
        }
    }

    var tint: Color {
        switch self {
        case .equipment: return Color(hex: "3CA55C")
        case .medications: return Color(hex: "2E7DD1")
        case .technique: return Color(hex: "E0883B")
        case .consultantNotes: return Color(hex: "7A5CD6")
        }
    }
}

/// A chip-based multi-select for regional block adjuvants/additives, plus a
/// free-text custom entry for less common agents. Persists the selection into a
/// single " + "-joined string on the block (e.g. "Adrenaline + Dexamethasone").
struct AdjuvantSelector: View {
    @Binding var value: String
    @State private var customEntry: String = ""

    private var selected: [String] {
        value.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(RegionalBlock.adjuvantOptions, id: \.self) { option in
                    Button { toggle(option) } label: {
                        Chip(text: option, selected: selected.contains(option))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                TextField("Add custom additive", text: $customEntry)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addCustom)
                Button(action: addCustom) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(customEntry.isBlank ? Color.secondary : Theme.accent)
                }
                .disabled(customEntry.isBlank)
            }
        }
    }

    private func toggle(_ option: String) {
        var current = selected
        if option == "None" {
            // "None" is exclusive — selecting it clears everything else.
            value = current.contains("None") ? "" : "None"
            return
        }
        current.removeAll { $0 == "None" }
        if let index = current.firstIndex(of: option) {
            current.remove(at: index)
        } else {
            current.append(option)
        }
        value = current.joined(separator: " + ")
    }

    private func addCustom() {
        let trimmed = customEntry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var current = selected.filter { $0 != "None" }
        if !current.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            current.append(trimmed)
        }
        value = current.joined(separator: " + ")
        customEntry = ""
    }
}

/// A grid picker that seeds a new block from a common block type.
struct BlockTypePicker: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(RegionalOptions.blockTypes, id: \.self) { type in
                        Button { onPick(type == "Other" ? "" : "\(type) Block") } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "scope")
                                    .font(.title2)
                                    .foregroundStyle(Theme.accent)
                                Text(type)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerMedium))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct RegionalBlockCard: View {
    let block: RegionalBlock
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.14)).frame(width: 38, height: 38)
                    Image(systemName: "scope").foregroundStyle(Theme.accent)
                }
                Text(block.name.isBlank ? "Untitled Block" : block.name)
                    .font(.headline)
                Spacer(minLength: 8)
                if !allItems.isEmpty {
                    PrefCountBadge(count: allItems.count, noun: "item")
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            if allItems.isEmpty {
                Text("Tap to complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                PrefChecklist(items: previewItems, tint: Theme.accent)
            }
        }
        .card()
    }

    private var previewItems: [String] { Array(allItems.prefix(5)) }

    private var allItems: [String] {
        var items: [String] = []
        if !block.drug.isBlank {
            var token = block.drug
            if !block.concentration.isBlank { token += " \(block.concentration)" }
            items.append(token)
        }
        if !block.typicalVolume.isBlank { items.append("\(block.typicalVolume) volume") }
        if !block.needleType.isBlank { items.append(block.needleType) }
        if !block.needleLength.isBlank { items.append("\(block.needleLength) needle") }
        if !block.ultrasoundProbe.isBlank { items.append("\(block.ultrasoundProbe) probe") }
        if !block.sterileCover.isBlank { items.append(block.sterileCover) }
        return items
    }
}

/// Editor for a regional block template using structured selectors.
struct RegionalBlockEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var doctor: Doctor
    @State private var block: RegionalBlock
    private let isExisting: Bool

    init(doctor: Doctor, block: RegionalBlock) {
        _doctor = State(initialValue: doctor)
        _block = State(initialValue: block)
        self.isExisting = doctor.regionalBlocks.contains { $0.id == block.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Block Name") {
                    LabeledField(label: "Name", text: $block.name)
                }
                Section("Local Anaesthetic") {
                    OptionPicker(label: "Drug", selection: $block.drug, options: RegionalOptions.drug, icon: "drop")
                    OptionPicker(label: "Concentration", selection: $block.concentration, options: RegionalOptions.concentration)
                    OptionPicker(label: "Typical volume", selection: $block.typicalVolume, options: RegionalOptions.volume)
                }
                Section("Adjuvant / Additive") {
                    AdjuvantSelector(value: $block.adjuvant)
                }
                Section("Equipment") {
                    OptionPicker(label: "Needle type", selection: $block.needleType, options: RegionalOptions.needle, icon: "line.diagonal")
                    OptionPicker(label: "Needle length", selection: $block.needleLength, options: RegionalOptions.needleLength)
                    OptionPicker(label: "US probe", selection: $block.ultrasoundProbe, options: RegionalOptions.probe)
                    OptionPicker(label: "Sterile cover", selection: $block.sterileCover, options: RegionalOptions.cover)
                }
                Section("Notes") {
                    NotesField(label: "Ultrasound / setup notes", text: $block.setupNotes)
                    NotesField(label: "Positioning notes", text: $block.positioningNotes)
                    NotesField(label: "Assistant notes", text: $block.assistantNotes)
                    NotesField(label: "Safety notes", text: $block.safetyNotes)
                    NotesField(label: "Special notes", text: $block.specialNotes)
                }
                if isExisting {
                    Section {
                        Button("Delete Block", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isExisting ? "Edit Block" : "New Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(block.name.isBlank)
                }
            }
        }
    }

    private func save() {
        var updated = doctor
        if let index = updated.regionalBlocks.firstIndex(where: { $0.id == block.id }) {
            updated.regionalBlocks[index] = block
        } else {
            updated.regionalBlocks.append(block)
        }
        store.upsert(updated)
        dismiss()
    }

    private func delete() {
        var updated = doctor
        updated.regionalBlocks.removeAll { $0.id == block.id }
        store.upsert(updated)
        dismiss()
    }
}
