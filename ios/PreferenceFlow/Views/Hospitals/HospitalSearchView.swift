//
//  HospitalSearchView.swift
//  PreferenceFlow
//

import SwiftUI

/// One search bar across a hospital's operating manual — instantly find an
/// equipment location, a contact, a policy, a shared file or a department
/// standard without hunting through individual screens.
struct HospitalSearchView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let hospitalID: UUID

    @State private var query = ""
    @State private var editingEquipment: EquipmentLocation?
    @State private var editingContact: HospitalContact?
    @State private var editingPolicy: PolicyWorkflow?
    @State private var editingFile: SharedFile?
    @State private var editingMachine: AnaestheticMachine?

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let results = makeResults()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if query.isBlank {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Search this hospital",
                        message: "Find equipment locations, contacts, policies, shared files and department standards in one place."
                    )
                    .padding(.top, 40)
                } else if results.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No matches",
                        message: "Nothing here matches \u{201C}\(query)\u{201D}. Try a different term."
                    )
                    .padding(.top, 40)
                } else {
                    if !results.equipment.isEmpty {
                        group("Equipment", icon: "shippingbox.fill", tint: Theme.accent) {
                            ForEach(results.equipment) { item in
                                Button { editingEquipment = item } label: {
                                    resultRow(icon: item.symbol, title: item.title, subtitle: item.location)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !results.machines.isEmpty {
                        group("Anaesthetic Machines", icon: "gauge.with.dots.needle.bottom.50percent", tint: Color(hex: "4A90D9")) {
                            ForEach(results.machines) { m in
                                Button { editingMachine = m } label: {
                                    resultRow(icon: "gauge.with.dots.needle.bottom.50percent", title: m.displayName, subtitle: m.location)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !results.contacts.isEmpty {
                        group("Contacts", icon: "phone.fill", tint: Color(hex: "E08B3E")) {
                            ForEach(results.contacts) { c in
                                Button { editingContact = c } label: {
                                    resultRow(icon: c.symbol, title: c.roleTitle, subtitle: [c.name, c.phone].filter { !$0.isBlank }.joined(separator: " \u{00B7} "))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !results.policies.isEmpty {
                        group("Policies", icon: "doc.text.fill", tint: Color(hex: "9B7CC9")) {
                            ForEach(results.policies) { p in
                                Button { editingPolicy = p } label: {
                                    resultRow(icon: "doc.text.fill", title: p.title.isBlank ? "Untitled policy" : p.title, subtitle: p.body)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !results.files.isEmpty {
                        group("Shared Files", icon: "folder.fill", tint: Color(hex: "8A8F98")) {
                            ForEach(results.files) { f in
                                Button { editingFile = f } label: {
                                    resultRow(icon: "doc.fill", title: f.name.isBlank ? "Untitled file" : f.name, subtitle: f.notes)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !results.standards.isEmpty {
                        group("Standards", icon: "doc.on.doc.fill", tint: Color(hex: "5E7CE2")) {
                            ForEach(results.standards) { t in
                                NavigationLink {
                                    DepartmentTemplatesTab(hospitalID: hospitalID)
                                        .navigationTitle("Standards").navigationBarTitleDisplayMode(.inline)
                                        .background(Color(.systemGroupedBackground))
                                } label: {
                                    resultRow(icon: t.icon, title: t.name.isBlank ? "Untitled standard" : t.name, subtitle: "Department standard")
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Equipment, contacts, policies\u{2026}")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
        .sheet(item: $editingEquipment) { item in
            EquipmentLocationEditView(hospitalID: hospitalID, item: item)
        }
        .sheet(item: $editingContact) { c in
            ContactEditView(hospitalID: hospitalID, contact: c)
        }
        .sheet(item: $editingPolicy) { p in
            PolicyEditView(hospitalID: hospitalID, policy: p)
        }
        .sheet(item: $editingFile) { f in
            SharedFileEditView(hospitalID: hospitalID, file: f)
        }
        .sheet(item: $editingMachine) { m in
            MachineEditView(hospitalID: hospitalID, machine: m, isNew: false)
        }
    }

    // MARK: - Results

    private struct Results {
        var equipment: [EquipmentLocation] = []
        var machines: [AnaestheticMachine] = []
        var contacts: [HospitalContact] = []
        var policies: [PolicyWorkflow] = []
        var files: [SharedFile] = []
        var standards: [DepartmentTemplate] = []

        var isEmpty: Bool {
            equipment.isEmpty && machines.isEmpty && contacts.isEmpty && policies.isEmpty
                && files.isEmpty && standards.isEmpty
        }
    }

    private func makeResults() -> Results {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isBlank, let h = hospital else { return Results() }
        let o = h.orientationOrEmpty
        func hit(_ values: String...) -> Bool {
            values.contains { $0.localizedCaseInsensitiveContains(q) }
        }
        var r = Results()
        r.equipment = o.equipmentLocations.filter { hit($0.title, $0.location, $0.accessInstructions, $0.notes) }
        r.machines = o.anaestheticMachines.filter {
            hit($0.displayName, $0.model.manufacturer, $0.location, $0.notes,
                $0.checkDocuments.map(\.title).joined(separator: " "))
        }
        r.contacts = o.contacts.filter { hit($0.roleTitle, $0.name, $0.phone, $0.email, $0.notes) }
        r.policies = o.policies.filter { hit($0.title, $0.body) }
        r.files = o.sharedFiles.filter { hit($0.name, $0.notes) }
        r.standards = store.templates(forHospital: hospitalID).filter { hit($0.name) }
        return r
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func group<Content: View>(_ title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title, icon: icon)
            VStack(spacing: 8) { content() }
        }
    }

    private func resultRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.subheadline).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                if !subtitle.isBlank {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card(padding: 12)
    }
}
