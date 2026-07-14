//
//  QuickAddConsultantView.swift
//  PreferenceFlow
//

import SwiftUI
import PhotosUI
import UIKit

/// A minimal, under-60-seconds capture form for adding a new consultant quickly —
/// either from memory after a case or while reading the physical theatre card.
/// Captures only the essentials; full clinical setup can follow later.
struct QuickAddConsultantView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// Which profile type to create — anaesthetist or surgeon.
    var kind: ClinicianKind = .anaesthetist
    /// Called after a successful save with the new profile's id and whether the
    /// user chose to jump straight into the full setup editor.
    var onSaved: (UUID, Bool) -> Void

    @State private var fullName = ""
    @State private var specialties: [Subspecialty] = []
    @State private var sterileGloveSize = ""
    @State private var gownSize = ""
    @State private var coffee = ""
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showSavedPrompt = false
    @State private var showVerifyPrompt = false
    @State private var savedID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField(label: "Full Name", text: $fullName, placeholder: "Dr Jane Smith", icon: "person")
                    NavigationLink {
                        SubspecialtyPicker(selected: $specialties, kind: kind)
                    } label: {
                        HStack {
                            Label("Specialty", systemImage: "square.grid.2x2")
                            Spacer()
                            Text(specialties.isEmpty ? "None" : specialties.map(\.rawValue).joined(separator: ", "))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Who")
                } footer: {
                    Text("Just the essentials — you can add the full setup later.")
                }

                Section("Quick preferences") {
                    OptionPicker(label: kind == .surgeon ? "Glove size" : "Sterile glove size",
                                 selection: $sterileGloveSize,
                                 options: GeneralPreferences.sterileGloveSizes, icon: "hand.raised")
                    LabeledField(label: "Gown size", text: $gownSize, placeholder: "e.g. Large", icon: "tshirt")
                    if kind == .anaesthetist {
                        LabeledField(label: "Coffee order", text: $coffee, placeholder: "e.g. Flat white", icon: "cup.and.saucer")
                    }
                }

                Section("Notes") {
                    NotesField(label: "Free notes", text: $notes)
                }

                photoSection
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { showVerifyPrompt = true }
                        .disabled(fullName.isBlank)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    if let image, let data = image.resizedJPEG(maxDimension: 1400, quality: 0.8) {
                        photoData = data
                    }
                }
                .ignoresSafeArea()
            }
            .confirmationDialog(
                "Mark this profile as verified?",
                isPresented: $showVerifyPrompt,
                titleVisibility: .visible
            ) {
                Button("Yes, verified") { save(verified: true) }
                Button("Not yet") { save(verified: false) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Mark as verified only if these preferences were confirmed with the consultant. Choose \u{201C}Not yet\u{201D} if you\u{2019}re adding this from memory or a paper card \u{2014} a reminder banner will show until it\u{2019}s verified.")
            }
            .confirmationDialog("Profile saved", isPresented: $showSavedPrompt, titleVisibility: .visible) {
                Button("Add full setup details now") { finish(openEdit: true) }
                Button("Do it later", role: .cancel) { finish(openEdit: false) }
            } message: {
                Text("The basic card is already useful. Add airway, drugs and more now, or come back later.")
            }
        }
    }

    private var photoSection: some View {
        Section {
            if let photoData, let image = UIImage(data: photoData) {
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
                    self.photoData = nil
                    photoItem = nil
                }
                .font(.caption)
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoData == nil ? "Attach Card Photo" : "Choose Different Photo", systemImage: "photo")
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

    private func save(verified: Bool) {
        var doctor = Doctor(fullName: fullName, kind: kind, subspecialties: specialties)
        doctor.isVerified = verified
        // Attach to the only hospital automatically so the profile isn't orphaned.
        if store.hospitals.count == 1, let only = store.hospitals.first {
            doctor.hospitalId = only.id
            doctor.department = only.department
        }
        if kind == .surgeon {
            // Surgeon quick preferences live in the surgical section so the
            // surgeon card displays them.
            var surgical = SurgicalPreferences()
            surgical.gloves.gloveSize = sterileGloveSize
            surgical.gloves.gownPreference = gownSize
            doctor.surgical = surgical
        } else {
            doctor.general.sterileGloveSize = sterileGloveSize
            doctor.general.gownSize = gownSize
            doctor.general.coffeePreference = coffee
        }
        doctor.personalNotes = notes
        doctor.referencePhotoData = photoData
        store.upsert(doctor)
        savedID = doctor.id
        showSavedPrompt = true
    }

    private func finish(openEdit: Bool) {
        guard let savedID else { dismiss(); return }
        onSaved(savedID, openEdit)
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let resized = image.resizedJPEG(maxDimension: 1400, quality: 0.8) {
            photoData = resized
        }
    }
}
