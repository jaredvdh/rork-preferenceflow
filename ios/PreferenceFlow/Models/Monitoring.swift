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

/// NIBP cuff placement preference relative to IV access — a genuinely common
/// consultant preference worth capturing (e.g. "cuff opposite arm from IV").
nonisolated enum BPCuffPlacement: String, Codable, CaseIterable, Identifiable {
    case noPreference = "No preference"
    case oppositeArmFromIV = "Opposite arm from IV, where possible"
    case sameArmAsIV = "Same arm as IV"

    var id: String { rawValue }
}

/// Structured monitoring preferences beyond the standard ASA baseline.
/// Standard ASA monitoring (SpO2, NIBP, ECG, EtCO2, temperature) is the
/// baseline for every case and isn't itself a toggle — it's always present.
/// Stored preference reference only — never a clinical instruction.
nonisolated struct MonitoringPreferences: Codable, Hashable {
    var ecgLeads: ECGLeads
    var depthMonitoring: DepthMonitoring
    var tofMonitoring: TOFMonitoring
    var bpCuffPlacement: BPCuffPlacement
    /// Curated extras beyond the structured fields (multi-select).
    var additional: [String]
    /// Custom extras added by the user.
    var customAdditional: [String]
    var notes: String

    init(ecgLeads: ECGLeads = .threeLead, depthMonitoring: DepthMonitoring = .none,
         tofMonitoring: TOFMonitoring = .none, bpCuffPlacement: BPCuffPlacement = .noPreference,
         additional: [String] = [], customAdditional: [String] = [], notes: String = "") {
        self.ecgLeads = ecgLeads
        self.depthMonitoring = depthMonitoring
        self.tofMonitoring = tofMonitoring
        self.bpCuffPlacement = bpCuffPlacement
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
            || bpCuffPlacement != .noPreference
            || !additional.isEmpty || !customAdditional.isEmpty || !notes.isEmpty
    }

    /// The checklist lines shown on the consultant card and in exports. The
    /// baseline line spells out the actual components of standard ASA
    /// monitoring (so it reads as real information, not a placeholder) and
    /// folds the ECG lead count into itself — a 5-lead preference updates the
    /// baseline rather than adding a redundant second line. Only genuine
    /// additions follow.
    var displayItems: [String] {
        let leads = ecgLeads == .fiveLead ? "5-lead ECG" : "3-lead ECG"
        var items = ["SpO\u{2082}, \(leads), NIBP, EtCO\u{2082}, temperature (standard ASA monitoring)"]
        if depthMonitoring != .none { items.append(depthMonitoring.rawValue) }
        if tofMonitoring != .none { items.append(tofMonitoring.displayItem) }
        if bpCuffPlacement != .noPreference { items.append("BP cuff: \(bpCuffPlacement.rawValue)") }
        items.append(contentsOf: additional)
        items.append(contentsOf: customAdditional)
        return items
    }

    private enum CodingKeys: String, CodingKey {
        case ecgLeads, depthMonitoring, tofMonitoring, bpCuffPlacement, additional, customAdditional, notes
    }

    /// Backward-compatible decoding: every field falls back to its default so
    /// profiles saved before a field existed keep loading unchanged.
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ecgLeads = try c.decodeIfPresent(ECGLeads.self, forKey: .ecgLeads) ?? .threeLead
        depthMonitoring = try c.decodeIfPresent(DepthMonitoring.self, forKey: .depthMonitoring) ?? .none
        tofMonitoring = try c.decodeIfPresent(TOFMonitoring.self, forKey: .tofMonitoring) ?? .none
        bpCuffPlacement = try c.decodeIfPresent(BPCuffPlacement.self, forKey: .bpCuffPlacement) ?? .noPreference
        additional = try c.decodeIfPresent([String].self, forKey: .additional) ?? []
        customAdditional = try c.decodeIfPresent([String].self, forKey: .customAdditional) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}
