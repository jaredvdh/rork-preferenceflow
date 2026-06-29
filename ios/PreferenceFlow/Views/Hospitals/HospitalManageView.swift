//
//  HospitalManageView.swift
//  PreferenceFlow
//

import SwiftUI

/// Single "Edit Hospital" experience — one hub for every editable part of a
/// hospital: details, department standards, equipment, contacts, policies,
/// orientation and shared files. Mirrors the consultant single-edit pattern,
/// kept deliberately lightweight since hospitals are edited less often.
struct HospitalManageView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let hospitalID: UUID

    // Detail fields are held locally and saved on Done, merged onto the freshest
    // hospital so section edits made in this same session are never clobbered.
    @State private var name: String = ""
    @State private var city: String = ""
    @State private var country: String = ""
    @State private var department: String = ""
    @State private var notes: String = ""
    @State private var loaded = false

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hospital details") {
                    LabeledField(label: "Name", text: $name, placeholder: "Christchurch Hospital", icon: "building.2")
                    LabeledField(label: "City", text: $city, placeholder: "Christchurch", icon: "mappin.and.ellipse")
                    LabeledField(label: "Country", text: $country, placeholder: "New Zealand", icon: "globe")
                    LabeledField(label: "Department", text: $department, placeholder: "Anaesthesia", icon: "cross.case")
                    NotesField(label: "Site notes", text: $notes)
                }

                Section {
                    manageRow(
                        destination: AnyView(
                            DepartmentTemplatesTab(hospitalID: hospitalID)
                                .navigationTitle("Department Standards").navigationBarTitleDisplayMode(.inline)
                                .background(Color(.systemGroupedBackground))
                        ),
                        icon: "doc.on.doc.fill", tint: Color(hex: "5E7CE2"),
                        title: "Department Standards",
                        subtitle: "Default setups consultants inherit",
                        count: store.templates(forHospital: hospitalID).count
                    )
                    manageRow(
                        destination: AnyView(
                            EquipmentLocationsTab(hospitalID: hospitalID)
                                .navigationTitle("Equipment & Locations").navigationBarTitleDisplayMode(.inline)
                                .background(Color(.systemGroupedBackground))
                        ),
                        icon: "shippingbox.fill", tint: Theme.accent,
                        title: "Equipment Locations",
                        subtitle: "Where to find critical kit",
                        count: orientation.equipmentLocations.count
                    )
                    manageRow(
                        destination: AnyView(
                            HospitalContactsTab(hospitalID: hospitalID)
                                .navigationTitle("Contacts").navigationBarTitleDisplayMode(.inline)
                                .background(Color(.systemGroupedBackground))
                        ),
                        icon: "phone.fill", tint: Color(hex: "E08B3E"),
                        title: "Contacts",
                        subtitle: "Sick call · who to call",
                        count: orientation.contacts.count
                    )
                    manageRow(
                        destination: AnyView(
                            HospitalPoliciesTab(hospitalID: hospitalID)
                                .navigationTitle("Policies & Guidelines").navigationBarTitleDisplayMode(.inline)
                                .background(Color(.systemGroupedBackground))
                        ),
                        icon: "doc.text.fill", tint: Color(hex: "9B7CC9"),
                        title: "Policies",
                        subtitle: "Local workflows & routines",
                        count: orientation.policies.count
                    )
                    manageRow(
                        destination: AnyView(
                            HospitalOrientationScreen(hospitalID: hospitalID)
                                .navigationTitle("Orientation").navigationBarTitleDisplayMode(.inline)
                                .background(Color(.systemGroupedBackground))
                        ),
                        icon: "map.fill", tint: Color(hex: "2FA98C"),
                        title: "Orientation",
                        subtitle: "Sick call · site notes",
                        count: nil
                    )
                    manageRow(
                        destination: AnyView(
                            HospitalFilesTab(hospitalID: hospitalID)
                                .navigationTitle("Shared Files").navigationBarTitleDisplayMode(.inline)
                                .background(Color(.systemGroupedBackground))
                        ),
                        icon: "folder.fill", tint: Color(hex: "8A8F98"),
                        title: "Shared Files",
                        subtitle: "Packs, maps & checklists",
                        count: orientation.sharedFiles.count
                    )
                } header: {
                    Text("Manage")
                } footer: {
                    Text("Everything about this hospital lives here. Changes in each section save as you go.")
                }
            }
            .navigationTitle("Edit Hospital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveDetails(); dismiss() }
                        .disabled(name.isBlank)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private var orientation: HospitalOrientation { hospital?.orientationOrEmpty ?? HospitalOrientation() }

    private func manageRow(destination: AnyView, icon: String, tint: Color, title: String, subtitle: String, count: Int?) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.subheadline).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let count {
                    Text("\(count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func loadIfNeeded() {
        guard !loaded, let h = hospital else { return }
        name = h.name
        city = h.city
        country = h.country
        department = h.department
        notes = h.notes
        loaded = true
    }

    private func saveDetails() {
        guard var h = hospital else { return }
        h.name = name
        h.city = city
        h.country = country
        h.department = department
        h.notes = notes
        store.upsert(h)
    }
}
