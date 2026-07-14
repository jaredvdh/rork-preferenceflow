//
//  Discipline.swift
//  PreferenceFlow
//

import Foundation

/// The user's working discipline, chosen during onboarding (changeable in
/// Settings). Drives which profile type the app foregrounds — anaesthetic
/// consultants or surgeons/proceduralists — and relabels the Providers tab
/// accordingly. Shared content (hospitals, crisis manual, backups, search)
/// is identical in both.
nonisolated enum Discipline: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Anaesthetic technicians / ODPs / anesthesia assistants — the original focus.
    case anaesthesia
    /// Scrub and circulating nurses in surgery, cath lab and endoscopy.
    case surgical

    var id: String { rawValue }

    /// Display name, respecting regional spelling for anaesthesia.
    func displayName(for region: TerminologyRegion) -> String {
        switch self {
        case .anaesthesia: return region.discipline
        case .surgical: return "Surgical / Perioperative"
        }
    }

    /// Short explanation shown under the option during onboarding / in Settings.
    var detail: String {
        switch self {
        case .anaesthesia:
            return "Anaesthetic technicians, ODPs and anaesthesia assistants — consultant anaesthetic preference cards."
        case .surgical:
            return "Scrub and circulating nurses — surgeon preference cards: gloves, trays, sutures, energy and positioning."
        }
    }

    var symbol: String {
        switch self {
        case .anaesthesia: return "lungs.fill"
        case .surgical: return "scissors"
        }
    }

    /// The profile type this discipline works with day-to-day.
    var primaryKind: ClinicianKind {
        switch self {
        case .anaesthesia: return .anaesthetist
        case .surgical: return .surgeon
        }
    }
}

/// Which type of clinician a preference profile describes. Stored on `Doctor`
/// as an optional for backward-compatible decoding — profiles saved before
/// the surgical module existed decode as nil and read as `.anaesthetist`.
nonisolated enum ClinicianKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case anaesthetist
    case surgeon

    var id: String { rawValue }

    /// Singular provider title, e.g. "Anaesthetist" / "Surgeon".
    func provider(_ region: TerminologyRegion) -> String {
        switch self {
        case .anaesthetist: return region.provider
        case .surgeon: return "Surgeon"
        }
    }

    /// Plural provider title, e.g. "Anaesthetists" / "Surgeons".
    func providerPlural(_ region: TerminologyRegion) -> String {
        switch self {
        case .anaesthetist: return region.providerPlural
        case .surgeon: return "Surgeons"
        }
    }

    var symbol: String {
        switch self {
        case .anaesthetist: return "lungs.fill"
        case .surgeon: return "scissors"
        }
    }
}
