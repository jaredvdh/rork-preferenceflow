//
//  PreferenceCardExportView.swift
//  PreferenceFlow
//

import SwiftUI

/// The two printable document formats, merged into one export flow.
enum PDFExportFormat: String, CaseIterable, Identifiable {
    /// One A4 page, condensed — lives laminated by the anaesthetic machine.
    case theatreCard = "Theatre Card"
    /// Multi-page detailed export with selectable sections and appendix.
    case fullCard = "Full Preference Card"
    /// One A4 page for a single operation card (surgeon or anaesthetist).
    case procedureCard = "Operation Card"
    /// One A4 page for a single specialty setup (e.g. Cardiac, Neuro, Obstetrics).
    case specialtyCard = "Specialty Card"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .theatreCard: return "printer"
        case .fullCard: return "doc.richtext"
        case .procedureCard: return "cross.case"
        case .specialtyCard: return "square.grid.2x2"
        }
    }

    var subtitle: String {
        switch self {
        case .theatreCard: return "One page, laminate-ready — the whole setup at a glance"
        case .fullCard: return "Detailed multi-page card — choose sections, add hospital appendix"
        case .procedureCard: return "One page for a single operation's exact setup"
        case .specialtyCard: return "One page for a single specialty list — what changes vs standard"
        }
    }
}

