//
//  ProcedureTemplate.swift
//  PreferenceFlow
//

import Foundation

/// Monitoring options shown as checkboxes in a procedure template.
nonisolated enum MonitoringOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case ecg = "ECG"
    case bis = "BIS"
    case arterialLine = "Arterial Line"
    case cvp = "CVP"
    case paCatheter = "PA Catheter"
    case tee = "TEE"
    case nirs = "NIRS"
    var id: String { rawValue }
}

/// One row in a preparation timeline (e.g. "0710 — Arterial line").
nonisolated struct TimelineEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var time: String
    var event: String

    init(id: UUID = UUID(), time: String = "", event: String = "") {
        self.id = id
        self.time = time
        self.event = event
    }
}

/// A custom checklist item with a completed flag (acts as a reusable template).
nonisolated struct ChecklistItem: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var isChecked: Bool

    init(id: UUID = UUID(), text: String = "", isChecked: Bool = false) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
    }
}

/// The flagship feature: a detailed setup guide for a specific procedure.
nonisolated struct ProcedureTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var typicalStartTime: String
    var typicalLocation: String

    var timeline: [TimelineEntry]
    var monitoring: Set<MonitoringOption>

    // IV access
    var ivCount: String
    var ivSize: String
    var ivLocation: String

    var airwayNotes: String
    var lineSetup: String
    var infusions: String
    var equipmentChecklist: [ChecklistItem]
    var specialNotes: String

    init(
        id: UUID = UUID(),
        name: String = "",
        typicalStartTime: String = "",
        typicalLocation: String = "",
        timeline: [TimelineEntry] = [],
        monitoring: Set<MonitoringOption> = [],
        ivCount: String = "",
        ivSize: String = "",
        ivLocation: String = "",
        airwayNotes: String = "",
        lineSetup: String = "",
        infusions: String = "",
        equipmentChecklist: [ChecklistItem] = [],
        specialNotes: String = ""
    ) {
        self.id = id
        self.name = name
        self.typicalStartTime = typicalStartTime
        self.typicalLocation = typicalLocation
        self.timeline = timeline
        self.monitoring = monitoring
        self.ivCount = ivCount
        self.ivSize = ivSize
        self.ivLocation = ivLocation
        self.airwayNotes = airwayNotes
        self.lineSetup = lineSetup
        self.infusions = infusions
        self.equipmentChecklist = equipmentChecklist
        self.specialNotes = specialNotes
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Operation" : name
    }

    /// Whether this operation card carries any meaningful content beyond a name.
    var hasContent: Bool {
        !timeline.isEmpty || !monitoring.isEmpty
            || !ivCount.trimmingCharacters(in: .whitespaces).isEmpty
            || !ivSize.trimmingCharacters(in: .whitespaces).isEmpty
            || !ivLocation.trimmingCharacters(in: .whitespaces).isEmpty
            || !airwayNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !lineSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !infusions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !equipmentChecklist.isEmpty
            || !specialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A short summary line for list rows and tab chips: monitoring plus counts.
    var summaryLine: String {
        var parts: [String] = []
        if !monitoring.isEmpty {
            parts.append(monitoring.map { $0.rawValue }.sorted().prefix(3).joined(separator: " · "))
        }
        let ivSummary = [ivCount, ivSize].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " ")
        if !ivSummary.isEmpty { parts.append("IV: \(ivSummary)") }
        if !equipmentChecklist.isEmpty {
            parts.append("\(equipmentChecklist.count) equipment item\(equipmentChecklist.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// Common procedure names for quick-create suggestions.
    static let suggestions = [
        "CABG", "Valve Surgery", "TAVI", "Paediatric Cardiac",
        "Trauma Laparotomy", "Whipple", "Craniotomy", "Spine Surgery",
        "Paediatric Dental", "MRI Anaesthesia", "C-section", "Liver Resection"
    ]
}
