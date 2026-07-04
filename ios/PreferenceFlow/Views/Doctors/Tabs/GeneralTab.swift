//
//  GeneralTab.swift
//  PreferenceFlow
//

import SwiftUI

/// General working preferences — a direct inline editor. This tab is only
/// reachable from Edit mode, so it lands straight on editable fields; the read
/// presentation lives on the Overview card.
struct GeneralTab: View {
    let doctor: Doctor

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            GeneralEditorForm(draft: $draft)
        }
    }
}

/// The general preferences form fields, bound to the Edit-mode session draft.
private struct GeneralEditorForm: View {
    @Binding var draft: Doctor

    var body: some View {
        Form {
            Section {
                OptionPicker(label: "Size", selection: $draft.general.sterileGloveSize,
                             options: GeneralPreferences.sterileGloveSizes, icon: "hand.raised.fill")
                SuggestionField(label: "Type", text: $draft.general.sterileGloveType,
                                suggestions: GeneralPreferences.sterileGloveTypes,
                                placeholder: "e.g. Biogel")
            } header: {
                Text("Sterile gloves")
            } footer: {
                Text("Worn for procedures — intubation, regional blocks, lines.")
            }
            Section {
                SegmentedRow(label: "Size", selection: $draft.general.nonSterileGloveSize,
                             options: GeneralPreferences.nonSterileGloveSizes)
            } header: {
                Text("Non-sterile gloves")
            } footer: {
                Text("Worn for general tasks.")
            }
            Section("Theatre Setup") {
                LabeledField(label: "Gown size", text: $draft.general.gownSize)
                LabeledField(label: "Mask", text: $draft.general.maskPreference)
                LabeledField(label: "Shoe size", text: $draft.general.theatreShoeSize)
                LabeledField(label: "Room temp", text: $draft.general.roomTemperature)
            }
            Section("Personal") {
                LabeledField(label: "Coffee", text: $draft.general.coffeePreference)
                LabeledField(label: "Tea", text: $draft.general.teaPreference)
                LabeledField(label: "Snacks", text: $draft.general.favouriteSnacks)
                LabeledField(label: "Contact", text: $draft.general.contactPreferences)
            }
            Section("Workflow") {
                Toggle("Arrives before patient", isOn: $draft.general.arriveBeforePatient)
                Toggle("Prepares own medications", isOn: $draft.general.prepareOwnMedications)
                Toggle("Assistant may prepare meds", isOn: $draft.general.assistantMayPrepareMedications)
                LabeledField(label: "Briefing style", text: $draft.general.briefingStyle)
            }
            Section("General Notes") {
                NotesField(label: "Notes", text: $draft.general.generalNotes)
            }
            Section {
            } footer: {
                InlineEditFooter()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
