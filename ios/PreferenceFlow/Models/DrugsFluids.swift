//
//  DrugsFluids.swift
//  PreferenceFlow
//

import Foundation

/// A structured drug category that the user fills from a curated multi-select
/// list rather than free text. Custom entries are still allowed via `custom`.
nonisolated struct DrugSelection: Codable, Hashable {
    /// Chosen agent names from the curated list.
    var selected: [String]
    /// Custom agent names added by the user (unusual agents not in the curated list).
    var custom: [String]
    /// Who prepares these agents.
    var preparedBy: PreparedBy
    /// Free-text special notes only.
    var notes: String

    init(selected: [String] = [], custom: [String] = [], preparedBy: PreparedBy = .caseDependent, notes: String = "") {
        self.selected = selected
        self.custom = custom
        self.preparedBy = preparedBy
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case selected, custom, preparedBy, notes
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selected = try c.decodeIfPresent([String].self, forKey: .selected) ?? []
        custom = try c.decodeIfPresent([String].self, forKey: .custom) ?? []
        preparedBy = try c.decodeIfPresent(PreparedBy.self, forKey: .preparedBy) ?? .caseDependent
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    /// Curated selections plus any custom additions, in display order.
    var allAgents: [String] { selected + custom }

    var isEmpty: Bool { selected.isEmpty && custom.isEmpty && notes.isBlank }
}

/// The drug & fluid categories surfaced in the Drugs & Fluids tab. Each maps to a
/// curated option list. Reference text only — no doses or recommendations.
nonisolated enum DrugCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case induction = "Induction Agent"
    case opioid = "Opioid"
    case vasopressor = "Vasopressor"
    case muscleRelaxant = "Muscle Relaxant"
    case reversal = "Reversal Agents"
    case fluid = "IV Fluids"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .induction: return "zzz"
        case .opioid: return "bandage.fill"
        case .vasopressor: return "arrow.up.heart.fill"
        case .muscleRelaxant: return "figure.flexibility"
        case .reversal: return "arrow.uturn.backward.circle.fill"
        case .fluid: return "drop.fill"
        }
    }

    /// Curated options the user selects from. These are simply common agent names
    /// for quick selection — the app stores user preference only.
    var options: [String] {
        switch self {
        case .induction:
            return ["Propofol", "Ketamine", "Thiopentone", "Etomidate",
                    "Dexmedetomidine", "Midazolam", "Remimazolam"]
        case .opioid:
            return ["Fentanyl", "Alfentanil", "Remifentanil", "Morphine",
                    "Oxycodone", "Hydromorphone", "Tramadol", "Sufentanil"]
        case .vasopressor:
            return ["Metaraminol", "Phenylephrine", "Ephedrine", "Noradrenaline",
                    "Vasopressin", "Adrenaline (Epinephrine)", "Dopamine", "Dobutamine"]
        case .muscleRelaxant:
            return ["Rocuronium", "Succinylcholine", "Atracurium", "Cisatracurium",
                    "Vecuronium", "Mivacurium", "Pancuronium"]
        case .reversal:
            return ["Sugammadex", "Neostigmine", "Glycopyrrolate",
                    "Neostigmine + Glycopyrrolate", "Flumazenil", "Naloxone"]
        case .fluid:
            return ["Hartmann's", "Plasma-Lyte", "Normal Saline", "Glucose 5%",
                    "Gelofusine", "Albumin 4%", "Albumin 20%", "Plasmalyte 148"]
        }
    }

    /// The routine drug categories backed by a `DrugSelection` — everything
    /// except IV fluids, which now uses the structured `FluidSetup` model.
    static let drugCases: [DrugCategory] = [.induction, .opioid, .vasopressor, .muscleRelaxant, .reversal]
}

/// The giving set the technician should prime alongside the chosen IV fluids.
nonisolated enum GivingSetType: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard set"
    case pump = "Pump set"
    case buretrol = "Buretrol"
    case bloodSet = "Blood administration set"
    case other = "Other"

    var id: String { rawValue }
}

