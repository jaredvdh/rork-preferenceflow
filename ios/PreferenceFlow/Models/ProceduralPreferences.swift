//
//  ProceduralPreferences.swift
//  PreferenceFlow
//
//  Dedicated storage for procedural workflow customisations (Arterial Line,
//  CVC). These previously had no storage of their own — demo data parked them
//  inside `NeuraxialPreferences.workflows`, which was semantically wrong (an
//  arterial line is not a neuraxial technique) and left real profiles with no
//  way to hold this data at all.
//

import Foundation

/// Consultant customisations for procedural workflows (Arterial Line, CVC),
/// keyed by `WorkflowDefinition.id`. Mirrors the `NeuraxialPreferences`
/// workflow API so the shared editor and summary pipelines work unchanged.
nonisolated struct ProceduralPreferences: Codable, Hashable {
    /// Each entry stores only the consultant's deviations from the department
    /// standard, exactly like the neuraxial workflows.
    var workflows: [WorkflowCustomization]

    init(workflows: [WorkflowCustomization] = []) {
        self.workflows = workflows
    }

    /// The saved customization for a workflow id, or a fresh one if absent.
    func customization(for definitionID: String) -> WorkflowCustomization {
        workflows.first { $0.id == definitionID } ?? WorkflowCustomization(id: definitionID)
    }

    /// Inserts or replaces a workflow customization.
    mutating func setCustomization(_ customization: WorkflowCustomization) {
        if let index = workflows.firstIndex(where: { $0.id == customization.id }) {
            workflows[index] = customization
        } else {
            workflows.append(customization)
        }
    }

    /// Whether the consultant has configured a given workflow.
    func isConfigured(_ definitionID: String) -> Bool {
        workflows.first { $0.id == definitionID }?.isConfigured ?? false
    }
}

extension Doctor {
    /// One-time, idempotent migration: procedural workflow customisations
    /// (Arterial Line, CVC) saved under `neuraxial.workflows` by earlier
    /// versions move into their own `procedural` storage. Returns true if
    /// anything was moved.
    @discardableResult
    mutating func migrateProceduralStorageIfNeeded() -> Bool {
        guard var list = neuraxial.workflows else { return false }
        let proceduralIDs = Set(WorkflowLibrary.procedural.map(\.id))
        let moving = list.filter { proceduralIDs.contains($0.id) }
        guard !moving.isEmpty else { return false }

        var updated = procedural ?? ProceduralPreferences()
        for item in moving where !updated.isConfigured(item.id) {
            updated.setCustomization(item)
        }
        procedural = updated

        list.removeAll { proceduralIDs.contains($0.id) }
        neuraxial.workflows = list.isEmpty ? nil : list
        return true
    }
}
