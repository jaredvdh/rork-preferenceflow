//
//  WorkflowSummaryView.swift
//  PreferenceFlow
//
//  Read-only "laminated preference card" view of a template-driven workflow.
//  Rather than mirroring the editor's field structure, this consolidates the
//  resolved department-standard-plus-overrides into five human-meaningful
//  summary cards — Equipment, Medications, Technique, Consultant Notes and an
//  optional Hospital Notes — so a technician or registrar can glance for ten
//  seconds and know exactly how to prepare for this consultant.
//
//  Editing remains a completely separate experience: the Edit button launches
//  the unchanged guided WorkflowGuideView.
//

import SwiftUI

struct WorkflowSummaryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let doctorID: UUID
    let definition: WorkflowDefinition

    @State private var editing = false
    @State private var expanded: Set<String> = []

    private var doctor: Doctor? { store.doctor(id: doctorID) }
    private var hospital: Hospital? { store.hospital(id: doctor?.hospitalId) }

    private var customization: WorkflowCustomization {
        guard let doctor else { return WorkflowCustomization(id: definition.id) }
        // Procedural workflows (Arterial Line, CVC) read from their own storage.
        return WorkflowLibrary.isProcedural(definition.id)
            ? doctor.proceduralPreferences.customization(for: definition.id)
            : doctor.neuraxial.customization(for: definition.id)
    }

    private var resolved: ResolvedWorkflow {
        ResolvedWorkflow(definition: definition, customization: customization)
    }

    private var isConfigured: Bool { customization.isConfigured }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    if !isConfigured {
                        notConfiguredNote
                    }

                    ForEach(SummaryCategory.allCases, id: \.self) { category in
                        if categoryHasContent(category) {
                            summaryCard(category)
                        }
                    }

                    if let hospitalCard = hospitalItems, !hospitalCard.isEmpty {
                        hospitalCardView(hospitalCard)
                    }

                    disclaimer
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(definition.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { editing = true } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $editing) {
                WorkflowGuideView(
                    doctorID: doctorID,
                    definition: definition,
                    existing: customization
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.14)).frame(width: 48, height: 48)
                    Image(systemName: definition.icon)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.title)
                        .font(.title3.weight(.bold))
                    statusBadge
                }
                Spacer(minLength: 0)
            }

            if !highlightChips.isEmpty {
                Divider()
                PrefChecklist(items: highlightChips, tint: Theme.accent)
            }

            if isConfigured, resolved.modificationCount > 0 {
                Label("^[\(resolved.modificationCount) consultant modification](inflect: true)",
                      systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .card()
    }

    private var statusBadge: some View {
        let modified = isConfigured && resolved.modificationCount > 0
        let text: String = !isConfigured
            ? "Department Standard"
            : (modified ? "Updated by you" : "Department Standard")
        let color: Color = modified ? .orange : Theme.accent
        return HStack(spacing: 5) {
            Image(systemName: modified ? "person.fill.checkmark" : "checkmark.seal.fill")
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
    }

    private var notConfiguredNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.accent)
            Text("This consultant hasn't customised this workflow yet — the department standard is shown below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }

    // MARK: - Summary card (collapsible)

    private func summaryCard(_ category: SummaryCategory) -> some View {
        let key = "cat-\(category.rawValue)"
        let isExpanded = expanded.contains(key)
        let modified = categoryIsModified(category)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded { expanded.remove(key) } else { expanded.insert(key) }
                }
            } label: {
                HStack(spacing: 12) {
                    categoryIcon(category)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(category.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            if modified { badge("Updated by you", .orange) }
                        }
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
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.vertical, 12)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(steps(in: category)) { step in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(step.title.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.5)
                                    .foregroundStyle(category.tint)
                                ForEach(fields(in: step, category: category)) { field in
                                    fieldDetail(field)
                                }
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
    }

    private func categoryIcon(_ category: SummaryCategory) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(category.tint.opacity(0.16))
                .frame(width: 38, height: 38)
            Image(systemName: category.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category.tint)
        }
    }

    // MARK: - Hospital card

    private func hospitalCardView(_ items: [(title: String, detail: String, icon: String)]) -> some View {
        let key = "cat-hospital"
        let isExpanded = expanded.contains(key)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded { expanded.remove(key) } else { expanded.insert(key) }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 38, height: 38)
                        Image(systemName: "building.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("Hospital Information")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            badge("Hospital Specific", .secondary)
                        }
                        if !isExpanded {
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
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.vertical, 12)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(items, id: \.title) { item in
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
    }

    /// Neuraxial-relevant equipment locations for this consultant's hospital.
    private var hospitalItems: [(title: String, detail: String, icon: String)]? {
        guard let orientation = hospital?.orientation else { return nil }
        let relevant: Set<EquipmentKind> = [
            .ultrasound, .regionalEquipment, .pharmacy, .theatreStores,
            .anaestheticWorkroom, .emergencyAirway, .other
        ]
        let items = orientation.equipmentLocations
            .filter { relevant.contains($0.kind) && !$0.location.isBlank }
            .map { (title: $0.title, detail: $0.location, icon: $0.symbol) }
        return items.isEmpty ? nil : items
    }

    // MARK: - Field detail

    @ViewBuilder
    private func fieldDetail(_ field: WorkflowField) -> some View {
        let modified = resolved.isModified(field)
        switch field.kind {
        case .toggle:
            detailRow(label: field.label,
                      value: resolved.boolValue(field.id) ? "Yes" : "No",
                      modified: modified)
        case .singleSelect, .segmented:
            let value = resolved.selection(field.id)
            if !value.isBlank {
                detailRow(label: field.label, value: value, modified: modified)
            }
        case .multiSelect:
            let values = resolved.multi(field.id)
            if !values.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(field.label, modified: modified)
                    PrefChecklist(items: values, tint: Theme.accent)
                }
            }
        case .note:
            let text = resolved.note(field.id)
            if !text.isBlank {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel(field.label, modified: modified)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .packReference:
            VStack(alignment: .leading, spacing: 8) {
                detailRow(label: field.label,
                          value: resolved.boolValue(field.id) ? "Yes" : "No",
                          modified: modified)
                if resolved.boolValue(field.id), !field.referenceItems.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(field.referenceItems, id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tertiary)
                                Text(item).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    private func fieldLabel(_ label: String, modified: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            if modified { badge("Updated", .orange) }
        }
    }

    private func detailRow(label: String, value: String, modified: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if modified { badge("Updated", .orange) }
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: .capsule)
            .foregroundStyle(color)
    }

    private var disclaimer: some View {
        Text(SafetyText.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    // MARK: - Categorisation

    private func categoryOf(_ field: WorkflowField) -> SummaryCategory {
        let id = field.id.lowercased()
        if id.contains("intrathecal") || id.contains("additive") || id.contains("skinla")
            || id.contains("agent") || id.contains("infusion") {
            return .medications
        }
        if id.hasPrefix("consultant") || id.hasPrefix("assistant") {
            return .consultantNotes
        }
        if id.hasPrefix("sterile") || id.hasPrefix("pack") || id.hasPrefix("kit")
            || id.hasPrefix("additional") || id.hasPrefix("dressing") || id.contains("securing") {
            return .equipment
        }
        return .technique
    }

    /// Whether a field carries a value worth displaying.
    private func meaningful(_ field: WorkflowField) -> Bool {
        switch field.kind {
        case .toggle, .packReference:
            return true
        case .singleSelect, .segmented:
            return !resolved.selection(field.id).isBlank
        case .multiSelect:
            return !resolved.multi(field.id).isEmpty
        case .note:
            return !resolved.note(field.id).isBlank
        }
    }

    private func categoryHasContent(_ category: SummaryCategory) -> Bool {
        definition.allFields.contains { categoryOf($0) == category && meaningful($0) }
    }

    private func categoryIsModified(_ category: SummaryCategory) -> Bool {
        definition.allFields.contains { categoryOf($0) == category && resolved.isModified($0) }
    }

    private func steps(in category: SummaryCategory) -> [WorkflowStep] {
        definition.steps.filter { step in
            step.fields.contains { categoryOf($0) == category && meaningful($0) }
        }
    }

    private func fields(in step: WorkflowStep, category: SummaryCategory) -> [WorkflowField] {
        step.fields.filter { categoryOf($0) == category && meaningful($0) }
    }

    // MARK: - Collapsed summary line

    private func collapsedSummary(_ category: SummaryCategory) -> String {
        let tokens = definition.allFields
            .filter { categoryOf($0) == category }
            .compactMap { compactToken($0) }
        return tokens.isEmpty ? "Department standard" : tokens.joined(separator: " • ")
    }

    private func compactToken(_ field: WorkflowField) -> String? {
        switch field.kind {
        case .toggle:
            return resolved.boolValue(field.id) ? field.label : nil
        case .packReference:
            return resolved.boolValue(field.id) ? "Standard pack" : nil
        case .singleSelect, .segmented:
            let v = resolved.selection(field.id)
            return v.isBlank ? nil : shortAgent(v)
        case .multiSelect:
            let v = resolved.multi(field.id)
            if v.isEmpty { return nil }
            if v.count <= 2 { return v.map(shortAgent).joined(separator: ", ") }
            let id = field.id.lowercased()
            let noun = id.contains("additive") ? "additives"
                : (id.contains("additional") ? "additional items" : "items")
            return "\(v.count) \(noun)"
        case .note:
            return nil
        }
    }

    // MARK: - Header highlight chips

    private var highlightChips: [String] {
        var chips: [String] = []

        // Needle (+ gauge) — the headline technique detail.
        if let needle = definition.allFields.first(where: { $0.id.lowercased().contains("needle") }) {
            var token = resolved.selection(needle.id)
            if let gauge = definition.allFields.first(where: { $0.id.lowercased().contains("gauge") }) {
                let g = resolved.selection(gauge.id)
                if !g.isBlank { token += " \(g)" }
            }
            if !token.isBlank { chips.append(token) }
        }

        // Primary anaesthetic agent (intrathecal / spinal, not skin local).
        if let agent = definition.allFields.first(where: {
            let id = $0.id.lowercased()
            return id.contains("agent") && !id.contains("skin")
        }) {
            let v = shortAgent(resolved.selection(agent.id))
            if !v.isBlank { chips.append(v) }
        }

        // Additives.
        if let additives = definition.allFields.first(where: {
            $0.id.lowercased().contains("additive") && $0.kind == .multiSelect
        }) {
            chips.append(contentsOf: resolved.multi(additives.id).map(shortAgent))
        }

        // Position.
        if let position = definition.allFields.first(where: {
            $0.id.lowercased().contains("position") && ($0.kind == .segmented || $0.kind == .singleSelect)
        }) {
            let v = resolved.selection(position.id)
            if !v.isBlank { chips.append("\(v) position") }
        }

        return Array(chips.prefix(5))
    }

    /// Shortens drug names for chips: drops parentheticals and a leading
    /// concentration so "0.5% Heavy Bupivacaine (Marcaine Heavy)" → "Heavy Bupivacaine".
    private func shortAgent(_ value: String) -> String {
        var text = value
        if let range = text.range(of: " (") {
            text = String(text[..<range.lowerBound])
        }
        let parts = text.split(separator: " ")
        if let first = parts.first, first.contains("%") {
            text = parts.dropFirst().joined(separator: " ")
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Summary categories

/// The five human-meaningful groupings a consultant preference card is read in.
private enum SummaryCategory: Int, CaseIterable {
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
        case .equipment: return Color(hex: "3CA55C")     // green
        case .medications: return Color(hex: "2E7DD1")   // blue
        case .technique: return Color(hex: "E0883B")     // orange
        case .consultantNotes: return Color(hex: "7A5CD6") // purple
        }
    }
}
