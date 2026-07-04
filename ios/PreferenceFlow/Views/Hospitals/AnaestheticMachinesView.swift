//
//  AnaestheticMachinesView.swift
//  PreferenceFlow
//
//  Hospital → Anaesthetic Machines: which machine models are in use at this
//  site (e.g. "GE Aisys CS2 · Theatres 1-8") and a daily machine-check
//  checklist per machine. Checklist ticks are session-only (they reset each
//  time the checklist is opened), matching how other checklists in the app
//  behave. The generic checklist is a convenience starting reference only —
//  the caption below every checklist makes that explicit.
//

import SwiftUI

// MARK: - Machines list

struct AnaestheticMachinesTab: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var creating = false
    @State private var editingMachine: AnaestheticMachine?

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let machines = hospital?.orientationOrEmpty.anaestheticMachines ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button { creating = true } label: {
                    Label("Add machine", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
                .buttonStyle(.plain)

                if machines.isEmpty {
                    EmptyStateView(
                        icon: "gauge.with.dots.needle.bottom.50percent",
                        title: "No machines yet",
                        message: "Add the anaesthetic machine models in use at this site — each starts with an editable daily check checklist."
                    )
                } else {
                    ForEach(machines) { machine in
                        NavigationLink(value: machine) {
                            MachineCard(machine: machine)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editingMachine = machine } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { delete(machine) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                MachineChecklistCaption()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationDestination(for: AnaestheticMachine.self) { machine in
            MachineChecklistView(hospitalID: hospitalID, machineID: machine.id)
        }
        .sheet(isPresented: $creating) {
            MachineEditView(
                hospitalID: hospitalID,
                machine: AnaestheticMachine(
                    model: .geAisysCS2,
                    checklistItems: AnaestheticMachine.defaultChecklist(for: .geAisysCS2)
                ),
                isNew: true
            )
        }
        .sheet(item: $editingMachine) { machine in
            MachineEditView(hospitalID: hospitalID, machine: machine, isNew: false)
        }
    }

    private func delete(_ machine: AnaestheticMachine) {
        guard var h = hospital else { return }
        var o = h.orientationOrEmpty
        o.anaestheticMachines.removeAll { $0.id == machine.id }
        h.orientation = o
        store.upsert(h)
    }
}

/// One machine in the list — model name, location and checklist size.
private struct MachineCard: View {
    let machine: AnaestheticMachine

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 46, height: 46)
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.title3).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(machine.displayName).font(.headline)
                if !machine.location.isBlank {
                    Label(machine.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if machine.model != .other {
                        Text(machine.model.manufacturer)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                    Text("^[\(machine.checklistItems.count) check item](inflect: true)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
    }
}

/// The always-visible generic-checklist safety caption.
struct MachineChecklistCaption: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text(AnaestheticMachine.checklistCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerMedium))
    }
}

// MARK: - Daily check (session-only ticks)

/// A machine's checklist as a tick-off reference for the daily check. Ticks are
/// `@State` only — they reset every time the screen opens, never persisted.
struct MachineChecklistView: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID
    let machineID: UUID

    @State private var checked: Set<UUID> = []
    @State private var editing = false

    /// Always read the live machine from the store so edits reflect immediately.
    private var machine: AnaestheticMachine? {
        store.hospital(id: hospitalID)?.orientationOrEmpty.anaestheticMachines
            .first { $0.id == machineID }
    }

    var body: some View {
        ScrollView {
            if let machine {
                VStack(alignment: .leading, spacing: 14) {
                    header(machine)
                    progress(machine)
                    checklist(machine)
                    if !machine.notes.isBlank {
                        NotesDisplay(title: "Notes", text: machine.notes, icon: "note.text")
                    }
                    MachineChecklistCaption()
                }
                .padding(16)
            } else {
                VStack(spacing: 12) {
                    Spacer(minLength: 120)
                    Text("Machine not found").foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(machine?.displayName ?? "Machine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            if let machine {
                MachineEditView(hospitalID: hospitalID, machine: machine, isNew: false)
            }
        }
    }

    private func header(_ machine: AnaestheticMachine) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 52, height: 52)
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.title2).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(machine.displayName).font(.title3.weight(.bold))
                HStack(spacing: 8) {
                    if !machine.location.isBlank {
                        Label(machine.location, systemImage: "mappin.and.ellipse")
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    if machine.model != .other {
                        Text(machine.model.manufacturer)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    private func progress(_ machine: AnaestheticMachine) -> some View {
        let total = machine.checklistItems.count
        let done = machine.checklistItems.filter { checked.contains($0.id) }.count
        return HStack(spacing: 12) {
            ProgressView(value: total == 0 ? 0 : Double(done) / Double(total))
                .tint(done == total && total > 0 ? .green : Theme.accent)
            Text("\(done)/\(total)")
                .font(.caption.weight(.bold))
                .foregroundStyle(done == total && total > 0 ? .green : .secondary)
                .monospacedDigit()
            if done > 0 {
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.2)) { checked.removeAll() }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
            }
        }
        .card(padding: 14)
        .sensoryFeedback(.success, trigger: done == total && total > 0)
    }

    private func checklist(_ machine: AnaestheticMachine) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(machine.checklistItems) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if checked.contains(item.id) { checked.remove(item.id) } else { checked.insert(item.id) }
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: checked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(checked.contains(item.id) ? Theme.accent : Color(.tertiaryLabel))
                        Text(item.text)
                            .font(.subheadline)
                            .foregroundStyle(checked.contains(item.id) ? .secondary : .primary)
                            .strikethrough(checked.contains(item.id), color: .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        if !item.isDefault {
                            Text("Added")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Theme.accent.opacity(0.12), in: .capsule)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if item.id != machine.checklistItems.last?.id {
                    Divider()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: checked)
        .card()
    }
}

// MARK: - Machine editor

struct MachineEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: AnaestheticMachine
    @State private var newItemText = ""
    private let isNew: Bool

    init(hospitalID: UUID, machine: AnaestheticMachine, isNew: Bool) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: machine)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Machine") {
                    Picker(selection: $draft.model) {
                        ForEach(MachineModel.allCases) { Text($0.displayName).tag($0) }
                    } label: {
                        Label("Model", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    }
                    if draft.model == .other {
                        LabeledField(label: "Model name", text: $draft.customModelName, placeholder: "Machine model", icon: "tag")
                    }
                    LabeledField(label: "Location", text: $draft.location, placeholder: "e.g. Theatres 1-4", icon: "mappin.and.ellipse")
                }

                Section {
                    ForEach($draft.checklistItems) { $item in
                        TextField("Check item", text: $item.text, axis: .vertical)
                            .font(.subheadline)
                    }
                    .onDelete { draft.checklistItems.remove(atOffsets: $0) }
                    .onMove { draft.checklistItems.move(fromOffsets: $0, toOffset: $1) }

                    HStack(spacing: 8) {
                        TextField("Add check item", text: $newItemText)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                        Button(action: addItem) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(newItemText.isBlank ? Color.secondary : Theme.accent)
                        }
                        .disabled(newItemText.isBlank)
                    }
                } header: {
                    Text("Daily Check Checklist")
                } footer: {
                    Text(AnaestheticMachine.checklistCaption)
                }

                Section("Notes") {
                    NotesField(label: "Notes (optional)", text: $draft.notes)
                }

                if !isNew {
                    Section {
                        Button("Delete Machine", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New Machine" : "Edit Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(draft.model == .other && draft.customModelName.isBlank)
                }
            }
        }
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft.checklistItems.append(MachineCheckItem(text: trimmed, isDefault: false))
        newItemText = ""
    }

    private func save() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        var cleaned = draft
        cleaned.checklistItems.removeAll { $0.text.isBlank }
        if let index = o.anaestheticMachines.firstIndex(where: { $0.id == cleaned.id }) {
            o.anaestheticMachines[index] = cleaned
        } else {
            o.anaestheticMachines.append(cleaned)
        }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }

    private func delete() {
        guard var h = store.hospital(id: hospitalID) else { return }
        var o = h.orientationOrEmpty
        o.anaestheticMachines.removeAll { $0.id == draft.id }
        h.orientation = o
        store.upsert(h)
        dismiss()
    }
}
