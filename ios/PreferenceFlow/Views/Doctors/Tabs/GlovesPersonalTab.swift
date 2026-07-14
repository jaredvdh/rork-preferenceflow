//
//  GlovesPersonalTab.swift
//  PreferenceFlow
//
//  Surgeon edit tab: glove size/brand (with double-gloving), gown preference,
//  loupes/headlight, music and communication style. Inline autosaving editor,
//  matching the flat edit-tab pattern used across the profile.
//

import SwiftUI

/// Gloves & Personal — a direct inline editor for a surgeon profile.
struct GlovesPersonalTab: View {
    let doctor: Doctor

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            Form {
                glovesSection(surgicalBinding($draft))
                gownSection(surgicalBinding($draft))
                styleSection(surgicalBinding($draft))
                Section {
                } footer: {
                    InlineEditFooter()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// Binds the surgeon preferences on the session draft, materialising the
    /// optional on first edit.
    private func surgicalBinding(_ draft: Binding<Doctor>) -> Binding<SurgicalPreferences> {
        Binding(
            get: { draft.wrappedValue.surgical ?? SurgicalPreferences() },
            set: { draft.wrappedValue.surgical = $0 }
        )
    }

    private func glovesSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            OptionPicker(
                label: "Glove size",
                selection: surgical.gloves.gloveSize,
                options: GeneralPreferences.sterileGloveSizes,
                icon: "hand.raised"
            )
            SuggestionField(
                label: "Brand / type",
                text: surgical.gloves.gloveBrand,
                suggestions: SurgicalOptions.gloveBrands,
                placeholder: "e.g. Biogel",
                icon: "tag"
            )
            Toggle(isOn: surgical.gloves.doubleGloves) {
                Label("Double gloves", systemImage: "hand.raised.fingers.spread")
            }
            .sensoryFeedback(.selection, trigger: surgical.gloves.doubleGloves.wrappedValue)
            if surgical.gloves.doubleGloves.wrappedValue {
                OptionPicker(
                    label: "Under-glove size",
                    selection: surgical.gloves.underGloveSize,
                    options: GeneralPreferences.sterileGloveSizes,
                    icon: "hand.raised.slash"
                )
            }
        } header: {
            Label("Gloves", systemImage: "hand.raised.fill")
        } footer: {
            Text("Many surgeons wear a half size larger underneath when double-gloving.")
        }
    }

    private func gownSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SuggestionField(
                label: "Gown",
                text: surgical.gloves.gownPreference,
                suggestions: SurgicalOptions.gownPreferences,
                placeholder: "e.g. Wrap-around XL",
                icon: "tshirt"
            )
            Toggle(isOn: surgical.gloves.wearsLoupes) {
                Label("Wears loupes", systemImage: "eyeglasses")
            }
            .sensoryFeedback(.selection, trigger: surgical.gloves.wearsLoupes.wrappedValue)
            Toggle(isOn: surgical.gloves.wearsHeadlight) {
                Label("Wears headlight", systemImage: "lightbulb")
            }
            .sensoryFeedback(.selection, trigger: surgical.gloves.wearsHeadlight.wrappedValue)
        } header: {
            Label("Gown & Wearables", systemImage: "tshirt.fill")
        }
    }

    private func styleSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            LabeledField(
                label: "Music",
                text: surgical.gloves.musicPreference,
                placeholder: "e.g. Quiet during closing",
                icon: "music.note"
            )
            NotesField(label: "Communication style", text: surgical.gloves.communicationStyle, minHeight: 60)
            NotesField(label: "Notes", text: surgical.gloves.notes, minHeight: 60)
        } header: {
            Label("Working Style", systemImage: "bubble.left.and.bubble.right")
        } footer: {
            Text("How this surgeon likes the room run — music, counts read-back, when to speak up.")
        }
    }
}
