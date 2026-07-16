//
//  SurgeonProcedure.swift
//  PreferenceFlow
//

import Foundation

/// One operation's specific preference card for a surgeon — e.g. "Lap
/// Cholecystectomy" or "Right Hemicolectomy". Reuses the same section
/// structures as the surgeon's general preferences (trays, sutures, energy,
/// positioning) so the editors, read cards and printouts stay consistent.
/// Each procedure prints as its own one-page card.
nonisolated struct SurgeonProcedure: Identifiable, Codable, Hashable {
    var id: UUID
    /// The operation name, e.g. "Laparoscopic Appendicectomy".
    var name: String
    var trays: TraysInstruments
    var sutures: SuturesClosure
    var energy: EnergyEquipment
    var positioning: PositioningPrep
    /// Anything else specific to this operation (timing, order of events,
    /// what the surgeon wants ready before knife to skin).
    var notes: String

    init(
        id: UUID = UUID(),
        name: String = "",
        trays: TraysInstruments = TraysInstruments(),
        sutures: SuturesClosure = SuturesClosure(),
        energy: EnergyEquipment = EnergyEquipment(),
        positioning: PositioningPrep = PositioningPrep(),
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.trays = trays
        self.sutures = sutures
        self.energy = energy
        self.positioning = positioning
        self.notes = notes
    }

    /// Decodes with per-section fallbacks so future additions never break
    /// older exports.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        trays = try container.decodeIfPresent(TraysInstruments.self, forKey: .trays) ?? TraysInstruments()
        sutures = try container.decodeIfPresent(SuturesClosure.self, forKey: .sutures) ?? SuturesClosure()
        energy = try container.decodeIfPresent(EnergyEquipment.self, forKey: .energy) ?? EnergyEquipment()
        positioning = try container.decodeIfPresent(PositioningPrep.self, forKey: .positioning) ?? PositioningPrep()
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    var hasContent: Bool {
        trays.hasContent || sutures.hasContent || energy.hasContent
            || positioning.hasContent
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Procedure" : name
    }

    /// A short summary line for list rows: position plus counts of what's set.
    var summaryLine: String {
        var parts: [String] = []
        if !positioning.patientPosition.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(positioning.patientPosition)
        }
        if !trays.traysToOpen.isEmpty {
            parts.append("\(trays.traysToOpen.count) tray\(trays.traysToOpen.count == 1 ? "" : "s")")
        }
        if !energy.energyDevices.isEmpty {
            parts.append("\(energy.energyDevices.count) energy device\(energy.energyDevices.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// Common operation names for quick-create suggestions across specialties.
    static let suggestions = [
        "Lap Cholecystectomy", "Lap Appendicectomy", "Inguinal Hernia Repair",
        "Right Hemicolectomy", "Trauma Laparotomy", "Liver Resection",
        "Total Knee Replacement", "Total Hip Replacement", "Arthroscopy",
        "CABG", "Aortic Valve Replacement", "VATS Lobectomy",
        "PCI / Angiogram", "Pacemaker Insertion",
        "Colonoscopy", "Gastroscopy", "ERCP",
        "TURP", "Caesarean Section", "Hysterectomy",
        "Carotid Endarterectomy", "Craniotomy", "Cataract Surgery"
    ]
}