/// Single "Export / Print PDF" flow: pick a format (one-page Theatre Card or the
/// full detailed Preference Card), tune options where relevant, then share via
/// the system sheet (print, AirDrop, Files). Presented from the profile "…"
/// menu and the Share tab.
struct PreferenceCardExportView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let doctor: Doctor
    /// Preferred hospital context (e.g. today's hospital); falls back to the
    /// doctor's own hospital.
    var hospitalID: UUID? = nil

    @State private var format: PDFExportFormat = .theatreCard
    @State private var options: PreferenceCardOptions = .standard
    @State private var includeQR = false
    /// The operation exported when the format is `.procedureCard`.
    @State private var selectedProcedureID: UUID?
    /// The specialty setup exported when the format is `.specialtyCard`.
    @State private var selectedSpecialtyID: UUID?
    @State private var sharePayload: SharePayload?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var hospital: Hospital? { store.hospital(id: hospitalID ?? doctor.hospitalId) }
    private var hospitalHasOrientation: Bool { hospital?.orientationOrEmpty.hasContent ?? false }

    /// Formats offered for this profile — the per-operation card only appears
    /// when the profile has operation cards (surgeon procedures or anaesthetist
    /// operations); the per-specialty card only when the profile has specialty
    /// setups (Cardiac, Neuro, Obstetrics…).
    private var availableFormats: [PDFExportFormat] {
        var formats: [PDFExportFormat] = [.theatreCard, .fullCard]
        let hasOperations = doctor.isSurgeon
            ? !doctor.surgicalProcedures.isEmpty
            : !doctor.operations.isEmpty
        if hasOperations {
            formats.append(.procedureCard)
        }
        if !doctor.activeSpecialtySetups.isEmpty {
            formats.append(.specialtyCard)
        }
        return formats
    }

    /// The selectable export sections, in document order — surgical sections
    /// for surgeon profiles, anaesthetic sections otherwise.
    private var sectionRows: [(member: PreferenceCardOptions, title: String, icon: String, subtitle: String)] {
        if doctor.isSurgeon {
            return [
                (.consultant, "Surgeon Preferences", "hand.raised", "Gloves, gown, loupes, music, communication"),
                (.standardSetup, "Standard Setup", "checklist", "Trays, sutures, energy settings, positioning"),
                (.specialty, "Specialty Setups", "square.grid.2x2", "What changes for Cath Lab, Endoscopy, Ortho…"),
                (.notes, "Notes", "note.text", "Biography and personal notes")
            ]
        }
        return [
            (.consultant, "Consultant Preferences", "person.text.rectangle", "Glove size, coffee, communication, workflow"),
            (.standardSetup, "Standard Setup", "checklist", "Airway, induction drugs, IV fluids"),
            (.specialty, "Specialty Setups", "square.grid.2x2", "What changes for Cardiac, Paediatric, Neuro…"),
            (.regional, "Regional", "scope", "Blocks this consultant performs"),
            (.neuraxial, "Neuraxial", "figure.walk.motion", "Spinal, epidural, combined"),
            (.notes, "Notes", "note.text", "Biography and personal notes")
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                previewHeader

                formatSection

                if format == .procedureCard {
                    procedurePickerSection
                }

                if format == .specialtyCard {
                    specialtyPickerSection
                }

                if format == .fullCard {
                    Section("Include sections") {
                        ForEach(sectionRows, id: \.member.rawValue) { row in
                            toggleRow(row.member, title: row.title, icon: row.icon, subtitle: row.subtitle)
                        }
                    }

                    Section {
                        if hospitalHasOrientation {
                            toggleRow(
                                .hospitalInfo,
                                title: "Hospital Information",
                                icon: "building.2",
                                subtitle: "Equipment locations, contacts, sick-call — appendix for locums"
                            )
                        } else {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hospital Information").foregroundStyle(.secondary)
                                    Text("Add equipment locations or contacts to the hospital to include them")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                            } icon: {
                                Image(systemName: "building.2").foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Text("Optional appendix")
                    }

                    Section {
                        Toggle(isOn: $includeQR) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("QR code")
                                    Text("Adds a scannable link to open this profile in-app (deep-linking coming soon)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "qrcode").foregroundStyle(Theme.accent)
                            }
                        }
                        .tint(Theme.accent)
                    } header: {
                        Text("Extras")
                    }

                    Section {
                        presetButtons
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: format)
            .sensoryFeedback(.selection, trigger: format)
            .navigationTitle("Export / Print PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        generate()
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate").fontWeight(.semibold)
                        }
                    }
                    .disabled(
                        (format == .fullCard && options.isEmpty)
                            || (format == .procedureCard && selectedProcedureID == nil)
                            || (format == .specialtyCard && selectedSpecialtyID == nil)
                            || isGenerating
                    )
                }
            }
            .sensoryFeedback(.success, trigger: sharePayload?.id) { _, newValue in newValue != nil }
            .sensoryFeedback(.error, trigger: errorMessage) { _, newValue in newValue != nil }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: [payload.url])
            }
            .alert("Export Failed", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if selectedProcedureID == nil {
                    selectedProcedureID = doctor.isSurgeon
                        ? doctor.surgicalProcedures.first?.id
                        : doctor.operations.first?.id
                }
                if selectedSpecialtyID == nil {
                    selectedSpecialtyID = doctor.activeSpecialtySetups.first?.id
                }
            }
        }
    }

    private var previewHeader: some View {
        Section {
            HStack(spacing: 14) {
                DoctorAvatar(doctor: doctor, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(doctor.displayName).font(.headline)
                    if let hospital, !hospital.name.isEmpty {
                        Text(hospital.name).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(format == .theatreCard
                         ? "One A4 page · print, laminate, or AirDrop"
                         : "A4 · print, laminate, or AirDrop")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: format.icon)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 4)
        }
    }

    /// The operation cards this profile can print — surgeon procedures or
    /// anaesthetist operations, flattened to (id, name, summary) rows.
    private var operationRows: [(id: UUID, name: String, summary: String)] {
        if doctor.isSurgeon {
            return doctor.surgicalProcedures.map { ($0.id, $0.displayName, $0.summaryLine) }
        }
        return doctor.operations.map { ($0.id, $0.displayName, $0.summaryLine) }
    }

    /// Picks which operation card to print when exporting a single operation.
    private var procedurePickerSection: some View {
        Section("Operation") {
            ForEach(operationRows, id: \.id) { row in
                Button {
                    selectedProcedureID = row.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cross.case.fill")
                            .font(.body)
                            .foregroundStyle(Color(hex: "2E7DD1"))
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if !row.summary.isEmpty {
                                Text(row.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: selectedProcedureID == row.id ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedProcedureID == row.id ? Theme.accent : Color(.tertiaryLabel))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Picks which specialty setup to print when exporting a single specialty
    /// card (e.g. just the Cardiac list changes).
    private var specialtyPickerSection: some View {
        Section("Specialty") {
            ForEach(doctor.activeSpecialtySetups) { setup in
                Button {
                    selectedSpecialtyID = setup.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: setup.specialty.symbol)
                            .font(.body)
                            .foregroundStyle(setup.specialty.color)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(setup.specialty.rawValue)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("^[\(setup.changeCount) change](inflect: true) vs standard setup")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selectedSpecialtyID == setup.id ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedSpecialtyID == setup.id ? Theme.accent : Color(.tertiaryLabel))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Format chooser: one-page Theatre Card vs full detailed card.
    private var formatSection: some View {
        Section("Format") {
            ForEach(availableFormats) { candidate in
                Button {
                    format = candidate
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: candidate.icon)
                            .font(.body)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.rawValue)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(candidate.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: format == candidate ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(format == candidate ? Theme.accent : Color(.tertiaryLabel))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var presetButtons: some View {
        HStack(spacing: 10) {
            presetButton("Full card", systemImage: "doc.text.fill") {
                options = hospitalHasOrientation ? .everything : .standard
            }
            presetButton("Essentials", systemImage: "doc.text") {
                options = [.consultant, .standardSetup]
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func presetButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: .capsule)
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
                .foregroundStyle(Theme.accentDeep)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ member: PreferenceCardOptions, title: String, icon: String, subtitle: String) -> some View {
        Toggle(isOn: binding(for: member)) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: icon).foregroundStyle(Theme.accent)
            }
        }
        .tint(Theme.accent)
    }

    private func binding(for member: PreferenceCardOptions) -> Binding<Bool> {
        Binding(
            get: { options.contains(member) },
            set: { isOn in
                if isOn { options.insert(member) } else { options.remove(member) }
            }
        )
    }

    private func generate() {
        isGenerating = true
        do {
            let url: URL
            switch format {
            case .theatreCard:
                url = try TheatreCardPDF.writeFile(for: doctor, hospital: hospital, region: settings.region)
            case .procedureCard:
                if let procedure = doctor.surgicalProcedures.first(where: { $0.id == selectedProcedureID }) {
                    url = try SurgeonProcedurePDF.writeFile(procedure: procedure, doctor: doctor, hospital: hospital)
                } else if let procedure = doctor.operations.first(where: { $0.id == selectedProcedureID }) {
                    url = try AnaesthetistProcedurePDF.writeFile(procedure: procedure, doctor: doctor, hospital: hospital)
                } else {
                    isGenerating = false
                    errorMessage = "Choose an operation to print."
                    return
                }
            case .specialtyCard:
                guard let setup = doctor.activeSpecialtySetups.first(where: { $0.id == selectedSpecialtyID }) else {
                    isGenerating = false
                    errorMessage = "Choose a specialty to print."
                    return
                }
                url = try SpecialtyCardPDF.writeFile(setup: setup, doctor: doctor, hospital: hospital)
            case .fullCard:
                url = try ProfilePDF.writeFile(
                    for: doctor,
                    hospital: hospital,
                    region: settings.region,
                    options: options,
                    includeQRCode: includeQR
                )
            }
            isGenerating = false
            sharePayload = SharePayload(url: url)
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
        }
    }
}

/// Identifiable wrapper so the share sheet presents reliably via `.sheet(item:)`.
struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}
