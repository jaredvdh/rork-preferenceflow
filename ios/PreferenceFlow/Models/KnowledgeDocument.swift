//
//  KnowledgeDocument.swift
//  PreferenceFlow
//

import Foundation

/// How an imported reference document is filed in the library. Mirrors the
/// built-in knowledge groupings but adds site/department/personal buckets so PDFs
/// slot alongside curated articles.
nonisolated enum DocumentCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case hospitalGuide = "Hospital guide"
    case emergency = "Emergency guide"
    case airway = "Airway"
    case regional = "Regional anaesthesia"
    case ventilation = "Mechanical ventilation"
    case departmentPolicy = "Department policy"
    case userNotes = "User notes"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .hospitalGuide: return "building.2.fill"
        case .emergency: return "cross.case.fill"
        case .airway: return "lungs.fill"
        case .regional: return "scope"
        case .ventilation: return "waveform.path"
        case .departmentPolicy: return "doc.text.fill"
        case .userNotes: return "note.text"
        }
    }

    var tint: String {
        switch self {
        case .hospitalGuide: return "2E7DD1"
        case .emergency: return "D1576E"
        case .airway: return "2E7DD1"
        case .regional: return "0E9F8E"
        case .ventilation: return "7A5CD6"
        case .departmentPolicy: return "E0883B"
        case .userNotes: return "47808F"
        }
    }

    var blurb: String {
        switch self {
        case .hospitalGuide: return "Site orientation & local guides"
        case .emergency: return "Crisis cards & action plans"
        case .airway: return "Airway management references"
        case .regional: return "Block techniques & guides"
        case .ventilation: return "Ventilation references"
        case .departmentPolicy: return "Policies & SOPs"
        case .userNotes: return "Your own imported notes"
        }
    }
}

/// An imported PDF reference document. The binary lives in the app's Documents
/// directory (under `KnowledgeDocs/`); this record stores its metadata plus the
/// extracted plain text so it can be searched without re-opening the file.
nonisolated struct KnowledgeDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var category: DocumentCategory
    /// Optional hospital association.
    var hospitalId: UUID?
    var dateAdded: Date
    /// Filename within the `KnowledgeDocs/` directory (not a full path, so it stays
    /// valid across reinstalls / container moves).
    var fileName: String
    /// Plain text extracted from the PDF at import time, used for in-app search.
    var extractedText: String
    var pageCount: Int
    /// Pinned to the Emergency Guides hub for instant access.
    var pinnedToEmergency: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        category: DocumentCategory = .userNotes,
        hospitalId: UUID? = nil,
        dateAdded: Date = Date(),
        fileName: String,
        extractedText: String = "",
        pageCount: Int = 0,
        pinnedToEmergency: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.hospitalId = hospitalId
        self.dateAdded = dateAdded
        self.fileName = fileName
        self.extractedText = extractedText
        self.pageCount = pageCount
        self.pinnedToEmergency = pinnedToEmergency
    }

    var displayTitle: String {
        title.isBlank ? "Untitled document" : title
    }

    /// Whether the extracted text contains the query (case/diacritic-insensitive).
    func textMatches(_ query: String) -> Bool {
        guard !extractedText.isEmpty else { return false }
        return extractedText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
