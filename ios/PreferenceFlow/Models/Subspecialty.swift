//
//  Subspecialty.swift
//  PreferenceFlow
//

import Foundation

/// Selectable provider subspecialties. Stored by raw string for forward
/// compatibility (custom values land under `.other`).
nonisolated enum Subspecialty: String, Codable, CaseIterable, Identifiable, Hashable {
    case general = "General Anaesthesia"
    case cardiac = "Cardiac"
    case paediatrics = "Paediatrics"
    case neuro = "Neuro"
    case trauma = "Trauma"
    case vascular = "Vascular"
    case ent = "ENT"
    case plastics = "Plastics"
    case obstetrics = "Obstetrics"
    case regional = "Regional Anaesthesia"
    case icu = "ICU"
    case mri = "MRI Anaesthesia"
    case thoracic = "Thoracic"
    case transplant = "Transplant"
    case other = "Other"

    var id: String { rawValue }

    /// SF Symbol used for specialty badges.
    var symbol: String {
        switch self {
        case .general: return "stethoscope"
        case .cardiac: return "heart.fill"
        case .paediatrics: return "figure.child"
        case .neuro: return "brain.head.profile"
        case .trauma: return "bolt.heart"
        case .vascular: return "waveform.path.ecg"
        case .ent: return "ear"
        case .plastics: return "hand.draw"
        case .obstetrics: return "figure.2.and.child.holdinghands"
        case .regional: return "scope"
        case .icu: return "bed.double.fill"
        case .mri: return "waveform.path"
        case .thoracic: return "lungs.fill"
        case .transplant: return "arrow.triangle.2.circlepath"
        case .other: return "square.grid.2x2"
        }
    }
}
