//
//  AirwayPreferences.swift
//  PreferenceFlow
//

import Foundation

nonisolated enum LaryngoscopyTechnique: String, Codable, CaseIterable, Identifiable, Hashable {
    case direct = "Direct"
    case video = "Video"
    var id: String { rawValue }
}

nonisolated enum VideoLaryngoscopeSystem: String, Codable, CaseIterable, Identifiable, Hashable {
    case mcGrath = "McGrath"
    case glideScope = "GlideScope"
    case cMac = "C-MAC"
    case hyperangulated = "Hyperangulated"
    case other = "Other"
    case none = "Not specified"
    var id: String { rawValue }
}

nonisolated enum LaryngoscopeBlade: String, Codable, CaseIterable, Identifiable, Hashable {
    case macintosh = "Macintosh"
    case miller = "Miller"
    case other = "Other"
    case none = "Not specified"
    var id: String { rawValue }
}

/// A single airway setup (adult male, adult female or paediatric). Independent
/// per the spec but share the same structure.
nonisolated struct AirwaySetup: Codable, Hashable {
    // Endotracheal tube
    var tubeSize: String = ""
    var cuffedPreference: String = ""
    var styletPreference: String = ""
    var bougiePreference: String = ""
    var tubeSecuring: String = ""

    // Laryngoscopy
    var primaryTechnique: LaryngoscopyTechnique = .direct
    var videoSystem: VideoLaryngoscopeSystem = .none
    var blade: LaryngoscopeBlade = .macintosh
    var bladeSize: String = ""

    var notes: String = ""
}

nonisolated enum SupraglotticDevice: String, Codable, CaseIterable, Identifiable, Hashable {
    case lmaClassic = "LMA Classic"
    case lmaProSeal = "LMA ProSeal"
    case igel = "i-gel"
    case lmaSupreme = "LMA Supreme"
    case auraGain = "AuraGain"
    case other = "Other"
    case none = "Not specified"
    var id: String { rawValue }
}

/// Age-based paediatric endotracheal tube sizing reference.
/// Cuffed = age ÷ 4 + 3.5, Uncuffed = age ÷ 4 + 4 (internal diameter, mm),
/// rounded to the nearest half size. Educational reference only — always confirm
/// against the patient and local policy.
nonisolated enum PaediatricETT {
    /// Internal diameter (mm) rounded to the nearest 0.5 for a given age in years.
    static func size(ageYears: Double, cuffed: Bool) -> Double {
        let raw = ageYears / 4.0 + (cuffed ? 3.5 : 4.0)
        return (raw * 2).rounded() / 2
    }

    /// One-decimal string for display (e.g. "4.5").
    static func formatted(ageYears: Double, cuffed: Bool) -> String {
        String(format: "%.1f", size(ageYears: ageYears, cuffed: cuffed))
    }
}

/// A single row in the age/weight-based laryngoscope blade size reference.
nonisolated struct PaediatricBladeRow: Identifiable, Hashable {
    var id: String { ageGroup }
    let ageGroup: String
    let miller: String
    let macintosh: String
}

/// Age/weight-based laryngoscope blade size reference for paediatric airways.
/// Educational reference only — confirm against the patient and local policy.
nonisolated enum PaediatricBlade {
    static let rows: [PaediatricBladeRow] = [
        PaediatricBladeRow(ageGroup: "Premature / Neonate", miller: "00 or 0", macintosh: "–"),
        PaediatricBladeRow(ageGroup: "Infant (0–1 year)", miller: "0 or 1", macintosh: "1"),
        PaediatricBladeRow(ageGroup: "Toddler (1–3 years)", miller: "1 or 1.5", macintosh: "1.5 or 2"),
        PaediatricBladeRow(ageGroup: "Child (3–10 years)", miller: "1.5 or 2", macintosh: "2"),
        PaediatricBladeRow(ageGroup: "Adolescent (10+ years)", miller: "2 or 3", macintosh: "2 or 3"),
    ]
}

