//
//  Medication.swift
//  PreferenceFlow
//

import Foundation

/// Who prepares a given item.
nonisolated enum PreparedBy: String, Codable, CaseIterable, Identifiable, Hashable {
    case doctor = "Doctor prepares"
    case assistant = "Assistant prepares"
    case caseDependent = "Case dependent"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .doctor: return "Doctor"
        case .assistant: return "Assistant"
        case .caseDependent: return "Case dependent"
        }
    }
}

/// Medication category groupings used in adult & paediatric sections.
nonisolated enum MedicationCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case anaestheticAgent = "Anaesthetic Agent"
    case analgesic = "Analgesic"
    case vasopressor = "Vasopressor"
    case antibiotic = "Antibiotics"
    case muscleRelaxant = "Muscle Relaxants"
    case antiemetic = "Antiemetics"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .anaestheticAgent: return "zzz"
        case .analgesic: return "bandage"
        case .vasopressor: return "arrow.up.heart"
        case .antibiotic: return "cross.vial"
        case .muscleRelaxant: return "figure.flexibility"
        case .antiemetic: return "stomach"
        case .other: return "pills"
        }
    }

    /// Example agents to suggest in the editor. Reference text only.
    var examples: [String] {
        switch self {
        case .anaestheticAgent: return ["Propofol", "Thiopentone", "Ketamine", "Etomidate"]
        case .analgesic: return ["Fentanyl", "Alfentanil", "Remifentanil"]
        case .vasopressor: return ["Metaraminol", "Phenylephrine", "Ephedrine"]
        case .antibiotic: return ["Cefazolin", "Gentamicin"]
        case .muscleRelaxant: return ["Rocuronium", "Suxamethonium", "Atracurium"]
        case .antiemetic: return ["Ondansetron", "Dexamethasone", "Droperidol"]
        case .other: return []
        }
    }
}

/// A single user-entered medication preparation preference. No dosing logic — all
/// fields are free text entered by the user.
nonisolated struct Medication: Identifiable, Codable, Hashable {
    var id: UUID
    var category: MedicationCategory
    var name: String
    var preparation: String
    var concentration: String
    var drawUpNotes: String
    var labellingNotes: String
    var preparedBy: PreparedBy
    var specialNotes: String

    init(
        id: UUID = UUID(),
        category: MedicationCategory = .anaestheticAgent,
        name: String = "",
        preparation: String = "",
        concentration: String = "",
        drawUpNotes: String = "",
        labellingNotes: String = "",
        preparedBy: PreparedBy = .caseDependent,
        specialNotes: String = ""
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.preparation = preparation
        self.concentration = concentration
        self.drawUpNotes = drawUpNotes
        self.labellingNotes = labellingNotes
        self.preparedBy = preparedBy
        self.specialNotes = specialNotes
    }
}

/// IV fluid setup preferences, shared by adult & paediatric sections.
nonisolated struct IVFluidPreferences: Codable, Hashable {
    var preferredCrystalloid: String = ""
    var balancedCrystalloid: String = ""
    var salinePreference: String = ""
    var pressureBagUse: String = ""
    var fluidWarmer: String = ""
    var bloodSetup: String = ""
    var specialNotes: String = ""
}

/// A medication-driven anaesthesia setup section (adult or paediatric). Both share
/// the exact same shape but are stored independently per the spec.
nonisolated struct MedicationSetup: Codable, Hashable {
    var medications: [Medication] = []
    var fluids: IVFluidPreferences = IVFluidPreferences()
    var notes: String = ""
}
