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
    @State private var showingDeleteConfirm = false
    private let isNew: Bool

    init(hospitalID: UUID, item: EquipmentLocation) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: item)
        self.isNew = item.location.isBlank && item.notes.isBlank && item.accessInstructions.isBlank
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    photoPicker
                    itemTypeSection
                    locationSection
                    accessSection
                    if !isNew {
                        deleteButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNew ? "New Location" : "Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
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
            .alert("Delete this item?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) { deleteItem() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes \(draft.title) and its location from this hospital.")
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

    // MARK: - Photo

    @ViewBuilder
    private var photoPicker: some View {
        if let data = draft.photoData, let image = UIImage(data: data) {
            Color(.secondarySystemBackground)
                .frame(height: 200)
                .overlay { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: Theme.cornerLarge))
                .overlay(alignment: .topTrailing) {
                    Menu {
                        if CameraImagePicker.isAvailable {
                            Button { showingCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                        }
                        Button { showingLibrary = true } label: { Label("Choose from Library", systemImage: "photo") }
                        Button(role: .destructive) { draft.photoData = nil; photoItem = nil } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    } label: {
                        Label("Change", systemImage: "pencil")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: .capsule)
                            .foregroundStyle(.primary)
                    }
                    .padding(12)
                }
        } else {
            VStack(spacing: 0) {
                if CameraImagePicker.isAvailable {
                    photoOption(title: "Take photo", icon: "camera.fill") { showingCamera = true }
                    Divider().padding(.leading, 56)
                }
                photoOption(title: "Choose from library", icon: "photo.fill") { showingLibrary = true }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Theme.accent.opacity(0.07))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                    .strokeBorder(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
            }
            .clipShape(.rect(cornerRadius: Theme.cornerLarge))
        }
    }

    private func photoOption(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 42)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.accentDeep)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Item type

    private var itemTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("What is it?", icon: "shippingbox")
            VStack(spacing: 12) {
                Picker(selection: $draft.kind) {
                    ForEach(EquipmentKind.allCases) { Text($0.rawValue).tag($0) }
                } label: {
                    Label("Item", systemImage: draft.symbol)
                }
                if draft.kind == .other {
                    Divider()
                    LabeledField(label: "Name", text: $draft.customLabel, placeholder: "Equipment name", icon: "tag")
                }
            }
            .card()
        }
    }

    // MARK: - Location (prominent)

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Where is it?", icon: "mappin.and.ellipse")
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
                TextField(
                    "e.g. Anaesthetic tech room \u{00B7} top shelf",
                    text: $draft.location,
                    axis: .vertical
                )
                .font(.title3.weight(.semibold))
                .lineLimit(1...3)
            }
            .card()
            Text("Be specific — room, then shelf or trolley. This is what a locum reads to find it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Access & notes

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Access & notes", icon: "key")
            VStack(alignment: .leading, spacing: 14) {
                NotesField(label: "Access instructions", text: $draft.accessInstructions)
                Divider()
                NotesField(label: "Notes", text: $draft.notes)
            }
            .card()
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) { showingDeleteConfirm = true } label: {
            Label("Delete item", systemImage: "trash")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1), in: .rect(cornerRadius: Theme.cornerLarge))
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
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

    private func deleteItem() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        o.equipmentLocations.removeAll { $0.id == draft.id }
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
