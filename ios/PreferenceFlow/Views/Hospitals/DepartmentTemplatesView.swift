//
//  DepartmentTemplatesView.swift
//  PreferenceFlow
//

import SwiftUI

/// The department standards for a hospital. Editing a standard updates the default
/// setup every inheriting consultant sees, without rebuilding their profiles.
struct DepartmentTemplatesTab: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var editing: DepartmentTemplate?
    @State private var addingNew = false

    private var templates: [DepartmentTemplate] { store.templates(forHospital: hospitalID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(templates) { template in
                    Button { editing = template } label: {
                        DepartmentTemplateRow(
                            template: template,
                            usedBy: store.doctors(forHospital: hospitalID).filter { $0.departmentTemplateId == template.id }.count
                        )
                    }
                    .buttonStyle(.plain)
                }
                referenceGuides
            }
            .padding(16)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { template in
            DepartmentTemplateEditView(hospitalID: hospitalID, template: template, isNew: false)
        }
        .sheet(isPresented: $addingNew) {
            DepartmentTemplateEditView(
                hospitalID: hospitalID,
                template: DepartmentTemplate(name: "", icon: "rectangle.stack"),
                isNew: true
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Department Standards", icon: "doc.on.doc")
            Text("The default setups consultants inherit. Update a standard here and every inheriting consultant follows the change.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Educational airway and technique reference guides, surfaced alongside the
    /// department's standards now that the standalone Knowledge tab is gone.
    private var referenceGuides: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Reference Guides", icon: "books.vertical")
                .padding(.top, 8)
            Text("Educational airway, regional and ventilation references.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.bottom, 4)
            ForEach(KnowledgeCategory.allCases.filter { $0 != .emergency }) { category in
                NavigationLink(value: category) {
                    KnowledgeCategoryCard(category: category)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A department standard row showing its headline setup and how many consultants
/// currently inherit it.
private struct DepartmentTemplateRow: View {
    let template: DepartmentTemplate
    let usedBy: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: template.icon).font(.headline).foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name.isBlank ? "Untitled standard" : template.name)
                        .font(.headline).foregroundStyle(.primary)
                    if usedBy == 0 {
                        Label("No consultants assigned", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hex: "E08B3E"))
                    } else {
                        Text(usedBy == 1 ? "1 consultant inherits" : "\(usedBy) consultants inherit")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "pencil").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .card()
        .overlay(alignment: .leading) {
            if usedBy == 0 {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "E08B3E"))
                    .frame(width: 4)
                    .padding(.vertical, 10)
            }
        }
    }
}

/// Lightweight editor for a department standard's headline setup — the items shown
/// on consultant dashboards. Stores real structured values so inheritance compares
/// correctly.
struct DepartmentTemplateEditView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let hospitalID: UUID
    @State private var draft: DepartmentTemplate
    private let isNew: Bool

    private let icons = ["rectangle.stack.fill", "heart.fill", "figure.child", "brain.head.profile", "scope", "figure.2.and.child.holdinghands", "cross.case.fill", "lungs.fill"]

    init(hospitalID: UUID, template: DepartmentTemplate, isNew: Bool) {
        self.hospitalID = hospitalID
        _draft = State(initialValue: template)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Standard") {
                    LabeledField(label: "Name", text: $draft.name, placeholder: "e.g. General Theatre", icon: "textformat")
                    iconPicker
                }

                Section("Standard Airway") {
                    LabeledField(label: "ETT (male)", text: $draft.airway.adultMale.tubeSize, placeholder: "7.5", icon: "lungs")
                    LabeledField(label: "ETT (female)", text: $draft.airway.adultFemale.tubeSize, placeholder: "7.0")
                    OptionPicker(label: "Video system", selection: videoSystemBinding, options: VideoLaryngoscopeSystem.allCases.filter { $0 != .none }.map { $0.rawValue }, icon: "video")
                    LabeledField(label: "Blade size", text: $draft.airway.adultMale.bladeSize, placeholder: "4")
                    OptionPicker(label: "Supraglottic", selection: supraglotticBinding, options: SupraglotticDevice.allCases.filter { $0 != .none }.map { $0.rawValue }, icon: "bubbles.and.sparkles")
                    LabeledField(label: "Supraglottic size", text: $draft.airway.supraglottic.adultMale.size, placeholder: "5")
                }

                Section("Standard Induction Drugs") {
                    drugChips("Induction", category: .induction, keyPath: \.induction)
                    drugChips("Opioid", category: .opioid, keyPath: \.opioid)
                    drugChips("Vasopressor", category: .vasopressor, keyPath: \.vasopressor)
                    drugChips("IV Fluids", category: .fluid, keyPath: \.fluids)
                }

                Section("General") {
                    Toggle("Assistant may prepare medications", isOn: $draft.general.assistantMayPrepareMedications)
                    Toggle("Arrive before patient", isOn: $draft.general.arriveBeforePatient)
                }

                Section("Notes") {
                    NotesField(label: "Standard notes", text: $draft.notes)
                }

                if !isNew && !draft.isBuiltIn {
                    Section {
                        Button("Delete standard", role: .destructive) {
                            store.deleteTemplate(draft, forHospital: hospitalID)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Standard" : "Edit Standard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsertTemplate(draft, forHospital: hospitalID)
                        dismiss()
                    }
                    .disabled(draft.name.isBlank)
                }
            }
        }
    }

    private var iconPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(icons, id: \.self) { icon in
                    Button { draft.icon = icon } label: {
                        Image(systemName: icon)
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(draft.icon == icon ? Theme.accent : Color(.tertiarySystemFill), in: .circle)
                            .foregroundStyle(draft.icon == icon ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var videoSystemBinding: Binding<String> {
        Binding(
            get: { draft.airway.adultMale.videoSystem == .none ? "" : draft.airway.adultMale.videoSystem.rawValue },
            set: { newValue in
                let system = VideoLaryngoscopeSystem(rawValue: newValue) ?? .none
                draft.airway.adultMale.videoSystem = system
                draft.airway.adultFemale.videoSystem = system
                draft.airway.adultMale.primaryTechnique = system == .none ? .direct : .video
                draft.airway.adultFemale.primaryTechnique = system == .none ? .direct : .video
            }
        )
    }

    private var supraglotticBinding: Binding<String> {
        Binding(
            get: { draft.airway.supraglottic.adultMale.device == .none ? "" : draft.airway.supraglottic.adultMale.device.rawValue },
            set: {
                let device = SupraglotticDevice(rawValue: $0) ?? .none
                draft.airway.supraglottic.adultMale.device = device
                draft.airway.supraglottic.adultFemale.device = device
            }
        )
    }

    private func drugChips(_ label: String, category: DrugCategory, keyPath: WritableKeyPath<DrugsFluidsSetup, DrugSelection>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ChipMultiSelect(
                selected: Binding(
                    get: { draft.adultDrugs[keyPath: keyPath].selected },
                    set: { draft.adultDrugs[keyPath: keyPath].selected = $0 }
                ),
                options: category.options
            )
        }
        .padding(.vertical, 2)
    }
}
