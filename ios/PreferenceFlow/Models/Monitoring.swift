//
//  Monitoring.swift
//  PreferenceFlow
//

import Foundation

/// ECG lead configuration. 3-lead is the unremarkable default and never shown
/// as its own checklist line; 5-lead is a genuine addition worth surfacing.
nonisolated enum ECGLeads: String, Codable, CaseIterable, Identifiable {
    case threeLead = "3-lead (standard)"
    case fiveLead = "5-lead"

    var id: String { rawValue }

    /// Compact label for the segmented editor control.
    var shortLabel: String {
        switch self {
        case .threeLead: return "3-lead"
        case .fiveLead: return "5-lead"
        }
    }
}

/// Depth-of-anaesthesia (processed EEG) monitoring preference.
nonisolated enum DepthMonitoring: String, Codable, CaseIterable, Identifiable {
    case none = "Not routinely used"
    case bis = "BIS"
    case entropy = "Entropy"
    case other = "Other processed EEG"

    var id: String { rawValue }
}

/// Train-of-four neuromuscular monitoring preference. The equipment distinction
/// matters to a technician: an integrated sensor (e.g. the GE NMT module) is
/// part of the main monitor, while a standalone stimulator is a separate device
/// to fetch and set up.
nonisolated enum TOFMonitoring: String, Codable, CaseIterable, Identifiable {
    case none = "Not routinely used"
    case integratedSensor = "Integrated sensor (e.g. GE NMT module)"
    case standaloneStimulator = "Standalone TOF stimulator/monitor"

    var id: String { rawValue }

    /// Checklist/card line, e.g. "TOF — Integrated sensor (GE NMT module)".
    var displayItem: String {
        switch self {
        case .none: return ""
        case .integratedSensor: return "TOF — Integrated sensor (GE NMT module)"
        case .standaloneStimulator: return "TOF — Standalone stimulator/monitor"
        }
    }
}

/// Structured monitoring preferences beyond the standard ASA baseline.
/// Standard ASA monitoring (SpO2, NIBP, ECG, EtCO2, temperature) is the
/// baseline for every case and isn't itself a toggle — it's always present.
/// Stored preference reference only — never a clinical instruction.
nonisolated struct MonitoringPreferences: Codable, Hashable {
    var ecgLeads: ECGLeads
    var depthMonitoring: DepthMonitoring
    var tofMonitoring: TOFMonitoring
    /// Curated extras beyond the structured fields (multi-select).
    var additional: [String]
    /// Custom extras added by the user.
    var customAdditional: [String]
    var notes: String

    init(ecgLeads: ECGLeads = .threeLead, depthMonitoring: DepthMonitoring = .none,
         tofMonitoring: TOFMonitoring = .none, additional: [String] = [],
         customAdditional: [String] = [], notes: String = "") {
        self.ecgLeads = ecgLeads
        self.depthMonitoring = depthMonitoring
        self.tofMonitoring = tofMonitoring
        self.additional = additional
        self.customAdditional = customAdditional
        self.notes = notes
    }

    /// Curated additional options. Wording matches `SpecialtySetupOptions`
    /// where the concepts overlap so the same item isn't named two ways.
    static let additionalOptions = [
        "Arterial line (routine)", "CVP (routine)", "Urinary catheter (routine)",
        "Temperature (continuous)", "Cerebral oximetry (NIRS)", "Oesophageal stethoscope"
    ]

    /// Whether anything beyond the standard baseline has been configured —
    /// used to decide whether to show the collapsed "Standard ASA monitoring"
    /// summary or the fuller detail.
    var hasAdditions: Bool {
        ecgLeads != .threeLead || depthMonitoring != .none || tofMonitoring != .none
            || !additional.isEmpty || !customAdditional.isEmpty || !notes.isEmpty
    }

    /// The checklist lines shown on the consultant card and in exports:
    /// always "Standard ASA monitoring" first, then only genuine additions
    /// (3-lead ECG is the default and never listed).
    var displayItems: [String] {
        var items = ["Standard ASA monitoring"]
        if ecgLeads == .fiveLead { items.append("5-lead ECG") }
        if depthMonitoring != .none { items.append(depthMonitoring.rawValue) }
        if tofMonitoring != .none { items.append(tofMonitoring.displayItem) }
        items.append(contentsOf: additional)
        items.append(contentsOf: customAdditional)
        return items
    }

    private enum CodingKeys: String, CodingKey {
        case ecgLeads, depthMonitoring, tofMonitoring, additional, customAdditional, notes
    }

    /// Backward-compatible decoding: every field falls back to its default so
    /// profiles saved before a field existed keep loading unchanged.
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ecgLeads = try c.decodeIfPresent(ECGLeads.self, forKey: .ecgLeads) ?? .threeLead
        depthMonitoring = try c.decodeIfPresent(DepthMonitoring.self, forKey: .depthMonitoring) ?? .none
        tofMonitoring = try c.decodeIfPresent(TOFMonitoring.self, forKey: .tofMonitoring) ?? .none
        additional = try c.decodeIfPresent([String].self, forKey: .additional) ?? []
        customAdditional = try c.decodeIfPresent([String].self, forKey: .customAdditional) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}
