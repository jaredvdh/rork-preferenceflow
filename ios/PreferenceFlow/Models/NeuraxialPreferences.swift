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
    /// Local anaesthetic infiltrated at the skin / subcutaneous site before the
    /// spinal needle is inserted (e.g. "Lignocaine 1% 5 mL"). Distinct from the
    /// intrathecal agent below.
    var topicalSkinAnaesthetic: String = ""
    /// The drug(s) injected intrathecally — a primary agent plus an optional
    /// adjunct (e.g. "Heavy Bupivacaine with Fentanyl").
    var intrathecalAgent: String = ""
    var additives: String = ""
    var needleType: String = ""
    var needleGauge: String = ""
    var introducerPreference: String = ""
    var position: String = ""
    var skinPrep: String = ""
    var dressingPreference: String = ""
    var assistantSetupNotes: String = ""
    var specialNotes: String = ""

    init() {}

    private enum CodingKeys: String, CodingKey {
        case preferredPack, topicalSkinAnaesthetic, intrathecalAgent
        case localAnaesthetic // legacy combined field
        case additives, needleType, needleGauge, introducerPreference
        case position, skinPrep, dressingPreference, assistantSetupNotes, specialNotes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preferredPack = try c.decodeIfPresent(String.self, forKey: .preferredPack) ?? ""
        topicalSkinAnaesthetic = try c.decodeIfPresent(String.self, forKey: .topicalSkinAnaesthetic) ?? ""
        // Migrate the old combined "localAnaesthetic" value into intrathecalAgent;
        // leave topicalSkinAnaesthetic blank for the user to fill in separately.
        if let agent = try c.decodeIfPresent(String.self, forKey: .intrathecalAgent), !agent.isEmpty {
            intrathecalAgent = agent
        } else {
            intrathecalAgent = try c.decodeIfPresent(String.self, forKey: .localAnaesthetic) ?? ""
        }
        additives = try c.decodeIfPresent(String.self, forKey: .additives) ?? ""
        needleType = try c.decodeIfPresent(String.self, forKey: .needleType) ?? ""
        needleGauge = try c.decodeIfPresent(String.self, forKey: .needleGauge) ?? ""
        introducerPreference = try c.decodeIfPresent(String.self, forKey: .introducerPreference) ?? ""
        position = try c.decodeIfPresent(String.self, forKey: .position) ?? ""
        skinPrep = try c.decodeIfPresent(String.self, forKey: .skinPrep) ?? ""
        dressingPreference = try c.decodeIfPresent(String.self, forKey: .dressingPreference) ?? ""
        assistantSetupNotes = try c.decodeIfPresent(String.self, forKey: .assistantSetupNotes) ?? ""
        specialNotes = try c.decodeIfPresent(String.self, forKey: .specialNotes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(preferredPack, forKey: .preferredPack)
        try c.encode(topicalSkinAnaesthetic, forKey: .topicalSkinAnaesthetic)
        try c.encode(intrathecalAgent, forKey: .intrathecalAgent)
        try c.encode(additives, forKey: .additives)
        try c.encode(needleType, forKey: .needleType)
        try c.encode(needleGauge, forKey: .needleGauge)
        try c.encode(introducerPreference, forKey: .introducerPreference)
        try c.encode(position, forKey: .position)
        try c.encode(skinPrep, forKey: .skinPrep)
        try c.encode(dressingPreference, forKey: .dressingPreference)
        try c.encode(assistantSetupNotes, forKey: .assistantSetupNotes)
        try c.encode(specialNotes, forKey: .specialNotes)
    }
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
