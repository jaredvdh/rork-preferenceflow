//
//  AnaestheticMachine.swift
//  PreferenceFlow
//
//  Which anaesthetic machine model is in use at a hospital location, plus an
//  editable daily machine-check checklist for it. New machines pre-populate a
//  generic starting checklist (grouped by manufacturer for future tailoring) —
//  a convenience reference the hospital/technician edits, never a substitute
//  for the manufacturer's official pre-use check or local policy.
//

import Foundation

/// One anaesthetic machine (or fleet of identical machines) at a hospital,
/// with its location and an editable daily check checklist.
nonisolated struct AnaestheticMachine: Identifiable, Codable, Hashable {
    var id: UUID
    var model: MachineModel
    /// Used when `model == .other`.
    var customModelName: String
    /// e.g. "Theatres 1-4", "Cardiac Theatre".
    var location: String
    var checklistItems: [MachineCheckItem]
    var notes: String

    init(
        id: UUID = UUID(),
        model: MachineModel = .other,
        customModelName: String = "",
        location: String = "",
        checklistItems: [MachineCheckItem] = [],
        notes: String = ""
    ) {
        self.id = id
        self.model = model
        self.customModelName = customModelName
        self.location = location
        self.checklistItems = checklistItems
        self.notes = notes
    }

    var displayName: String {
        model == .other && !customModelName.isEmpty ? customModelName : model.displayName
    }

    /// Generic starting checklist texts. Kept as plain strings so callers that
    /// need deterministic item ids (e.g. demo data) can build their own items.
    static let genericChecklistTexts: [String] = [
        "Confirm mains power and back-up battery status",
        "Check gas supply pressures (O2, Air, N2O if fitted) and pipeline/cylinder reserve",
        "Perform machine self-test / auto machine check per manufacturer sequence",
        "Check breathing circuit for leaks and correct assembly",
        "Confirm vaporiser(s) filled, correctly seated, and leak-checked",
        "Check APL valve and manual ventilation (bag) function",
        "Confirm ventilator settings and perform test ventilation",
        "Check scavenging system connected and functioning",
        "Confirm suction unit functional with adequate vacuum",
        "Check monitors calibrated/zeroed (gas analyser, SpO2, NIBP, ECG)",
        "Confirm CO2 absorbent adequate and not exhausted",
        "Check emergency O2 flush function",
        "Confirm self-inflating bag and alternative ventilation available as backup"
    ]

    /// A sensible generic default checklist for a newly added machine. The
    /// `model` parameter is accepted so manufacturer-specific starting points
    /// can be added later without changing call sites.
    static func defaultChecklist(for model: MachineModel) -> [MachineCheckItem] {
        genericChecklistTexts.map { MachineCheckItem(text: $0, isDefault: true) }
    }

    /// The caption that must accompany any machine checklist display.
    static let checklistCaption =
        "Generic reference checklist — always follow your machine's official pre-use check and local hospital policy."
}

/// Curated anaesthetic machine models found in most theatre suites.
nonisolated enum MachineModel: String, Codable, CaseIterable, Identifiable {
    case geAisys = "GE Aisys"
    case geAisysCS2 = "GE Aisys CS2"
    case geAvance = "GE Avance"
    case draegerZeus = "Dräger Zeus"
    case draegerZeusIE = "Dräger Zeus IE"
    case draegerPerseus = "Dräger Perseus A500"
    case draegerFabius = "Dräger Fabius"
    case mindrayA7 = "Mindray A7"
    case mindrayA5 = "Mindray A5"
    case other = "Other / not listed"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Manufacturer, used to group machines and pick a sensible default checklist.
    var manufacturer: String {
        switch self {
        case .geAisys, .geAisysCS2, .geAvance: return "GE"
        case .draegerZeus, .draegerZeusIE, .draegerPerseus, .draegerFabius: return "Dräger"
        case .mindrayA7, .mindrayA5: return "Mindray"
        case .other: return "Other"
        }
    }
}

/// One line of a machine-check checklist. `isDefault` distinguishes the
/// pre-populated generic items from hospital-added ones.
nonisolated struct MachineCheckItem: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var isDefault: Bool

    init(id: UUID = UUID(), text: String, isDefault: Bool = false) {
        self.id = id
        self.text = text
        self.isDefault = isDefault
    }
}
