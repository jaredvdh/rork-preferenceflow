//
//  DataStore.swift
//  PreferenceFlow
//

import Foundation
import Observation

/// Local-first persistence engine. Holds all hospitals and provider profiles,
/// autosaving to a single JSON file in the app's Documents directory. No accounts,
/// no network — everything lives on device and exports cleanly.
@MainActor
@Observable
final class DataStore {
    private(set) var hospitals: [Hospital] = []
    private(set) var doctors: [Doctor] = []
    private(set) var documents: [KnowledgeDocument] = []

    private let fileName = "preferenceflow_store.json"
    private let documentsDirName = "KnowledgeDocs"

    init() {
        load()
    }

    // MARK: - Persistence

    private nonisolated struct Snapshot: Codable {
        var hospitals: [Hospital]
        var doctors: [Doctor]
        var documents: [KnowledgeDocument]?
    }

    private var storeURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    private func load() {
        let url = storeURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try PreferenceCoding.decoder().decode(Snapshot.self, from: data)
            hospitals = snapshot.hospitals
            doctors = snapshot.doctors
            documents = (snapshot.documents ?? []).sorted { $0.dateAdded > $1.dateAdded }
            migrateLegacyNeuraxial()
        } catch {
            // Corrupt or incompatible file — start clean rather than crashing.
            print("DataStore load failed: \(error.localizedDescription)")
        }
    }

    /// One-time, idempotent migrations applied to profiles after they load.
    /// Currently folds any legacy Combined Spinal Epidural struct data into the
    /// guided workflow system so the workflow is the single source of truth.
    private func migrateLegacyNeuraxial() {
        var changed = false
        for index in doctors.indices {
            if doctors[index].neuraxial.migrateLegacyCSEIfNeeded() { changed = true }
        }
        if changed { save() }
    }

    private func save() {
        let snapshot = Snapshot(hospitals: hospitals, doctors: doctors, documents: documents)
        do {
            let data = try PreferenceCoding.encoder().encode(snapshot)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            print("DataStore save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Hospitals

    func hospital(id: UUID?) -> Hospital? {
        guard let id else { return nil }
        return hospitals.first { $0.id == id }
    }

    func upsert(_ hospital: Hospital) {
        var updated = hospital
        updated.updatedAt = Date()
        if let index = hospitals.firstIndex(where: { $0.id == hospital.id }) {
            hospitals[index] = updated
        } else {
            hospitals.append(updated)
        }
        hospitals.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
    }

    func deleteHospital(_ hospital: Hospital) {
        hospitals.removeAll { $0.id == hospital.id }
        // Detach providers from the deleted hospital but keep them.
        for index in doctors.indices where doctors[index].hospitalId == hospital.id {
            doctors[index].hospitalId = nil
        }
        save()
    }

    func doctorCount(forHospital id: UUID) -> Int {
        doctors.filter { $0.hospitalId == id }.count
    }

    // MARK: - Department standard templates

    /// Department standards for a hospital — stored ones, or the seeded defaults
    /// until a department customises them.
    func templates(forHospital id: UUID?) -> [DepartmentTemplate] {
        guard let id, let hospital = hospital(id: id) else { return DepartmentTemplateLibrary.defaults }
        return hospital.standardTemplates
    }

    /// Resolves a single template within a hospital, falling back to the seeded
    /// defaults so built-in standards always resolve.
    func template(id templateID: UUID?, hospitalID: UUID?) -> DepartmentTemplate? {
        guard let templateID else { return nil }
        if let match = templates(forHospital: hospitalID).first(where: { $0.id == templateID }) {
            return match
        }
        return DepartmentTemplateLibrary.defaults.first { $0.id == templateID }
    }

    /// The department standard a consultant inherits from (if any).
    func template(for doctor: Doctor) -> DepartmentTemplate? {
        template(id: doctor.departmentTemplateId, hospitalID: doctor.hospitalId)
    }

    /// Inserts or updates a department standard, materialising the seeded defaults
    /// into the hospital on first edit so changes persist.
    func upsertTemplate(_ template: DepartmentTemplate, forHospital id: UUID) {
        guard var hospital = hospital(id: id) else { return }
        var list = hospital.standardTemplates
        if let index = list.firstIndex(where: { $0.id == template.id }) {
            list[index] = template
        } else {
            list.append(template)
        }
        hospital.templates = list
        upsert(hospital)
    }

    func deleteTemplate(_ template: DepartmentTemplate, forHospital id: UUID) {
        guard var hospital = hospital(id: id) else { return }
        var list = hospital.standardTemplates
        list.removeAll { $0.id == template.id }
        hospital.templates = list
        upsert(hospital)
    }

    // MARK: - Doctors

    func doctor(id: UUID) -> Doctor? {
        doctors.first { $0.id == id }
    }

    func upsert(_ doctor: Doctor) {
        var updated = doctor
        updated.updatedAt = Date()
        if let index = doctors.firstIndex(where: { $0.id == doctor.id }) {
            // Editing an imported (or, later, synced) profile diverges it from the
            // original received from a colleague — flag it so the technician knows
            // their copy now differs.
            if case .imported = updated.resolvedSource, updated.isLocallyModified != true {
                updated.isLocallyModified = true
            }
            doctors[index] = updated
        } else {
            doctors.append(updated)
        }
        sortDoctors()
        save()
    }

    func deleteDoctor(_ doctor: Doctor) {
        doctors.removeAll { $0.id == doctor.id }
        save()
    }

    private func sortDoctors() {
        doctors.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func doctors(forHospital id: UUID) -> [Doctor] {
        doctors.filter { $0.hospitalId == id }
    }

    // MARK: - Profile migration between hospitals

    /// All profiles that belong to the same clinician as `doctor` (including itself).
    func relatedProfiles(for doctor: Doctor) -> [Doctor] {
        let identity = doctor.clinicianIdentity
        return doctors.filter { $0.clinicianIdentity == identity }
    }

    /// Other hospital-specific versions of the same clinician (excludes `doctor`).
    func otherHospitalVersions(of doctor: Doctor) -> [Doctor] {
        relatedProfiles(for: doctor).filter { $0.id != doctor.id }
    }

    /// Creates a hospital-specific copy of `source` linked to the same clinician.
    /// The original is left untouched. `scope` controls which preference sections
    /// carry over; the new profile keeps identity (name/photo/contact) but is
    /// re-pointed at `hospitalId` and flagged as a hospital-specific version.
    /// Returns the new profile's id.
    @discardableResult
    func copyProfile(_ source: Doctor, toHospital hospitalId: UUID?, scope: MigrationScope) -> UUID {
        // Ensure the source carries a stable shared clinician identity so future
        // copies all link together.
        let identity = source.clinicianIdentity
        if source.clinicianId == nil, let index = doctors.firstIndex(where: { $0.id == source.id }) {
            doctors[index].clinicianId = identity
        }

        // Start from a blank profile that shares identity fields, then layer in
        // whichever preference sections the chosen scope includes.
        var copy = Doctor(
            fullName: source.fullName,
            photoData: source.photoData,
            avatarColorHex: source.avatarColorHex,
            phone: source.phone,
            email: source.email,
            hospitalId: hospitalId,
            department: source.department,
            role: source.role,
            subspecialties: source.subspecialties,
            biography: source.biography,
            personalNotes: source.personalNotes
        )
        copy.clinicianId = identity
        copy.isHospitalSpecific = true

        if scope.contains(.general) {
            copy.general = source.general
        }
        if scope.contains(.airway) {
            copy.airway = source.airway
        }
        if scope.contains(.drugs) {
            copy.adult = source.adult
            copy.paediatric = source.paediatric
            copy.adultDrugs = source.adultDrugs
            copy.paediatricDrugs = source.paediatricDrugs
        }
        if scope.contains(.regionalNeuraxial) {
            copy.regionalBlocks = source.regionalBlocks
            copy.neuraxial = source.neuraxial
        }
        if scope.contains(.procedures) {
            copy.operations = source.operations
            copy.specialtySetups = source.specialtySetups
        }

        doctors.append(copy)
        sortDoctors()
        save()
        return copy.id
    }

    // MARK: - Knowledge documents

    /// Directory holding imported PDF binaries; created lazily.
    private var documentsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(documentsDirName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Resolves the on-disk URL for an imported document's PDF.
    func documentURL(for document: KnowledgeDocument) -> URL {
        documentsDirectory.appendingPathComponent(document.fileName)
    }

    /// Imports a PDF from a (possibly security-scoped) source URL: copies the file
    /// into the app, extracts its text for search, and stores the metadata record.
    @discardableResult
    func importDocument(
        from sourceURL: URL,
        title: String,
        category: DocumentCategory,
        hospitalId: UUID?
    ) throws -> KnowledgeDocument {
        let needsStop = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsStop { sourceURL.stopAccessingSecurityScopedResource() } }

        let id = UUID()
        let fileName = "\(id.uuidString).pdf"
        let destination = documentsDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destination, options: [.atomic])

        let extraction = PDFTextExtractor.extract(from: destination)
        let cleanTitle = title.isBlank
            ? sourceURL.deletingPathExtension().lastPathComponent
            : title
        let document = KnowledgeDocument(
            id: id,
            title: cleanTitle,
            category: category,
            hospitalId: hospitalId,
            fileName: fileName,
            extractedText: extraction.text,
            pageCount: extraction.pageCount
        )
        documents.insert(document, at: 0)
        save()
        return document
    }

    func updateDocument(_ document: KnowledgeDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
        documents.sort { $0.dateAdded > $1.dateAdded }
        save()
    }

    func deleteDocument(_ document: KnowledgeDocument) {
        try? FileManager.default.removeItem(at: documentURL(for: document))
        documents.removeAll { $0.id == document.id }
        save()
    }

    func toggleEmergencyPin(_ document: KnowledgeDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].pinnedToEmergency.toggle()
        save()
    }

    /// Documents pinned to the Emergency Guides hub.
    var pinnedEmergencyDocuments: [KnowledgeDocument] {
        documents.filter { $0.pinnedToEmergency }
    }

    func documents(forHospital id: UUID) -> [KnowledgeDocument] {
        documents.filter { $0.hospitalId == id }
    }

    /// Links a document to a hospital and registers it under that hospital's
    /// orientation shared files so it surfaces in the site guide.
    func addDocumentToOrientation(_ document: KnowledgeDocument, hospitalID: UUID) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].hospitalId = hospitalID
        }
        guard var hospital = hospital(id: hospitalID) else { save(); return }
        var orientation = hospital.orientationOrEmpty
        let reference = SharedFile(
            name: document.displayTitle,
            link: "",
            notes: "Imported \(document.category.rawValue) · in Knowledge library"
        )
        if !orientation.sharedFiles.contains(where: { $0.name == reference.name }) {
            orientation.sharedFiles.append(reference)
        }
        hospital.orientation = orientation
        upsert(hospital)
    }

    // MARK: - Import / Export

    /// Builds a versioned export for the given doctors (or all if nil).
    func makeExport(doctorIDs: [UUID]? = nil, region: TerminologyRegion, sharedBy: String? = nil) -> PreferenceExport {
        let selected: [Doctor]
        if let ids = doctorIDs {
            let set = Set(ids)
            selected = doctors.filter { set.contains($0.id) }
        } else {
            selected = doctors
        }
        let referencedHospitalIDs = Set(selected.compactMap { $0.hospitalId })
        let includedHospitals = hospitals.filter { referencedHospitalIDs.contains($0.id) }
        let sharer = sharedBy?.trimmingCharacters(in: .whitespaces)
        return PreferenceExport(
            sharedBy: (sharer?.isEmpty == false) ? sharer : nil,
            region: region,
            hospitals: includedHospitals,
            doctors: selected
        )
    }

    /// Returns the set of doctor IDs in `export` that already exist locally.
    func existingDoctorIDs(in export: PreferenceExport) -> [Doctor] {
        let localIDs = Set(doctors.map { $0.id })
        return export.doctors.filter { localIDs.contains($0.id) }
    }

    /// Applies an import. `replace` overwrites matching IDs; `saveAsCopy` assigns
    /// fresh IDs to incoming doctors so nothing is overwritten.
    func applyImport(_ export: PreferenceExport, resolution: ImportResolution) {
        guard resolution != .cancel else { return }

        // Merge hospitals by ID (imported context shouldn't clobber edits silently;
        // only add hospitals we don't already have).
        for hospital in export.hospitals where !hospitals.contains(where: { $0.id == hospital.id }) {
            hospitals.append(hospital)
        }

        // Stamp every incoming profile as imported so the recipient sees where it
        // came from. A fresh import starts un-modified; local edits set the flag.
        let importedSource: ProfileSource = .imported(from: export.sharedBy ?? "")

        switch resolution {
        case .replace:
            for incoming in export.doctors {
                var stamped = incoming
                stamped.source = importedSource
                stamped.isLocallyModified = false
                if let index = doctors.firstIndex(where: { $0.id == incoming.id }) {
                    doctors[index] = stamped
                } else {
                    doctors.append(stamped)
                }
            }
        case .saveAsCopy:
            for incoming in export.doctors {
                var stamped = incoming
                stamped.source = importedSource
                stamped.isLocallyModified = false
                if doctors.contains(where: { $0.id == incoming.id }) {
                    stamped.id = UUID()
                    stamped.fullName = incoming.fullName.isEmpty ? "Imported Copy" : "\(incoming.fullName) (Copy)"
                    stamped.createdAt = Date()
                }
                doctors.append(stamped)
            }
        case .cancel:
            break
        }
        hospitals.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sortDoctors()
        save()
    }

    /// Writes an export to a temporary file and returns the URL for sharing.
    func writeExportFile(_ export: PreferenceExport) throws -> URL {
        let data = try PreferenceCoding.encoder().encode(export)
        let safeName: String
        if export.doctors.count == 1, let only = export.doctors.first, !only.fullName.isEmpty {
            safeName = only.fullName.replacingOccurrences(of: " ", with: "_")
        } else {
            safeName = "Profiles_\(export.doctors.count)"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreferenceFlow_\(safeName).json")
        try data.write(to: url, options: [.atomic])
        return url
    }

    /// Parses an export file from disk.
    nonisolated func parseImport(from url: URL) throws -> PreferenceExport {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try PreferenceCoding.decoder().decode(PreferenceExport.self, from: data)
    }
}
