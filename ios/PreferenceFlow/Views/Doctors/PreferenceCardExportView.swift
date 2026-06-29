//
//  PreferenceCardExportView.swift
//  PreferenceFlow
//

import SwiftUI

/// Lets the user choose which sections to include, then generates and shares a
/// polished "Consultant Preference Card" PDF. Presented from the profile "…"
/// menu and the Share tab.
struct PreferenceCardExportView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let doctor: Doctor

    @State private var options: PreferenceCardOptions = .standard
    @State private var includeQR = false
    @State private var sharePayload: SharePayload?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var hospital: Hospital? { store.hospital(id: doctor.hospitalId) }
    private var hospitalHasOrientation: Bool { hospital?.orientationOrEmpty.hasContent ?? false }

    /// The selectable export sections, in document order.
    private var sectionRows: [(member: PreferenceCardOptions, title: String, icon: String, subtitle: String)] {
        [
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
            .navigationTitle("Export Preference Card")
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
                    .disabled(options.isEmpty || isGenerating)
                }
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: [payload.url])
            }
            .alert("Export Failed", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
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
                    Text("A4 · print, laminate, or AirDrop")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "doc.richtext.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 4)
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
            let url = try ProfilePDF.writeFile(
                for: doctor,
                hospital: hospital,
                region: settings.region,
                options: options,
                includeQRCode: includeQR
            )
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
