//
//  OrientationTabs.swift
//  PreferenceFlow
//

import SwiftUI

// MARK: - Equipment Locations

struct EquipmentLocationsTab: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var creating = false

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let items = hospital?.orientationOrEmpty.equipmentLocations ?? []
        let grouped = EquipmentCategory.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { category -> (EquipmentCategory, [EquipmentLocation])? in
                let matches = items.filter { $0.kind.category == category }
                return matches.isEmpty ? nil : (category, matches)
            }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                addButton(title: "Add equipment location")

                if items.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No equipment locations",
                        message: "Add where to find the difficult airway trolley, MH kit, rapid infuser and more."
                    )
                } else {
                    ForEach(grouped, id: \.0) { category, matches in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                SectionLabel(category.rawValue, icon: category.symbol)
                                Text("\(matches.count)")
                                    .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            }
                            ForEach(matches) { item in
                                NavigationLink(value: item) {
                                    EquipmentLocationCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { delete(item) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationDestination(for: EquipmentLocation.self) { item in
            EquipmentLocationDetailView(hospitalID: hospitalID, item: item)
        }
        .sheet(isPresented: $creating) {
            EquipmentLocationEditView(hospitalID: hospitalID, item: EquipmentLocation())
        }
    }

    private func addButton(title: String) -> some View {
        Button { creating = true } label: {
            Label(title, systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private func delete(_ item: EquipmentLocation) {
        guard var h = hospital else { return }
        var o = h.orientationOrEmpty
        o.equipmentLocations.removeAll { $0.id == item.id }
        h.orientation = o
        store.upsert(h)
    }
}

private struct EquipmentLocationCard: View {
    let item: EquipmentLocation

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 46, height: 46)
                Image(systemName: item.symbol).font(.title3).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline)
                if !item.location.isBlank {
                    Label(item.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !item.accessInstructions.isBlank {
                    Text(item.accessInstructions).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if let data = item.photoData, let image = UIImage(data: data) {
                Color(.secondarySystemBackground)
                    .frame(width: 56, height: 56)
                    .overlay { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false) }
                    .clipShape(.rect(cornerRadius: Theme.cornerSmall))
            }
        }
        .card()
    }
}

// MARK: - Contacts

struct HospitalContactsTab: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var editingContact: HospitalContact?
    @State private var editingSickCall = false
    @State private var creating = false

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let o = hospital?.orientationOrEmpty ?? HospitalOrientation()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Sick call workflow card (always visible, tap to edit).
                Button { editingSickCall = true } label: { SickCallEditableCard(info: o.sickCall) }
                    .buttonStyle(.plain)

                SectionLabel("Key contacts", icon: "person.crop.rectangle.stack")
                    .padding(.top, 4)

                Button { creating = true } label: {
                    Label("Add contact", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
                .buttonStyle(.plain)

                if o.contacts.isEmpty {
                    Text("No contacts yet. Add the charge technician, duty anaesthetist, pharmacy, blood bank and more.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).card()
                } else {
                    ForEach(groupedContacts(o.contacts), id: \.0) { category, matches in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(category.rawValue, icon: category.symbol).padding(.top, 2)
                            ForEach(matches) { contact in
                                Button { editingContact = contact } label: { ContactCard(contact: contact) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) { delete(contact) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $creating) {
            ContactEditView(hospitalID: hospitalID, contact: HospitalContact())
        }
        .sheet(item: $editingContact) { contact in
            ContactEditView(hospitalID: hospitalID, contact: contact)
        }
        .sheet(isPresented: $editingSickCall) {
            SickCallEditView(hospitalID: hospitalID, info: o.sickCall)
        }
    }

    private func groupedContacts(_ contacts: [HospitalContact]) -> [(ContactCategory, [HospitalContact])] {
        ContactCategory.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { category in
                let matches = contacts.filter { $0.role.category == category }
                return matches.isEmpty ? nil : (category, matches)
            }
    }

    private func delete(_ contact: HospitalContact) {
        guard var h = hospital else { return }
        var o = h.orientationOrEmpty
        o.contacts.removeAll { $0.id == contact.id }
        h.orientation = o
        store.upsert(h)
    }
}

private struct ContactCard: View {
    let contact: HospitalContact

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 46, height: 46)
                Image(systemName: contact.symbol).font(.title3).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.roleTitle).font(.headline)
                if !contact.name.isBlank {
                    Text(contact.name).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    if !contact.phone.isBlank { miniTag(contact.phone, "phone.fill") }
                    if !contact.extensionNumber.isBlank { miniTag("x\(contact.extensionNumber)", "phone.connection") }
                    if !contact.pager.isBlank { miniTag(contact.pager, "dot.radiowaves.left.and.right") }
                }
            }
            Spacer(minLength: 0)
            if let url = telURL {
                Link(destination: url) {
                    Image(systemName: "phone.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                }
            }
        }
        .card()
    }

    private var telURL: URL? {
        let digits = contact.phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    private func miniTag(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.accentDeep)
    }
}

private struct SickCallEditableCard: View {
    let info: SickCallInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Calling in sick", systemImage: "phone.badge.waveform")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentDeep)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            if info.hasContent {
                VStack(spacing: 6) {
                    ValueRow(label: "Contact", value: info.whoToContact, icon: "person")
                    ValueRow(label: "Phone", value: info.phone, icon: "phone")
                    ValueRow(label: "Notice", value: info.noticePeriod, icon: "clock")
                }
            } else {
                Text("Tap to set how to report illness at this site.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

// MARK: - Policies / Workflows

struct HospitalPoliciesTab: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var editingPolicy: PolicyWorkflow?
    @State private var creating = false
    @State private var query = ""

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let all = hospital?.orientationOrEmpty.policies ?? []
        let items = query.isBlank ? all : all.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button { creating = true } label: {
                    Label("Add policy or workflow", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
                .buttonStyle(.plain)

                if items.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: query.isBlank ? "No policies yet" : "No matching policies",
                        message: query.isBlank
                            ? "Capture local workflows — blood ordering, briefing routine, emergency call process."
                            : "Nothing matches \u{201C}\(query)\u{201D}."
                    )
                } else {
                    ForEach(items) { policy in
                        Button { editingPolicy = policy } label: { PolicyCard(policy: policy) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { delete(policy) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }

                DisclaimerNote()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search policies")
        .sheet(isPresented: $creating) {
            PolicyEditView(hospitalID: hospitalID, policy: PolicyWorkflow())
        }
        .sheet(item: $editingPolicy) { policy in
            PolicyEditView(hospitalID: hospitalID, policy: policy)
        }
    }

    private func delete(_ policy: PolicyWorkflow) {
        guard var h = hospital else { return }
        var o = h.orientationOrEmpty
        o.policies.removeAll { $0.id == policy.id }
        h.orientation = o
        store.upsert(h)
    }
}

private struct PolicyCard: View {
    let policy: PolicyWorkflow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(policy.title.isBlank ? "Untitled policy" : policy.title).font(.headline)
            if !policy.body.isBlank {
                Text(policy.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
            }
            if !policy.link.isBlank {
                LinkRow(label: "Link", value: policy.link)
            }
        }
        .card()
    }
}

// MARK: - Shared Files

struct HospitalFilesTab: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var editingFile: SharedFile?
    @State private var creating = false
    @State private var query = ""

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let all = hospital?.orientationOrEmpty.sharedFiles ?? []
        let items = query.isBlank ? all : all.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.notes.localizedCaseInsensitiveContains(query)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button { creating = true } label: {
                    Label("Add shared file or link", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
                .buttonStyle(.plain)

                if items.isEmpty {
                    EmptyStateView(
                        icon: "folder",
                        title: query.isBlank ? "No shared files" : "No matching files",
                        message: query.isBlank
                            ? "Reference orientation packs, maps or checklists by name and link. Full attachments arrive with cloud sync."
                            : "Nothing matches \u{201C}\(query)\u{201D}."
                    )
                } else {
                    ForEach(items) { file in
                        Button { editingFile = file } label: { FileCard(file: file) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { delete(file) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search files")
        .sheet(isPresented: $creating) {
            SharedFileEditView(hospitalID: hospitalID, file: SharedFile())
        }
        .sheet(item: $editingFile) { file in
            SharedFileEditView(hospitalID: hospitalID, file: file)
        }
    }

    private func delete(_ file: SharedFile) {
        guard var h = hospital else { return }
        var o = h.orientationOrEmpty
        o.sharedFiles.removeAll { $0.id == file.id }
        h.orientation = o
        store.upsert(h)
    }
}

private struct FileCard: View {
    let file: SharedFile

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14)).frame(width: 46, height: 46)
                Image(systemName: "doc.fill").font(.title3).foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name.isBlank ? "Untitled file" : file.name).font(.headline)
                if !file.notes.isBlank {
                    Text(file.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if !file.link.isBlank {
                    LinkRow(label: "Open", value: file.link)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .card()
    }
}
