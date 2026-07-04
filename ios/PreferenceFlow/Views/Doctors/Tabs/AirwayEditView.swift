//
//  AirwayEditView.swift
//  PreferenceFlow
//

import SwiftUI
import PhotosUI

/// Curated airway option lists for the structured pickers.
enum AirwayOptions {
    static let maleTube = ["7.0", "7.5", "8.0", "8.5", "9.0"]
    static let femaleTube = ["6.0", "6.5", "7.0", "7.5"]
    static let paedTube = ["3.0", "3.5", "4.0", "4.5", "5.0", "5.5", "6.0"]
    static let cuffed = ["Cuffed", "Uncuffed"]
    static let bougie = ["Always", "Usually", "Occasionally", "Rarely"]
    /// Adult tube securing quick-select options (free-text override allowed).
    static let adultSecuring = ["Tie", "Tape", "Elastoplast", "Suture", "Thomas tube holder", "Dual lumen tube holder"]
    /// Paediatric securing method quick-select options.
    static let paedSecuring = ["Tie", "Tape", "Zinc oxide", "Elastoplast", "Sleek"]
    static let paedTapeType = ["5mm zinc oxide", "1cm zinc oxide", "1cm Elastoplast", "Sleek"]
    static let paedTapingTechnique = ["Trouser legs", "Cross-tape", "Single split strip", "H-tape"]
    static let bladeSize = ["Mac 3", "Mac 4", "Miller 2", "Miller 3"]
    static let paedBladeSize = ["Miller 0", "Miller 1", "Miller 1.5", "Miller 2", "Mac 1", "Mac 1.5", "Mac 2"]
    static let videoSystem = ["McGrath", "GlideScope", "C-MAC", "King Vision", "Other"]
    static let supraglottic = ["i-gel", "LMA Classic", "LMA Supreme", "LMA ProSeal", "AuraGain"]
    static let sgSizes = ["3", "4", "5"]
    static let paedSgSizes = ["1", "1.5", "2", "2.5", "3"]
}

/// The airway preference form fields, bound to the Edit-mode session draft and
/// filtered by the Adult / Paediatric cohort picker. Rendered inline inside the
/// Airway tab's Form — no modal chrome, no separate Save step.
struct AirwayFormSections: View {
    @Environment(AppSettings.self) private var settings
    @Binding var draft: Doctor
    let cohort: AirwayTab.Cohort

    @State private var tapingPhotoItem: PhotosPickerItem?
    @State private var showingTapingCamera = false
    @State private var showingTapingLibrary = false

    var body: some View {
        if cohort == .adult {
            airwaySetupSection("Adult Male", tubes: AirwayOptions.maleTube, setup: $draft.airway.adultMale)
            airwaySetupSection("Adult Female", tubes: AirwayOptions.femaleTube, setup: $draft.airway.adultFemale)

            Section {
                supraglotticChoiceRows(choice: $draft.airway.supraglottic.adultFemale)
            } header: {
                Text("Supraglottic — Adult Female")
            } footer: {
                Text("e.g. i-gel Size 4 or LMA Supreme Size 4.")
            }

            Section("Supraglottic — Adult Male") {
                supraglotticChoiceRows(choice: $draft.airway.supraglottic.adultMale)
            }

            Section {
                supraglotticChoiceRows(choice: $draft.airway.supraglottic.largeAdult)
            } header: {
                Text("Supraglottic — Large Adult / High IBW (optional)")
            } footer: {
                Text("For consultants who routinely upsize larger patients. Leave blank if not used. Paediatric sizing is on the airway summary's weight-based reference.")
            }

            Section("Supraglottic Notes") {
                NotesField(label: "Special notes", text: $draft.airway.supraglottic.notes)
            }
        } else {
            airwaySetupSection(settings.region.paediatric, tubes: AirwayOptions.paedTube, setup: $draft.airway.paediatric, showTubeSize: false, blades: AirwayOptions.paedBladeSize, notesLabel: "Cuff inflation / tube notes (e.g. Kimberly-Clark)", isPaediatric: true)

            paediatricTapingSection
        }

        Section("Difficult Airway") {
            NotesField(label: "Backup plan", text: $draft.airway.difficultAirway.backupPlan)
            NotesField(label: "Fibreoptic preference", text: $draft.airway.difficultAirway.fibreopticPreference)
            NotesField(label: "Surgical airway notes", text: $draft.airway.difficultAirway.surgicalAirwayNotes)
            NotesField(label: "Special equipment", text: $draft.airway.difficultAirway.specialEquipment)
        }
    }

    /// Device + size pickers for a single supraglottic cohort.
    @ViewBuilder
    private func supraglotticChoiceRows(choice: Binding<SupraglotticChoice>) -> some View {
        OptionPicker(label: "Device", selection: deviceBinding(choice), options: AirwayOptions.supraglottic, icon: "lungs")
        OptionPicker(label: "Size", selection: choice.size, options: AirwayOptions.sgSizes)
    }

    /// Bridges a cohort's supraglottic device enum to the OptionPicker's String binding.
    private func deviceBinding(_ choice: Binding<SupraglotticChoice>) -> Binding<String> {
        Binding(
            get: { choice.wrappedValue.device == .none ? "" : choice.wrappedValue.device.rawValue },
            set: { choice.wrappedValue.device = SupraglotticDevice(rawValue: $0) ?? .none }
        )
    }

