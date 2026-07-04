//
//  AnaestheticMachine.swift
//  PreferenceFlow
//
//  Which anaesthetic machine model is in use at a hospital location, plus the
//  actual machine-check documents the user has uploaded for it (e.g. the NZATS
//  check document or the hospital's approved SOP). The app never authors or
//  bundles any check content itself — it stores and displays whatever official
//  PDF the user has legitimate access to and chooses to attach.
//

import Foundation

/// One anaesthetic machine (or fleet of identical machines) at a hospital,
/// with its location and any uploaded check documents.
nonisolated struct AnaestheticMachine: Identifiable, Codable, Hashable {
    var id: UUID
    var model: MachineModel
    /// Used when `model == .other`.
    var customModelName: String
    /// e.g. "Theatres 1-4", "Cardiac Theatre".
    var location: String
    var checkDocuments: [MachineCheckDocument]
    var notes: String

    init(
        id: UUID = UUID(),
        model: MachineModel = .other,
        customModelName: String = "",
        location: String = "",
        checkDocuments: [MachineCheckDocument] = [],
        notes: String = ""
    ) {
        self.id = id
        self.model = model
        self.customModelName = customModelName
        self.location = location
        self.checkDocuments = checkDocuments
        self.notes = notes
    }

    /// Decode-safe against earlier saved data (which carried an app-authored
    /// checklist instead of documents — that legacy field is intentionally
    /// dropped, never displayed).
    private enum CodingKeys: String, CodingKey {
        case id, model, customModelName, location, checkDocuments, notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        model = try c.decodeIfPresent(MachineModel.self, forKey: .model) ?? .other
        customModelName = try c.decodeIfPresent(String.self, forKey: .customModelName) ?? ""
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        checkDocuments = try c.decodeIfPresent([MachineCheckDocument].self, forKey: .checkDocuments) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    var displayName: String {
        model == .other && !customModelName.isEmpty ? customModelName : model.displayName
    }

    /// The caption shown alongside machine check documents.
    static let documentsCaption =
        "Upload the NZATS document or your hospital's approved check procedure. Always follow your machine's official pre-use check and local hospital policy."
}

/// Curated anaesthetic machine models found in most theatre suites.
nonisolated enum MachineModel: String, Codable, CaseIterable, Identifiable {
    case geAisys = "GE Aisys"
    case geAisysCS2 = "GE Aisys CS2"
    case geAvance = "GE Avance"
    case draegerZeus = "Dräger Zeus"
    case draegerZeusIE = "Dräger Zeus IE"
    case draegerPerseus = "Dräger Perseus A500"
    case draegerFabius = "Dräger Fabius"
    case mindrayA7 = "Mindray A7"
    case mindrayA5 = "Mindray A5"
    case other = "Other / not listed"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Manufacturer, used to group machines.
    var manufacturer: String {
        switch self {
        case .geAisys, .geAisysCS2, .geAvance: return "GE"
        case .draegerZeus, .draegerZeusIE, .draegerPerseus, .draegerFabius: return "Dräger"
        case .mindrayA7, .mindrayA5: return "Mindray"
        case .other: return "Other"
        }
    }
}

/// A machine-check document (PDF) the user has uploaded for a machine — e.g.
/// the NZATS check document or a hospital's own SOP. The PDF bytes live as a
/// separate file in the app's documents directory (see `DataStore`); only this
/// lightweight reference is stored in the JSON snapshot so autosaves stay fast.
nonisolated struct MachineCheckDocument: Identifiable, Codable, Hashable {
    var id: UUID
    /// e.g. "NZATS Aisys CS2 Check", "Mercy Local SOP — Mindray A5".
    var title: String
    var source: DocumentSource
    /// Original file name, for display and export.
    var fileName: String
    /// File name of the stored PDF inside the app's MachineDocs directory.
    var storedFileName: String
    var uploadedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        source: DocumentSource,
        fileName: String,
        storedFileName: String,
        uploadedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.fileName = fileName
        self.storedFileName = storedFileName
        self.uploadedAt = uploadedAt
    }
}

/// Where a machine-check document came from.
nonisolated enum DocumentSource: String, Codable, CaseIterable, Identifiable {
    case nzats = "NZATS"
    case manufacturer = "Manufacturer"
    case hospitalSOP = "Hospital SOP"
    case other = "Other"

    var id: String { rawValue }

    /// Badge tint hex for source tags.
    var tintHex: String {
        switch self {
        case .nzats: return "2A8F84"
        case .manufacturer: return "4A90D9"
        case .hospitalSOP: return "F39C12"
        case .other: return "8E8E93"
        }
    }
}

/// Errors thrown while storing machine-check documents.
nonisolated enum MachineDocumentError: LocalizedError {
    case machineNotFound
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .machineNotFound:
            return "This machine could not be found — it may have been deleted."
        case .fileTooLarge:
            return "This PDF is larger than 25 MB. Please compress it or attach a smaller version."
        }
    }
}
