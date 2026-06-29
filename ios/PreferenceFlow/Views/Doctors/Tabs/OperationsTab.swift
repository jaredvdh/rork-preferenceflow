//
//  OperationsTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Operations — detailed setup guides for specific procedures (the flagship).
struct OperationsTab: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor

    @State private var editing: ProcedureTemplate?
    @State private var viewing: ProcedureTemplate?
    @State private var choosingPreset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button { choosingPreset = true } label: {
                    Label("Add Procedure", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(.white)
                }

                if doctor.operations.isEmpty {
                    EmptyStateView(
                        icon: "cross.case",
                        title: "No procedure templates",
                        message: "Start from a library template like CABG, Craniotomy or C-Section — each comes pre-filled.",
                        actionTitle: "Add Procedure",
                        action: { choosingPreset = true }
                    )
                    .card()
                } else {
                    ForEach(doctor.operations) { proc in
                        Button { viewing = proc } label: {
                            ProcedureRowCard(procedure: proc)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editing = proc } label: { Label("Edit", systemImage: "pencil") }
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $editing) { proc in
            ProcedureEditView(doctor: doctor, procedure: proc)
        }
        .sheet(item: $viewing) { proc in
            ProcedureDetailView(procedure: proc, onEdit: {
                viewing = nil
                editing = proc
            })
        }
        .sheet(isPresented: $choosingPreset) {
            ProcedurePresetPicker { preset in
                choosingPreset = false
                editing = preset.makeTemplate()
            }
        }
    }
}

/// A grid picker that seeds a new procedure from a library preset.
struct ProcedurePresetPicker: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (ProcedurePreset) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ProcedurePreset.library) { preset in
                        Button { onPick(preset) } label: {
                            VStack(spacing: 10) {
                                Image(systemName: preset.symbol)
                                    .font(.title2)
                                    .foregroundStyle(Theme.accent)
                                Text(preset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                if !preset.location.isEmpty {
                                    Text(preset.location)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerMedium))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Procedure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct ProcedureRowCard: View {
    let procedure: ProcedureTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cross.case.fill").foregroundStyle(Theme.accent)
                Text(procedure.name.isBlank ? "Untitled Procedure" : procedure.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            HStack(spacing: 12) {
                if !procedure.typicalStartTime.isBlank {
                    Label(procedure.typicalStartTime, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
                if !procedure.typicalLocation.isBlank {
                    Label(procedure.typicalLocation, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !procedure.monitoring.isEmpty {
                Text(procedure.monitoring.map { $0.rawValue }.sorted().joined(separator: " · "))
                    .font(.caption2).foregroundStyle(Theme.accent)
            }
        }
        .card()
    }
}