/// A single paediatric patient profile used as the shared source of truth for
/// every paediatric airway calculation. Age is the primary input; estimated
/// weight is derived from the standard formula `(age × 2) + 10`. An optional
/// actual weight overrides the estimate for weight-based sizing.
nonisolated struct PaediatricPatient: Hashable {
    var ageYears: Double = 4
    var useActualWeight: Bool = false
    var actualWeightKg: Double = 16

    /// Standard age-formula estimate: (age × 2) + 10, in kg.
    var estimatedWeightKg: Double { ageYears * 2 + 10 }

    /// The weight all weight-based calculations should use.
    var effectiveWeightKg: Double { useActualWeight ? actualWeightKg : estimatedWeightKg }

    var ageLabel: String {
        ageYears < 1 ? "<1 yr" : "\(Int(ageYears)) yr\(ageYears >= 2 ? "s" : "")"
    }

    var estimatedWeightLabel: String { "\(Int(estimatedWeightKg.rounded())) kg" }
    var effectiveWeightLabel: String { "\(Int(effectiveWeightKg.rounded())) kg" }

    var usingLabel: String {
        useActualWeight ? "Using Actual Weight" : "Using Estimated Weight (Age Formula)"
    }
}

/// A single weight band in the paediatric supraglottic device sizing reference.
nonisolated struct PaediatricSupraglotticRow: Identifiable, Hashable {
    var id: String { weightBand }
    let weightBand: String
    let igel: String
    let lma: String
}

/// Weight-based paediatric supraglottic airway sizing reference (i-gel and LMA).
/// Educational reference only — confirm against the patient, device packaging and
/// local policy.
nonisolated enum PaediatricSupraglottic {
    static let rows: [PaediatricSupraglotticRow] = [
        PaediatricSupraglotticRow(weightBand: "2–5 kg (neonate)", igel: "1", lma: "1"),
        PaediatricSupraglotticRow(weightBand: "5–12 kg (infant)", igel: "1.5", lma: "1.5"),
        PaediatricSupraglotticRow(weightBand: "10–25 kg (small child)", igel: "2", lma: "2"),
        PaediatricSupraglotticRow(weightBand: "25–35 kg (large child)", igel: "2.5", lma: "2.5"),
        PaediatricSupraglotticRow(weightBand: "30–60 kg (adolescent)", igel: "3", lma: "3"),
    ]

    /// Recommended i-gel size for a given weight in kg.
    static func igelSize(weightKg: Double) -> String {
        switch weightKg {
        case ..<5: return "1"
        case 5..<12: return "1.5"
        case 12..<25: return "2"
        case 25..<35: return "2.5"
        case 35..<60: return "3"
        case 60..<90: return "4"
        default: return "5"
        }
    }

    /// Recommended LMA (Classic) size for a given weight in kg.
    static func lmaSize(weightKg: Double) -> String {
        switch weightKg {
        case ..<5: return "1"
        case 5..<10: return "1.5"
        case 10..<20: return "2"
        case 20..<30: return "2.5"
        case 30..<50: return "3"
        case 50..<70: return "4"
        default: return "5"
        }
    }

    /// Manufacturer weight range for the recommended i-gel size at a given weight.
    static func igelRange(weightKg: Double) -> String {
        switch weightKg {
        case ..<5: return "2–5 kg"
        case 5..<12: return "5–12 kg"
        case 12..<25: return "10–25 kg"
        case 25..<35: return "25–35 kg"
        case 35..<60: return "30–60 kg"
        case 60..<90: return "50–90 kg"
        default: return "90+ kg"
        }
    }

    /// Manufacturer weight range for the recommended LMA (Classic) size at a given weight.
    static func lmaRange(weightKg: Double) -> String {
        switch weightKg {
        case ..<5: return "<5 kg"
        case 5..<10: return "5–10 kg"
        case 10..<20: return "10–20 kg"
        case 20..<30: return "20–30 kg"
        case 30..<50: return "30–50 kg"
        case 50..<70: return "50–70 kg"
        default: return "70–100 kg"
        }
    }
}

/// A single supraglottic airway default (device + size) for one adult cohort.
nonisolated struct SupraglotticChoice: Codable, Hashable {
    var device: SupraglotticDevice = .none
    var size: String = ""

    var isEmpty: Bool { device == .none && size.isBlank }

    /// e.g. "i-gel Size 4" or "i-gel" or "".
    var summary: String {
        guard device != .none else { return size.isBlank ? "" : "Size \(size)" }
        return size.isBlank ? device.rawValue : "\(device.rawValue) Size \(size)"
    }
}

