//
//  SpecialtySetup.swift
//  PreferenceFlow
//

import Foundation

/// How a consultant's setup changes for a specialist list (Cardiac, Paediatric,
/// Neuro, Trauma, Obstetrics, Orthopaedics, …) compared with their standard
/// theatre setup. Stored only when a consultant actually has specialty-specific
/// modifications, so the dashboard shows specialty cards only when they exist.
nonisolated struct SpecialtySetup: Identifiable, Codable, Hashable {
    var id: UUID
    /// The specialty this setup describes.
    var specialty: Subspecialty
    /// Extra monitoring beyond standard ASA (e.g. Arterial line, Triple transducer, TEE).
    var additionalMonitoring: [String]
    /// Vascular access / lines that differ (e.g. Quad lumen CVC, PICC, Rapid infuser).
    var linesAndAccess: [String]
    /// Equipment that differs (e.g. Belmont, Cell saver, Warming).
    var equipment: [String]
    /// How drug preferences change for this specialty (free text).
    var drugChanges: String
    /// Any special notes for this specialty.
    var specialNotes: String
    /// Optional photo of the finished specialty setup / equipment layout
    /// (resized JPEG).
    var setupPhoto: Data?

    init(
        id: UUID = UUID(),
        specialty: Subspecialty = .cardiac,
        additionalMonitoring: [String] = [],
        linesAndAccess: [String] = [],
        equipment: [String] = [],
        drugChanges: String = "",
        specialNotes: String = "",
        setupPhoto: Data? = nil
    ) {
        self.id = id
        self.specialty = specialty
        self.additionalMonitoring = additionalMonitoring
        self.linesAndAccess = linesAndAccess
        self.equipment = equipment
        self.drugChanges = drugChanges
        self.specialNotes = specialNotes
        self.setupPhoto = setupPhoto
    }

    /// Whether the setup carries any meaningful content.
    var hasContent: Bool {
        !additionalMonitoring.isEmpty || !linesAndAccess.isEmpty || !equipment.isEmpty
            || !drugChanges.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !specialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || setupPhoto != nil
    }

    /// Number of distinct differences captured, for the dashboard card summary.
    var changeCount: Int {
        var count = additionalMonitoring.count + linesAndAccess.count + equipment.count
        if !drugChanges.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if !specialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if setupPhoto != nil { count += 1 }
        return count
    }
}

/// Curated option lists for building a specialty setup quickly via chips.
nonisolated enum SpecialtySetupOptions {
    static let monitoring = [
        "Arterial line", "Triple transducer", "CVP", "Cardiac output",
        "TEE", "BIS / Entropy (depth of anaesthesia)", "Processed EEG",
        "Cerebral oximetry (NIRS)", "Pulmonary artery catheter (PAC)",
        "Oesophageal Doppler", "FloTrac / Vigileo", "LiDCO / PiCCO (cardiac output)",
        "Temperature", "Urinary catheter"
    ]
    static let lines = [
        "Large-bore IV", "Quad lumen CVC", "Introducer sheath",
        "Cordis / Introducer sheath", "PICC", "Rapid infuser",
        "Belmont / Level 1", "Arterial line", "PA catheter",
        "Intraosseous (IO)", "CRRT / dialysis catheter",
        "Epidural (for post-op analgesia)"
    ]
    static let equipment = [
        "Cell saver", "Cell saver suction setup", "Belmont", "Forced-air warmer",
        "Fluid warmer", "Defibrillator pads", "Pacing", "Ultrasound",
        "Difficult airway trolley", "IABP (intra-aortic balloon pump)", "Impella",
        "ECMO circuit", "Bronchial blocker", "Double-lumen ETT setup",
        "Jet ventilator", "Fibreoptic bronchoscope"
    ]
}
