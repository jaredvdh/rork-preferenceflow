//
//  WorkflowGuideView.swift
//  PreferenceFlow
//
//  The guided, checklist-style editor for a template-driven workflow. Starts
//  from the department standard; the consultant simply confirms defaults or
//  marks deviations, and only those differences are stored.
//

import SwiftUI

struct WorkflowGuideView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let doctorID: UUID
    let definition: WorkflowDefinition

    @State private var draft: WorkflowCustomization
    @State private var saveSuccess = false

    init(doctorID: UUID, definition: WorkflowDefinition, existing: WorkflowCustomization) {
        self.doctorID = doctorID
        self.definition = definition
        _draft = State(initialValue: existing)
    }

    private var modificationCount: Int {
        ResolvedWorkflow(definition: definition, customization: draft).modificationCount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    standardHeader

                    ForEach(Array(definition.steps.enumerated()), id: \.element.id) { index, step in
                        stepCard(step, number: index + 1)
                    }

                    if showsIntrathecalAgentNudge { intrathecalAgentNudge }

                    disclaimer
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(definition.title)
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: saveSuccess)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Standard / custom header

    private var standardHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: definition.icon)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use Standard Department Setup")
                        .font(.subheadline.weight(.semibold))
                    Text("Start from the standard. Anything you change is saved as a difference.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Setup mode", selection: $draft.usesStandard) {
                Text("Standard").tag(true)
                Text("Custom").tag(false)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: modificationCount == 0 ? "checkmark.seal.fill" : "slider.horizontal.3")
                    .foregroundStyle(modificationCount == 0 ? Theme.accent : Color.orange)
                Text(modificationCount == 0
                     ? "Following department standard"
                     : "^[\(modificationCount) change](inflect: true) from standard")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: - Step card

    private func stepCard(_ step: WorkflowStep, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.12)).frame(width: 26, height: 26)
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label(step.title, systemImage: step.icon)
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                    if let subtitle = step.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(spacing: 14) {
                ForEach(step.fields) { field in
                    WorkflowFieldRow(field: field, draft: $draft)
                    if field.id != step.fields.last?.id {
                        Divider()
                    }
                }
            }
        }
        .card()
    }

    /// For a CSE migrated from the legacy struct, the intrathecal agent was never
    /// recorded. Until the consultant explicitly picks one, flag it so the gap is
    /// visible rather than masked by the department default.
    private var showsIntrathecalAgentNudge: Bool {
        guard definition.id == "cse" else { return false }
        let explicit = (draft.selectionOverrides["spinal.agent"]?.isBlank == false)
        guard !explicit else { return false }
        return store.doctor(id: doctorID)?.neuraxial.legacyCSEHasContent ?? false
    }

    private var intrathecalAgentNudge: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Intrathecal agent not recorded")
                    .font(.subheadline.weight(.semibold))
                Text("This setup was carried over from an earlier version that didn’t store an intrathecal agent. Choose one in the Spinal Component step above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private var disclaimer: some View {
        Text(SafetyText.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    // MARK: - Save

    private func save() {
        guard var doctor = store.doctor(id: doctorID) else { dismiss(); return }
        draft.isConfigured = true
        doctor.neuraxial.setCustomization(draft)
        store.upsert(doctor)
        saveSuccess = true
        dismiss()
    }
}

// MARK: - Field row

/// Renders one workflow field with the appropriate control, a "Modified" badge
/// when it deviates from the standard, and optional custom-option entry.
struct WorkflowFieldRow: View {
    let field: WorkflowField
    @Binding var draft: WorkflowCustomization

    @State private var addingCustom = false
    @State private var customText = ""
    @State private var packExpanded = false

    // Effective values
    private var effectiveBool: Bool { draft.boolOverrides[field.id] ?? field.defaultBool }
    private var effectiveSelection: String { draft.selectionOverrides[field.id] ?? field.defaultSelection }
    private var effectiveMulti: [String] { draft.multiOverrides[field.id] ?? field.defaultMulti }
    private var noteText: String { draft.notes[field.id] ?? "" }
    private var availableOptions: [String] { field.options + (draft.customOptions[field.id] ?? []) }

    private var isModified: Bool {
        switch field.kind {
        case .toggle, .packReference: return effectiveBool != field.defaultBool
        case .singleSelect, .segmented: return effectiveSelection != field.defaultSelection
        case .multiSelect: return Set(effectiveMulti) != Set(field.defaultMulti)
        case .note: return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch field.kind {
            case .toggle: toggleRow
            case .singleSelect: singleSelectRow
            case .segmented: segmentedRow
            case .multiSelect: multiSelectRow
            case .note: noteRow
            case .packReference: packRow
            }
        }
        .alert("Add custom option", isPresented: $addingCustom) {
            TextField("Name", text: $customText)
            Button("Add") { commitCustom() }
            Button("Cancel", role: .cancel) { customText = "" }
        } message: {
            Text("Add an item not in the standard list.")
        }
    }

    // MARK: Controls

    private var labelLine: some View {
        HStack(spacing: 8) {
            if let icon = field.icon {
                Image(systemName: icon).font(.subheadline).foregroundStyle(Theme.accent).frame(width: 20)
            }
            Text(field.label).font(.subheadline)
            if isModified { modifiedBadge }
            Spacer(minLength: 8)
        }
    }

    private var modifiedBadge: some View {
        Text("Updated")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.16), in: .capsule)
            .foregroundStyle(.orange)
    }

    private var toggleRow: some View {
        Toggle(isOn: Binding(
            get: { effectiveBool },
            set: { draft.setBool(field.id, $0, default: field.defaultBool) }
        )) {
            HStack(spacing: 8) {
                if let icon = field.icon {
                    Image(systemName: icon).font(.subheadline).foregroundStyle(Theme.accent).frame(width: 20)
                }
                Text(field.label).font(.subheadline)
                if isModified { modifiedBadge }
            }
        }
        .tint(Theme.accent)
    }

    private var singleSelectRow: some View {
        Menu {
            ForEach(availableOptions, id: \.self) { option in
                Button {
                    draft.setSelection(field.id, option, default: field.defaultSelection)
                } label: {
                    if option == effectiveSelection {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
            if field.allowsCustom {
                Divider()
                Button { addingCustom = true } label: { Label("Add custom…", systemImage: "plus") }
            }
        } label: {
            HStack(spacing: 8) {
                if let icon = field.icon {
                    Image(systemName: icon).font(.subheadline).foregroundStyle(Theme.accent).frame(width: 20)
                }
                Text(field.label).font(.subheadline).foregroundStyle(.primary)
                if isModified { modifiedBadge }
                Spacer(minLength: 8)
                Text(effectiveSelection.isBlank ? "Choose" : effectiveSelection)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(effectiveSelection.isBlank ? .secondary : Theme.accentDeep)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private var segmentedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            labelLine
            Picker(field.label, selection: Binding(
                get: { effectiveSelection },
                set: { draft.setSelection(field.id, $0, default: field.defaultSelection) }
            )) {
                ForEach(field.options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var multiSelectRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            labelLine
            FlowLayout(spacing: 8) {
                ForEach(availableOptions, id: \.self) { option in
                    Button { toggleMulti(option) } label: {
                        Chip(text: option, selected: effectiveMulti.contains(option))
                    }
                    .buttonStyle(.plain)
                }
                if field.allowsCustom {
                    Button { addingCustom = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.accent.opacity(0.12), in: .capsule)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            if effectiveMulti.isEmpty {
                Text("Nothing beyond the standard").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var noteRow: some View {
        NotesField(label: field.label, text: Binding(
            get: { noteText },
            set: { draft.setNote(field.id, $0) }
        ), minHeight: 64)
    }

    private var packRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { effectiveBool },
                set: { draft.setBool(field.id, $0, default: field.defaultBool) }
            )) {
                HStack(spacing: 8) {
                    if let icon = field.icon {
                        Image(systemName: icon).font(.subheadline).foregroundStyle(Theme.accent).frame(width: 20)
                    }
                    Text(field.label).font(.subheadline)
                    if isModified { modifiedBadge }
                }
            }
            .tint(Theme.accent)

            if !field.referenceItems.isEmpty {
                DisclosureGroup(isExpanded: $packExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(field.referenceItems, id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tertiary)
                                Text(item).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Typical pack contents (reference)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Mutations

    private func toggleMulti(_ option: String) {
        var current = effectiveMulti
        if let index = current.firstIndex(of: option) {
            current.remove(at: index)
        } else {
            current.append(option)
        }
        draft.setMulti(field.id, current, default: field.defaultMulti)
    }

    private func commitCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft.addCustomOption(field.id, trimmed)
        // Auto-select the newly added option.
        switch field.kind {
        case .singleSelect:
            draft.setSelection(field.id, trimmed, default: field.defaultSelection)
        case .multiSelect:
            var current = effectiveMulti
            current.append(trimmed)
            draft.setMulti(field.id, current, default: field.defaultMulti)
        default:
            break
        }
        customText = ""
    }
}
