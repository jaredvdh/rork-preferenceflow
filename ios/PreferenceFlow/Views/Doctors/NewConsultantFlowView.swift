//
//  NewConsultantFlowView.swift
//  PreferenceFlow
//

import SwiftUI

/// Guided consultant creation: pick a hospital, choose a department standard, then
/// the profile is pre-populated from that standard and only the differences are
/// edited. Replaces starting from a blank form.
struct NewConsultantFlowView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// Pre-selected hospital (e.g. when launched from a hospital). Skips step 1.
    var presetHospitalID: UUID?
    /// Which profile type to create — anaesthetist or surgeon.
    var kind: ClinicianKind

    @State private var step: Step = .hospital
    @State private var hospitalID: UUID?
    @State private var draft: Doctor?

    private enum Step { case hospital, template, identity }

    init(presetHospitalID: UUID? = nil, kind: ClinicianKind = .anaesthetist) {
        self.presetHospitalID = presetHospitalID
        self.kind = kind
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .hospital: hospitalStep
                case .template:
                    if kind == .surgeon {
                        // Department standards describe anaesthetic setups — a
                        // surgeon profile starts blank instead.
                        Color.clear.onAppear { choose(nil) }
                    } else {
                        templateStep
                    }
                case .identity:
                    if let draft {
                        // Reuse the identity editor; it saves via the store on Save.
                        ConsultantIdentityStep(draft: draft, hospitalName: store.hospital(id: hospitalID)?.name)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear(perform: bootstrap)
    }

    private var title: String {
        switch step {
        case .hospital: return "Select Hospital"
        case .template: return "Choose Standard"
        case .identity: return "New \(kind.provider(settings.region))"
        }
    }

    /// Decides the starting step: skip hospital selection when there is a preset or
    /// a single (or no) hospital.
    private func bootstrap() {
        guard step == .hospital, draft == nil else { return }
        if let presetHospitalID {
            hospitalID = presetHospitalID
            step = .template
        } else if store.hospitals.count == 1 {
            hospitalID = store.hospitals.first?.id
            step = .template
        } else if store.hospitals.isEmpty {
            step = .template
        }
    }

    // MARK: - Step 1: Hospital

    private var hospitalStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                StepHeader(
                    number: 1,
                    title: "Which hospital?",
                    subtitle: "The standards and orientation for this site will apply."
                )
                ForEach(store.hospitals) { hospital in
                    Button {
                        hospitalID = hospital.id
                        withAnimation(.spring(response: 0.3)) { step = .template }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Theme.accent.opacity(0.14)).frame(width: 46, height: 46)
                                Image(systemName: "building.2.fill").foregroundStyle(Theme.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hospital.name).font(.headline).foregroundStyle(.primary)
                                if !hospital.locationLine.isEmpty {
                                    Text(hospital.locationLine).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    hospitalID = nil
                    withAnimation(.spring(response: 0.3)) { step = .template }
                } label: {
                    Text("No hospital / decide later")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Step 2: Template

    private var templateStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                StepHeader(
                    number: 2,
                    title: "Start from a department standard",
                    subtitle: "The profile inherits this standard. You then change only what differs for this consultant."
                )
                ForEach(store.templates(forHospital: hospitalID)) { template in
                    Button { choose(template) } label: {
                        TemplateChoiceCard(template: template)
                    }
                    .buttonStyle(.plain)
                }
                Button { choose(nil) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc").font(.title3).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start blank").font(.headline).foregroundStyle(.primary)
                            Text("No inherited standard — build from scratch.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .card()
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    private func choose(_ template: DepartmentTemplate?) {
        var doctor = Doctor(hospitalId: hospitalID)
        doctor.kind = kind
        doctor.department = store.hospital(id: hospitalID)?.department ?? ""
        if kind == .surgeon { doctor.surgical = SurgicalPreferences() }
        if let template { template.apply(to: &doctor) }
        draft = doctor
        withAnimation(.spring(response: 0.3)) { step = .identity }
    }
}

/// Final identity step — name, role, photo — then saves the pre-populated profile.
private struct ConsultantIdentityStep: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State var draft: Doctor
    let hospitalName: String?
    @State private var showVerifyPrompt = false

    var body: some View {
        Form {
            if let template = store.template(for: draft) {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: template.icon).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Inheriting \(template.name)").font(.subheadline.weight(.semibold))
                            Text("Edit only what differs after saving.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Identity") {
                LabeledField(label: "Full Name", text: $draft.fullName, placeholder: "Dr Jane Smith", icon: "person")
                LabeledField(
                    label: "Role",
                    text: $draft.role,
                    placeholder: draft.clinicianKind.provider(settings.region),
                    icon: draft.isSurgeon ? "scissors" : "stethoscope"
                )
                if let hospitalName {
                    HStack {
                        Label("Hospital", systemImage: "building.2")
                        Spacer()
                        Text(hospitalName).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                NavigationLink {
                    SubspecialtyPicker(selected: $draft.subspecialties, kind: draft.clinicianKind)
                } label: {
                    HStack {
                        Label("Subspecialties", systemImage: "square.grid.2x2")
                        Spacer()
                        Text(draft.subspecialties.isEmpty ? "None" : "\(draft.subspecialties.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { showVerifyPrompt = true }
                    .disabled(draft.fullName.isBlank)
            }
        }
        .confirmationDialog(
            "Mark this profile as verified?",
            isPresented: $showVerifyPrompt,
            titleVisibility: .visible
        ) {
            Button("Yes, verified") { create(verified: true) }
            Button("Not yet") { create(verified: false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark as verified only if these preferences were confirmed with the consultant. Choose \u{201C}Not yet\u{201D} if you\u{2019}re creating this from memory or a paper card \u{2014} a reminder banner will show until it\u{2019}s verified.")
        }
    }

    private func create(verified: Bool) {
        draft.isVerified = verified
        store.upsert(draft)
        dismiss()
    }
}

/// A numbered step header used in the guided creation flow.
struct StepHeader: View {
    let number: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.heroGradient).frame(width: 30, height: 30)
                    Text("\(number)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                }
                Text(title).font(.title3.weight(.bold))
            }
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

/// A selectable department standard card showing its headline setup.
struct TemplateChoiceCard: View {
    let template: DepartmentTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: template.icon).font(.headline).foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name).font(.headline).foregroundStyle(.primary)
                    if template.isBuiltIn {
                        Text("Department standard").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            if !headline.isEmpty {
                PrefChecklist(items: headline)
            }
        }
        .card()
    }

    private var headline: [String] {
        var items: [String] = []
        let a = template.airway
        if !a.adultMale.tubeSize.isBlank { items.append("ETT \(a.adultMale.tubeSize)") }
        if a.adultMale.videoSystem != .none { items.append(a.adultMale.videoSystem.rawValue) }
        items += a.supraglottic.summaryChips.map { "SGA \($0)" }
        items += template.adultDrugs.induction.selected
        items += template.adultDrugs.fluids.allAgents.prefix(1)
        if !template.regionalBlocks.isEmpty { items.append("\(template.regionalBlocks.count) blocks") }
        return Array(items.prefix(5))
    }
}
