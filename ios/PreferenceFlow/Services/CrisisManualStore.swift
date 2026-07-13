//
//  CrisisManualStore.swift
//  PreferenceFlow
//

import Foundation

/// Which edition of the crisis manual to display. Both editions ship inside the
/// app bundle and cover the same 33 cards with identical ids — they differ in
/// units and drug terminology (adrenaline vs epinephrine, °C vs °F alongside).
nonisolated enum CrisisEdition: String, Codable, CaseIterable, Identifiable {
    /// SI units with UK / NZ / AU drug names (adrenaline, salbutamol, lignocaine).
    case si
    /// US drug names (epinephrine, albuterol, lidocaine) with °F shown alongside °C.
    case us

    var id: String { rawValue }

    /// Full name for pickers.
    var displayName: String {
        switch self {
        case .si: return "UK / NZ / AU — SI units"
        case .us: return "US — US terminology"
        }
    }

    /// Compact label for the in-card switcher pill.
    var shortLabel: String {
        switch self {
        case .si: return "UK · SI"
        case .us: return "US"
        }
    }

    /// One-line description of what changes in this edition.
    var detail: String {
        switch self {
        case .si: return "Adrenaline · salbutamol · mmol/L · °C"
        case .us: return "Epinephrine · albuterol · °F alongside °C"
        }
    }

    /// Bundled JSON resource for this edition.
    var resourceName: String {
        switch self {
        case .si: return "crisis_manual_nz_uk_au"
        case .us: return "crisis_manual_us"
        }
    }

    /// The natural edition for a terminology region, used until the user
    /// explicitly picks one.
    static func `default`(for region: TerminologyRegion) -> CrisisEdition {
        region == .northAmerica ? .us : .si
    }
}

/// Loads the bundled crisis manual JSON for the active edition, fully offline.
/// Decoded manuals are cached so repeated screen visits are instant. There is no
/// network dependency — both edition files ship inside the app bundle.
nonisolated enum CrisisManualStore {

    private static let cache = NSCache<NSString, CacheBox>()

    /// Wrapper so a value-type manual can live in NSCache.
    private final class CacheBox {
        let manual: CrisisManual
        init(_ manual: CrisisManual) { self.manual = manual }
    }

    /// Returns the decoded manual for the edition, loading and caching on first use.
    /// Returns nil only if the resource is missing or fails to decode (which would
    /// indicate a packaging error rather than a runtime condition).
    static func manual(for edition: CrisisEdition) -> CrisisManual? {
        let name = edition.resourceName
        if let cached = cache.object(forKey: name as NSString) {
            return cached.manual
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            assertionFailure("Missing bundled crisis manual: \(name).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let manual = try JSONDecoder().decode(CrisisManual.self, from: data)
            cache.setObject(CacheBox(manual), forKey: name as NSString)
            return manual
        } catch {
            assertionFailure("Failed to decode \(name).json: \(error)")
            return nil
        }
    }
}

/// Stable card ids for the emergency shortcuts surfaced throughout the app.
/// These ids are identical across both region files.
nonisolated enum CrisisShortcut: String, CaseIterable, Identifiable {
    case malignantHyperthermia = "16e"
    case localAnaestheticToxicity = "15e"
    case anaphylaxis = "10e"
    case cicoRescue = "2e"
    case massiveHaemorrhage = "12e"

    var id: String { rawValue }

    /// Short label for the shortcut chip.
    var shortLabel: String {
        switch self {
        case .malignantHyperthermia: return "MH"
        case .localAnaestheticToxicity: return "LAST"
        case .anaphylaxis: return "Anaphylaxis"
        case .cicoRescue: return "CICO"
        case .massiveHaemorrhage: return "Haemorrhage"
        }
    }

    var symbol: String {
        switch self {
        case .malignantHyperthermia: return "thermometer.sun.fill"
        case .localAnaestheticToxicity: return "bolt.heart.fill"
        case .anaphylaxis: return "allergens.fill"
        case .cicoRescue: return "xmark.octagon.fill"
        case .massiveHaemorrhage: return "drop.triangle.fill"
        }
    }
}
