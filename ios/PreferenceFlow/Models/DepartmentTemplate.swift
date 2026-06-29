//
//  DepartmentTemplate.swift
//  PreferenceFlow
//

import Foundation

/// A hospital department's *standard* theatre setup. Consultant profiles inherit
/// 100% of a template's values on creation and then store only their own
/// deviations, so a profile is a small set of overrides on top of the
/// departmental standard. Templates are stored per hospital and can be edited
/// centrally — updating a standard updates every consultant who still inherits it.
nonisolated struct DepartmentTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    /// True for the seeded department standards. User-created templates are false.
    var isBuiltIn: Bool

    // Standard setup payload — mirrors the consultant preference shape so a
    // consultant section can be compared field-for-field against the standard.
    var general: GeneralPreferences
    var airway: AirwayPreferences
    var adultDrugs: DrugsFluidsSetup
    var neuraxial: NeuraxialPreferences
    var regionalBlocks: [RegionalBlock]
    var notes: String

    init(
        id: UUID = UUID(),
        name: String = "",
        icon: String = "rectangle.stack",
        isBuiltIn: Bool = false,
        general: GeneralPreferences = GeneralPreferences(),
        airway: AirwayPreferences = AirwayPreferences(),
        adultDrugs: DrugsFluidsSetup = DrugsFluidsSetup(),
        neuraxial: NeuraxialPreferences = NeuraxialPreferences(),
        regionalBlocks: [RegionalBlock] = [],
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.general = general
        self.airway = airway
        self.adultDrugs = adultDrugs
        self.neuraxial = neuraxial
        self.regionalBlocks = regionalBlocks
        self.notes = notes
    }

    /// Applies this template's standard setup to a consultant profile and records
    /// the inheritance link. Used when creating a consultant from a template.
    func apply(to doctor: inout Doctor) {
        doctor.general = general
        doctor.airway = airway
        doctor.adultDrugs = adultDrugs
        doctor.neuraxial = neuraxial
        doctor.regionalBlocks = regionalBlocks
        doctor.departmentTemplateId = id
    }

    /// A fresh consultant pre-populated from this standard, ready for identity.
    func makeDoctor(hospitalId: UUID?) -> Doctor {
        var doctor = Doctor(hospitalId: hospitalId)
        apply(to: &doctor)
        return doctor
    }
}

/// Which top-level consultant sections participate in inheritance comparison.
nonisolated enum InheritedSection: String, CaseIterable, Identifiable {
    case general = "General"
    case airway = "Airway"
    case drugs = "Drugs & Fluids"
    case regional = "Regional"
    case neuraxial = "Neuraxial"

    var id: String { rawValue }
}

/// Whether a consultant section still matches the department standard (inherited)
/// or has been customised (modified). Drives the grey/blue badges.
nonisolated enum InheritanceStatus: Hashable {
    case inherited
    case modified
    /// No department template linked — inheritance does not apply.
    case standalone

    var label: String {
        switch self {
        case .inherited: return "Inherited from Department"
        case .modified: return "Updated by you"
        case .standalone: return ""
        }
    }

    var shortLabel: String {
        switch self {
        case .inherited: return "Standard"
        case .modified: return "Updated"
        case .standalone: return ""
        }
    }
}

/// Compares a consultant against their linked department standard, section by
/// section, so the UI can show what is inherited vs customised.
nonisolated enum ProfileInheritance {
    static func status(_ section: InheritedSection, doctor: Doctor, template: DepartmentTemplate?) -> InheritanceStatus {
        guard let template else { return .standalone }
        let matches: Bool
        switch section {
        case .general: matches = doctor.general == template.general
        case .airway: matches = doctor.airway == template.airway
        case .drugs: matches = (doctor.adultDrugs ?? DrugsFluidsSetup()) == template.adultDrugs
        case .regional: matches = doctor.regionalBlocks == template.regionalBlocks
        case .neuraxial: matches = doctor.neuraxial == template.neuraxial
        }
        return matches ? .inherited : .modified
    }

    /// Resets a single consultant section back to the department standard.
    static func reset(_ section: InheritedSection, doctor: inout Doctor, template: DepartmentTemplate) {
        switch section {
        case .general: doctor.general = template.general
        case .airway: doctor.airway = template.airway
        case .drugs: doctor.adultDrugs = template.adultDrugs
        case .regional: doctor.regionalBlocks = template.regionalBlocks
        case .neuraxial: doctor.neuraxial = template.neuraxial
        }
    }

    /// Count of sections a consultant has customised away from the standard.
    static func modifiedCount(doctor: Doctor, template: DepartmentTemplate?) -> Int {
        guard template != nil else { return 0 }
        return InheritedSection.allCases.filter { status($0, doctor: doctor, template: template) == .modified }.count
    }
}
