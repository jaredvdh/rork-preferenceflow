//
//  CrisisManual.swift
//  PreferenceFlow
//

import Foundation

/// Structured anaesthetic crisis manual decoded from a bundled JSON file. The
/// schema matches `crisis_manual_*.json` exactly. Educational reference only —
/// clinical content is rendered verbatim and never paraphrased.
nonisolated struct CrisisManual: Codable, Hashable {
    let meta: CrisisMeta
    let legend: CrisisLegend
    let sections: [String: CrisisSection]
    let cards: [CrisisCard]
    let adultDrugFormulary: [CrisisDrug]
    let pediatricDrugFormulary: [CrisisDrug]

    /// Section keys in the canonical display order used across the app.
    static let sectionOrder = ["airway", "breathing", "circulation", "everything", "obstetrics", "diagnosing"]

    /// Cards belonging to a given section key, preserving JSON order.
    func cards(in sectionKey: String) -> [CrisisCard] {
        cards.filter { $0.section == sectionKey }
    }

    /// Looks up a card by its id (e.g. "16e").
    func card(id: String) -> CrisisCard? {
        cards.first { $0.id == id }
    }
}

/// Manual-level metadata (region, units, attribution, disclaimer).
nonisolated struct CrisisMeta: Codable, Hashable {
    let region: String
    let regionCode: String
    let units: String
    let terminology: String
    let title: String
    let version: String
    let sourceAcknowledgement: String
    let disclaimer: String
}

/// Colour legend describing the meaning of the red / yellow / green boxes.
nonisolated struct CrisisLegend: Codable, Hashable {
    let red: String
    let yellow: String
    let green: String
}

/// A section grouping (Airway, Breathing, …) with its display label and short tag.
nonisolated struct CrisisSection: Codable, Hashable {
    let label: String
    let book: String
    let tag: String
}

/// A single crisis card. Optional fields are absent on most cards.
nonisolated struct CrisisCard: Codable, Hashable, Identifiable {
    let id: String
    let section: String
    let title: String
    let priority: String
    let doing: [String]
    let thinking: [String]
    let drugs: [CrisisDrug]
    let crossRefs: [String]
    let sectionLabel: String
    let sectionTag: String
    let book: String
    /// Optional accent colour key for the card ("red" on the highest-priority cards).
    let color: String?
    /// Optional comparison/grading table (e.g. anaphylaxis grades).
    let grading: CrisisTable?
    /// Optional paediatric calculations table.
    let pedsTable: CrisisTable?
    /// Optional blood compatibility reference (massive haemorrhage card).
    let bloodCompat: CrisisBloodCompat?
}

/// One drug/equipment row. Any of the dose columns may be absent.
nonisolated struct CrisisDrug: Codable, Hashable, Identifiable {
    let drug: String
    let bolus: String?
    let infusion: String?
    let peds: String?
    let notes: String?

    /// Stable identity for ForEach (drug name + columns are unique within a card).
    var id: String { [drug, bolus ?? "", infusion ?? "", peds ?? "", notes ?? ""].joined(separator: "|") }

    /// Whether this row carries any paediatric dosing.
    var hasPeds: Bool { !(peds ?? "").isEmpty }
    /// Whether this row carries an infusion column.
    var hasInfusion: Bool { !(infusion ?? "").isEmpty }
    /// Whether this row carries a bolus column.
    var hasBolus: Bool { !(bolus ?? "").isEmpty }
    /// Whether this row carries a free-text notes column.
    var hasNotes: Bool { !(notes ?? "").isEmpty }
}

/// A generic column/row table (grading or paediatric calculations).
nonisolated struct CrisisTable: Codable, Hashable {
    let columns: [String]
    let rows: [[String]]
}

/// Blood compatibility reference tables for the massive haemorrhage card.
nonisolated struct CrisisBloodCompat: Codable, Hashable {
    /// Red cell compatibility rows: [patientGroup, compatibleGroups].
    let rbc: [[String]]
    /// Fresh frozen plasma compatibility rows.
    let ffp: [[String]]
    let note: String
}
