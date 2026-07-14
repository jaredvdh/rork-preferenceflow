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
    // Surgical specialties (surgeon / proceduralist profiles).
    case generalSurgery = "General / Laparoscopic"
    case hepatobiliary = "Hepatobiliary (HPB)"
    case orthopaedics = "Orthopaedics"
    case cathLab = "Cath Lab"
    case endoscopy = "Endoscopy"
    case cardiothoracic = "Cardiothoracic"
    case urology = "Urology"
    case gynaecology = "Gynaecology"
    case ophthalmology = "Ophthalmology"
    case other = "Other"

    var id: String { rawValue }

    /// Specialties offered when tagging an anaesthetic consultant profile.
    static let anaesthetic: [Subspecialty] = [
        .general, .cardiac, .paediatrics, .neuro, .trauma, .vascular, .ent,
        .plastics, .obstetrics, .regional, .icu, .mri, .thoracic, .transplant, .other
    ]

    /// Specialties offered when tagging a surgeon / proceduralist profile.
    static let surgical: [Subspecialty] = [
        .generalSurgery, .hepatobiliary, .orthopaedics, .cathLab, .endoscopy,
        .cardiothoracic, .urology, .gynaecology, .ent, .vascular, .neuro,
        .plastics, .ophthalmology, .obstetrics, .paediatrics, .trauma, .other
    ]

    /// The specialty list appropriate to a profile's clinician kind.
    static func options(for kind: ClinicianKind) -> [Subspecialty] {
        kind == .surgeon ? surgical : anaesthetic
    }

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
        case .generalSurgery: return "scissors"
        case .hepatobiliary: return "cross.vial"
        case .orthopaedics: return "figure.walk"
        case .cathLab: return "waveform.path.ecg.rectangle"
        case .endoscopy: return "scope"
        case .cardiothoracic: return "bolt.heart.fill"
        case .urology: return "drop.fill"
        case .gynaecology: return "figure.2"
        case .ophthalmology: return "eye.fill"
        case .other: return "square.grid.2x2"
        }
    }
}
