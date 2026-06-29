//
//  DrugsFluids.swift
//  PreferenceFlow
//

import Foundation

/// A structured drug category that the user fills from a curated multi-select
/// list rather than free text. Custom entries are still allowed via `custom`.
nonisolated struct DrugSelection: Codable, Hashable {
    /// Chosen agent names (from the curated list or custom additions).
    var selected: [String]
    /// Who prepares these agents.
    var preparedBy: PreparedBy
    /// Free-text special notes only.
    var notes: String

    init(selected: [String] = [], preparedBy: PreparedBy = .caseDependent, notes: String = "") {
        self.selected = selected
        self.preparedBy = preparedBy
        self.notes = notes
    }

    var isEmpty: Bool { selected.isEmpty && notes.isBlank }
}

/// The drug & fluid categories surfaced in the Drugs & Fluids tab. Each maps to a
/// curated option list. Reference text only — no doses or recommendations.
nonisolated enum DrugCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case induction = "Induction Agent"
    case opioid = "Opioid"
    case vasopressor = "Vasopressor"
    case muscleRelaxant = "Muscle Relaxant"
    case fluid = "IV Fluids"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .induction: return "zzz"
        case .opioid: return "bandage.fill"
        case .vasopressor: return "arrow.up.heart.fill"
        case .muscleRelaxant: return "figure.flexibility"
        case .fluid: return "drop.fill"
        }
    }

    /// Curated options the user selects from. These are simply common agent names
    /// for quick selection — the app stores user preference only.
    var options: [String] {
        switch self {
        case .induction: return ["Propofol", "Ketamine", "Thiopentone", "Etomidate"]
        case .opioid: return ["Fentanyl", "Alfentanil", "Remifentanil", "Morphine"]
        case .vasopressor: return ["Metaraminol", "Phenylephrine", "Ephedrine", "Noradrenaline"]
        case .muscleRelaxant: return ["Rocuronium", "Succinylcholine", "Atracurium", "Cisatracurium"]
        case .fluid: return ["Hartmann's", "Plasma-Lyte", "Normal Saline", "Glucose 5%"]
        }
    }
}

/// Consultant paediatric gas (inhalational) induction preferences. A stored
/// preference only — not a clinical instruction. Surfaced in the Paediatric
/// Drugs & Fluids section and linked from the paediatric airway view.
nonisolated struct GasInductionPreferences: Codable, Hashable {
    /// Whether the consultant records a gas induction preference at all.
    var enabled: Bool
    /// Volatile agent — "Sevoflurane" or "Other".
    var volatileAgent: String
    /// Carrier gas mix (single choice from `carrierOptions`).
    var carrierGas: String
    /// Typical step-up sequence, stored as percentage strings (e.g. "0%", "2%").
    var stepUpSequence: [String]
    /// Free-text notes (mask technique, parent present, IV after induction, etc.).
    var notes: String

    init(
        enabled: Bool = false,
        volatileAgent: String = "Sevoflurane",
        carrierGas: String = "",
        stepUpSequence: [String] = [],
        notes: String = ""
    ) {
        self.enabled = enabled
        self.volatileAgent = volatileAgent
        self.carrierGas = carrierGas
        self.stepUpSequence = stepUpSequence
        self.notes = notes
    }

    static let volatileOptions = ["Sevoflurane", "Other"]
    static let carrierOptions = ["Oxygen", "Nitrous oxide + oxygen", "Air/oxygen"]
    static let stepOptions = ["0%", "1%", "2%", "4%", "6%", "8%"]

    /// Short carrier-gas label for compact summaries.
    var carrierShort: String {
        switch carrierGas {
        case "Oxygen": return "O₂"
        case "Nitrous oxide + oxygen": return "N₂O/O₂"
        case "Air/oxygen": return "Air/O₂"
        default: return carrierGas
        }
    }

    /// e.g. "0 → 1 → 2 → 4 → 6 → 8%", ordered by the canonical step list.
    var sequenceSummary: String {
        let ordered = Self.stepOptions.filter { stepUpSequence.contains($0) }
        guard !ordered.isEmpty else { return "" }
        return ordered.map { $0.replacingOccurrences(of: "%", with: "") }
            .joined(separator: " → ") + "%"
    }

    /// e.g. "Sevoflurane · N₂O/O₂".
    var headlineSummary: String {
        var parts: [String] = []
        if !volatileAgent.isBlank { parts.append(volatileAgent) }
        if !carrierShort.isBlank { parts.append(carrierShort) }
        return parts.joined(separator: " · ")
    }

    var hasContent: Bool { enabled }
}

/// Structured drugs & fluids preferences for one age cohort (adult or paediatric).
/// Independent per cohort, replacing the old free-text medication list. The legacy
/// `MedicationSetup` is retained on `Doctor` so existing data is never lost.
nonisolated struct DrugsFluidsSetup: Codable, Hashable {
    var induction: DrugSelection
    var opioid: DrugSelection
    var vasopressor: DrugSelection
    var muscleRelaxant: DrugSelection
    var fluids: DrugSelection
    var notes: String
    /// Paediatric gas induction preference. Only surfaced for the paediatric
    /// cohort. Optional for backward-compatible decoding of older profiles.
    var gasInduction: GasInductionPreferences?

    init(
        induction: DrugSelection = DrugSelection(),
        opioid: DrugSelection = DrugSelection(),
        vasopressor: DrugSelection = DrugSelection(),
        muscleRelaxant: DrugSelection = DrugSelection(),
        fluids: DrugSelection = DrugSelection(),
        notes: String = "",
        gasInduction: GasInductionPreferences? = nil
    ) {
        self.induction = induction
        self.opioid = opioid
        self.vasopressor = vasopressor
        self.muscleRelaxant = muscleRelaxant
        self.fluids = fluids
        self.notes = notes
        self.gasInduction = gasInduction
    }

    func selection(for category: DrugCategory) -> DrugSelection {
        switch category {
        case .induction: return induction
        case .opioid: return opioid
        case .vasopressor: return vasopressor
        case .muscleRelaxant: return muscleRelaxant
        case .fluid: return fluids
        }
    }

    /// Whether any category has been filled in.
    var hasContent: Bool {
        !induction.isEmpty || !opioid.isEmpty || !vasopressor.isEmpty
            || !muscleRelaxant.isEmpty || !fluids.isEmpty || !notes.isBlank
    }

    /// All prepared-by-assistant or doctor agents flattened for checklist building.
    var allSelectedAgents: [String] {
        induction.selected + opioid.selected + vasopressor.selected
            + muscleRelaxant.selected + fluids.selected
    }
}
