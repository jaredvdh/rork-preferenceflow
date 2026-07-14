//
//  DoctorEditView.swift
//  PreferenceFlow
//

import SwiftUI
import PhotosUI

/// The "Consultant Details" section of the single Edit Consultant experience —
/// a direct inline editor. Selecting the Details tab in Edit mode lands straight
/// on editable identity fields; changes autosave via the edit session.
struct DetailsTab: View {
    let doctor: Doctor

    var body: some View {
        ConsultantEditSession(doctor: doctor, isValid: { !$0.fullName.isBlank }) { $draft in
            Form {
                DoctorDetailsFormSections(draft: $draft)
                Section {
                } footer: {
                    InlineEditFooter()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

/// The consultant identity form fields (photos, identity, professional info,
/// notes), bound to the Edit-mode session draft. Rendered inline inside the
/// Details tab's Form — no modal chrome.
struct DoctorDetailsFormSections: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Binding var draft: Doctor

    @State private var photoItem: PhotosPickerItem?
    @State private var referenceItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        photoSection
            .onChange(of: photoItem) { _, newItem in
                Task { await loadPhoto(newItem) }
            }
        referencePhotoSection
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
        identitySection
        professionalSection
        notesSection
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
            LabeledField(
                label: "Role",
                text: $draft.role,
                placeholder: draft.clinicianKind.provider(settings.region),
                icon: draft.isSurgeon ? "scissors" : "stethoscope"
            )
            NavigationLink {
                SubspecialtyPicker(selected: $draft.subspecialties, kind: draft.clinicianKind)
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

/// Multi-select picker for provider subspecialties, filtered to the profile's
/// clinician kind (anaesthetic vs surgical specialty lists). Already-selected
/// values outside the list are kept visible so nothing is silently dropped.
struct SubspecialtyPicker: View {
    @Binding var selected: [Subspecialty]
    var kind: ClinicianKind = .anaesthetist

    private var options: [Subspecialty] {
        var list = Subspecialty.options(for: kind)
        for item in selected where !list.contains(item) {
            list.insert(item, at: 0)
        }
        return list
    }

    var body: some View {
        List {
            ForEach(options) { item in
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
