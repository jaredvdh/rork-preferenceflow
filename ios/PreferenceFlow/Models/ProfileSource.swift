//
//  ProfileSource.swift
//  PreferenceFlow
//

import Foundation

/// Where a preference profile originated. Deliberately modelled as an enum so it
/// can grow forward-compatibly: a future version that syncs to a central hospital
/// database will simply add a `.synced(hospital:)` case without breaking existing
/// stored data or shared files.
///
/// Encoded as structured JSON (a `kind` discriminator plus optional fields) so a
/// future backend can read and write it directly.
nonisolated enum ProfileSource: Codable, Hashable {
    /// Entered on this device by the technician.
    case local
    /// Received from a colleague (peer-to-peer share). Carries the sharer's name
    /// when known, e.g. "Imported from Sam Carter".
    case imported(from: String)
    // Reserved for a future release with a central database:
    // case synced(hospital: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case from
    }

    private enum Kind: String, Codable {
        case local
        case imported
        case synced
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .imported, .synced:
            let name = (try? container.decode(String.self, forKey: .from)) ?? ""
            self = .imported(from: name)
        case .local:
            self = .local
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .local:
            try container.encode(Kind.local, forKey: .kind)
        case .imported(let name):
            try container.encode(Kind.imported, forKey: .kind)
            try container.encode(name, forKey: .from)
        }
    }

    /// Short label for the profile's source row, e.g. "Local — created by you" or
    /// "Imported from Sam Carter".
    var label: String {
        switch self {
        case .local:
            return "Local — created by you"
        case .imported(let name):
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "Imported from a colleague" : "Imported from \(trimmed)"
        }
    }

    /// SF Symbol that represents the source kind.
    var symbol: String {
        switch self {
        case .local: return "iphone"
        case .imported: return "square.and.arrow.down"
        }
    }
}
