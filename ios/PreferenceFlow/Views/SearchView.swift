//
//  SearchView.swift
//  PreferenceFlow
//

import SwiftUI

/// Global search across providers, hospitals, procedures, regional blocks & notes.
struct SearchView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var query = ""
    @State private var hospitalFilter: UUID?
    @State private var specialtyFilter: Subspecialty?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    filterBar

                    if query.isBlank && hospitalFilter == nil && specialtyFilter == nil {
                        idleState
                    } else {
                        results
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Providers, hospitals, procedures…")
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Button("All hospitals") { hospitalFilter = nil }
                        ForEach(store.hospitals) { h in
                            Button(h.name) { hospitalFilter = h.id }
                        }
                    } label: {
                        FilterPill(
                            text: store.hospital(id: hospitalFilter)?.name ?? "Hospital",
                            active: hospitalFilter != nil,
                            icon: "building.2"
                        )
                    }
                    Menu {
                        Button("All specialties") { specialtyFilter = nil }
                        ForEach(Subspecialty.allCases) { s in
                            Button(s.rawValue) { specialtyFilter = s }
                        }
                    } label: {
                        FilterPill(
                            text: specialtyFilter?.rawValue ?? "Specialty",
                            active: specialtyFilter != nil,
                            icon: "square.grid.2x2"
                        )
                    }
                    if hospitalFilter != nil || specialtyFilter != nil {
                        Button {
                            hospitalFilter = nil
                            specialtyFilter = nil
                        } label: {
                            FilterPill(text: "Clear", active: false, icon: "xmark")
                        }
                    }
                }
            }
        }
    }

    // MARK: Results

    private var matchingDoctors: [Doctor] {
        store.doctors.filter { doc in
            if let hospitalFilter, doc.hospitalId != hospitalFilter { return false }
            if let specialtyFilter, !doc.subspecialties.contains(specialtyFilter) { return false }
            guard !query.isBlank else { return true }
            return doc.fullName.localizedCaseInsensitiveContains(query)
                || doc.role.localizedCaseInsensitiveContains(query)
                || doc.department.localizedCaseInsensitiveContains(query)
                || doc.biography.localizedCaseInsensitiveContains(query)
                || doc.personalNotes.localizedCaseInsensitiveContains(query)
                || doc.subspecialties.contains { $0.rawValue.localizedCaseInsensitiveContains(query) }
        }
    }

    private var matchingHospitals: [Hospital] {
        guard !query.isBlank, specialtyFilter == nil else { return [] }
        return store.hospitals.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.city.localizedCaseInsensitiveContains(query)
            || $0.department.localizedCaseInsensitiveContains(query)
        }
    }

    /// Hospital scope for orientation matches, respecting the hospital filter.
    private var hospitalScope: [Hospital] {
        guard specialtyFilter == nil else { return [] }
        if let hospitalFilter { return store.hospitals.filter { $0.id == hospitalFilter } }
        return store.hospitals
    }

    /// Equipment locations (e.g. "MH kit") across hospital orientation guides.
    private var matchingEquipmentLocations: [(hospital: Hospital, item: EquipmentLocation)] {
        guard !query.isBlank else { return [] }
        return hospitalScope.flatMap { h in
            h.orientationOrEmpty.equipmentLocations
                .filter {
                    $0.title.localizedCaseInsensitiveContains(query)
                    || $0.location.localizedCaseInsensitiveContains(query)
                    || $0.notes.localizedCaseInsensitiveContains(query)
                }
                .map { (h, $0) }
        }
    }

    /// Hospital contacts across orientation guides.
    private var matchingContacts: [(hospital: Hospital, contact: HospitalContact)] {
        guard !query.isBlank else { return [] }
        return hospitalScope.flatMap { h in
            h.orientationOrEmpty.contacts
                .filter {
                    $0.roleTitle.localizedCaseInsensitiveContains(query)
                    || $0.name.localizedCaseInsensitiveContains(query)
                }
                .map { (h, $0) }
        }
    }

    /// Sick-call instructions matched by keyword.
    private var matchingSickCall: [Hospital] {
        guard !query.isBlank else { return [] }
        let keys = ["sick", "illness", "call in", "unwell", "absence"]
        let isSickQuery = keys.contains { query.localizedCaseInsensitiveContains($0) }
        return hospitalScope.filter { h in
            let s = h.orientationOrEmpty.sickCall
            guard s.hasContent else { return false }
            return isSickQuery
                || s.whoToContact.localizedCaseInsensitiveContains(query)
                || s.notes.localizedCaseInsensitiveContains(query)
        }
    }

    private var matchingProcedures: [(doctor: Doctor, procedure: ProcedureTemplate)] {
        guard !query.isBlank else { return [] }
        return matchingDoctorsScope.flatMap { doc in
            doc.operations
                .filter { $0.name.localizedCaseInsensitiveContains(query) || $0.specialNotes.localizedCaseInsensitiveContains(query) }
                .map { (doc, $0) }
        }
    }

    private var matchingBlocks: [(doctor: Doctor, block: RegionalBlock)] {
        guard !query.isBlank else { return [] }
        return matchingDoctorsScope.flatMap { doc in
            doc.regionalBlocks
                .filter { $0.name.localizedCaseInsensitiveContains(query) || $0.drug.localizedCaseInsensitiveContains(query) }
                .map { (doc, $0) }
        }
    }

    private var matchingKnowledge: [KnowledgeArticle] {
        guard !query.isBlank else { return [] }
        return KnowledgeLibrary.all.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    /// Imported PDF documents matched by title, category or extracted text.
    private var matchingDocuments: [KnowledgeDocument] {
        guard !query.isBlank else { return [] }
        return store.documents.filter { doc in
            if let hospitalFilter, doc.hospitalId != hospitalFilter { return false }
            return doc.title.localizedCaseInsensitiveContains(query)
                || doc.category.rawValue.localizedCaseInsensitiveContains(query)
                || doc.textMatches(query)
        }
    }

    /// Providers whose drug preferences include an agent matching the query.
    private var matchingMedications: [(doctor: Doctor, agent: String)] {
        guard !query.isBlank else { return [] }
        return matchingDoctorsScope.flatMap { doc -> [(Doctor, String)] in
            let agents = (doc.adultDrugs?.allSelectedAgents ?? []) + (doc.paediatricDrugs?.allSelectedAgents ?? [])
            let unique = Array(Set(agents)).filter { $0.localizedCaseInsensitiveContains(query) }
            return unique.map { (doc, $0) }
        }
    }

    /// Providers whose procedure equipment checklists match the query.
    private var matchingEquipment: [(doctor: Doctor, item: String)] {
        guard !query.isBlank else { return [] }
        return matchingDoctorsScope.flatMap { doc -> [(Doctor, String)] in
            let items = doc.operations.flatMap { $0.equipmentChecklist.map(\.text) }
            let unique = Array(Set(items)).filter { $0.localizedCaseInsensitiveContains(query) }
            return unique.map { (doc, $0) }
        }
    }

    /// Scope used for nested matches, respecting the hospital filter.
    private var matchingDoctorsScope: [Doctor] {
        store.doctors.filter { doc in
            if let hospitalFilter, doc.hospitalId != hospitalFilter { return false }
            if let specialtyFilter, !doc.subspecialties.contains(specialtyFilter) { return false }
            return true
        }
    }

    private var hasAnyResults: Bool {
        !matchingDoctors.isEmpty || !matchingHospitals.isEmpty || !matchingProcedures.isEmpty
            || !matchingBlocks.isEmpty || !matchingKnowledge.isEmpty
            || !matchingMedications.isEmpty || !matchingEquipment.isEmpty
            || !matchingEquipmentLocations.isEmpty || !matchingContacts.isEmpty
            || !matchingSickCall.isEmpty || !matchingDocuments.isEmpty
    }

    @ViewBuilder
    private var results: some View {
        if !hasAnyResults {
            EmptyStateView(icon: "magnifyingglass", title: "No matches", message: "Try a different search or clear your filters.")
                .padding(.top, 40)
        } else {
            if !matchingDoctors.isEmpty {
                resultGroup("Providers", icon: "person.text.rectangle") {
                    ForEach(matchingDoctors) { doc in
                        NavigationLink {
                            DoctorDetailView(doctorID: doc.id)
                        } label: {
                            DoctorRow(doctor: doc, hospitalName: store.hospital(id: doc.hospitalId)?.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingHospitals.isEmpty {
                resultGroup("Hospitals", icon: "building.2") {
                    ForEach(matchingHospitals) { h in
                        NavigationLink {
                            HospitalDetailView(hospitalID: h.id)
                        } label: {
                            HospitalRow(hospital: h, count: store.doctorCount(forHospital: h.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingProcedures.isEmpty {
                resultGroup("Procedures", icon: "cross.case") {
                    ForEach(matchingProcedures, id: \.procedure.id) { pair in
                        NavigationLink {
                            DoctorDetailView(doctorID: pair.doctor.id)
                        } label: {
                            searchSubRow(title: pair.procedure.name, subtitle: pair.doctor.displayName, icon: "cross.case.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingBlocks.isEmpty {
                resultGroup("Regional Blocks", icon: "scope") {
                    ForEach(matchingBlocks, id: \.block.id) { pair in
                        NavigationLink {
                            DoctorDetailView(doctorID: pair.doctor.id)
                        } label: {
                            searchSubRow(title: pair.block.name, subtitle: pair.doctor.displayName, icon: "scope")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingMedications.isEmpty {
                resultGroup("Medications", icon: "cross.vial") {
                    ForEach(Array(matchingMedications.enumerated()), id: \.offset) { _, pair in
                        NavigationLink {
                            DoctorDetailView(doctorID: pair.doctor.id)
                        } label: {
                            searchSubRow(title: pair.agent, subtitle: pair.doctor.displayName, icon: "cross.vial.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingEquipment.isEmpty {
                resultGroup("Equipment", icon: "shippingbox") {
                    ForEach(Array(matchingEquipment.enumerated()), id: \.offset) { _, pair in
                        NavigationLink {
                            DoctorDetailView(doctorID: pair.doctor.id)
                        } label: {
                            searchSubRow(title: pair.item, subtitle: pair.doctor.displayName, icon: "shippingbox.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingEquipmentLocations.isEmpty {
                resultGroup("Equipment Locations", icon: "mappin.and.ellipse") {
                    ForEach(matchingEquipmentLocations, id: \.item.id) { pair in
                        NavigationLink {
                            HospitalDetailView(hospitalID: pair.hospital.id)
                        } label: {
                            searchSubRow(
                                title: pair.item.title,
                                subtitle: "\(pair.hospital.name)\(pair.item.location.isBlank ? "" : " → \(pair.item.location)")",
                                icon: pair.item.symbol
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingContacts.isEmpty {
                resultGroup("Hospital Contacts", icon: "person.crop.rectangle.stack") {
                    ForEach(matchingContacts, id: \.contact.id) { pair in
                        NavigationLink {
                            HospitalDetailView(hospitalID: pair.hospital.id)
                        } label: {
                            searchSubRow(
                                title: pair.contact.roleTitle,
                                subtitle: "\(pair.hospital.name)\(pair.contact.name.isBlank ? "" : " → \(pair.contact.name)")",
                                icon: pair.contact.symbol
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingSickCall.isEmpty {
                resultGroup("Sick Call", icon: "phone.badge.waveform") {
                    ForEach(matchingSickCall) { h in
                        NavigationLink {
                            HospitalDetailView(hospitalID: h.id)
                        } label: {
                            searchSubRow(
                                title: "Calling in sick",
                                subtitle: "\(h.name)\(h.orientationOrEmpty.sickCall.whoToContact.isBlank ? "" : " → \(h.orientationOrEmpty.sickCall.whoToContact)")",
                                icon: "phone.badge.waveform"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingDocuments.isEmpty {
                resultGroup("Documents", icon: "doc.text") {
                    ForEach(matchingDocuments) { document in
                        NavigationLink {
                            DocumentReaderView(documentID: document.id)
                        } label: {
                            searchSubRow(
                                title: document.displayTitle,
                                subtitle: [document.category.rawValue, store.hospital(id: document.hospitalId)?.name].compactMap { $0 }.joined(separator: " · "),
                                icon: document.category.symbol
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !matchingKnowledge.isEmpty {
                resultGroup("Knowledge Base", icon: "books.vertical") {
                    ForEach(matchingKnowledge) { article in
                        NavigationLink {
                            KnowledgeArticleView(article: article)
                        } label: {
                            searchSubRow(title: article.title, subtitle: article.category.rawValue, icon: article.symbol)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func resultGroup<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title, icon: icon)
            content()
        }
    }

    private func searchSubRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.isBlank ? "Untitled" : title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .card(padding: 14)
    }

    private var idleState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundStyle(Theme.accent)
            }
            Text("Search everything")
                .font(.title3.weight(.semibold))
            Text("Find providers, hospitals, procedures, regional blocks and notes instantly.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

struct FilterPill: View {
    let text: String
    let active: Bool
    var icon: String?
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.caption2) }
            Text(text).font(.subheadline.weight(.medium))
            Image(systemName: "chevron.down").font(.caption2)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(active ? Theme.accent : Color(.secondarySystemGroupedBackground), in: .capsule)
        .foregroundStyle(active ? .white : .primary)
    }
}
