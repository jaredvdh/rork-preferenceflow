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
    /// Local change history for profile edits — newest entries appended last;
    /// capped per doctor. Purely on-device, like everything else here.
    private(set) var changeRecords: [ProfileChangeRecord] = []

    private let fileName = "preferenceflow_store.json"
    private let documentsDirName = "KnowledgeDocs"
    private let machineDocsDirName = "MachineDocs"

    init() {
        load()
    }

    // MARK: - Persistence

    private nonisolated struct Snapshot: Codable {
        var hospitals: [Hospital]
        var doctors: [Doctor]
        var documents: [KnowledgeDocument]?
        var changeRecords: [ProfileChangeRecord]?
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
            changeRecords = snapshot.changeRecords ?? []
            migrateLegacyNeuraxial()
        } catch {
            // Corrupt or incompatible file — start clean rather than crashing.
            print("DataStore load failed: \(error.localizedDescription)")
        }
    }

    /// One-time, idempotent migrations applied to profiles after they load.
    /// Folds any legacy Combined Spinal Epidural struct data into the guided
    /// workflow system, and moves procedural workflows (Arterial Line, CVC)
    /// out of neuraxial storage into their own `procedural` storage.
    private func migrateLegacyNeuraxial() {
        var changed = false
        for index in doctors.indices {
            if doctors[index].neuraxial.migrateLegacyCSEIfNeeded() { changed = true }
            if doctors[index].migrateProceduralStorageIfNeeded() { changed = true }
        }
        if changed { save() }
    }

    private func save() {
        let snapshot = Snapshot(hospitals: hospitals, doctors: doctors, documents: documents, changeRecords: changeRecords)
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
        // Clean up any machine-check PDFs stored on disk for this hospital.
        for machine in hospital.orientationOrEmpty.anaestheticMachines {
            removeMachineDocumentFiles(for: machine)
        }
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
            recordChange(from: doctors[index], to: updated)
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
        changeRecords.removeAll { $0.doctorID == doctor.id }
        save()
    }

    // MARK: - Profile change history

    /// The most recent changes kept per profile — oldest pruned first, mirroring
    /// the iCloud backup retention style.
    private static let maxChangeRecordsPerDoctor = 20

    /// A one-shot summary override for the next recorded change — set by
    /// `revertDoctor` so the revert flows through the exact same record pipeline
    /// as any other edit, just with a clearer label.
    private var pendingChangeSummary: String?

    /// A doctor's change history, newest first.
    func changeRecords(for doctorID: UUID) -> [ProfileChangeRecord] {
        changeRecords
            .filter { $0.doctorID == doctorID }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Restores a profile to how it looked before `record`'s edit. The restore
    /// goes through `upsert`, which itself records a new history entry — nothing
    /// is ever removed from history by reverting.
    func revertDoctor(_ doctorID: UUID, to record: ProfileChangeRecord) {
        guard record.doctorID == doctorID,
              var restored = try? PreferenceCoding.decoder().decode(Doctor.self, from: record.snapshotBefore) else {
            return
        }
        restored.id = doctorID
        pendingChangeSummary = "Reverted to previous version"
        upsert(restored)
    }

    /// Diffs the old and new profile section by section and appends a history
    /// entry when anything actually changed. Skips silently when nothing did.
    private func recordChange(from old: Doctor, to new: Doctor) {
        // Neutralise the fields upsert itself stamps so an untouched save (or a
        // no-op revert) never generates a phantom history entry.
        var comparable = new
        comparable.updatedAt = old.updatedAt
        comparable.isLocallyModified = old.isLocallyModified
        guard comparable != old else {
            pendingChangeSummary = nil
            return
        }

        let sections = changedSections(from: old, to: new)
        let summary: String
        if let override = pendingChangeSummary {
            summary = override
        } else if sections.isEmpty {
            summary = "Updated profile details"
        } else {
            summary = "Updated " + sections.joined(separator: ", ")
        }
        pendingChangeSummary = nil

        guard let snapshot = try? PreferenceCoding.encoder().encode(old) else { return }
        let editor = AppSettings.currentEditor()
        changeRecords.append(ProfileChangeRecord(
            doctorID: old.id,
            editorName: editor.name,
            editorRole: editor.role,
            summary: summary,
            snapshotBefore: snapshot
        ))
        pruneChangeRecords(for: old.id)
    }

    /// Plain-English names of the preference sections that differ between two
    /// versions of a profile. Surgical preferences diff at the sub-section level
    /// so summaries read like the edit tabs ("Trays & Instruments", …).
    private func changedSections(from old: Doctor, to new: Doctor) -> [String] {
        var changed: [String] = []
        if old.general != new.general { changed.append("General") }
        if old.airway != new.airway { changed.append("Airway") }
        if old.adultDrugs != new.adultDrugs { changed.append("Drugs & Fluids") }
        if old.monitoring != new.monitoring { changed.append("Monitoring & Lines") }
        if old.regionalBlocks != new.regionalBlocks { changed.append("Regional Blocks") }
        if old.neuraxial != new.neuraxial { changed.append("Neuraxial") }
        if old.procedural != new.procedural { changed.append("Procedural Lines") }

        let oldSurgical = old.surgicalPreferences
        let newSurgical = new.surgicalPreferences
        if oldSurgical.gloves != newSurgical.gloves { changed.append("Gloves & Personal") }
        if oldSurgical.trays != newSurgical.trays { changed.append("Trays & Instruments") }
        if oldSurgical.sutures != newSurgical.sutures { changed.append("Sutures & Closure") }
        if oldSurgical.energy != newSurgical.energy { changed.append("Energy & Equipment") }
        if oldSurgical.positioning != newSurgical.positioning { changed.append("Positioning & Prep") }

        if oldSurgical.procedures != newSurgical.procedures || old.operations != new.operations {
            changed.append("Operation Cards")
        }
        if old.specialtySetups != new.specialtySetups { changed.append("Specialty Setups") }
        return changed
    }

    /// Keeps the newest `maxChangeRecordsPerDoctor` entries for a profile and
    /// removes the rest, oldest first.
    private func pruneChangeRecords(for doctorID: UUID) {
        let forDoctor = changeRecords
            .filter { $0.doctorID == doctorID }
            .sorted { $0.timestamp > $1.timestamp }
        guard forDoctor.count > Self.maxChangeRecordsPerDoctor else { return }
        let staleIDs = Set(forDoctor.dropFirst(Self.maxChangeRecordsPerDoctor).map(\.id))
        changeRecords.removeAll { staleIDs.contains($0.id) }
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
            // Procedural lines (Arterial Line, CVC) travel with this scope —
            // they historically lived inside neuraxial storage.
            copy.procedural = source.procedural
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

    // MARK: - Machine check documents

    /// Maximum accepted machine-check PDF size (25 MB).
    static let maxMachineDocumentBytes = 25 * 1024 * 1024

    /// Directory holding uploaded machine-check PDF binaries; created lazily.
    /// Only lightweight references live in the JSON snapshot — the PDF bytes
    /// stay out of the autosave path so saves remain fast.
    private var machineDocsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(machineDocsDirName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Resolves the on-disk URL for a machine-check document's PDF.
    func machineDocumentURL(for document: MachineCheckDocument) -> URL {
        machineDocsDirectory.appendingPathComponent(document.storedFileName)
    }

    /// Whether the PDF backing this document still exists on disk.
    func machineDocumentFileExists(_ document: MachineCheckDocument) -> Bool {
        FileManager.default.fileExists(atPath: machineDocumentURL(for: document).path)
    }

    /// Writes the uploaded PDF to disk and attaches its reference record to the
    /// machine. Throws if the machine no longer exists or the file is oversized.
    @discardableResult
    func addMachineCheckDocument(
        pdfData: Data,
        title: String,
        source: DocumentSource,
        originalFileName: String,
        hospitalID: UUID,
        machineID: UUID
    ) throws -> MachineCheckDocument {
        guard pdfData.count <= Self.maxMachineDocumentBytes else {
            throw MachineDocumentError.fileTooLarge
        }
        guard var hospital = hospital(id: hospitalID) else {
            throw MachineDocumentError.machineNotFound
        }
        var orientation = hospital.orientationOrEmpty
        guard let index = orientation.anaestheticMachines.firstIndex(where: { $0.id == machineID }) else {
            throw MachineDocumentError.machineNotFound
        }

        let id = UUID()
        let storedFileName = "\(id.uuidString).pdf"
        try pdfData.write(to: machineDocsDirectory.appendingPathComponent(storedFileName), options: [.atomic])

        let cleanTitle = title.isBlank
            ? (originalFileName as NSString).deletingPathExtension
            : title
        let document = MachineCheckDocument(
            id: id,
            title: cleanTitle,
            source: source,
            fileName: originalFileName,
            storedFileName: storedFileName
        )
        orientation.anaestheticMachines[index].checkDocuments.append(document)
        hospital.orientation = orientation
        upsert(hospital)
        return document
    }

    /// Removes a machine-check document — both its record and its on-disk PDF.
    func deleteMachineCheckDocument(_ document: MachineCheckDocument, hospitalID: UUID, machineID: UUID) {
        try? FileManager.default.removeItem(at: machineDocumentURL(for: document))
        guard var hospital = hospital(id: hospitalID) else { return }
        var orientation = hospital.orientationOrEmpty
        guard let index = orientation.anaestheticMachines.firstIndex(where: { $0.id == machineID }) else { return }
        orientation.anaestheticMachines[index].checkDocuments.removeAll { $0.id == document.id }
        hospital.orientation = orientation
        upsert(hospital)
    }

    /// Removes the on-disk PDFs backing a machine's documents.
    ///
    /// IMPORTANT: This must be called before ANY code path that removes a machine
    /// from a hospital's `anaestheticMachines` array — not just `deleteHospital`.
    /// Individual-machine deletion (e.g. the context-menu delete and the editor's
    /// Delete Machine button in `AnaestheticMachinesView`) must call this first,
    /// otherwise the machine's PDF files are orphaned on disk with no remaining
    /// record pointing at them. If you add a new deletion path, call this before
    /// mutating the array.
    func removeMachineDocumentFiles(for machine: AnaestheticMachine) {
        for document in machine.checkDocuments {
            try? FileManager.default.removeItem(at: machineDocumentURL(for: document))
        }
    }

    // MARK: - Demo Mode

    /// Whether any demo record currently exists in the store, matched definitively
    /// by demo id. Drives the Settings toggle so it reflects reality, not just the
    /// persisted flag.
    var hasDemoData: Bool {
        hospitals.contains { DemoData.allDemoHospitalIDs.contains($0.id) }
            || doctors.contains { DemoData.allDemoDoctorIDs.contains($0.id) }
    }

    /// Whether any installed demo record has been edited by the user — used to warn
    /// before removal would discard those explorations.
    var hasEditedDemoData: Bool {
        doctors.contains { DemoData.isEditedDemoDoctor($0) }
            || hospitals.contains { DemoData.isEditedDemoHospital($0) }
    }

    /// Installs the demo hospitals and consultants. Idempotent — a record is only
    /// added when its deterministic id isn't already present, so installing twice
    /// never duplicates and never overwrites a demo record the user has since
    /// edited. Real user data is never touched.
    func installDemoData() {
        for hospital in DemoData.hospitals where !hospitals.contains(where: { $0.id == hospital.id }) {
            hospitals.append(hospital)
        }
        for doctor in DemoData.doctors where !doctors.contains(where: { $0.id == doctor.id }) {
            doctors.append(doctor)
        }
        hospitals.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sortDoctors()
        save()
    }

    /// Removes demo records, matching **only** on the known demo id sets — never on
    /// the fallible `isDemoData` flag — so a record whose id isn't a demo id can
    /// never be deleted, whatever its field values. When `preserveEdited` is true,
    /// demo records the user has explored/edited are kept.
    func removeDemoData(preserveEdited: Bool = false) {
        let hospitalIDs = DemoData.allDemoHospitalIDs
        let doctorIDs = DemoData.allDemoDoctorIDs

        // Snapshot the records that must survive untouched (everything outside the
        // demo id sets) so we can assert we never harmed real data.
        let protectedDoctorIDs = doctors.map(\.id).filter { !doctorIDs.contains($0) }
        let protectedHospitalIDs = hospitals.map(\.id).filter { !hospitalIDs.contains($0) }

        if preserveEdited {
            doctors.removeAll { doctorIDs.contains($0.id) && !DemoData.isEditedDemoDoctor($0) }
            hospitals.removeAll { hospitalIDs.contains($0.id) && !DemoData.isEditedDemoHospital($0) }
        } else {
            doctors.removeAll { doctorIDs.contains($0.id) }
            hospitals.removeAll { hospitalIDs.contains($0.id) }
        }

        // Belt-and-suspenders: prove no real record was removed before persisting.
        let survivingDoctorIDs = Set(doctors.map(\.id))
        let survivingHospitalIDs = Set(hospitals.map(\.id))
        assert(protectedDoctorIDs.allSatisfy { survivingDoctorIDs.contains($0) },
               "Demo removal must never delete a non-demo consultant")
        assert(protectedHospitalIDs.allSatisfy { survivingHospitalIDs.contains($0) },
               "Demo removal must never delete a non-demo hospital")

        save()
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

    /// Local profiles whose (normalised) name matches an incoming profile but whose
    /// id differs — likely the same consultant entered independently by another
    /// technician. Excludes exact-id matches (handled separately) to avoid
    /// double-prompting.
    func fuzzyNameMatches(in export: PreferenceExport) -> [Doctor] {
        let incomingIDs = Set(export.doctors.map { $0.id })
        let incomingNames = Set(
            export.doctors
                .map { Doctor.normalizedName($0.fullName) }
                .filter { !$0.isEmpty }
        )
        guard !incomingNames.isEmpty else { return [] }
        return doctors.filter { existing in
            guard !incomingIDs.contains(existing.id) else { return false }
            let key = Doctor.normalizedName(existing.fullName)
            return !key.isEmpty && incomingNames.contains(key)
        }
    }

    /// Applies an import where incoming profiles replace existing local profiles
    /// matched by name (not id). The existing local id is preserved so favourites,
    /// recents and deep links keep working; unmatched profiles are appended.
    func applyImportReplacingNameMatches(_ export: PreferenceExport) {
        let importedSource: ProfileSource = .imported(from: export.sharedBy ?? "")
        for hospital in export.hospitals where !hospitals.contains(where: { $0.id == hospital.id }) {
            hospitals.append(hospital)
        }
        for incoming in export.doctors {
            var stamped = incoming
            stamped.source = importedSource
            stamped.isLocallyModified = false
            let key = Doctor.normalizedName(incoming.fullName)
            if !key.isEmpty,
               let index = doctors.firstIndex(where: { Doctor.normalizedName($0.fullName) == key }) {
                stamped.id = doctors[index].id
                doctors[index] = stamped
            } else if let index = doctors.firstIndex(where: { $0.id == incoming.id }) {
                doctors[index] = stamped
            } else {
                doctors.append(stamped)
            }
        }
        hospitals.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sortDoctors()
        save()
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

    /// Restores a full iCloud backup. Unlike a peer-to-peer import, restored
    /// profiles keep their original source and modification flags — this is the
    /// user's own data coming home, not a colleague's share. Matching IDs are
    /// overwritten; anything not in the backup is left untouched.
    func restoreBackup(_ export: PreferenceExport) {
        for hospital in export.hospitals {
            if let index = hospitals.firstIndex(where: { $0.id == hospital.id }) {
                hospitals[index] = hospital
            } else {
                hospitals.append(hospital)
            }
        }
        for incoming in export.doctors {
            if let index = doctors.firstIndex(where: { $0.id == incoming.id }) {
                doctors[index] = incoming
            } else {
                doctors.append(incoming)
            }
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
