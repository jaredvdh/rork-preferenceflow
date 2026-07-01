//
//  DoctorsView.swift
//  PreferenceFlow
//

import SwiftUI
import UniformTypeIdentifiers

/// Providers tab — search-first directory designed so a technician can reach
/// any consultant's preference card in under three taps: open the tab (search
/// is already focused), type a name, tap the result. Recents and Favourites
/// give one-tap access to frequently worked-with consultants.
struct DoctorsView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var creatingNew = false
    @State private var quickAdding = false
    /// Result from Quick Add, consumed on sheet dismiss to navigate appropriately.
    @State private var quickAddResult: (id: UUID, openEdit: Bool)?
    @State private var query = ""
    @State private var showingSettings = false
    @State private var path = NavigationPath()
    @FocusState private var searchFocused: Bool

    // Peer-to-peer import (AirDrop / Messages / Files) — no cloud sync.
    @State private var showFileImporter = false
    @State private var pendingImport: PreferenceExport?
    @State private var duplicates: [Doctor] = []
    @State private var showResolution = false
    @State private var fuzzyMatches: [Doctor] = []
    @State private var showFuzzyResolution = false
    @State private var importMessage: String?
    @State private var importIsError = false

    /// Results matching the current query (whole list when query is blank).
    private var filtered: [Doctor] {
        guard !query.isBlank else { return store.doctors }
        let q = query
        return store.doctors.filter {
            $0.fullName.localizedCaseInsensitiveContains(q)
            || $0.role.localizedCaseInsensitiveContains(q)
            || $0.department.localizedCaseInsensitiveContains(q)
            || $0.subspecialties.contains { $0.rawValue.localizedCaseInsensitiveContains(q) }
        }
    }

    private var favourites: [Doctor] {
        settings.favouriteDoctorIds.compactMap { store.doctor(id: $0) }
    }

    private var recents: [Doctor] {
        settings.recentDoctorIds
            .compactMap { store.doctor(id: $0) }
            .filter { !settings.favouriteDoctorIds.contains($0.id) }
            .prefix(3)
            .map { $0 }
    }

    private var isSearching: Bool { !query.isBlank }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.doctors.isEmpty {
                    EmptyStateView(
                        icon: "person.text.rectangle",
                        title: "No \(settings.region.providerPlural.lowercased()) yet",
                        message: "Create a profile to start saving theatre setup preferences.",
                        actionTitle: "Add \(settings.region.provider)",
                        action: { creatingNew = true }
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle(settings.region.providerPlural)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { quickAdding = true } label: {
                            Label("Quick Add", systemImage: "bolt.fill")
                        }
                        Button { creatingNew = true } label: {
                            Label("New \(settings.region.provider)", systemImage: "person.crop.circle.badge.plus")
                        }
                        Button { showFileImporter = true } label: {
                            Label("Import Profile…", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $creatingNew) {
                NewConsultantFlowView()
            }
            .sheet(isPresented: $quickAdding, onDismiss: consumeQuickAddResult) {
                QuickAddConsultantView { id, openEdit in
                    quickAddResult = (id, openEdit)
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView(embedInStack: false) }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .confirmationDialog(
                duplicateTitle,
                isPresented: $showResolution,
                titleVisibility: .visible
            ) {
                Button("Replace") { resolveImport(.replace) }
                Button("Keep both") { resolveImport(.saveAsCopy) }
                Button("Cancel", role: .cancel) { resolveImport(.cancel) }
            } message: {
                Text(duplicateMessage)
            }
            .confirmationDialog(
                fuzzyTitle,
                isPresented: $showFuzzyResolution,
                titleVisibility: .visible
            ) {
                Button("Import as new") { resolveFuzzy(replace: false) }
                Button("Replace existing") { resolveFuzzy(replace: true) }
                Button("Cancel", role: .cancel) { cancelFuzzy() }
            } message: {
                Text(fuzzyMessage)
            }
            .alert(importIsError ? "Import Error" : "Profile Imported", isPresented: .constant(importMessage != nil)) {
                Button("OK") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .navigationDestination(for: UUID.self) { id in
                DoctorDetailView(doctorID: id)
            }
            .navigationDestination(for: ConsultantEditRoute.self) { route in
                DoctorDetailView(doctorID: route.id, startEditing: true)
            }
        }
        .onChange(of: settings.pendingDeepLinkDoctorID) { _, id in
            consumeDeepLink(id)
        }
        .onAppear { consumeDeepLink(settings.pendingDeepLinkDoctorID) }
    }

    /// After Quick Add closes, jump to the new profile — straight into the editor
    /// if the technician chose to add full details now, otherwise to the card.
    private func consumeQuickAddResult() {
        guard let result = quickAddResult else { return }
        quickAddResult = nil
        if result.openEdit {
            path.append(ConsultantEditRoute(id: result.id))
        } else {
            path.append(result.id)
        }
    }

    // MARK: - Peer-to-peer import

    /// Wording for the duplicate-resolution prompt, naming the consultant when a
    /// single profile conflicts.
    private var duplicateTitle: String {
        if duplicates.count == 1, let only = duplicates.first {
            return "You already have \(only.displayName)"
        }
        return "You already have these profiles"
    }

    private var duplicateMessage: String {
        if duplicates.count == 1, let only = duplicates.first {
            return "You already have a profile for \(only.displayName). Replace it, or keep both?"
        }
        return "\(duplicates.count) imported profiles match ones you already have. Replace them, or keep both?"
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let parsed = try store.parseImport(from: url)
                guard parsed.schemaVersion <= PreferenceExport.currentSchemaVersion else {
                    failImport("This file was created by a newer version of PreferenceFlow. Please update the app.")
                    return
                }
                pendingImport = parsed
                let exact = store.existingDoctorIDs(in: parsed)
                if !exact.isEmpty {
                    duplicates = exact
                    showResolution = true
                } else {
                    let fuzzy = store.fuzzyNameMatches(in: parsed)
                    if fuzzy.isEmpty {
                        resolveImport(.replace) // pure add — no conflicts
                    } else {
                        fuzzyMatches = fuzzy
                        showFuzzyResolution = true
                    }
                }
            } catch {
                failImport("Couldn't read this file. Make sure it's a profile shared from PreferenceFlow.")
            }
        case .failure(let error):
            failImport(error.localizedDescription)
        }
    }

    private func resolveImport(_ resolution: ImportResolution) {
        guard let export = pendingImport else { return }
        if resolution != .cancel {
            store.applyImport(export, resolution: resolution)
            let count = export.doctors.count
            importIsError = false
            if count == 1, let only = export.doctors.first {
                importMessage = "\(only.displayName) was added to your profiles."
            } else {
                importMessage = "Imported \(count) profiles."
            }
        }
        pendingImport = nil
        duplicates = []
    }

    private func failImport(_ text: String) {
        importIsError = true
        importMessage = text
    }

    // MARK: Fuzzy (same-name, different-id) resolution

    private var fuzzyTitle: String {
        if fuzzyMatches.count == 1, let only = fuzzyMatches.first {
            return "A profile for \(only.displayName) already exists"
        }
        return "Similar profiles already exist"
    }

    private var fuzzyMessage: String {
        if fuzzyMatches.count == 1, let only = fuzzyMatches.first {
            return "You already have a profile that looks like \(only.displayName). Import as a separate new profile, or replace the existing one?"
        }
        let names = fuzzyMatches.map(\.displayName).joined(separator: ", ")
        return "These look like profiles you already have: \(names). Import as separate new profiles, or replace the existing ones?"
    }

    private func resolveFuzzy(replace: Bool) {
        guard let export = pendingImport else { return }
        if replace {
            store.applyImportReplacingNameMatches(export)
        } else {
            store.applyImport(export, resolution: .saveAsCopy)
        }
        importIsError = false
        let count = export.doctors.count
        if count == 1, let only = export.doctors.first {
            importMessage = "\(only.displayName) was \(replace ? "updated" : "added") in your profiles."
        } else {
            importMessage = "Imported \(count) profiles."
        }
        pendingImport = nil
        fuzzyMatches = []
    }

    private func cancelFuzzy() {
        pendingImport = nil
        fuzzyMatches = []
    }

    /// Pushes the deep-linked consultant (from a scanned preference-card QR) and
    /// clears the pending route so it only fires once.
    private func consumeDeepLink(_ id: UUID?) {
        guard let id, store.doctor(id: id) != nil else { return }
        path.append(id)
        settings.pendingDeepLinkDoctorID = nil
    }

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                searchField

                if isSearching {
                    searchResults
                } else {
                    if !favourites.isEmpty {
                        section(title: "Favourites", icon: "star.fill", doctors: favourites)
                    }
                    if !recents.isEmpty {
                        section(title: "Recent", icon: "clock.arrow.circlepath", doctors: recents)
                    }
                    section(
                        title: "All \(settings.region.providerPlural)",
                        icon: "person.2",
                        doctors: store.doctors
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            // Auto-focus so the technician can start typing immediately.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                searchFocused = true
            }
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search \(settings.region.providerPlural.lowercased())", text: $query)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerMedium))
    }

    // MARK: - Sections

    @ViewBuilder
    private var searchResults: some View {
        if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No matches for \u{201C}\(query)\u{201D}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(filtered) { row($0) }
            }
        }
    }

    private func section(title: String, icon: String, doctors: [Doctor]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title, icon: icon)
            LazyVStack(spacing: 12) {
                ForEach(doctors) { row($0) }
            }
        }
    }

    private func row(_ doctor: Doctor) -> some View {
        NavigationLink {
            DoctorDetailView(doctorID: doctor.id)
        } label: {
            DoctorRow(
                doctor: doctor,
                hospitalName: store.hospital(id: doctor.hospitalId)?.name,
                isFavourite: settings.isFavouriteDoctor(doctor.id),
                onToggleFavourite: { settings.toggleFavouriteDoctor(doctor.id) }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                settings.toggleFavouriteDoctor(doctor.id)
            } label: {
                Label(
                    settings.isFavouriteDoctor(doctor.id) ? "Remove Favourite" : "Add to Favourites",
                    systemImage: settings.isFavouriteDoctor(doctor.id) ? "star.slash" : "star"
                )
            }
            Button(role: .destructive) { store.deleteDoctor(doctor) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// A provider list row with avatar, name, specialty chips, hospital and a
/// star to pin frequently worked-with consultants.
struct DoctorRow: View {
    let doctor: Doctor
    let hospitalName: String?
    var isFavourite: Bool = false
    var onToggleFavourite: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            DoctorAvatar(doctor: doctor, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(doctor.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !doctor.subspecialties.isEmpty {
                    Text(doctor.subspecialties.prefix(3).map(\.rawValue).joined(separator: " · "))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accentDeep)
                        .lineLimit(1)
                } else if !doctor.role.isBlank {
                    Text(doctor.role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let hospitalName, !hospitalName.isBlank {
                    Label(hospitalName, systemImage: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
                freshnessLine
            }
            Spacer()
            if let onToggleFavourite {
                Button(action: onToggleFavourite) {
                    Image(systemName: isFavourite ? "star.fill" : "star")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isFavourite ? Color.yellow : Color.secondary.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .card()
    }

    /// Age-of-last-update signal: a subtle amber "May need review" badge once a
    /// profile is over 12 months stale, otherwise a quiet "Updated …" line.
    @ViewBuilder
    private var freshnessLine: some View {
        if doctor.needsReview {
            HStack(spacing: 4) {
                Image(systemName: "clock.badge.exclamationmark")
                Text("May need review")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(hex: "E0883B"))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(hex: "E0883B").opacity(0.14), in: .capsule)
        } else {
            Text(doctor.updatedSummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
