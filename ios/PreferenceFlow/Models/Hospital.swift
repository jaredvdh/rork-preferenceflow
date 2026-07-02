//
//  Hospital.swift
//  PreferenceFlow
//

import Foundation

/// A hospital / facility where providers work. Designed to be extended later with
/// department accounts and team ownership without breaking the stored shape.
nonisolated struct Hospital: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var city: String
    var country: String
    var department: String
    var notes: String
    /// Orientation guide (equipment locations, contacts, sick-call, policies).
    /// Optional for backward-compatible decoding of older stored hospitals.
    var orientation: HospitalOrientation?
    /// Editable department standard templates consultants inherit from. Optional
    /// for backward-compatible decoding; falls back to the seeded defaults.
    var templates: [DepartmentTemplate]?
    /// True for sample records installed by Demo Mode. Optional for
    /// backward-compatible decoding of records saved before Demo Mode existed.
    var isDemoData: Bool?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        city: String = "",
        country: String = "",
        department: String = "",
        notes: String = "",
        orientation: HospitalOrientation? = nil,
        templates: [DepartmentTemplate]? = nil,
        isDemoData: Bool? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.country = country
        self.department = department
        self.notes = notes
        self.orientation = orientation
        self.templates = templates
        self.isDemoData = isDemoData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Whether this is a Demo Mode sample record.
    var isDemo: Bool { isDemoData ?? false }

    /// Non-optional accessor; returns an empty orientation when none is stored.
    var orientationOrEmpty: HospitalOrientation {
        orientation ?? HospitalOrientation()
    }

    /// Department standards for this hospital, falling back to seeded defaults
    /// until a department customises them.
    var standardTemplates: [DepartmentTemplate] {
        if let templates, !templates.isEmpty { return templates }
        return DepartmentTemplateLibrary.defaults
    }

    /// Compact location summary for list rows.
    var locationLine: String {
        [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
