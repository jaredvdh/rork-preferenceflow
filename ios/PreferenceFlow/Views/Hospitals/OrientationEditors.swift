//
//  OrientationEditors.swift
//  PreferenceFlow
//

import SwiftUI
import PhotosUI

// MARK: - Equipment location editor

struct EquipmentLocationEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: EquipmentLocation
    @State private var photoItem: PhotosPickerItem?
    @State private var showingSourceChoice = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    private let isNew: Bool

    init(hospitalID: UUID, item: EquipmentLocation) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: item)
        self.isNew = item.location.isBlank && item.notes.isBlank && item.accessInstructions.isBlank
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Equipment") {
                    Picker(selection: $draft.kind) {
                        ForEach(EquipmentKind.allCases) { Text($0.rawValue).tag($0) }
                    } label: {
                        Label("Item", systemImage: draft.symbol)
                    }
                    if draft.kind == .other {
                        LabeledField(label: "Name", text: $draft.customLabel, placeholder: "Equipment name", icon: "tag")
                    }
                    LabeledField(label: "Location", text: $draft.location, placeholder: "Theatre corridor by OR 4", icon: "mappin.and.ellipse")
                }
                Section("Access") {
                    NotesField(label: "Access instructions", text: $draft.accessInstructions)
                    NotesField(label: "Notes", text: $draft.notes)
                }
                Section("Photo") {
                    photoRow
                }
            }
            .navigationTitle(isNew ? "New Location" : "Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.kind == .other && draft.customLabel.isBlank)
                }
            }
            .onChange(of: photoItem) { _, item in Task { await loadPhoto(item) } }
            .confirmationDialog("Add Photo", isPresented: $showingSourceChoice, titleVisibility: .visible) {
                if CameraImagePicker.isAvailable {
                    Button("Take Photo") { showingCamera = true }
                }
                Button("Choose from Library") { showingLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showingLibrary, selection: $photoItem, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraImagePicker { image in
                    if let resized = image?.resizedJPEG(maxDimension: 900, quality: 0.8) {
                        draft.photoData = resized
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var photoRow: some View {
        if let data = draft.photoData, let image = UIImage(data: data) {
            VStack(spacing: 10) {
                Color(.secondarySystemBackground)
                    .frame(height: 180)
                    .overlay { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false) }
                    .clipShape(.rect(cornerRadius: Theme.cornerMedium))
                HStack {
                    Button {
                        showingSourceChoice = true
                    } label: {
                        Text("Change Photo").font(.subheadline.weight(.medium)).foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Button("Remove", role: .destructive) { draft.photoData = nil; photoItem = nil }
                        .font(.subheadline)
                }
            }
            .listRowBackground(Color.clear)
        } else {
            Button {
                showingSourceChoice = true
            } label: {
                Label("Take or Choose Photo", systemImage: "camera.badge.plus").foregroundStyle(Theme.accent)
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let resized = image.resizedJPEG(maxDimension: 900, quality: 0.8) {
            draft.photoData = resized
        }
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        if let index = o.equipmentLocations.firstIndex(where: { $0.id == draft.id }) {
            o.equipmentLocations[index] = draft
        } else {
            o.equipmentLocations.append(draft)
        }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }
}

// MARK: - Contact editor

struct ContactEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: HospitalContact
    private let isNew: Bool

    init(hospitalID: UUID, contact: HospitalContact) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: contact)
        self.isNew = contact.name.isBlank && contact.phone.isBlank
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Role") {
                    Picker(selection: $draft.role) {
                        ForEach(ContactRole.allCases) { Text($0.rawValue).tag($0) }
                    } label: {
                        Label("Role", systemImage: draft.symbol)
                    }
                    if draft.role == .other {
                        LabeledField(label: "Role name", text: $draft.customRole, placeholder: "Custom role", icon: "tag")
                    }
                    LabeledField(label: "Name", text: $draft.name, placeholder: "Optional", icon: "person")
                }
                Section("Reach") {
                    LabeledField(label: "Phone", text: $draft.phone, placeholder: "Optional", icon: "phone")
                        .keyboardType(.phonePad)
                    LabeledField(label: "Extension", text: $draft.extensionNumber, placeholder: "Optional", icon: "phone.connection")
                        .keyboardType(.numbersAndPunctuation)
                    LabeledField(label: "Pager", text: $draft.pager, placeholder: "Optional", icon: "dot.radiowaves.left.and.right")
                    LabeledField(label: "Email", text: $draft.email, placeholder: "Optional", icon: "envelope")
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    NotesField(label: "Notes", text: $draft.notes)
                }
            }
            .navigationTitle(isNew ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.role == .other && draft.customRole.isBlank)
                }
            }
        }
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        if let index = o.contacts.firstIndex(where: { $0.id == draft.id }) {
            o.contacts[index] = draft
        } else {
            o.contacts.append(draft)
        }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }
}

// MARK: - Sick call editor

struct SickCallEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: SickCallInfo

    init(hospitalID: UUID, info: SickCallInfo) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: info)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reporting illness") {
                    LabeledField(label: "Who to contact", text: $draft.whoToContact, placeholder: "Charge technician", icon: "person")
                    LabeledField(label: "Phone", text: $draft.phone, placeholder: "Sick line", icon: "phone")
                        .keyboardType(.phonePad)
                    LabeledField(label: "Notice period", text: $draft.noticePeriod, placeholder: "e.g. 2 hours before shift", icon: "clock")
                    LabeledField(label: "Backup contact", text: $draft.backupContact, placeholder: "Optional", icon: "person.2")
                }
                Section("More") {
                    NotesField(label: "Notes", text: $draft.notes)
                    LabeledField(label: "Policy link", text: $draft.policyLink, placeholder: "Optional URL", icon: "link")
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Sick Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        o.sickCall = draft
        h.orientation = o
        store.upsert(h)
        dismiss()
    }
}

// MARK: - Policy editor

struct PolicyEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: PolicyWorkflow
    private let isNew: Bool

    init(hospitalID: UUID, policy: PolicyWorkflow) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: policy)
        self.isNew = policy.title.isBlank && policy.body.isBlank
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Policy / Workflow") {
                    LabeledField(label: "Title", text: $draft.title, placeholder: "Blood ordering", icon: "doc.text")
                    NotesField(label: "Details", text: $draft.body, minHeight: 140)
                    LabeledField(label: "Link", text: $draft.link, placeholder: "Optional URL", icon: "link")
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(isNew ? "New Policy" : "Edit Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(draft.title.isBlank)
                }
            }
        }
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        if let index = o.policies.firstIndex(where: { $0.id == draft.id }) {
            o.policies[index] = draft
        } else {
            o.policies.append(draft)
        }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }
}

// MARK: - Shared file editor

struct SharedFileEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: SharedFile
    private let isNew: Bool

    init(hospitalID: UUID, file: SharedFile) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: file)
        self.isNew = file.name.isBlank && file.link.isBlank
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shared file") {
                    LabeledField(label: "Name", text: $draft.name, placeholder: "Orientation pack", icon: "doc")
                    LabeledField(label: "Link", text: $draft.link, placeholder: "Optional URL", icon: "link")
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    NotesField(label: "Notes", text: $draft.notes)
                }
            }
            .navigationTitle(isNew ? "New File" : "Edit File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(draft.name.isBlank)
                }
            }
        }
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        if let index = o.sharedFiles.firstIndex(where: { $0.id == draft.id }) {
            o.sharedFiles[index] = draft
        } else {
            o.sharedFiles.append(draft)
        }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }
}
