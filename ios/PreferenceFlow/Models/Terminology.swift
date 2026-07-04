//
//  Terminology.swift
//  PreferenceFlow
//

import Foundation

/// Regional terminology variant. Drives provider/assistant titles and spelling
/// throughout the app based on the user's country selection during onboarding.
nonisolated enum TerminologyRegion: String, Codable, CaseIterable, Identifiable, Hashable {
    /// New Zealand and Australia.
    case commonwealth
    /// United Kingdom — separate from commonwealth: the assistant role is the
    /// Operating Department Practitioner (ODP), an HCPC-registered profession,
    /// not "Anaesthetic Technician".
    case unitedKingdom
    /// United States, Canada and similar.
    case northAmerica

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commonwealth: return "NZ / Australia"
        case .unitedKingdom: return "United Kingdom"
        case .northAmerica: return "North America (US / CA)"
        }
    }

    /// Singular provider title, e.g. "Anaesthetist".
    var provider: String {
        switch self {
        case .commonwealth, .unitedKingdom: return "Anaesthetist"
        case .northAmerica: return "Anesthesiologist"
        }
    }

    /// Plural provider title.
    var providerPlural: String {
        switch self {
        case .commonwealth, .unitedKingdom: return "Anaesthetists"
        case .northAmerica: return "Anesthesiologists"
        }
    }

    /// Assistant role title, e.g. "Anaesthetic Technician".
    var assistant: String {
        switch self {
        case .commonwealth: return "Anaesthetic Technician"
        case .unitedKingdom: return "Operating Department Practitioner (ODP)"
        case .northAmerica: return "Anesthesia Assistant"
        }
    }

    /// Short assistant form for places where space is tight (chips, badges, tab labels).
    var assistantShort: String {
        switch self {
        case .commonwealth: return "Anaesthetic Tech"
        case .unitedKingdom: return "ODP"
        case .northAmerica: return "Anesthesia Assistant"
        }
    }

    /// Discipline noun, e.g. "Anaesthesia".
    var discipline: String {
        switch self {
        case .commonwealth, .unitedKingdom: return "Anaesthesia"
        case .northAmerica: return "Anesthesia"
        }
    }

    /// Paediatric vs pediatric spelling.
    var paediatric: String {
        switch self {
        case .commonwealth, .unitedKingdom: return "Paediatric"
        case .northAmerica: return "Pediatric"
        }
    }

    /// Best-guess region for a given country name. Returns `nil` when the
    /// country isn't recognised — the caller must let the user choose
    /// explicitly rather than silently defaulting to any preset.
    static func suggested(for country: String) -> TerminologyRegion? {
        let normalised = country.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalised.isEmpty else { return nil }

        // Short country codes are matched exactly — substring matching would
        // false-positive ("australia" contains "us", "south africa" contains "ca").
        let exactCodes: [String: TerminologyRegion] = [
            "us": .northAmerica, "usa": .northAmerica, "ca": .northAmerica,
            "uk": .unitedKingdom, "gb": .unitedKingdom,
            "nz": .commonwealth, "au": .commonwealth, "aus": .commonwealth,
            "sg": .commonwealth, "za": .commonwealth
        ]
        if let match = exactCodes[normalised] { return match }

        let northAmerican = ["united states", "america", "canada"]
        let uk = ["united kingdom", "england", "scotland", "wales",
                  "northern ireland", "britain", "great britain", "ireland"]
        let commonwealth = ["new zealand", "australia", "singapore",
                            "south africa", "india", "malaysia", "hong kong"]
        if northAmerican.contains(where: { normalised.contains($0) }) {
            return .northAmerica
        }
        if uk.contains(where: { normalised.contains($0) }) {
            return .unitedKingdom
        }
        if commonwealth.contains(where: { normalised.contains($0) }) {
            return .commonwealth
        }
        return nil // genuinely unknown — let the user choose without a false default
    }
}

/// Common country options surfaced during onboarding. Free text is also allowed.
nonisolated enum CountryOption: String, CaseIterable, Identifiable {
    case newZealand = "New Zealand"
    case australia = "Australia"
    case unitedKingdom = "United Kingdom"
    case ireland = "Ireland"
    case unitedStates = "United States"
    case canada = "Canada"
    case singapore = "Singapore"
    case southAfrica = "South Africa"
    case other = "Other / not listed"

    var id: String { rawValue }

    /// Terminology preset for this country. `nil` for "Other / not listed" —
    /// the user picks explicitly on the terminology step instead.
    var region: TerminologyRegion? {
        switch self {
        case .newZealand, .australia: return .commonwealth
        case .unitedKingdom, .ireland: return .unitedKingdom
        case .unitedStates, .canada: return .northAmerica
        case .singapore, .southAfrica: return .commonwealth // English-medium, Commonwealth-trained systems
        case .other: return nil // triggers explicit terminology choice
        }
    }

    var flag: String {
        switch self {
        case .newZealand: return "🇳🇿"
        case .australia: return "🇦🇺"
        case .unitedKingdom: return "🇬🇧"
        case .ireland: return "🇮🇪"
        case .unitedStates: return "🇺🇸"
        case .canada: return "🇨🇦"
        case .singapore: return "🇸🇬"
        case .southAfrica: return "🇿🇦"
        case .other: return "🌐"
        }
    }
}
