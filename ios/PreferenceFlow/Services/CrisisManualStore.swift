//
//  CrisisManualStore.swift
//  PreferenceFlow
//

import Foundation

/// Loads the bundled crisis manual JSON for the active region, fully offline.
/// Decoded manuals are cached so repeated screen visits are instant. There is no
/// network dependency — both region files ship inside the app bundle.
nonisolated enum CrisisManualStore {
    /// Bundle resource name for a given terminology region.
    private static func resourceName(for region: TerminologyRegion) -> String {
        switch region {
        case .northAmerica: return "crisis_manual_us"
        case .commonwealth: return "crisis_manual_nz_uk_au"
        }
    }

    private static let cache = NSCache<NSString, CacheBox>()

    /// Wrapper so a value-type manual can live in NSCache.
    private final class CacheBox {
        let manual: CrisisManual
        init(_ manual: CrisisManual) { self.manual = manual }
    }

    /// Returns the decoded manual for the region, loading and caching on first use.
    /// Returns nil only if the resource is missing or fails to decode (which would
    /// indicate a packaging error rather than a runtime condition).
    static func manual(for region: TerminologyRegion) -> CrisisManual? {
        let name = resourceName(for: region)
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
