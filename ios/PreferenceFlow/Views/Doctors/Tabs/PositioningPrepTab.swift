//
//  PositioningPrepTab.swift
//  PreferenceFlow
//
//  Surgeon edit tab: patient position, table attachments, skin prep, draping
//  and catheter usage, plus a positioning setup photo. Inline autosaving editor.
//

import SwiftUI

/// Positioning & Prep — a direct inline editor for a surgeon profile.
struct PositioningPrepTab: View {
    let doctor: Doctor

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            Form {
                positionSection(surgicalBinding($draft))
                prepSection(surgicalBinding($draft))
                photoSection(surgicalBinding($draft))
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

    private func positionSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SuggestionField(
                label: "Position",
                text: surgical.positioning.patientPosition,
                suggestions: SurgicalOptions.positions,
                placeholder: "e.g. Supine",
                icon: "bed.double"
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("Table setup & attachments")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ChipMultiSelect(selected: surgical.positioning.tableAttachments,
                                options: SurgicalOptions.tableAttachments)
                CustomListEditor(items: surgical.positioning.tableAttachments,
                                 curated: SurgicalOptions.tableAttachments,
                                 addLabel: "Add attachment / padding")
            }
            .padding(.vertical, 4)
        } header: {
            Label("Patient Position", systemImage: "bed.double.fill")
        }
    }

    private func prepSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SuggestionField(
                label: "Prep solution",
                text: surgical.positioning.prepSolution,
                suggestions: SurgicalOptions.prepSolutions,
                placeholder: "e.g. ChloraPrep",
                icon: "drop.triangle"
            )
            SuggestionField(
                label: "Draping",
                text: surgical.positioning.drapingStyle,
                suggestions: SurgicalOptions.drapingStyles,
                placeholder: "e.g. Laparotomy drapes + Ioban",
                icon: "square.3.layers.3d"
            )
            SuggestionField(
                label: "Catheter",
                text: surgical.positioning.catheter,
                suggestions: SurgicalOptions.catheters,
                placeholder: "e.g. Foley 14Fr for cases > 2h",
                icon: "cross.vial"
            )
            NotesField(label: "Notes", text: surgical.positioning.notes, minHeight: 60)
        } header: {
            Label("Prep & Draping", systemImage: "sparkles")
        } footer: {
            Text("Check prep against documented allergies — chlorhexidine and iodine sensitivities are common.")
        }
    }

    private func photoSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SetupPhotoField(
                label: "Positioning photo (optional)",
                help: "A photo of the finished positioning helps the team match padding and attachments exactly.",
                photoData: surgical.positioning.setupPhoto
            )
        } header: {
            Label("Setup Photo", systemImage: "photo")
        }
    }
}