    private func airwaySetupSection(_ title: String, tubes: [String], setup: Binding<AirwaySetup>, showTubeSize: Bool = true, blades: [String] = AirwayOptions.bladeSize, notesLabel: String = "Special notes", isPaediatric: Bool = false) -> some View {
        Section(title) {
            if showTubeSize {
                OptionPicker(label: "Tube size", selection: setup.tubeSize, options: tubes, icon: "lungs")
            } else {
                Label("Tube size is calculated by age on the airway summary (cuffed age ÷ 4 + 3.5, uncuffed age ÷ 4 + 4).", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if isPaediatric {
                // Cuffed vs uncuffed genuinely matters for paediatric sizing.
                SegmentedRow(label: "Cuffed / uncuffed preference", selection: setup.cuffedPreference, options: AirwayOptions.cuffed)
            } else {
                // Adult tubes are cuffed by default — offer tube type instead.
                Picker(selection: setup.tubeType) {
                    ForEach(TubeType.allCases) { Text($0.rawValue).tag($0) }
                } label: {
                    Label("Tube type", systemImage: "lungs.fill")
                }
                .pickerStyle(.menu)
                if setup.wrappedValue.tubeType.isRAE {
                    LabeledField(label: "RAE note", text: setup.tubeTypeNote, placeholder: "e.g. nasal, left nostril", icon: "arrow.turn.down.right")
                }
            }
            Toggle(isOn: Binding(
                get: { setup.wrappedValue.styletPreference == "Yes" },
                set: { setup.wrappedValue.styletPreference = $0 ? "Yes" : "No" }
            )) {
                Label("Stylet", systemImage: "line.diagonal")
            }
            OptionPicker(label: "Bougie", selection: setup.bougiePreference, options: AirwayOptions.bougie, icon: "line.diagonal")
            if !isPaediatric {
                SuggestionField(label: "Tube securing", text: setup.tubeSecuring, suggestions: AirwayOptions.adultSecuring, placeholder: "e.g. Tie", icon: "bandage")
            }
            Picker(selection: setup.primaryTechnique) {
                ForEach(LaryngoscopyTechnique.allCases) { Text($0.rawValue).tag($0) }
            } label: {
                Label("Technique", systemImage: "eye")
            }
            .pickerStyle(.segmented)
            if setup.wrappedValue.primaryTechnique == .video {
                OptionPicker(label: "Video system", selection: videoBinding(setup), options: AirwayOptions.videoSystem, icon: "video")
            }
            OptionPicker(label: "Blade", selection: setup.bladeSize, options: blades)
            NotesField(label: notesLabel, text: setup.notes)
        }
    }

    // MARK: - Paediatric taping technique

    private var paediatricTapingSection: some View {
        Section {
            SuggestionField(label: "Securing method", text: $draft.airway.paediatric.tubeSecuring, suggestions: AirwayOptions.paedSecuring, placeholder: "e.g. Zinc oxide", icon: "bandage")
            SuggestionField(label: "Tape width / type", text: $draft.airway.paediatric.tapingTape, suggestions: AirwayOptions.paedTapeType, placeholder: "e.g. 5mm zinc oxide", icon: "ruler")
            SuggestionField(label: "Technique", text: $draft.airway.paediatric.tapingTechnique, suggestions: AirwayOptions.paedTapingTechnique, placeholder: "e.g. Trouser legs", icon: "scribble.variable")
            tapingPhotoRow
        } header: {
            Text("\(settings.region.paediatric) Tube Securing")
        } footer: {
            Text("Paediatric taping is often consultant-specific. A photo of the finished technique helps a technician match it exactly.")
        }
        .onChange(of: tapingPhotoItem) { _, item in Task { await loadTapingPhoto(item) } }
        .photosPicker(isPresented: $showingTapingLibrary, selection: $tapingPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showingTapingCamera) {
            CameraImagePicker { image in
                if let resized = image?.resizedJPEG(maxDimension: 1000, quality: 0.8) {
                    draft.airway.paediatric.tapingTechniquePhoto = resized
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var tapingPhotoRow: some View {
        if let data = draft.airway.paediatric.tapingTechniquePhoto, let image = UIImage(data: data) {
            Color(.secondarySystemBackground)
                .frame(height: 180)
                .overlay { Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: Theme.cornerMedium))
                .overlay(alignment: .topTrailing) {
                    Menu {
                        if CameraImagePicker.isAvailable {
                            Button { showingTapingCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                        }
                        Button { showingTapingLibrary = true } label: { Label("Choose from Library", systemImage: "photo") }
                        Button(role: .destructive) { draft.airway.paediatric.tapingTechniquePhoto = nil } label: {
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
                .listRowInsets(EdgeInsets())
        } else {
            Menu {
                if CameraImagePicker.isAvailable {
                    Button { showingTapingCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                }
                Button { showingTapingLibrary = true } label: { Label("Choose from Library", systemImage: "photo") }
            } label: {
                Label("Add photo of technique", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private func loadTapingPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let resized = image.resizedJPEG(maxDimension: 1000, quality: 0.8) {
            draft.airway.paediatric.tapingTechniquePhoto = resized
        }
    }

    private func videoBinding(_ setup: Binding<AirwaySetup>) -> Binding<String> {
        Binding(
            get: { setup.wrappedValue.videoSystem == .none ? "" : setup.wrappedValue.videoSystem.rawValue },
            set: { setup.wrappedValue.videoSystem = VideoLaryngoscopeSystem(rawValue: $0) ?? .none }
        )
    }
}
