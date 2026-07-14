//
//  SuturesClosureTab.swift
//  PreferenceFlow
//
//  Surgeon edit tab: suture preferences by layer, staplers and loads, drains
//  and dressings. Inline autosaving editor.
//

import SwiftUI

/// Sutures & Closure — a direct inline editor for a surgeon profile.
struct SuturesClosureTab: View {
    let doctor: Doctor

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            Form {
                layersSection(surgicalBinding($draft))
                staplersSection(surgicalBinding($draft))
                drainsSection(surgicalBinding($draft))
                dressingsSection(surgicalBinding($draft))
                Section {
                } footer: {
                    InlineEditFooter()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func surgicalBinding(_ draft: Binding<Doctor>) -> Binding<SurgicalPreferences> {
        Binding(
            get: { draft.wrappedValue.surgical ?? SurgicalPreferences() },
            set: { draft.wrappedValue.surgical = $0 }
        )
    }

    private func layersSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SuggestionField(
                label: "Fascia / deep",
                text: surgical.sutures.fascia,
                suggestions: SurgicalOptions.fasciaSutures,
                placeholder: "e.g. 1 PDS loop",
                icon: "circle.dotted"
            )
            SuggestionField(
                label: "Subcutaneous",
                text: surgical.sutures.subcutaneous,
                suggestions: SurgicalOptions.subcutaneousSutures,
                placeholder: "e.g. 2-0 Vicryl",
                icon: "circle.bottomhalf.filled"
            )
            SuggestionField(
                label: "Skin",
                text: surgical.sutures.skin,
                suggestions: SurgicalOptions.skinClosure,
                placeholder: "e.g. 3-0 Monocryl subcuticular",
                icon: "bandage"
            )
        } header: {
            Label("Sutures by Layer", systemImage: "bandage.fill")
        } footer: {
            Text("The surgeon's routine closure for a standard case — procedure cards can record exceptions.")
        }
    }

    private func staplersSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.sutures.staplers,
                                options: SurgicalOptions.staplers)
                CustomListEditor(items: surgical.sutures.staplers,
                                 curated: SurgicalOptions.staplers,
                                 addLabel: "Add stapler / load")
            }
            .padding(.vertical, 4)
        } header: {
            Label("Staplers & Loads", systemImage: "rectangle.compress.vertical")
        }
    }

    private func drainsSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.sutures.drains,
                                options: SurgicalOptions.drains)
                CustomListEditor(items: surgical.sutures.drains,
                                 curated: SurgicalOptions.drains,
                                 addLabel: "Add drain")
            }
            .padding(.vertical, 4)
        } header: {
            Label("Drains", systemImage: "arrow.down.to.line.compact")
        }
    }

    private func dressingsSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.sutures.dressings,
                                options: SurgicalOptions.dressings)
                CustomListEditor(items: surgical.sutures.dressings,
                                 curated: SurgicalOptions.dressings,
                                 addLabel: "Add dressing")
            }
            .padding(.vertical, 4)
            NotesField(label: "Notes", text: surgical.sutures.notes, minHeight: 60)
        } header: {
            Label("Dressings", systemImage: "square.on.square.dashed")
        }
    }
}
