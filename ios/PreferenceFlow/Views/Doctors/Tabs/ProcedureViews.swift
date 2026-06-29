//
//  ProcedureViews.swift
//  PreferenceFlow
//

import SwiftUI

/// Read-only detail for a procedure template, shown as a sheet.
struct ProcedureDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let procedure: ProcedureTemplate
    var onEdit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overview

                    if !procedure.timeline.isEmpty {
                        timelineCard
                    }
                    if !procedure.monitoring.isEmpty {
                        monitoringCard
                    }
                    ivAccessCard
                    if !procedure.airwayNotes.isBlank {
                        NotesDisplay(title: "Airway", text: procedure.airwayNotes, icon: "lungs")
                    }
                    if !procedure.lineSetup.isBlank {
                        NotesDisplay(title: "Line Setup", text: procedure.lineSetup, icon: "cable.connector")
                    }
                    if !procedure.infusions.isBlank {
                        NotesDisplay(title: "Infusions", text: procedure.infusions, icon: "drop")
                    }
                    if !procedure.equipmentChecklist.isEmpty {
                        checklistCard
                    }
                    if !procedure.specialNotes.isBlank {
                        NotesDisplay(title: "Special Notes", text: procedure.specialNotes)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(procedure.name.isBlank ? "Procedure" : procedure.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Edit") { onEdit() } }
            }
        }
    }

    private var overview: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(Theme.heroGradient).frame(width: 64, height: 64)
                Image(systemName: "cross.case.fill").font(.title2).foregroundStyle(.white)
            }
            Text(procedure.name.isBlank ? "Untitled" : procedure.name).font(.title3.weight(.bold))
            HStack(spacing: 14) {
                if !procedure.typicalStartTime.isBlank {
                    Label(procedure.typicalStartTime, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
                if !procedure.typicalLocation.isBlank {
                    Label(procedure.typicalLocation, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Preparation Timeline", icon: "timeline.selection")
            VStack(spacing: 0) {
                ForEach(Array(procedure.timeline.enumerated()), id: \.element.id) { index, entry in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(Theme.accent).frame(width: 10, height: 10)
                            if index < procedure.timeline.count - 1 {
                                Rectangle().fill(Theme.accent.opacity(0.3)).frame(width: 2)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.time).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
                            Text(entry.event).font(.subheadline)
                        }
                        .padding(.bottom, 14)
                        Spacer()
                    }
                }
            }
            .card()
        }
    }

    private var monitoringCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Monitoring", icon: "waveform.path.ecg")
            PrefChecklist(items: procedure.monitoring.map { $0.rawValue }.sorted(), tint: PrefGroup.monitoring.tint)
                .card()
        }
    }

    private var ivAccessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("IV Access", icon: "syringe")
            VStack(spacing: 8) {
                ValueRow(label: "Number", value: procedure.ivCount)
                ValueRow(label: "Size", value: procedure.ivSize)
                ValueRow(label: "Location", value: procedure.ivLocation)
                if procedure.ivCount.isBlank && procedure.ivSize.isBlank && procedure.ivLocation.isBlank {
                    Text("Not set").font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .card()
        }
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Equipment Checklist", icon: "checklist")
            VStack(spacing: 10) {
                ForEach(procedure.equipmentChecklist) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
                        Text(item.text).font(.subheadline)
                        Spacer()
                    }
                }
            }
            .card()
        }
    }
}

/// Editor for a procedure template.
struct ProcedureEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var doctor: Doctor
    @State private var proc: ProcedureTemplate
    private let isExisting: Bool

    init(doctor: Doctor, procedure: ProcedureTemplate) {
        _doctor = State(initialValue: doctor)
        _proc = State(initialValue: procedure)
        self.isExisting = doctor.operations.contains { $0.id == procedure.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Overview") {
                    LabeledField(label: "Name", text: $proc.name)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ProcedureTemplate.suggestions, id: \.self) { name in
                                Button { proc.name = name } label: { Chip(text: name) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    LabeledField(label: "Start time", text: $proc.typicalStartTime)
                    LabeledField(label: "Location", text: $proc.typicalLocation)
                }

                Section("Preparation Timeline") {
                    ForEach($proc.timeline) { $entry in
                        HStack {
                            TextField("Time", text: $entry.time).frame(width: 70)
                            Divider()
                            TextField("Event", text: $entry.event)
                        }
                    }
                    .onDelete { proc.timeline.remove(atOffsets: $0) }
                    Button { proc.timeline.append(TimelineEntry()) } label: {
                        Label("Add Step", systemImage: "plus")
                    }
                }

                Section("Monitoring") {
                    ForEach(MonitoringOption.allCases) { option in
                        Button {
                            if proc.monitoring.contains(option) { proc.monitoring.remove(option) }
                            else { proc.monitoring.insert(option) }
                        } label: {
                            HStack {
                                Text(option.rawValue).foregroundStyle(.primary)
                                Spacer()
                                if proc.monitoring.contains(option) {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }

                Section("IV Access") {
                    LabeledField(label: "Number", text: $proc.ivCount)
                    LabeledField(label: "Size", text: $proc.ivSize)
                    LabeledField(label: "Location", text: $proc.ivLocation)
                }

                Section("Setup") {
                    NotesField(label: "Airway notes", text: $proc.airwayNotes)
                    NotesField(label: "Line setup", text: $proc.lineSetup)
                    NotesField(label: "Infusions", text: $proc.infusions)
                }

                Section("Equipment Checklist") {
                    ForEach($proc.equipmentChecklist) { $item in
                        HStack {
                            Button {
                                item.isChecked.toggle()
                            } label: {
                                Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(item.isChecked ? Theme.accent : .secondary)
                            }
                            .buttonStyle(.plain)
                            TextField("Item", text: $item.text)
                        }
                    }
                    .onDelete { proc.equipmentChecklist.remove(atOffsets: $0) }
                    Button { proc.equipmentChecklist.append(ChecklistItem()) } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }

                Section("Special Notes") {
                    NotesField(label: "Notes", text: $proc.specialNotes)
                }

                if isExisting {
                    Section {
                        Button("Delete Procedure", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isExisting ? "Edit Procedure" : "New Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(proc.name.isBlank)
                }
            }
        }
    }

    private func save() {
        var updated = doctor
        if let index = updated.operations.firstIndex(where: { $0.id == proc.id }) {
            updated.operations[index] = proc
        } else {
            updated.operations.append(proc)
        }
        store.upsert(updated)
        dismiss()
    }

    private func delete() {
        var updated = doctor
        updated.operations.removeAll { $0.id == proc.id }
        store.upsert(updated)
        dismiss()
    }
}
