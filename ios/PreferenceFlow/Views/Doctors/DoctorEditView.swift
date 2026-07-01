//
//  DoctorEditView.swift
//  PreferenceFlow
//

import SwiftUI
import PhotosUI

/// The "Consultant Details" section of the single Edit Consultant experience.
/// Shows a scannable summary of who the consultant is, with one button into the
/// identity editor — mirroring how every clinical section reads then edits.
struct DetailsTab: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor

    @State private var editing = false

    private var hospitalName: String? { store.hospital(id: doctor.hospitalId)?.name }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                detailsCard

                if !doctor.biography.isBlank || !doctor.personalNotes.isBlank {
                    notesCard
                }

                EditSectionButton(title: "Edit Consultant Details") { editing = true }
            }
            .padding(16)
        }
        .sheet(isPresented: $editing) {
            DoctorEditView(doctor: doctor, isNew: false)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            DoctorAvatar(doctor: doctor, size: 88)
            VStack(spacing: 4) {
                Text(doctor.displayName)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if !doctor.role.isBlank {
                    Text(doctor.role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !doctor.subspecialties.isEmpty {
                PrefChips(values: doctor.subspecialties.map(\.rawValue), tint: Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var detailsCard: some View {
        PrefCollapsibleCard(
            group: .personal,
            title: "Consultant Details",
            icon: "person.crop.circle",
            collapsedSummary: [hospitalName, doctor.department.isBlank ? nil : doctor.department]
                .compactMap { $0 }.joined(separator: " • ")
        ) {
            PrefRow(label: "Role", value: doctor.role)
            PrefRow(label: "Hospital", value: hospitalName ?? "")
            PrefRow(label: "Department", value: doctor.department)
            PrefRow(label: "Phone", value: doctor.phone)
            PrefRow(label: "Email", value: doctor.email)
            if !doctor.subspecialties.isEmpty {
                PrefRow(label: "Special interests", value: doctor.subspecialties.map(\.rawValue).joined(separator: ", "))
            }
        }
    }

    private var notesCard: some View {
        PrefCollapsibleCard(
            group: .consultantNotes,
            title: "Notes",
            collapsedSummary: [doctor.biography, doctor.personalNotes].filter { !$0.isBlank }.first ?? ""
        ) {
            if !doctor.biography.isBlank {
                PrefNote(label: "Biography", text: doctor.biography, tint: PrefGroup.consultantNotes.tint)
            }
            if !doctor.personalNotes.isBlank {
                PrefNote(label: "Personal notes", text: doctor.personalNotes, tint: PrefGroup.consultantNotes.tint)
            }
        }
    }
}

/// Create / edit a provider's identity, professional info and notes. Preference
/// sections are edited from within their respective profile tabs.
struct DoctorEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Doctor
    @State private var photoItem: PhotosPickerItem?
    @State private var referenceItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showVerifyPrompt = false
    private let isNew: Bool

    init(doctor: Doctor, isNew: Bool) {
        _draft = State(initialValue: doctor)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                referencePhotoSection
                identitySection
                professionalSection
                notesSection
            }
            .navigationTitle(isNew ? "New Consultant" : "Consultant Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isNew {
                            showVerifyPrompt = true
                        } else {
                            store.upsert(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.fullName.isBlank)
                }
            }
            .confirmationDialog(
                "Mark this profile as verified?",
                isPresented: $showVerifyPrompt,
                titleVisibility: .visible
            ) {
                Button("Yes, verified") { saveWith(verified: true) }
                Button("Not yet") { saveWith(verified: false) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Mark as verified only if these preferences were confirmed with the consultant. Choose \u{201C}Not yet\u{201D} if you\u{2019}re creating this from memory or a paper card \u{2014} a reminder banner will show until it\u{2019}s verified.")
            }
            .onChange(of: photoItem) { _, newItem in
                Task { await loadPhoto(newItem) }
            }
            .onChange(of: referenceItem) { _, newItem in
                Task { await loadReferencePhoto(newItem) }
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    if let image, let data = image.resizedJPEG(maxDimension: 1400, quality: 0.8) {
                        draft.referencePhotoData = data
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var referencePhotoSection: some View {
        Section {
            if let data = draft.referencePhotoData, let image = UIImage(data: data) {
                HStack {
                    Spacer()
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(.rect(cornerRadius: 12))
                    Spacer()
                }
                .listRowBackground(Color.clear)
                Button("Remove Photo", role: .destructive) {
                    draft.referencePhotoData = nil
                    referenceItem = nil
                }
                .font(.caption)
            }
            PhotosPicker(selection: $referenceItem, matching: .images) {
                Label(draft.referencePhotoData == nil ? "Attach Card Photo" : "Choose Different Photo", systemImage: "photo")
            }
            if CameraImagePicker.isAvailable {
                Button { showCamera = true } label: {
                    Label("Take Photo of Card", systemImage: "camera")
                }
            }
        } header: {
            Text("Reference photo")
        } footer: {
            Text("Optionally photograph the physical theatre card as a backup reference.")
        }
    }

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    DoctorAvatar(doctor: draft, size: 96)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(draft.photoData == nil ? "Add Photo" : "Change Photo")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                    }
                    if draft.photoData != nil {
                        Button("Remove Photo", role: .destructive) {
                            draft.photoData = nil
                            photoItem = nil
                        }
                        .font(.caption)
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private var identitySection: some View {
        Section("Identity") {
            LabeledField(label: "Full Name", text: $draft.fullName, placeholder: "Dr Jane Smith", icon: "person")
            LabeledField(label: "Phone", text: $draft.phone, placeholder: "Optional", icon: "phone")
                .keyboardType(.phonePad)
            LabeledField(label: "Email", text: $draft.email, placeholder: "Optional", icon: "envelope")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            Picker(selection: $draft.hospitalId) {
                Text("None").tag(UUID?.none)
                ForEach(store.hospitals) { hospital in
                    Text(hospital.name).tag(UUID?.some(hospital.id))
                }
            } label: {
                Label("Hospital", systemImage: "building.2")
            }
            LabeledField(label: "Department", text: $draft.department, placeholder: "Anaesthesia", icon: "cross.case")
        }
    }

    private var professionalSection: some View {
        Section("Professional") {
            LabeledField(label: "Role", text: $draft.role, placeholder: settings.region.provider, icon: "stethoscope")
            NavigationLink {
                SubspecialtyPicker(selected: $draft.subspecialties)
            } label: {
                HStack {
                    Label("Subspecialties", systemImage: "square.grid.2x2")
                    Spacer()
                    Text(draft.subspecialties.isEmpty ? "None" : "\(draft.subspecialties.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            NotesField(label: "Biography", text: $draft.biography)
            NotesField(label: "Personal notes", text: $draft.personalNotes)
        }
    }

    private func saveWith(verified: Bool) {
        draft.isVerified = verified
        store.upsert(draft)
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let resized = image.resizedJPEG(maxDimension: 600, quality: 0.8) {
            draft.photoData = resized
        }
    }

    private func loadReferencePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let resized = image.resizedJPEG(maxDimension: 1400, quality: 0.8) {
            draft.referencePhotoData = resized
        }
    }
}

/// Multi-select picker for provider subspecialties.
struct SubspecialtyPicker: View {
    @Binding var selected: [Subspecialty]

    var body: some View {
        List {
            ForEach(Subspecialty.allCases) { item in
                Button {
                    toggle(item)
                } label: {
                    HStack {
                        Text(item.rawValue).foregroundStyle(.primary)
                        Spacer()
                        if selected.contains(item) {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Subspecialties")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ item: Subspecialty) {
        if let index = selected.firstIndex(of: item) {
            selected.remove(at: index)
        } else {
            selected.append(item)
        }
    }
}

extension UIImage {
    /// Resizes and JPEG-compresses an image so profile photos stay portable.
    func resizedJPEG(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