/// Structured IV fluid preferences: a primary fluid, an optional secondary
/// (e.g. a saline bag run first for cost, then switching to Hartmann's or
/// Plasma-Lyte), and the giving set to prepare. Replaces the old flat
/// multi-select fluid list.
nonisolated struct FluidSetup: Codable, Hashable {
    /// The first-line fluid, e.g. "Hartmann's".
    var primary: String
    /// Optional follow-on fluid — blank when not used.
    var secondary: String
    /// The giving set the technician should prime.
    var givingSet: GivingSetType
    var notes: String

    init(primary: String = "", secondary: String = "",
         givingSet: GivingSetType = .standard, notes: String = "") {
        self.primary = primary
        self.secondary = secondary
        self.givingSet = givingSet
        self.notes = notes
    }

    /// Curated fluid options shared by the primary and secondary pickers.
    static let fluidOptions = ["Hartmann's", "Plasma-Lyte", "Normal Saline", "Glucose 5%",
                               "Gelofusine", "Albumin 4%", "Albumin 20%", "Plasmalyte 148"]

    /// The set fluids in display order (primary first).
    var allAgents: [String] { [primary, secondary].filter { !$0.isBlank } }

    var isEmpty: Bool { primary.isBlank && secondary.isBlank && notes.isBlank }

    private enum CodingKeys: String, CodingKey { case primary, secondary, givingSet, notes }
    /// The old flat `DrugSelection` fluid shape, for migrating saved profiles.
    private enum LegacyKeys: String, CodingKey { case selected, custom, notes }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.primary) || c.contains(.secondary) || c.contains(.givingSet) {
            primary = try c.decodeIfPresent(String.self, forKey: .primary) ?? ""
            secondary = try c.decodeIfPresent(String.self, forKey: .secondary) ?? ""
            givingSet = try c.decodeIfPresent(GivingSetType.self, forKey: .givingSet) ?? .standard
            notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        } else {
            // Legacy migration: the first saved fluid becomes the primary, the
            // second (if any) the secondary, and any further agents are
            // preserved in notes so no saved preference is lost.
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let agents = ((try legacy.decodeIfPresent([String].self, forKey: .selected)) ?? [])
                + ((try legacy.decodeIfPresent([String].self, forKey: .custom)) ?? [])
            primary = agents.first ?? ""
            secondary = agents.count > 1 ? agents[1] : ""
            givingSet = .standard
            var migratedNotes = try legacy.decodeIfPresent(String.self, forKey: .notes) ?? ""
            if agents.count > 2 {
                let extras = "Also: \(agents.dropFirst(2).joined(separator: ", "))"
                migratedNotes = migratedNotes.isBlank ? extras : migratedNotes + "\n" + extras
            }
            notes = migratedNotes
        }
    }
}

