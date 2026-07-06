//
//  Doctor.swift
//  PreferenceFlow
//

import Foundation

/// The central entity: a single provider's complete preference profile. Every
/// preference section is nested so the whole profile exports/imports as one unit.
nonisolated struct Doctor: Identifiable, Codable, Hashable {
    var id: UUID

    // Identity
    var fullName: String
    /// Base64-friendly photo data (JPEG) kept inline so profiles stay portable.
    var photoData: Data?
    /// Optional photo of the physical theatre card, kept as a backup reference
    /// while the digital profile is built. Optional for backward-compatible decoding.
    var referencePhotoData: Data?
    var avatarColorHex: String
    var phone: String
    var email: String
    var hospitalId: UUID?
    var department: String
    /// Shared clinician identity across hospital-specific copies of the same
    /// person. All copies of "Dr Mike Hamilton" share one `clinicianId` so the
    /// app can show the same clinician in different hospital contexts. Optional
    /// for backward-compatible decoding; falls back to the profile's own id.
    var clinicianId: UUID?
    /// True when this profile was created as a hospital-specific version of an
    /// existing clinician (drives the "Hospital-specific profile" label).
    var isHospitalSpecific: Bool?

    /// Where this profile came from. `nil` decodes as `.local` for profiles saved
    /// before sourcing existed. Forward-compatible with a future
    /// `.synced(hospital:)` case once a central hospital database is added.
    var source: ProfileSource?
    /// True when an imported (or, later, synced) profile has since been edited
    /// locally, so the technician knows their copy now differs from the original
    /// they received. Always nil/false for locally-created profiles.
    var isLocallyModified: Bool?
    /// Whether these preferences have been confirmed with the consultant. A
    /// profile built from memory or a second-hand paper card can be flagged
    /// unverified so readers know to double-check. Nil decodes as verified for
    /// profiles saved before verification existed (backward-compatible).
    var isVerified: Bool?
    /// True for sample records installed by Demo Mode. Optional for
    /// backward-compatible decoding of records saved before Demo Mode existed.
    var isDemoData: Bool?

    // Professional information
    var role: String
    var subspecialties: [Subspecialty]

    // Notes
    var biography: String
    var personalNotes: String

    // Preference sections
    var general: GeneralPreferences
    /// Legacy free-text medication lists, retained so existing profiles never lose
    /// data on upgrade. The structured `adultDrugs`/`paediatricDrugs` supersede them.
    var adult: MedicationSetup
    var paediatric: MedicationSetup
    /// Structured Drugs & Fluids (v2). Optional for backward-compatible decoding.
    var adultDrugs: DrugsFluidsSetup?
    var paediatricDrugs: DrugsFluidsSetup?
    /// Structured monitoring preferences beyond the standard ASA baseline.
    /// Optional for backward-compatible decoding — nil displays exactly like
    /// the untouched default ("Standard ASA monitoring" only).
    var monitoring: MonitoringPreferences?
    var airway: AirwayPreferences
    var regionalBlocks: [RegionalBlock]
    var neuraxial: NeuraxialPreferences
    /// Procedural workflow customisations (Arterial Line, CVC) — stored
    /// separately from neuraxial because an arterial line is not a neuraxial
    /// technique. Optional for backward-compatible decoding: profiles saved
    /// before this existed decode as nil and read as empty.
    var procedural: ProceduralPreferences?
    var operations: [ProcedureTemplate]
    /// Per-specialty setup modifications (what changes vs the standard setup).
    /// Optional for backward-compatible decoding of profiles saved earlier.
    var specialtySetups: [SpecialtySetup]?
    /// The department standard this consultant inherits from. The profile stores
    /// only its deviations from that standard. Optional for legacy profiles.
    var departmentTemplateId: UUID?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fullName: String = "",
        photoData: Data? = nil,
        referencePhotoData: Data? = nil,
        avatarColorHex: String = AvatarPalette.random(),
        phone: String = "",
        email: String = "",
        hospitalId: UUID? = nil,
        department: String = "",
        role: String = "",
        subspecialties: [Subspecialty] = [],
        biography: String = "",
        personalNotes: String = "",
        source: ProfileSource? = nil,
        isLocallyModified: Bool? = nil,
        isVerified: Bool? = nil,
        isDemoData: Bool? = nil,
        general: GeneralPreferences = GeneralPreferences(),
        adult: MedicationSetup = MedicationSetup(),
        paediatric: MedicationSetup = MedicationSetup(),
        adultDrugs: DrugsFluidsSetup? = nil,
        paediatricDrugs: DrugsFluidsSetup? = nil,
        monitoring: MonitoringPreferences? = nil,
        airway: AirwayPreferences = AirwayPreferences(),
        regionalBlocks: [RegionalBlock] = [],
        neuraxial: NeuraxialPreferences = NeuraxialPreferences(),
        procedural: ProceduralPreferences? = nil,
        operations: [ProcedureTemplate] = [],
        specialtySetups: [SpecialtySetup]? = nil,
        departmentTemplateId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fullName = fullName
        self.photoData = photoData
        self.referencePhotoData = referencePhotoData
        self.avatarColorHex = avatarColorHex
        self.phone = phone
        self.email = email
        self.hospitalId = hospitalId
        self.department = department
        self.role = role
        self.subspecialties = subspecialties
        self.biography = biography
        self.personalNotes = personalNotes
        self.source = source
        self.isLocallyModified = isLocallyModified
        self.isVerified = isVerified
        self.isDemoData = isDemoData
        self.general = general
        self.adult = adult
        self.paediatric = paediatric
        self.adultDrugs = adultDrugs
        self.paediatricDrugs = paediatricDrugs
        self.monitoring = monitoring
        self.airway = airway
        self.regionalBlocks = regionalBlocks
        self.neuraxial = neuraxial
        self.procedural = procedural
        self.operations = operations
        self.specialtySetups = specialtySetups
        self.departmentTemplateId = departmentTemplateId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Up to two initials derived from the provider's name.
    var initials: String {
        let parts = fullName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        return parts.joined().uppercased()
    }

    var displayName: String {
        fullName.trimmingCharacters(in: .whitespaces).isEmpty ? "Unnamed Provider" : fullName
    }

    /// Shared clinician identity used to link hospital-specific copies; falls
    /// back to this profile's own id for legacy profiles.
    var clinicianIdentity: UUID { clinicianId ?? id }

    /// Whether this profile is a hospital-specific copy of a clinician.
    var isHospitalVersion: Bool { isHospitalSpecific ?? false }

    /// The profile's source, defaulting to locally-created for legacy profiles.
    var resolvedSource: ProfileSource { source ?? .local }

    /// Whether an imported/synced profile has been edited locally.
    var hasLocalEdits: Bool { isLocallyModified ?? false }

    /// Whether these preferences have been confirmed with the consultant. Legacy
    /// profiles (nil) are treated as verified so they aren't retroactively flagged.
    var isVerifiedProfile: Bool { isVerified ?? true }

    /// Whether this is a Demo Mode sample record.
    var isDemo: Bool { isDemoData ?? false }

    /// True when the profile hasn't been updated in over 12 months and may be
    /// stale — a gentle prompt to confirm before relying on it.
    var needsReview: Bool {
        guard let threshold = Calendar.current.date(byAdding: .month, value: -12, to: Date()) else {
            return false
        }
        return updatedAt < threshold
    }

    /// Human-friendly "last updated" summary for list rows — relative for recent
    /// changes, month/year once it's older than a month.
    var updatedSummary: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: updatedAt, to: Date()).day ?? 0
        if days <= 0 { return "Updated today" }
        if days == 1 { return "Updated yesterday" }
        if days < 30 { return "Updated \(days) days ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "Updated \(formatter.string(from: updatedAt))"
    }

    /// Normalised name for fuzzy duplicate detection: lowercased, titles stripped,
    /// punctuation removed, whitespace collapsed.
    static func normalizedName(_ raw: String) -> String {
        let titles: Set<String> = [
            "dr", "dr.", "prof", "prof.", "professor", "mr", "mrs", "ms",
            "miss", "sir", "consultant", "assoc", "associate"
        ]
        let cleaned = raw.lowercased()
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let tokens = cleaned
            .split(whereSeparator: { $0 == " " })
            .map(String.init)
            .filter { !titles.contains($0) && !$0.isEmpty }
        return tokens.joined(separator: " ")
    }

    /// Specialty setups that actually carry content, ready for the dashboard.
    var activeSpecialtySetups: [SpecialtySetup] {
        (specialtySetups ?? []).filter { $0.hasContent }
    }

    /// The monitoring preferences with the nil legacy case normalised to the
    /// default (standard ASA baseline, nothing additional).
    var monitoringPreferences: MonitoringPreferences { monitoring ?? MonitoringPreferences() }

    /// The procedural workflow storage (Arterial Line, CVC) with the nil legacy
    /// case normalised to empty.
    var proceduralPreferences: ProceduralPreferences { procedural ?? ProceduralPreferences() }

    /// Inserts or replaces a procedural workflow customization, creating the
    /// storage on first write.
    mutating func setProceduralCustomization(_ customization: WorkflowCustomization) {
        var updated = procedural ?? ProceduralPreferences()
        updated.setCustomization(customization)
        procedural = updated
    }
}

/// Which preference sections carry over when copying a profile to another
/// hospital. Identity (name, photo, contact, role) always copies.
nonisolated struct MigrationScope: OptionSet, Hashable {
    let rawValue: Int

    static let general = MigrationScope(rawValue: 1 << 0)
    static let airway = MigrationScope(rawValue: 1 << 1)
    static let drugs = MigrationScope(rawValue: 1 << 2)
    static let regionalNeuraxial = MigrationScope(rawValue: 1 << 3)
    static let procedures = MigrationScope(rawValue: 1 << 4)

    /// Everything — a full clone of the source preferences.
    static let full: MigrationScope = [.general, .airway, .drugs, .regionalNeuraxial, .procedures]
    /// Nothing — a blank hospital version with identity only.
    static let blank: MigrationScope = []
}

/// Curated avatar accent colours (hex) for providers without a photo.
nonisolated enum AvatarPalette {
    static let colors = [
        "0E9F8E", "2E7DD1", "7A5CD6", "D1576E",
        "E0883B", "3CA55C", "C0489B", "47808F"
    ]

    static func random() -> String {
        colors.randomElement() ?? "0E9F8E"
    }
}
