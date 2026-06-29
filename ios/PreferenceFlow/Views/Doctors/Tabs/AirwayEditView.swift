//
//  AirwayEditView.swift
//  PreferenceFlow
//

import SwiftUI

/// Curated airway option lists for the structured pickers.
enum AirwayOptions {
    static let maleTube = ["7.0", "7.5", "8.0", "8.5", "9.0"]
    static let femaleTube = ["6.0", "6.5", "7.0", "7.5"]
    static let paedTube = ["3.0", "3.5", "4.0", "4.5", "5.0", "5.5", "6.0"]
    static let cuffed = ["Cuffed", "Uncuffed"]
    static let bougie = ["Always", "Usually", "Occasionally", "Rarely"]
    static let securing = ["Tie", "Tape", "Both"]
    static let bladeSize = ["Mac 3", "Mac 4", "Miller 2", "Miller 3"]
    static let paedBladeSize = ["Miller 0", "Miller 1", "Miller 1.5", "Miller 2", "Mac 1", "Mac 1.5", "Mac 2"]
    static let videoSystem = ["McGrath", "GlideScope", "C-MAC", "King Vision", "Other"]
    static let supraglottic = ["i-gel", "LMA Classic", "LMA Supreme", "LMA ProSeal", "AuraGain"]
    static let sgSizes = ["3", "4", "5"]
    static let paedSgSizes = ["1", "1.5", "2", "2.5", "3"]
}

/// Editor for the full airway preferences set using structured selectors.
struct AirwayEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Doctor

    init(doctor: Doctor) {
        _draft = State(initialValue: doctor)
    }

    var body: some View {
        NavigationStack {
            Form {
                airwaySetupSection("Adult Male", tubes: AirwayOptions.maleTube, setup: $draft.airway.adultMale)
                airwaySetupSection("Adult Female", tubes: AirwayOptions.femaleTube, setup: $draft.airway.adultFemale)
                airwaySetupSection(settings.region.paediatric, tubes: AirwayOptions.paedTube, setup: $draft.airway.paediatric, showTubeSize: false, blades: AirwayOptions.paedBladeSize, notesLabel: "Cuff inflation / tube notes (e.g. Kimberly-Clark)")

                Section {
                    supraglotticChoiceRows("Adult Female", choice: $draft.airway.supraglottic.adultFemale)
                } header: {
                    Text("Adult Female")
                } footer: {
                    Text("e.g. i-gel Size 4 or LMA Supreme Size 4.")
                }

                Section("Adult Male") {
                    supraglotticChoiceRows("Adult Male", choice: $draft.airway.supraglottic.adultMale)
                }

                Section {
                    supraglotticChoiceRows("Large Adult", choice: $draft.airway.supraglottic.largeAdult)
                } header: {
                    Text("Large Adult / High IBW (optional)")
                } footer: {
                    Text("For consultants who routinely upsize larger patients. Leave blank if not used. Paediatric sizing is on the airway summary's weight-based reference.")
                }

                Section("Supraglottic Notes") {
                    NotesField(label: "Special notes", text: $draft.airway.supraglottic.notes)
                }

                Section("Difficult Airway") {
                    NotesField(label: "Backup plan", text: $draft.airway.difficultAirway.backupPlan)
                    NotesField(label: "Fibreoptic preference", text: $draft.airway.difficultAirway.fibreopticPreference)
                    NotesField(label: "Surgical airway notes", text: $draft.airway.difficultAirway.surgicalAirwayNotes)
                    NotesField(label: "Special equipment", text: $draft.airway.difficultAirway.specialEquipment)
                }
            }
            .navigationTitle("Airway")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.upsert(draft); dismiss() }
                }
            }
        }
    }

    /// Device + size pickers for a single supraglottic cohort.
    @ViewBuilder
    private func supraglotticChoiceRows(_ title: String, choice: Binding<SupraglotticChoice>) -> some View {
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

    private func airwaySetupSection(_ title: String, tubes: [String], setup: Binding<AirwaySetup>, showTubeSize: Bool = true, blades: [String] = AirwayOptions.bladeSize, notesLabel: String = "Special notes") -> some View {
        Section(title) {
            if showTubeSize {
                OptionPicker(label: "Tube size", selection: setup.tubeSize, options: tubes, icon: "lungs")
            } else {
                Label("Tube size is calculated by age on the airway summary (cuffed age ÷ 4 + 3.5, uncuffed age ÷ 4 + 4).", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            SegmentedRow(label: "Cuffed / uncuffed preference", selection: setup.cuffedPreference, options: AirwayOptions.cuffed)
            Toggle(isOn: Binding(
                get: { setup.wrappedValue.styletPreference == "Yes" },
                set: { setup.wrappedValue.styletPreference = $0 ? "Yes" : "No" }
            )) {
                Label("Stylet", systemImage: "line.diagonal")
            }
            OptionPicker(label: "Bougie", selection: setup.bougiePreference, options: AirwayOptions.bougie, icon: "line.diagonal")
            OptionPicker(label: "Tube securing", selection: setup.tubeSecuring, options: AirwayOptions.securing)
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

    private func videoBinding(_ setup: Binding<AirwaySetup>) -> Binding<String> {
        Binding(
            get: { setup.wrappedValue.videoSystem == .none ? "" : setup.wrappedValue.videoSystem.rawValue },
            set: { setup.wrappedValue.videoSystem = VideoLaryngoscopeSystem(rawValue: $0) ?? .none }
        )
    }
}