/// Drugs the consultant wants drawn up or immediately available for emergencies
/// during the case — a separate category from routine induction/maintenance
/// drugs, always visible on the consultant card. Reference preference only.
nonisolated struct EmergencyDrugSetup: Codable, Hashable {
    /// Chosen drugs from the curated list.
    var selected: [String]
    /// Custom drug names added by the user.
    var custom: [String]
    /// e.g. "1:100,000 (10mcg/mL)", "1:1,000,000 (1mcg/mL)" or "Not used".
    var pushDoseAdrenalineDilution: String
    /// Whether Suxamethonium is kept drawn up for paediatric cases.
    var paediatricSuxamethonium: Bool
    var preparedBy: PreparedBy
    var notes: String

    init(selected: [String] = [], custom: [String] = [],
         pushDoseAdrenalineDilution: String = "Not used",
         paediatricSuxamethonium: Bool = false,
         preparedBy: PreparedBy = .caseDependent, notes: String = "") {
        self.selected = selected
        self.custom = custom
        self.pushDoseAdrenalineDilution = pushDoseAdrenalineDilution
        self.paediatricSuxamethonium = paediatricSuxamethonium
        self.preparedBy = preparedBy
        self.notes = notes
    }

    static let drugOptions = ["Atropine", "Suxamethonium", "Ephedrine (pre-drawn)",
                              "Glycopyrrolate", "Calcium chloride", "Calcium gluconate",
                              "Magnesium sulfate", "Sodium bicarbonate", "Intralipid (20%)"]
    static let dilutionOptions = ["1:100,000 (10mcg/mL)", "1:1,000,000 (1mcg/mL)", "Not used"]

    var allAgents: [String] { selected + custom }

    /// Whether a push-dose adrenaline dilution has actually been chosen.
    var hasPushDose: Bool {
        !pushDoseAdrenalineDilution.isBlank && pushDoseAdrenalineDilution != "Not used"
    }

    var isEmpty: Bool {
        selected.isEmpty && custom.isEmpty && !hasPushDose
            && !paediatricSuxamethonium && notes.isBlank
    }

    private enum CodingKeys: String, CodingKey {
        case selected, custom, pushDoseAdrenalineDilution, paediatricSuxamethonium, preparedBy, notes
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selected = try c.decodeIfPresent([String].self, forKey: .selected) ?? []
        custom = try c.decodeIfPresent([String].self, forKey: .custom) ?? []
        pushDoseAdrenalineDilution = try c.decodeIfPresent(String.self, forKey: .pushDoseAdrenalineDilution) ?? "Not used"
        paediatricSuxamethonium = try c.decodeIfPresent(Bool.self, forKey: .paediatricSuxamethonium) ?? false
        preparedBy = try c.decodeIfPresent(PreparedBy.self, forKey: .preparedBy) ?? .caseDependent
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

/// The anaesthetic maintenance technique — a first-class consultant preference
/// that directly drives what a technician prepares (TCI pump + infusions for
/// TIVA, calibrated vaporiser + agent for volatile). Adult cohort only.
nonisolated enum MaintenanceTechnique: String, CaseIterable, Codable, Identifiable {
    case notSpecified = "Not specified"
    case tiva = "TIVA"
    case volatile = "Volatile"
    case balanced = "Balanced (volatile + opioid)"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .notSpecified: return "questionmark.circle"
        case .tiva: return "ivfluid.bag"
        case .volatile: return "aqi.medium"
        case .balanced: return "slider.horizontal.3"
        }
    }

    /// TCI agent options surfaced when TIVA is chosen.
    static let tciAgentOptions = ["Propofol", "Propofol/Remifentanil"]
    /// TCI pharmacokinetic model options.
    static let tciModelOptions = ["Marsh", "Schnider", "Minto"]
    /// Volatile agent options surfaced when Volatile or Balanced is chosen.
    static let volatileAgentOptions = ["Sevoflurane", "Desflurane", "Isoflurane", "Other"]
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
    var reversal: DrugSelection
    var fluids: FluidSetup
    /// Emergency drugs kept drawn up or readily available during the case —
    /// separate from routine drugs, always visible on the consultant card.
    var emergency: EmergencyDrugSetup
    var notes: String
    /// Paediatric gas induction preference. Only surfaced for the paediatric
    /// cohort. Optional for backward-compatible decoding of older profiles.
    var gasInduction: GasInductionPreferences?
    /// Adult maintenance technique. Optional for backward-compatible decoding of
    /// older profiles (nil is treated as `.notSpecified`).
    var maintenance: MaintenanceTechnique?
    /// Preferred TCI agent when maintenance is TIVA.
    var tciAgent: String
    /// Preferred TCI pharmacokinetic model when maintenance is TIVA.
    var tciModel: String
    /// Preferred volatile agent when maintenance is Volatile or Balanced.
    var maintenanceVolatileAgent: String

    init(
        induction: DrugSelection = DrugSelection(),
        opioid: DrugSelection = DrugSelection(),
        vasopressor: DrugSelection = DrugSelection(),
        muscleRelaxant: DrugSelection = DrugSelection(),
        reversal: DrugSelection = DrugSelection(),
        fluids: FluidSetup = FluidSetup(),
        emergency: EmergencyDrugSetup = EmergencyDrugSetup(),
        notes: String = "",
        gasInduction: GasInductionPreferences? = nil,
        maintenance: MaintenanceTechnique? = nil,
        tciAgent: String = "",
        tciModel: String = "",
        maintenanceVolatileAgent: String = ""
    ) {
        self.induction = induction
        self.opioid = opioid
        self.vasopressor = vasopressor
        self.muscleRelaxant = muscleRelaxant
        self.reversal = reversal
        self.fluids = fluids
        self.emergency = emergency
        self.notes = notes
        self.gasInduction = gasInduction
        self.maintenance = maintenance
        self.tciAgent = tciAgent
        self.tciModel = tciModel
        self.maintenanceVolatileAgent = maintenanceVolatileAgent
    }

    private enum CodingKeys: String, CodingKey {
        case induction, opioid, vasopressor, muscleRelaxant, reversal, fluids, emergency,
             notes, gasInduction, maintenance, tciAgent, tciModel, maintenanceVolatileAgent
    }

    /// Backward-compatible decoding: every field falls back to its default when
    /// missing, and `fluids` migrates the old flat `DrugSelection` shape via
    /// `FluidSetup`'s own legacy-aware decoder.
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        induction = try c.decodeIfPresent(DrugSelection.self, forKey: .induction) ?? DrugSelection()
        opioid = try c.decodeIfPresent(DrugSelection.self, forKey: .opioid) ?? DrugSelection()
        vasopressor = try c.decodeIfPresent(DrugSelection.self, forKey: .vasopressor) ?? DrugSelection()
        muscleRelaxant = try c.decodeIfPresent(DrugSelection.self, forKey: .muscleRelaxant) ?? DrugSelection()
        reversal = try c.decodeIfPresent(DrugSelection.self, forKey: .reversal) ?? DrugSelection()
        fluids = try c.decodeIfPresent(FluidSetup.self, forKey: .fluids) ?? FluidSetup()
        emergency = try c.decodeIfPresent(EmergencyDrugSetup.self, forKey: .emergency) ?? EmergencyDrugSetup()
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        gasInduction = try c.decodeIfPresent(GasInductionPreferences.self, forKey: .gasInduction)
        maintenance = try c.decodeIfPresent(MaintenanceTechnique.self, forKey: .maintenance)
        tciAgent = try c.decodeIfPresent(String.self, forKey: .tciAgent) ?? ""
        tciModel = try c.decodeIfPresent(String.self, forKey: .tciModel) ?? ""
        maintenanceVolatileAgent = try c.decodeIfPresent(String.self, forKey: .maintenanceVolatileAgent) ?? ""
    }

    /// The effective maintenance technique (nil normalised to `.notSpecified`).
    var maintenanceTechnique: MaintenanceTechnique { maintenance ?? .notSpecified }

    /// Whether a maintenance technique worth surfacing has been set.
    var hasMaintenance: Bool { maintenanceTechnique != .notSpecified }

    /// One-line detail beneath the maintenance headline (agent / model), or "".
    var maintenanceDetail: String {
        switch maintenanceTechnique {
        case .tiva:
            var parts: [String] = []
            if !tciAgent.isBlank { parts.append(tciAgent) }
            if !tciModel.isBlank { parts.append("\(tciModel) model") }
            return parts.joined(separator: " · ")
        case .volatile, .balanced:
            return maintenanceVolatileAgent.isBlank ? "" : maintenanceVolatileAgent
        case .notSpecified:
            return ""
        }
    }

    func selection(for category: DrugCategory) -> DrugSelection {
        switch category {
        case .induction: return induction
        case .opioid: return opioid
        case .vasopressor: return vasopressor
        case .muscleRelaxant: return muscleRelaxant
        case .reversal: return reversal
        case .fluid:
            // Compatibility shim — the structured fluid setup exposed as a flat
            // selection for callers that only need the agent list.
            return DrugSelection(selected: fluids.allAgents, notes: fluids.notes)
        }
    }

    /// Whether any routine drug category (induction, opioid, vasopressor,
    /// relaxant, reversal) has been filled in — drives the collapsible
    /// "Anaesthetic Drugs" group on the consultant card.
    var hasRoutineDrugs: Bool {
        DrugCategory.drugCases.contains { !selection(for: $0).isEmpty }
    }

    /// Whether any category has been filled in.
    var hasContent: Bool {
        !induction.isEmpty || !opioid.isEmpty || !vasopressor.isEmpty
            || !muscleRelaxant.isEmpty || !reversal.isEmpty || !fluids.isEmpty
            || !emergency.isEmpty || !notes.isBlank || hasMaintenance
    }

    /// All selected and custom agents flattened for checklist building.
    var allSelectedAgents: [String] {
        induction.allAgents + opioid.allAgents + vasopressor.allAgents
            + muscleRelaxant.allAgents + reversal.allAgents + fluids.allAgents
            + emergency.allAgents
    }
}
