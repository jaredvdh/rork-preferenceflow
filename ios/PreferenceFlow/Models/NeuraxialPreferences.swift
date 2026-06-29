//
//  NeuraxialPreferences.swift
//  PreferenceFlow
//

import Foundation

nonisolated enum LossOfResistanceMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case saline = "Saline"
    case air = "Air"
    case either = "Either"
    case notSpecified = "Not specified"
    var id: String { rawValue }
}

nonisolated struct SpinalPreferences: Codable, Hashable {
    var preferredPack: String = ""
    var localAnaesthetic: String = ""
    var additives: String = ""
    var needleType: String = ""
    var needleGauge: String = ""
    var introducerPreference: String = ""
    var position: String = ""
    var skinPrep: String = ""
    var dressingPreference: String = ""
    var assistantSetupNotes: String = ""
    var specialNotes: String = ""
}

nonisolated struct EpiduralPreferences: Codable, Hashable {
    var epiduralKit: String = ""
    var lossOfResistanceMethod: LossOfResistanceMethod = .notSpecified
    var catheterSetup: String = ""
    var dressingPreference: String = ""
    var testDosePreference: String = ""
    var infusionSetupNotes: String = ""
    var assistantNotes: String = ""
    var specialNotes: String = ""
}

nonisolated struct CombinedSpinalEpiduralPreferences: Codable, Hashable {
    var preferredKit: String = ""
    var needleThroughNeedlePreference: String = ""
    var spinalSetupNotes: String = ""
    var epiduralSetupNotes: String = ""
    var dressingPreference: String = ""
    var assistantNotes: String = ""
}

nonisolated struct NeuraxialPreferences: Codable, Hashable {
    var spinal: SpinalPreferences = SpinalPreferences()
    var epidural: EpiduralPreferences = EpiduralPreferences()
    var combinedSpinalEpidural: CombinedSpinalEpiduralPreferences = CombinedSpinalEpiduralPreferences()
    /// Template-driven guided workflows (v3). Each stores only the consultant's
    /// deviations from the department standard. Optional for backward-compatible
    /// decoding of profiles saved before workflows existed.
    var workflows: [WorkflowCustomization]?

    /// The saved customization for a workflow id, or a fresh one if absent.
    func customization(for definitionID: String) -> WorkflowCustomization {
        workflows?.first { $0.id == definitionID } ?? WorkflowCustomization(id: definitionID)
    }

    /// Inserts or replaces a workflow customization.
    mutating func setCustomization(_ customization: WorkflowCustomization) {
        var list = workflows ?? []
        if let index = list.firstIndex(where: { $0.id == customization.id }) {
            list[index] = customization
        } else {
            list.append(customization)
        }
        workflows = list
    }

    /// Whether the consultant has configured a given workflow.
    func isConfigured(_ definitionID: String) -> Bool {
        workflows?.first { $0.id == definitionID }?.isConfigured ?? false
    }
}
