//
//  GeneralPreferences.swift
//  PreferenceFlow
//

import Foundation

/// General working preferences for a provider — theatre setup, personal touches
/// and workflow expectations. All free text / simple toggles entered by the user.
nonisolated struct GeneralPreferences: Codable, Hashable {
    // Theatre setup — gloves are captured as two distinct items because sterile
    // (procedure) gloves and non-sterile (general task) gloves are different
    // products fetched from different places in theatre.
    /// Sterile gloves — worn for procedures (intubation, regional, lines). Numeric size.
    var sterileGloveSize: String = ""
    /// Sterile glove material/type, e.g. Biogel, Gammex, Latex-free. Free text allowed.
    var sterileGloveType: String = ""
    /// Non-sterile gloves — general tasks. Sized XS/S/M/L/XL.
    var nonSterileGloveSize: String = ""
    var gownSize: String = ""
    var maskPreference: String = ""
    var theatreShoeSize: String = ""
    var roomTemperature: String = ""

    // Personal preferences
    var coffeePreference: String = ""
    var teaPreference: String = ""
    var favouriteSnacks: String = ""
    var contactPreferences: String = ""

    // Workflow preferences
    var arriveBeforePatient: Bool = false
    var prepareOwnMedications: Bool = false
    var assistantMayPrepareMedications: Bool = false
    var briefingStyle: String = ""

    var generalNotes: String = ""

    init() {}

    // MARK: - Option libraries

    static let sterileGloveSizes = ["6.0", "6.5", "7.0", "7.5", "8.0", "8.5", "9.0"]
    static let sterileGloveTypes = ["Latex-free", "Biogel", "Gammex", "Neoprene", "Standard"]
    static let nonSterileGloveSizes = ["XS", "S", "M", "L", "XL"]

    // MARK: - Display helpers

    /// Combined sterile glove summary, e.g. "7.5 · Biogel". Empty when nothing set.
    var sterileGloveDisplay: String {
        [sterileGloveSize, sterileGloveType].filter { !$0.isBlank }.joined(separator: " · ")
    }

    /// Full-word non-sterile size, e.g. "Large". Empty when nothing set.
    var nonSterileGloveDisplay: String {
        Self.nonSterileGloveName(nonSterileGloveSize)
    }

    static func nonSterileGloveName(_ size: String) -> String {
        switch size.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "XS": return "Extra small"
        case "S": return "Small"
        case "M": return "Medium"
        case "L": return "Large"
        case "XL": return "Extra large"
        default: return size
        }
    }

    // MARK: - Codable (with legacy migration)

    private enum CodingKeys: String, CodingKey {
        case sterileGloveSize, sterileGloveType, nonSterileGloveSize
        case gownSize, maskPreference, theatreShoeSize, roomTemperature
        case coffeePreference, teaPreference, favouriteSnacks, contactPreferences
        case arriveBeforePatient, prepareOwnMedications, assistantMayPrepareMedications, briefingStyle
        case generalNotes
        // Legacy single glove field — migrated into sterileGloveSize on decode.
        case gloveSize
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sterileGloveSize = try c.decodeIfPresent(String.self, forKey: .sterileGloveSize) ?? ""
        sterileGloveType = try c.decodeIfPresent(String.self, forKey: .sterileGloveType) ?? ""
        nonSterileGloveSize = try c.decodeIfPresent(String.self, forKey: .nonSterileGloveSize) ?? ""

        // Migrate older profiles that stored a single free-text glove size.
        if sterileGloveSize.isEmpty {
            let legacy = try c.decodeIfPresent(String.self, forKey: .gloveSize) ?? ""
            if !legacy.isEmpty { sterileGloveSize = legacy }
        }

        gownSize = try c.decodeIfPresent(String.self, forKey: .gownSize) ?? ""
        maskPreference = try c.decodeIfPresent(String.self, forKey: .maskPreference) ?? ""
        theatreShoeSize = try c.decodeIfPresent(String.self, forKey: .theatreShoeSize) ?? ""
        roomTemperature = try c.decodeIfPresent(String.self, forKey: .roomTemperature) ?? ""
        coffeePreference = try c.decodeIfPresent(String.self, forKey: .coffeePreference) ?? ""
        teaPreference = try c.decodeIfPresent(String.self, forKey: .teaPreference) ?? ""
        favouriteSnacks = try c.decodeIfPresent(String.self, forKey: .favouriteSnacks) ?? ""
        contactPreferences = try c.decodeIfPresent(String.self, forKey: .contactPreferences) ?? ""
        arriveBeforePatient = try c.decodeIfPresent(Bool.self, forKey: .arriveBeforePatient) ?? false
        prepareOwnMedications = try c.decodeIfPresent(Bool.self, forKey: .prepareOwnMedications) ?? false
        assistantMayPrepareMedications = try c.decodeIfPresent(Bool.self, forKey: .assistantMayPrepareMedications) ?? false
        briefingStyle = try c.decodeIfPresent(String.self, forKey: .briefingStyle) ?? ""
        generalNotes = try c.decodeIfPresent(String.self, forKey: .generalNotes) ?? ""
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sterileGloveSize, forKey: .sterileGloveSize)
        try c.encode(sterileGloveType, forKey: .sterileGloveType)
        try c.encode(nonSterileGloveSize, forKey: .nonSterileGloveSize)
        try c.encode(gownSize, forKey: .gownSize)
        try c.encode(maskPreference, forKey: .maskPreference)
        try c.encode(theatreShoeSize, forKey: .theatreShoeSize)
        try c.encode(roomTemperature, forKey: .roomTemperature)
        try c.encode(coffeePreference, forKey: .coffeePreference)
        try c.encode(teaPreference, forKey: .teaPreference)
        try c.encode(favouriteSnacks, forKey: .favouriteSnacks)
        try c.encode(contactPreferences, forKey: .contactPreferences)
        try c.encode(arriveBeforePatient, forKey: .arriveBeforePatient)
        try c.encode(prepareOwnMedications, forKey: .prepareOwnMedications)
        try c.encode(assistantMayPrepareMedications, forKey: .assistantMayPrepareMedications)
        try c.encode(briefingStyle, forKey: .briefingStyle)
        try c.encode(generalNotes, forKey: .generalNotes)
    }
}
