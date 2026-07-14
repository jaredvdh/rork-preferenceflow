//
//  EnergyEquipmentTab.swift
//  PreferenceFlow
//
//  Surgeon edit tab: diathermy settings, energy devices, tourniquet,
//  irrigation and imaging. Inline autosaving editor.
//

import SwiftUI

/// Energy & Equipment — a direct inline editor for a surgeon profile.
struct EnergyEquipmentTab: View {
    let doctor: Doctor

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            Form {
                diathermySection(surgicalBinding($draft))
                devicesSection(surgicalBinding($draft))
                tourniquetSection(surgicalBinding($draft))
                imagingSection(surgicalBinding($draft))
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

    private func diathermySection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SuggestionField(
                label: "Cut",
                text: surgical.energy.diathermyCut,
                suggestions: SurgicalOptions.diathermySettings,
                placeholder: "e.g. 30",
                icon: "scissors"
            )
            SuggestionField(
                label: "Coag",
                text: surgical.energy.diathermyCoag,
                suggestions: SurgicalOptions.diathermySettings,
                placeholder: "e.g. 35",
                icon: "flame"
            )
        } header: {
            Label("Diathermy Settings", systemImage: "bolt.fill")
        } footer: {
            Text("The surgeon's usual starting settings — always confirm against the machine and local policy.")
        }
    }

    private func devicesSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.energy.energyDevices,
                                options: SurgicalOptions.energyDevices)
                CustomListEditor(items: surgical.energy.energyDevices,
                                 curated: SurgicalOptions.energyDevices,
                                 addLabel: "Add energy device")
            }
            .padding(.vertical, 4)
        } header: {
            Label("Energy Devices", systemImage: "wand.and.rays")
        }
    }

    private func tourniquetSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SuggestionField(
                label: "Pressure",
                text: surgical.energy.tourniquetPressure,
                suggestions: SurgicalOptions.tourniquetPressures,
                placeholder: "e.g. 250 mmHg",
                icon: "gauge.with.needle"
            )
            LabeledField(
                label: "Time / reminders",
                text: surgical.energy.tourniquetNotes,
                placeholder: "e.g. Notify at 90 min",
                icon: "timer"
            )
            SuggestionField(
                label: "Irrigation",
                text: surgical.energy.irrigation,
                suggestions: SurgicalOptions.irrigation,
                placeholder: "e.g. Warm saline",
                icon: "drop"
            )
        } header: {
            Label("Tourniquet & Irrigation", systemImage: "timer")
        }
    }

    private func imagingSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.energy.imaging,
                                options: SurgicalOptions.imaging)
                CustomListEditor(items: surgical.energy.imaging,
                                 curated: SurgicalOptions.imaging,
                                 addLabel: "Add equipment")
            }
            .padding(.vertical, 4)
            NotesField(label: "Notes", text: surgical.energy.notes, minHeight: 60)
        } header: {
            Label("Imaging & Heavy Equipment", systemImage: "camera.metering.matrix")
        } footer: {
            Text("Equipment to have in the room before the case starts.")
        }
    }
}
