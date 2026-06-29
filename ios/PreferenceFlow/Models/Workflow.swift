//
//  Workflow.swift
//  PreferenceFlow
//
//  A data-driven guided-workflow engine. A WorkflowDefinition describes a
//  department "standard setup" as structured steps and fields. A consultant
//  profile stores only a WorkflowCustomization — the *differences* from that
//  standard — so profiles stay concise and easy to maintain. Adding new
//  workflow types (arterial line, CVC, blocks, RSI…) is purely additive: define
//  a new WorkflowDefinition and it renders with the same guided UI.
//

import Foundation

// MARK: - Definition (department standard, code-defined)

/// How a single field is captured.
nonisolated enum WorkflowFieldKind: String, Hashable {
    /// A single on/off choice (e.g. "Introducer").
    case toggle
    /// One option from a list, shown as a dropdown.
    case singleSelect
    /// One option from a short list, shown as a segmented control.
    case segmented
    /// Any number of options from a list, shown as chips.
    case multiSelect
    /// Free-text notes.
    case note
    /// A read-only reference list (e.g. standard pack contents) the user can expand.
    case packReference
}

/// One configurable item inside a workflow step. The `default*` values together
/// describe the department standard for this field.
nonisolated struct WorkflowField: Identifiable, Hashable {
    let id: String
    let label: String
    let kind: WorkflowFieldKind
    var icon: String? = nil
    var help: String? = nil
    var options: [String] = []
    /// Reference contents shown for `.packReference` fields.
    var referenceItems: [String] = []
    /// Lets the user add their own options (adds an "Add custom" affordance).
    var allowsCustom: Bool = false

    // Department standard defaults
    var defaultBool: Bool = false
    var defaultSelection: String = ""
    var defaultMulti: [String] = []
}

/// A titled group of fields — one card in the guided flow.
nonisolated struct WorkflowStep: Identifiable, Hashable {
    let id: String
    let title: String
    var icon: String = "circle"
    var subtitle: String? = nil
    var fields: [WorkflowField]
}

/// A complete workflow template (the department standard).
nonisolated struct WorkflowDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    var icon: String
    var summary: String
    var steps: [WorkflowStep]

    var allFields: [WorkflowField] { steps.flatMap(\.fields) }
    func field(_ fieldID: String) -> WorkflowField? { allFields.first { $0.id == fieldID } }
}

// MARK: - Customization (consultant deviations, persisted)

/// Stores only how a consultant deviates from the department standard for a
/// given workflow. Empty override dictionaries mean "follows the standard".
nonisolated struct WorkflowCustomization: Identifiable, Codable, Hashable {
    /// Matches the WorkflowDefinition id this customises.
    var id: String
    /// Intent flag: true = "Use standard department setup", false = "custom".
    var usesStandard: Bool = true
    /// True once the consultant has actively saved this workflow.
    var isConfigured: Bool = false

    var boolOverrides: [String: Bool] = [:]
    var selectionOverrides: [String: String] = [:]
    var multiOverrides: [String: [String]] = [:]
    /// Extra options the consultant added beyond the curated list, per field.
    var customOptions: [String: [String]] = [:]
    /// Free-text notes per field id.
    var notes: [String: String] = [:]

    init(id: String) { self.id = id }
}

// MARK: - Resolver (combines definition + customization)

/// Resolves the effective value of each field by layering the consultant's
/// overrides on top of the department standard, and reports deviations.
nonisolated struct ResolvedWorkflow {
    let definition: WorkflowDefinition
    var customization: WorkflowCustomization

    // Effective values -------------------------------------------------------

    func boolValue(_ fieldID: String) -> Bool {
        customization.boolOverrides[fieldID] ?? definition.field(fieldID)?.defaultBool ?? false
    }

    func selection(_ fieldID: String) -> String {
        customization.selectionOverrides[fieldID] ?? definition.field(fieldID)?.defaultSelection ?? ""
    }

    func multi(_ fieldID: String) -> [String] {
        customization.multiOverrides[fieldID] ?? definition.field(fieldID)?.defaultMulti ?? []
    }

    func note(_ fieldID: String) -> String {
        customization.notes[fieldID] ?? ""
    }

    /// All options available for a field: curated list plus any custom additions.
    func options(_ field: WorkflowField) -> [String] {
        field.options + (customization.customOptions[field.id] ?? [])
    }

    // Deviation detection ----------------------------------------------------

    /// Whether a field's effective value differs from the department standard.
    func isModified(_ field: WorkflowField) -> Bool {
        switch field.kind {
        case .toggle:
            return boolValue(field.id) != field.defaultBool
        case .singleSelect, .segmented:
            return selection(field.id) != field.defaultSelection
        case .multiSelect:
            return Set(multi(field.id)) != Set(field.defaultMulti)
        case .note:
            return !note(field.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .packReference:
            return false
        }
    }

    /// Count of fields that deviate from the department standard.
    var modificationCount: Int {
        definition.allFields.filter { isModified($0) }.count
    }

    // Human-readable value (for read displays / sharing) ---------------------

    /// A display string for a field's effective value, or "" if nothing meaningful.
    func displayValue(_ field: WorkflowField) -> String {
        switch field.kind {
        case .toggle:
            return boolValue(field.id) ? "Yes" : "No"
        case .singleSelect, .segmented:
            return selection(field.id)
        case .multiSelect:
            return multi(field.id).joined(separator: ", ")
        case .note:
            return note(field.id)
        case .packReference:
            return boolValue(field.id) ? "Standard pack" : ""
        }
    }
}

// MARK: - Mutation helpers (write back overrides, dropping no-op diffs)

extension WorkflowCustomization {
    /// Sets a bool override, clearing it when it matches the standard default.
    mutating func setBool(_ fieldID: String, _ value: Bool, default def: Bool) {
        if value == def { boolOverrides[fieldID] = nil } else { boolOverrides[fieldID] = value }
    }

    mutating func setSelection(_ fieldID: String, _ value: String, default def: String) {
        if value == def { selectionOverrides[fieldID] = nil } else { selectionOverrides[fieldID] = value }
    }

    mutating func setMulti(_ fieldID: String, _ value: [String], default def: [String]) {
        if Set(value) == Set(def) { multiOverrides[fieldID] = nil } else { multiOverrides[fieldID] = value }
    }

    mutating func setNote(_ fieldID: String, _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { notes[fieldID] = nil } else { notes[fieldID] = value }
    }

    mutating func addCustomOption(_ fieldID: String, _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var existing = customOptions[fieldID] ?? []
        guard !existing.contains(trimmed) else { return }
        existing.append(trimmed)
        customOptions[fieldID] = existing
    }
}
