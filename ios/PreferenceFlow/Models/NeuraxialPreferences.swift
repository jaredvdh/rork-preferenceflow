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

// MARK: - Legacy Combined Spinal Epidural migration

extension NeuraxialPreferences {
    /// True when the legacy `combinedSpinalEpidural` struct holds any content.
    /// Used both to drive the one-time migration and to distinguish a genuinely
    /// incomplete migrated CSE from a setup configured fresh via the workflow.
    var legacyCSEHasContent: Bool {
        let c = combinedSpinalEpidural
        return !c.preferredKit.isBlank
            || !c.needleThroughNeedlePreference.isBlank
            || !c.spinalSetupNotes.isBlank
            || !c.epiduralSetupNotes.isBlank
            || !c.dressingPreference.isBlank
            || !c.assistantNotes.isBlank
    }

    /// One-time migration: if the legacy CSE struct has content but no "cse"
    /// workflow is configured, fold whatever can be carried over from the legacy
    /// free-text fields into a new "cse" `WorkflowCustomization`, making the
    /// workflow system the active source of truth (consistent with every other
    /// neuraxial type). The legacy struct is preserved, not deleted.
    ///
    /// The intrathecal agent and additives are intentionally left blank — the
    /// legacy struct never stored them — so a genuinely missing agent is surfaced
    /// as incomplete elsewhere rather than fabricated here.
    ///
    /// Returns true if a migration was performed.
    @discardableResult
    mutating func migrateLegacyCSEIfNeeded() -> Bool {
        guard legacyCSEHasContent, !isConfigured("cse") else { return false }

        let def = WorkflowLibrary.cse
        let c = combinedSpinalEpidural
        var custom = customization(for: "cse")

        // Carry over the kit selection, registering a custom option when the
        // legacy value isn't one of the curated choices.
        if !c.preferredKit.isBlank {
            let field = def.field("kit.choice")
            if let field, !field.options.contains(c.preferredKit) {
                custom.addCustomOption("kit.choice", c.preferredKit)
            }
            custom.setSelection("kit.choice", c.preferredKit, default: field?.defaultSelection ?? "")
        }

        // Carry over the dressing selection similarly.
        if !c.dressingPreference.isBlank {
            let field = def.field("dressing.choice")
            if let field, !field.options.contains(c.dressingPreference) {
                custom.addCustomOption("dressing.choice", c.dressingPreference)
            }
            custom.setSelection("dressing.choice", c.dressingPreference, default: field?.defaultSelection ?? "")
        }

        // Fold the remaining free-text into the consultant / assistant note fields,
        // labelled so their origin stays clear.
        var consultantParts: [String] = []
        if !c.needleThroughNeedlePreference.isBlank {
            consultantParts.append("Needle-through-needle: \(c.needleThroughNeedlePreference)")
        }
        if !c.spinalSetupNotes.isBlank { consultantParts.append("Spinal setup: \(c.spinalSetupNotes)") }
        if !c.epiduralSetupNotes.isBlank { consultantParts.append("Epidural setup: \(c.epiduralSetupNotes)") }
        if !consultantParts.isEmpty {
            custom.setNote("consultant.notes", consultantParts.joined(separator: "\n"))
        }
        if !c.assistantNotes.isBlank { custom.setNote("assistant.notes", c.assistantNotes) }

        custom.usesStandard = false
        custom.isConfigured = true
        setCustomization(custom)
        return true
    }

    /// Whether a configured CSE's intrathecal agent has never been explicitly
    /// recorded — e.g. a profile migrated from the legacy struct, which never
    /// stored an agent. Drives a visible "not recorded" nudge rather than
    /// silently showing the department default as if the consultant chose it.
    var cseIntrathecalAgentMissing: Bool {
        guard isConfigured("cse") else { return false }
        let custom = customization(for: "cse")
        let explicit = (custom.selectionOverrides["spinal.agent"]?.isBlank == false)
        return !explicit && legacyCSEHasContent
    }
}
