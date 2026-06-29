//
//  MedicationTab.swift
//  PreferenceFlow
//

import SwiftUI

enum MedicationKind {
    case adult
    case paediatric
}

/// Adult / Paediatric induction medications + IV fluid preferences. Independent
/// data per the spec, but identical structure.
struct MedicationTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor
    let kind: MedicationKind

    @State private var editingMedication: Medication?
    @State private var editingFluids = false
    @State private var editingNotes = false

    private var setup: MedicationSetup {
        kind == .adult ? doctor.adult : doctor.paediatric
    }

    private var title: String {
        kind == .adult ? "Adult" : settings.region.paediatric
    }

    private var notesKeyPath: WritableKeyPath<Doctor, String> {
        switch kind {
        case .adult: return \Doctor.adult.notes
        case .paediatric: return \Doctor.paediatric.notes
        }
    }

    var body: some View {
        ScrollView {
            scrollContent
                .padding(16)
        }
        .sheet(item: $editingMedication) { med in
            MedicationEditView(doctor: doctor, kind: kind, medication: med)
        }
        .sheet(isPresented: $editingFluids) {
            FluidsEditView(doctor: doctor, kind: kind)
        }
        .sheet(isPresented: $editingNotes) {
            SingleNoteEditView(
                title: "\(title) Notes",
                doctor: doctor,
                keyPath: notesKeyPath
            )
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        VStack(spacing: 20) {
            Button {
                editingMedication = Medication()
            } label: {
                Label("Add Medication", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: .capsule)
                    .foregroundStyle(.white)
            }

            if setup.medications.isEmpty {
                Text("No \(title.lowercased()) medications saved yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                medicationGroups
            }

            fluidsCard
            notesCard
        }
    }

    private var medicationGroups: some View {
        ForEach(MedicationCategory.allCases) { category in
            let meds = setup.medications.filter { $0.category == category }
            if !meds.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(category.rawValue, icon: category.symbol)
                    VStack(spacing: 10) {
                        ForEach(meds) { med in
                            Button { editingMedication = med } label: {
                                MedicationCard(medication: med)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var fluidsCard: some View {
        let f = setup.fluids
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("IV Fluids", icon: "drop.fill")
                Spacer()
                Button("Edit") { editingFluids = true }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 8) {
                ValueRow(label: "Crystalloid", value: f.preferredCrystalloid)
                ValueRow(label: "Balanced", value: f.balancedCrystalloid)
                ValueRow(label: "Saline", value: f.salinePreference)
                ValueRow(label: "Pressure bag", value: f.pressureBagUse)
                ValueRow(label: "Fluid warmer", value: f.fluidWarmer)
                ValueRow(label: "Blood setup", value: f.bloodSetup)
                ValueRow(label: "Special notes", value: f.specialNotes)
                if f.preferredCrystalloid.isBlank && f.balancedCrystalloid.isBlank && f.salinePreference.isBlank && f.pressureBagUse.isBlank && f.fluidWarmer.isBlank && f.bloodSetup.isBlank && f.specialNotes.isBlank {
                    Text("Tap Edit to add fluid preferences")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Setup Notes", icon: "note.text")
                Spacer()
                Button("Edit") { editingNotes = true }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text(setup.notes.isBlank ? "No notes" : setup.notes)
                .font(.subheadline)
                .foregroundStyle(setup.notes.isBlank ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        }
    }
}

/// A medication summary card.
struct MedicationCard: View {
    let medication: Medication
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(medication.name.isBlank ? "Untitled" : medication.name)
                    .font(.headline)
                Spacer()
                Text(medication.preparedBy.shortLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
                    .foregroundStyle(Theme.accentDeep)
            }
            ValueRow(label: "Preparation", value: medication.preparation)
            ValueRow(label: "Concentration", value: medication.concentration)
            ValueRow(label: "Draw-up", value: medication.drawUpNotes)
            ValueRow(label: "Labelling", value: medication.labellingNotes)
            ValueRow(label: "Notes", value: medication.specialNotes)
        }
        .card()
    }
}
