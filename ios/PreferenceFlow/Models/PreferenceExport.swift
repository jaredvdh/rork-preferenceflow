//
//  PreferenceExport.swift
//  PreferenceFlow
//

import Foundation

/// Versioned envelope wrapping one or more exported provider profiles. The
/// `schemaVersion` lets future app versions migrate older shared files safely.
nonisolated struct PreferenceExport: Codable, Hashable {
    /// Bump when the stored shape changes in a non-additive way.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var appName: String
    var exportedAt: Date
    /// Name of the technician who shared this file, when known, so the recipient
    /// can label the imported profile "Imported from [name]". Optional for
    /// backward-compatible decoding of older files.
    var sharedBy: String?
    var region: TerminologyRegion
    /// Hospitals referenced by the exported doctors, included for context.
    var hospitals: [Hospital]
    var doctors: [Doctor]

    init(
        schemaVersion: Int = PreferenceExport.currentSchemaVersion,
        appName: String = "ORPrep",
        exportedAt: Date = Date(),
        sharedBy: String? = nil,
        region: TerminologyRegion,
        hospitals: [Hospital],
        doctors: [Doctor]
    ) {
        self.schemaVersion = schemaVersion
        self.appName = appName
        self.exportedAt = exportedAt
        self.sharedBy = sharedBy
        self.region = region
        self.hospitals = hospitals
        self.doctors = doctors
    }
}

/// Resolution chosen by the user when an imported profile already exists.
nonisolated enum ImportResolution {
    case replace
    case saveAsCopy
    case cancel
}

/// Shared JSON coding configuration so export and import stay symmetrical.
nonisolated enum PreferenceCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
