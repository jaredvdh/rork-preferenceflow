//
//  HospitalOrientation.swift
//  PreferenceFlow
//

import Foundation

/// A hospital's orientation guide — equipment locations, key contacts, the
/// sick-call workflow, and policy/workflow notes. Stored separately from any
/// individual provider's preferences so it reads as a fast site orientation for
/// new, casual, locum and rotating staff.
///
/// Shaped for a future "department mode": `approval` lets the same record later
/// progress from personal notes → department-verified → admin-approved without a
/// redesign. For MVP everything is `.personal` and stored locally.
nonisolated struct HospitalOrientation: Codable, Hashable {
    var equipmentLocations: [EquipmentLocation]
    var contacts: [HospitalContact]
    var sickCall: SickCallInfo
    var policies: [PolicyWorkflow]
    var sharedFiles: [SharedFile]
    /// Future department-mode state. Defaults to personal for MVP.
    var approval: OrientationApproval

    init(
        equipmentLocations: [EquipmentLocation] = [],
        contacts: [HospitalContact] = [],
        sickCall: SickCallInfo = SickCallInfo(),
        policies: [PolicyWorkflow] = [],
        sharedFiles: [SharedFile] = [],
        approval: OrientationApproval = .personal
    ) {
        self.equipmentLocations = equipmentLocations
        self.contacts = contacts
        self.sickCall = sickCall
        self.policies = policies
        self.sharedFiles = sharedFiles
        self.approval = approval
    }

    var hasContent: Bool {
        !equipmentLocations.isEmpty || !contacts.isEmpty || !policies.isEmpty
            || !sharedFiles.isEmpty || sickCall.hasContent
    }
}

/// Future-mode provenance for orientation content. Reserved for department
/// accounts; for MVP everything is `.personal`.
nonisolated enum OrientationApproval: String, Codable, Hashable, CaseIterable {
    case personal = "Personal notes"
    case departmentVerified = "Department verified"
    case adminApproved = "Admin approved"

    var symbol: String {
        switch self {
        case .personal: return "person.crop.circle"
        case .departmentVerified: return "checkmark.seal"
        case .adminApproved: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Equipment locations

/// A piece of key equipment and where to find it. `kind` maps to a curated set
/// of well-known items (with icons) but `customLabel` allows anything.
nonisolated struct EquipmentLocation: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: EquipmentKind
    /// Used only when `kind == .other`.
    var customLabel: String
    var location: String
    var accessInstructions: String
    var notes: String
    /// Optional inline photo (JPEG) kept portable for sharing/export.
    var photoData: Data?

    init(
        id: UUID = UUID(),
        kind: EquipmentKind = .difficultIntubationTrolley,
        customLabel: String = "",
        location: String = "",
        accessInstructions: String = "",
        notes: String = "",
        photoData: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.customLabel = customLabel
        self.location = location
        self.accessInstructions = accessInstructions
        self.notes = notes
        self.photoData = photoData
    }

    var title: String {
        kind == .other ? (customLabel.isBlank ? "Equipment" : customLabel) : kind.rawValue
    }

    var symbol: String { kind.symbol }
}

/// High-level grouping for equipment so the locations screen reads as categories
/// (Airway, Monitoring, Emergency…) rather than one long list.
nonisolated enum EquipmentCategory: String, Codable, Hashable, CaseIterable, Identifiable {
    case airway = "Airway"
    case emergency = "Emergency"
    case regional = "Regional"
    case warmingTransfusion = "Warming & Transfusion"
    case imaging = "Imaging"
    case storage = "Storage & Stores"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .airway: return "lungs.fill"
        case .emergency: return "cross.case.fill"
        case .regional: return "scope"
        case .warmingTransfusion: return "drop.fill"
        case .imaging: return "waveform.path.ecg"
        case .storage: return "shippingbox.fill"
        case .other: return "mappin.and.ellipse"
        }
    }

    /// Display order on the equipment screen — clinically most-urgent first.
    var sortIndex: Int {
        switch self {
        case .emergency: return 0
        case .airway: return 1
        case .warmingTransfusion: return 2
        case .regional: return 3
        case .imaging: return 4
        case .storage: return 5
        case .other: return 6
        }
    }
}