/// Consultant supraglottic airway preferences. Defaults are kept separately for
/// adult female, adult male and an optional large adult / high-IBW cohort so a
/// consultant can mix devices and sizes (e.g. i-gel 4 female, LMA Supreme 5 male).
/// Paediatric sizing is intentionally not stored here — it is handled by the
/// weight-based clinical decision-support reference on the airway summary.
nonisolated struct SupraglotticPreferences: Codable, Hashable {
    var adultFemale: SupraglotticChoice = SupraglotticChoice()
    var adultMale: SupraglotticChoice = SupraglotticChoice()
    var largeAdult: SupraglotticChoice = SupraglotticChoice()
    var notes: String = ""

    init(
        adultFemale: SupraglotticChoice = SupraglotticChoice(),
        adultMale: SupraglotticChoice = SupraglotticChoice(),
        largeAdult: SupraglotticChoice = SupraglotticChoice(),
        notes: String = ""
    ) {
        self.adultFemale = adultFemale
        self.adultMale = adultMale
        self.largeAdult = largeAdult
        self.notes = notes
    }

    /// Concise summary chips for the adult female / adult male supraglottic
    /// defaults, used by the consultant overview, standard-setup card, department
    /// preview and PDF summary. Large adult is intentionally excluded here — it is
    /// surfaced only inside the expanded airway card.
    ///
    /// - Both cohorts share a device: `["i-gel F4 / M5"]`
    /// - Cohorts use different devices: `["F: i-gel 4", "M: LMA Supreme 5"]`
    /// - Only one cohort configured: a single chip, e.g. `["i-gel 4"]`
    var summaryChips: [String] {
        let f = adultFemale
        let m = adultMale
        switch (!f.isEmpty, !m.isEmpty) {
        case (true, true):
            if f.device == m.device, f.device != .none {
                let fSize = f.size.isBlank ? "" : "F\(f.size)"
                let mSize = m.size.isBlank ? "" : "M\(m.size)"
                let sizes = [fSize, mSize].filter { !$0.isEmpty }.joined(separator: " / ")
                return sizes.isEmpty ? [f.device.rawValue] : ["\(f.device.rawValue) \(sizes)"]
            }
            return ["F: \(f.summary)", "M: \(m.summary)"]
        case (true, false):
            return [f.summary]
        case (false, true):
            return [m.summary]
        case (false, false):
            return []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case adultFemale, adultMale, largeAdult, notes
        // Legacy keys (single shared device + per-cohort size strings).
        case device, adultMaleSize, adultFemaleSize
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notes = (try? c.decode(String.self, forKey: .notes)) ?? ""

        if let female = try? c.decode(SupraglotticChoice.self, forKey: .adultFemale) {
            adultFemale = female
            adultMale = (try? c.decode(SupraglotticChoice.self, forKey: .adultMale)) ?? SupraglotticChoice()
            largeAdult = (try? c.decode(SupraglotticChoice.self, forKey: .largeAdult)) ?? SupraglotticChoice()
        } else {
            // Migrate the older single-device shape onto the new per-cohort one.
            let device = (try? c.decode(SupraglotticDevice.self, forKey: .device)) ?? .none
            let maleSize = (try? c.decode(String.self, forKey: .adultMaleSize)) ?? ""
            let femaleSize = (try? c.decode(String.self, forKey: .adultFemaleSize)) ?? ""
            adultFemale = SupraglotticChoice(device: device, size: femaleSize)
            adultMale = SupraglotticChoice(device: device, size: maleSize)
            largeAdult = SupraglotticChoice()
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(adultFemale, forKey: .adultFemale)
        try c.encode(adultMale, forKey: .adultMale)
        try c.encode(largeAdult, forKey: .largeAdult)
        try c.encode(notes, forKey: .notes)
    }
}

nonisolated struct DifficultAirwayNotes: Codable, Hashable {
    var backupPlan: String = ""
    var fibreopticPreference: String = ""
    var surgicalAirwayNotes: String = ""
    var specialEquipment: String = ""
}

/// Full airway management preferences for a provider.
nonisolated struct AirwayPreferences: Codable, Hashable {
    var adultMale: AirwaySetup = AirwaySetup()
    var adultFemale: AirwaySetup = AirwaySetup()
    var paediatric: AirwaySetup = AirwaySetup()
    var supraglottic: SupraglotticPreferences = SupraglotticPreferences()
    var difficultAirway: DifficultAirwayNotes = DifficultAirwayNotes()
}
