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
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var showingDeleteConfirm = false
    /// Which spot is currently picking a photo.
    @State private var activeSpotID: UUID?
    private let isNew: Bool

    init(hospitalID: UUID, item: EquipmentLocation) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: item)
        self.isNew = !item.spots.contains { $0.hasContent } && item.notes.isBlank
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    itemTypeSection
                    locationsSection
                    notesSection
                    if !isNew {
                        deleteButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNew ? "New Equipment" : "Edit Equipment")
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
            .alert("Delete this item?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) { deleteItem() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes \(draft.title) and all its locations from this hospital.")
            }
            .photosPicker(isPresented: $showingLibrary, selection: $photoItem, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraImagePicker { image in
                    if let resized = image?.resizedJPEG(maxDimension: 900, quality: 0.8) {
                        setPhoto(resized)
                    }
                }
                .ignoresSafeArea()
            }
        }
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

    // MARK: - Locations (one or more)

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Where is it?", icon: "mappin.and.ellipse")
                Spacer()
                if draft.spots.count > 1 {
                    Text("\(draft.spots.count) locations")
                        .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            ForEach($draft.spots) { $spot in
                locationCard(spot: $spot)
            }
            addLocationButton
            if draft.isEmergency {
                Label("Emergency item — add every place it can be found so staff reach the nearest one.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
            } else {
                Text("Add each place this item is kept. Be specific — room, then shelf or trolley.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func locationCard(spot: Binding<EquipmentSpot>) -> some View {
        let index = draft.spots.firstIndex(where: { $0.id == spot.wrappedValue.id }) ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Location \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentDeep)
                Spacer()
                if draft.spots.count > 1 {
                    Button(role: .destructive) {
                        draft.spots.removeAll { $0.id == spot.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash").font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            spotPhoto(spot: spot)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3).foregroundStyle(Theme.accent).padding(.top, 2)
                TextField(
                    "e.g. Theatre corridor \u{00B7} by OR 1",
                    text: spot.location,
                    axis: .vertical
                )
                .font(.title3.weight(.semibold))
                .lineLimit(1...3)
            }
            Divider()
            NotesField(label: "Access instructions (optional)", text: spot.accessInstructions, minHeight: 60)
        }
        .card()
    }

    private var addLocationButton: some View {
        Button {
            draft.spots.append(EquipmentSpot())
        } label: {
            Label("Add another location", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Per-spot photo

    @ViewBuilder
    private func spotPhoto(spot: Binding<EquipmentSpot>) -> some View {
        if let data = spot.wrappedValue.photoData, let image = UIImage(data: data) {
            Color(.secondarySystemBackground)
                .frame(height: 160)
                .overlay { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: Theme.cornerMedium))
                .overlay(alignment: .topTrailing) {
                    Menu {
                        if CameraImagePicker.isAvailable {
                            Button { activeSpotID = spot.wrappedValue.id; showingCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                        }
                        Button { activeSpotID = spot.wrappedValue.id; showingLibrary = true } label: { Label("Choose from Library", systemImage: "photo") }
                        Button(role: .destructive) { spot.wrappedValue.photoData = nil } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    } label: {
                        Label("Change", systemImage: "pencil")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: .capsule)
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                }
        } else {
            HStack(spacing: 0) {
                if CameraImagePicker.isAvailable {
                    photoOption(title: "Take photo", icon: "camera.fill") { activeSpotID = spot.wrappedValue.id; showingCamera = true }
                    Divider()
                }
                photoOption(title: "Library", icon: "photo.fill") { activeSpotID = spot.wrappedValue.id; showingLibrary = true }
            }
            .frame(height: 88)
            .frame(maxWidth: .infinity)
            .background(Theme.accent.opacity(0.07))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .strokeBorder(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .clipShape(.rect(cornerRadius: Theme.cornerMedium))
        }
    }

    private func photoOption(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.accentDeep)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes (item-wide)

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Notes", icon: "note.text")
            NotesField(label: "Notes for this item (optional)", text: $draft.notes)
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

    private func setPhoto(_ data: Data) {
        guard let spotID = activeSpotID,
              let index = draft.spots.firstIndex(where: { $0.id == spotID }) else { return }
        draft.spots[index].photoData = data
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let resized = image.resizedJPEG(maxDimension: 900, quality: 0.8) {
            setPhoto(resized)
        }
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        // Keep at least one spot; drop fully-empty extra spots on save.
        var cleaned = draft
        let nonEmpty = cleaned.spots.filter { $0.hasContent }
        cleaned.spots = nonEmpty.isEmpty ? [cleaned.spots.first ?? EquipmentSpot()] : nonEmpty
        if let index = o.equipmentLocations.firstIndex(where: { $0.id == cleaned.id }) {
            o.equipmentLocations[index] = cleaned
        } else {
            o.equipmentLocations.append(cleaned)
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
