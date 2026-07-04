//
//  AnaestheticMachinesView.swift
//  PreferenceFlow
//
//  Hospital → Anaesthetic Machines: which machine models are in use at this
//  site (e.g. "GE Aisys CS2 · Theatres 1-8") and the actual machine-check
//  documents uploaded for each — the NZATS document, the manufacturer's
//  procedure, or the hospital's own approved SOP. The app never authors its
//  own check content; it stores and displays what the user uploads.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Machines list

struct AnaestheticMachinesTab: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var creating = false
    @State private var editingMachine: AnaestheticMachine?

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let machines = hospital?.orientationOrEmpty.anaestheticMachines ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button { creating = true } label: {
                    Label("Add machine", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
                .buttonStyle(.plain)

                if machines.isEmpty {
                    EmptyStateView(
                        icon: "gauge.with.dots.needle.bottom.50percent",
                        title: "No machines yet",
                        message: "Add the anaesthetic machine models in use at this site, then attach each machine's official check document."
                    )
                } else {
                    ForEach(machines) { machine in
                        NavigationLink(value: machine) {
                            MachineCard(machine: machine)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editingMachine = machine } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { delete(machine) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                MachineDocumentsCaption()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationDestination(for: AnaestheticMachine.self) { machine in
            MachineDetailView(hospitalID: hospitalID, machineID: machine.id)
        }
        .sheet(isPresented: $creating) {
            MachineEditView(
                hospitalID: hospitalID,
                machine: AnaestheticMachine(model: .geAisysCS2),
                isNew: true
            )
        }
        .sheet(item: $editingMachine) { machine in
            MachineEditView(hospitalID: hospitalID, machine: machine, isNew: false)
        }
    }

    private func delete(_ machine: AnaestheticMachine) {
        guard var h = hospital else { return }
        store.removeMachineDocumentFiles(for: machine)
        var o = h.orientationOrEmpty
        o.anaestheticMachines.removeAll { $0.id == machine.id }
        h.orientation = o
        store.upsert(h)
    }
}

/// One machine in the list — model name, location and attached documents.
private struct MachineCard: View {
    let machine: AnaestheticMachine

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 46, height: 46)
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.title3).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(machine.displayName).font(.headline)
                if !machine.location.isBlank {
                    Label(machine.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if machine.model != .other {
                        Text(machine.model.manufacturer)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                    if machine.checkDocuments.isEmpty {
                        Label("No check document", systemImage: "doc.badge.ellipsis")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    } else {
                        Text("^[\(machine.checkDocuments.count) check document](inflect: true)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
    }
}

/// The always-visible guidance caption for machine check documents.
struct MachineDocumentsCaption: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text(AnaestheticMachine.documentsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerMedium))
    }
}

// MARK: - Machine detail (check documents)

/// A machine's attached check documents — upload, view and remove. The empty
/// state deliberately shows no app-authored checklist: the reference is always
/// the official document the user uploads.
struct MachineDetailView: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID
    let machineID: UUID

    @State private var editing = false
    @State private var showingDocumentPicker = false
    @State private var pendingUpload: PendingMachineDocument?
    @State private var errorMessage: String?

    /// Always read the live machine from the store so edits reflect immediately.
    private var machine: AnaestheticMachine? {
        store.hospital(id: hospitalID)?.orientationOrEmpty.anaestheticMachines
            .first { $0.id == machineID }
    }

    var body: some View {
        ScrollView {
            if let machine {
                VStack(alignment: .leading, spacing: 14) {
                    header(machine)
                    documentsSection(machine)
                    if !machine.notes.isBlank {
                        NotesDisplay(title: "Notes", text: machine.notes, icon: "note.text")
                    }
                    MachineDocumentsCaption()
                }
                .padding(16)
            } else {
                VStack(spacing: 12) {
                    Spacer(minLength: 120)
                    Text("Machine not found").foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(machine?.displayName ?? "Machine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .navigationDestination(for: MachineCheckDocument.self) { document in
            MachineDocumentReaderView(document: document)
        }
        .sheet(isPresented: $editing) {
            if let machine {
                MachineEditView(hospitalID: hospitalID, machine: machine, isNew: false)
            }
        }
        .sheet(item: $pendingUpload) { pending in
            MachineDocumentDetailsSheet(pending: pending) { title, source in
                saveDocument(pending: pending, title: title, source: source)
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePickedFile(result)
        }
        .alert("Couldn't Add Document", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sensoryFeedback(.error, trigger: errorMessage) { _, newValue in newValue != nil }
    }

    private func header(_ machine: AnaestheticMachine) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 52, height: 52)
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.title2).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(machine.displayName).font(.title3.weight(.bold))
                HStack(spacing: 8) {
                    if !machine.location.isBlank {
                        Label(machine.location, systemImage: "mappin.and.ellipse")
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    if machine.model != .other {
                        Text(machine.model.manufacturer)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    @ViewBuilder
    private func documentsSection(_ machine: AnaestheticMachine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Check Documents", icon: "doc.text")

            if machine.checkDocuments.isEmpty {
                emptyDocumentsCard
            } else {
                VStack(spacing: 8) {
                    ForEach(machine.checkDocuments) { document in
                        NavigationLink(value: document) {
                            MachineDocumentRow(document: document)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteMachineCheckDocument(document, hospitalID: hospitalID, machineID: machineID)
                            } label: {
                                Label("Remove Document", systemImage: "trash")
                            }
                        }
                    }
                }
                Button { showingDocumentPicker = true } label: {
                    Label("Add another document", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyDocumentsCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 64, height: 64)
                Image(systemName: "doc.badge.plus").font(.system(size: 26)).foregroundStyle(Theme.accent)
            }
            Text("No check document uploaded yet")
                .font(.subheadline.weight(.semibold))
            Text("Add the NZATS document or your hospital's approved check procedure.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingDocumentPicker = true } label: {
                Label("Upload document", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.12), in: .capsule)
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 20)
    }

    // MARK: Upload flow

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Couldn't read this file. Make sure it's a PDF you have access to."
                return
            }
            guard data.count <= DataStore.maxMachineDocumentBytes else {
                errorMessage = MachineDocumentError.fileTooLarge.errorDescription
                return
            }
            pendingUpload = PendingMachineDocument(
                data: data,
                fileName: url.lastPathComponent,
                suggestedTitle: url.deletingPathExtension().lastPathComponent
            )
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func saveDocument(pending: PendingMachineDocument, title: String, source: DocumentSource) {
        do {
            try store.addMachineCheckDocument(
                pdfData: pending.data,
                title: title,
                source: source,
                originalFileName: pending.fileName,
                hospitalID: hospitalID,
                machineID: machineID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A picked-but-not-yet-saved PDF, held while the user confirms title & source.
struct PendingMachineDocument: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
    let suggestedTitle: String
}

/// One attached check document — title, source badge and upload date.
private struct MachineDocumentRow: View {
    let document: MachineCheckDocument

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: document.source.tintHex).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "doc.text")
                    .foregroundStyle(Color(hex: document.source.tintHex))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                HStack(spacing: 8) {
                    Text(document.source.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: document.source.tintHex).opacity(0.14), in: .capsule)
                        .foregroundStyle(Color(hex: document.source.tintHex))
                    Text(document.uploadedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card(padding: 14)
    }
}

// MARK: - Document details (title + source before saving)

/// Confirms the title and source of a just-picked PDF before attaching it.
private struct MachineDocumentDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pending: PendingMachineDocument
    let onSave: (String, DocumentSource) -> Void

    @State private var title: String
    @State private var source: DocumentSource = .nzats

    init(pending: PendingMachineDocument, onSave: @escaping (String, DocumentSource) -> Void) {
        self.pending = pending
        self.onSave = onSave
        _title = State(initialValue: pending.suggestedTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField(label: "Title", text: $title, placeholder: "e.g. NZATS Aisys CS2 Check", icon: "textformat")
                    Picker(selection: $source) {
                        ForEach(DocumentSource.allCases) { Text($0.rawValue).tag($0) }
                    } label: {
                        Label("Source", systemImage: "building.columns")
                    }
                } header: {
                    Text("Document")
                } footer: {
                    Text("File: \(pending.fileName)")
                }
            }
            .navigationTitle("Add Check Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, source)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isBlank)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Document reader

/// In-app PDF viewer for an uploaded machine-check document.
struct MachineDocumentReaderView: View {
    @Environment(DataStore.self) private var store
    let document: MachineCheckDocument

    var body: some View {
        Group {
            if store.machineDocumentFileExists(document) {
                PDFKitView(url: store.machineDocumentURL(for: document))
                    .ignoresSafeArea(edges: .bottom)
            } else {
                EmptyStateView(
                    icon: "doc",
                    title: "Document unavailable",
                    message: "This file may have been removed from the device."
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.machineDocumentFileExists(document) {
                    ShareLink(item: store.machineDocumentURL(for: document)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Machine editor

struct MachineEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: AnaestheticMachine
    private let isNew: Bool

    init(hospitalID: UUID, machine: AnaestheticMachine, isNew: Bool) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: machine)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Machine") {
                    Picker(selection: $draft.model) {
                        ForEach(MachineModel.allCases) { Text($0.displayName).tag($0) }
                    } label: {
                        Label("Model", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    }
                    if draft.model == .other {
                        LabeledField(label: "Model name", text: $draft.customModelName, placeholder: "Machine model", icon: "tag")
                    }
                    LabeledField(label: "Location", text: $draft.location, placeholder: "e.g. Theatres 1-4", icon: "mappin.and.ellipse")
                }

                Section {
                    NotesField(label: "Notes (optional)", text: $draft.notes)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Check documents are attached from the machine's page — upload the NZATS document or your hospital's approved procedure there.")
                }

                if !isNew {
                    Section {
                        Button("Delete Machine", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New Machine" : "Edit Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(draft.model == .other && draft.customModelName.isBlank)
                }
            }
        }
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        if let index = o.anaestheticMachines.firstIndex(where: { $0.id == draft.id }) {
            o.anaestheticMachines[index] = draft
        } else {
            o.anaestheticMachines.append(draft)
        }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }

    private func delete() {
        guard var h = store.hospital(id: hospitalID) else { return }
        store.removeMachineDocumentFiles(for: draft)
        var o = h.orientationOrEmpty
        o.anaestheticMachines.removeAll { $0.id == draft.id }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }
}