/// Curated key equipment items found in most theatre suites.
nonisolated enum EquipmentKind: String, Codable, Hashable, CaseIterable, Identifiable {
    case difficultIntubationTrolley = "Difficult intubation trolley"
    case crashCart = "Crash cart / arrest trolley"
    case mhKit = "Malignant hyperthermia kit"
    case paediatricTrolley = "Paediatric trolley"
    case emergencyAirway = "Emergency airway equipment"
    case rapidInfuser = "Rapid infuser"
    case belmont = "Belmont / Level 1"
    case ultrasound = "Ultrasound machines"
    case videoLaryngoscopes = "Video laryngoscopes"
    case regionalEquipment = "Regional anaesthesia equipment"
    case bloodFridge = "Blood fridge"
    case pharmacy = "Pharmacy"
    case theatreStores = "Theatre stores"
    case anaestheticWorkroom = "Anaesthetic workroom"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .difficultIntubationTrolley: return "stethoscope"
        case .crashCart: return "bolt.heart"
        case .mhKit: return "thermometer.high"
        case .paediatricTrolley: return "figure.child"
        case .emergencyAirway: return "lungs"
        case .rapidInfuser: return "drop.triangle"
        case .belmont: return "thermometer.medium"
        case .ultrasound: return "waveform.path.ecg"
        case .videoLaryngoscopes: return "video"
        case .regionalEquipment: return "scope"
        case .bloodFridge: return "cross.vial"
        case .pharmacy: return "pills"
        case .theatreStores: return "shippingbox"
        case .anaestheticWorkroom: return "wrench.and.screwdriver"
        case .other: return "mappin.and.ellipse"
        }
    }

    /// Maps each item to its dashboard category.
    var category: EquipmentCategory {
        switch self {
        case .difficultIntubationTrolley, .emergencyAirway, .videoLaryngoscopes: return .airway
        case .crashCart, .mhKit: return .emergency
        case .paediatricTrolley: return .emergency
        case .rapidInfuser, .belmont, .bloodFridge: return .warmingTransfusion
        case .ultrasound: return .imaging
        case .regionalEquipment: return .regional
        case .pharmacy, .theatreStores, .anaestheticWorkroom: return .storage
        case .other: return .other
        }
    }
}

// MARK: - Contacts

/// An editable contact card for a key hospital role.
nonisolated struct HospitalContact: Identifiable, Codable, Hashable {
    var id: UUID
    var role: ContactRole
    /// Used only when `role == .other`.
    var customRole: String
    var name: String
    var phone: String
    var extensionNumber: String
    var pager: String
    var email: String
    var notes: String

    init(
        id: UUID = UUID(),
        role: ContactRole = .chargeTechnician,
        customRole: String = "",
        name: String = "",
        phone: String = "",
        extensionNumber: String = "",
        pager: String = "",
        email: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.role = role
        self.customRole = customRole
        self.name = name
        self.phone = phone
        self.extensionNumber = extensionNumber
        self.pager = pager
        self.email = email
        self.notes = notes
    }

    var roleTitle: String {
        role == .other ? (customRole.isBlank ? "Contact" : customRole) : role.rawValue
    }

    var symbol: String { role.symbol }
}

/// High-level grouping for contacts so the contacts screen reads as departments
/// (Clinical, Technical, Laboratory…) rather than one long list.
nonisolated enum ContactCategory: String, Codable, Hashable, CaseIterable, Identifiable {
    case clinical = "Clinical"
    case technical = "Technical"
    case administration = "Administration"
    case laboratory = "Laboratory"
    case bloodBank = "Blood Bank"
    case criticalCare = "Critical Care"
    case engineering = "Engineering"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .clinical: return "stethoscope"
        case .technical: return "person.2.badge.gearshape"
        case .administration: return "calendar.badge.clock"
        case .laboratory: return "testtube.2"
        case .bloodBank: return "cross.vial"
        case .criticalCare: return "bed.double"
        case .engineering: return "wrench.and.screwdriver"
        case .other: return "person.crop.circle"
        }
    }

    var sortIndex: Int {
        switch self {
        case .clinical: return 0
        case .technical: return 1
        case .criticalCare: return 2
        case .bloodBank: return 3
        case .laboratory: return 4
        case .administration: return 5
        case .engineering: return 6
        case .other: return 7
        }
    }
}

/// Curated key roles for theatre orientation.
nonisolated enum ContactRole: String, Codable, Hashable, CaseIterable, Identifiable {
    case chargeTechnician = "Charge Anaesthetic Technician"
    case techTeamLeader = "Anaesthetic Technician Team Leader"
    case dutyChargeAnaesthetist = "Duty Charge Anaesthetist"
    case theatreCoordinator = "Theatre Coordinator"
    case pharmacy = "Pharmacy"
    case bloodBank = "Blood Bank"
    case icu = "ICU"
    case pacu = "PACU"
    case biomedical = "Biomedical Engineering"
    case security = "Security"
    case sickCall = "Sick Call / Illness Reporting"
    case afterHoursManager = "After-Hours Manager"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .chargeTechnician: return "person.badge.key"
        case .techTeamLeader: return "person.2.badge.gearshape"
        case .dutyChargeAnaesthetist: return "stethoscope"
        case .theatreCoordinator: return "calendar.badge.clock"
        case .pharmacy: return "pills"
        case .bloodBank: return "cross.vial"
        case .icu: return "bed.double"
        case .pacu: return "waveform.path.ecg"
        case .biomedical: return "wrench.and.screwdriver"
        case .security: return "lock.shield"
        case .sickCall: return "phone.badge.waveform"
        case .afterHoursManager: return "moon.stars"
        case .other: return "person.crop.circle"
        }
    }

    /// Maps each role to its dashboard category.
    var category: ContactCategory {
        switch self {
        case .dutyChargeAnaesthetist, .pacu: return .clinical
        case .chargeTechnician, .techTeamLeader: return .technical
        case .theatreCoordinator, .sickCall, .afterHoursManager, .security: return .administration
        case .pharmacy: return .laboratory
        case .bloodBank: return .bloodBank
        case .icu: return .criticalCare
        case .biomedical: return .engineering
        case .other: return .other
        }
    }
}

// MARK: - Sick call

/// How to call in sick / report illness at this site.
nonisolated struct SickCallInfo: Codable, Hashable {
    var whoToContact: String
    var phone: String
    var noticePeriod: String
    var backupContact: String
    var notes: String
    var policyLink: String

    init(
        whoToContact: String = "",
        phone: String = "",
        noticePeriod: String = "",
        backupContact: String = "",
        notes: String = "",
        policyLink: String = ""
    ) {
        self.whoToContact = whoToContact
        self.phone = phone
        self.noticePeriod = noticePeriod
        self.backupContact = backupContact
        self.notes = notes
        self.policyLink = policyLink
    }

    var hasContent: Bool {
        !whoToContact.isBlank || !phone.isBlank || !noticePeriod.isBlank
            || !backupContact.isBlank || !notes.isBlank || !policyLink.isBlank
    }
}

// MARK: - Policies / workflows

/// A free-form policy or workflow note (e.g. blood ordering, briefing routine).
nonisolated struct PolicyWorkflow: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var link: String

    init(id: UUID = UUID(), title: String = "", body: String = "", link: String = "") {
        self.id = id
        self.title = title
        self.body = body
        self.link = link
    }
}

// MARK: - Shared files

/// A lightweight reference to a shared orientation file. For MVP this stores a
/// name and optional link/note; binary attachments arrive with cloud sync.
nonisolated struct SharedFile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var link: String
    var notes: String

    init(id: UUID = UUID(), name: String = "", link: String = "", notes: String = "") {
        self.id = id
        self.name = name
        self.link = link
        self.notes = notes
    }
}
