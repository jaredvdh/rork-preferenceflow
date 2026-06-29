//
//  KnowledgeBaseView.swift
//  PreferenceFlow
//

import SwiftUI
import UniformTypeIdentifiers

/// Knowledge tab — a searchable anaesthesia reference library combining curated
/// educational articles, imported PDF guides, and a fast route to the Emergency
/// hub. Educational only; every article carries the safety note.
struct KnowledgeBaseView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var query = ""
    @State private var showFileImporter = false
    @State private var pendingURL: URL?
    @State private var importError: String?

    // MARK: Matches

    private var articleMatches: [KnowledgeArticle] {
        guard !query.isBlank else { return [] }
        return KnowledgeLibrary.all.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.summary.localizedCaseInsensitiveContains(query)
            || $0.sections.contains { $0.body.localizedCaseInsensitiveContains(query) }
        }
    }

    private var documentMatches: [KnowledgeDocument] {
        guard !query.isBlank else { return [] }
        return store.documents.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.category.rawValue.localizedCaseInsensitiveContains(query)
            || $0.textMatches(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.isBlank {
                    library
                } else {
                    searchResults
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Knowledge")
            .searchable(text: $query, prompt: "Search guides, documents & references")
            .navigationDestination(for: KnowledgeCategory.self) { KnowledgeCategoryView(category: $0) }
            .navigationDestination(for: KnowledgeArticle.self) { KnowledgeArticleView(article: $0) }
            .navigationDestination(for: KnowledgeDocument.self) { DocumentReaderView(documentID: $0.id) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFileImporter = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                handleFileResult(result)
            }
            .sheet(item: $pendingURL) { url in
                DocumentImportSheet(sourceURL: url)
            }
            .alert("Import Error", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    // MARK: Library (idle)

    private var library: some View {
        VStack(spacing: 16) {
            intro

            EmergencyAccessButton(hospitalID: settings.activeHospitalId, style: .card)

            categorySection
            documentsSection
            importPrompt
            educationalNote
        }
        .padding(16)
    }

    private var intro: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.heroGradient).frame(width: 56, height: 56)
                Image(systemName: "books.vertical.fill")
                    .font(.title2.weight(.semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Anaesthesia companion").font(.headline)
                Text("Curated guides, your imported PDFs and orientation references.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Reference guides", icon: "books.vertical")
            ForEach(KnowledgeCategory.allCases) { category in
                NavigationLink(value: category) {
                    KnowledgeCategoryCard(category: category)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        if !store.documents.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("My documents", icon: "doc.on.doc")
                ForEach(store.documents) { document in
                    NavigationLink(value: document) {
                        DocumentRow(document: document, hospitalName: store.hospital(id: document.hospitalId)?.name)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var importPrompt: some View {
        Button { showFileImporter = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import a PDF").font(.headline)
                    Text("Add a hospital guide, policy or reference and file it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: Search results

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            if articleMatches.isEmpty && documentMatches.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "No results", message: "Try a different search term.")
                    .padding(.top, 40)
            } else {
                if !documentMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Documents", icon: "doc.text")
                        ForEach(documentMatches) { document in
                            NavigationLink(value: document) {
                                DocumentRow(document: document, hospitalName: store.hospital(id: document.hospitalId)?.name)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !articleMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Guides", icon: "books.vertical")
                        ForEach(articleMatches) { article in
                            NavigationLink(value: article) {
                                KnowledgeArticleRow(article: article)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private var educationalNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill").foregroundStyle(Theme.accent)
            Text("Educational reference only. Always follow your institution's current protocols and guidance.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
    }

    // MARK: Import

    private func handleFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            pendingURL = url
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

/// Lets URL be used with `.sheet(item:)`.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Categorise sheet shown after picking a PDF: title, category and optional
/// hospital association before the document is imported.
struct DocumentImportSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let sourceURL: URL

    @State private var title: String
    @State private var category: DocumentCategory = .hospitalGuide
    @State private var hospitalId: UUID?
    @State private var pinToEmergency = false
    @State private var addToOrientation = false
    @State private var importing = false
    @State private var error: String?

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        _title = State(initialValue: sourceURL.deletingPathExtension().lastPathComponent)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(DocumentCategory.allCases) { c in
                            Label(c.rawValue, systemImage: c.symbol).tag(c)
                        }
                    }
                }

                Section("Hospital") {
                    Picker("Association", selection: $hospitalId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.hospitals) { h in
                            Text(h.name).tag(UUID?.some(h.id))
                        }
                    }
                    if hospitalId != nil {
                        Toggle("Add to Hospital Orientation", isOn: $addToOrientation)
                    }
                }

                Section {
                    Toggle("Pin to Emergency Guides", isOn: $pinToEmergency)
                } footer: {
                    Text("Pinned documents appear at the top of the Emergency hub for instant access.")
                }
            }
            .navigationTitle("Import PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { performImport() }
                        .fontWeight(.semibold)
                        .disabled(importing)
                }
            }
            .alert("Import Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private func performImport() {
        importing = true
        do {
            var document = try store.importDocument(
                from: sourceURL,
                title: title,
                category: category,
                hospitalId: hospitalId
            )
            if pinToEmergency {
                document.pinnedToEmergency = true
                store.updateDocument(document)
            }
            if addToOrientation, let hospitalId {
                store.addDocumentToOrientation(document, hospitalID: hospitalId)
            }
            dismiss()
        } catch {
            importing = false
            self.error = "Couldn't import this PDF. Please try another file."
        }
    }
}

struct KnowledgeCategoryCard: View {
    let category: KnowledgeCategory

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: category.tint))
                    .frame(width: 50, height: 50)
                Image(systemName: category.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(category.rawValue).font(.headline)
                Text(category.blurb).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(KnowledgeLibrary.articles(in: category).count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
    }
}

/// Lists the articles within a category.
struct KnowledgeCategoryView: View {
    let category: KnowledgeCategory

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(KnowledgeLibrary.articles(in: category)) { article in
                    NavigationLink(value: article) {
                        KnowledgeArticleRow(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct KnowledgeArticleRow: View {
    let article: KnowledgeArticle

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: article.category.tint).opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: article.symbol).foregroundStyle(Color(hex: article.category.tint))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(article.title).font(.headline).foregroundStyle(.primary)
                Text(article.summary)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
    }
}

/// Full article reader with related consultant preferences and hospital info.
struct KnowledgeArticleView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let article: KnowledgeArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ForEach(article.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(section.heading, icon: "circle.fill")
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                    }
                }
                RelatedInYourData(article: article)
                SafetyBanner()
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: article.category.tint).opacity(0.15)).frame(width: 76, height: 76)
                Image(systemName: article.symbol)
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: article.category.tint))
            }
            Text(article.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
            Text(article.category.rawValue)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Color(hex: article.category.tint).opacity(0.14), in: .capsule)
                .foregroundStyle(Color(hex: article.category.tint))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

/// Surfaces the active hospital's relevant equipment locations and consultants
/// whose preferences relate to the article — turning a static guide into a live
/// companion (e.g. Direct Laryngoscopy → difficult airway trolley + airway prefs).
private struct RelatedInYourData: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let article: KnowledgeArticle

    private var hospital: Hospital? { store.hospital(id: settings.activeHospitalId) }

    private var relatedEquipment: [EquipmentLocation] {
        guard let hospital else { return [] }
        let kinds = Set(KnowledgeRelations.relatedEquipmentKinds(for: article))
        return hospital.orientationOrEmpty.equipmentLocations.filter { kinds.contains($0.kind) }
    }

    private var relatedDoctors: [Doctor] {
        guard article.category == .airway || article.category == .regional else { return [] }
        let scope = settings.activeHospitalId.map { store.doctors(forHospital: $0) } ?? store.doctors
        if article.category == .regional {
            let key = article.title.replacingOccurrences(of: " Block", with: "")
            return scope.filter { doc in
                doc.regionalBlocks.contains { $0.name.localizedCaseInsensitiveContains(key) }
            }
        }
        // Airway: consultants with any airway content.
        return scope.filter { !$0.airway.adultMale.notes.isBlank || !$0.airway.adultMale.tubeSize.isBlank || !$0.airway.adultFemale.tubeSize.isBlank }
    }

    private var tab: ProfileTab {
        switch KnowledgeRelations.relatedProfileTab(for: article) {
        case .airway: return .airway
        case .regional: return .regional
        case .general: return .general
        case .overview: return .overview
        }
    }

    var body: some View {
        if !relatedEquipment.isEmpty || !relatedDoctors.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Related in your data", icon: "link")

                if !relatedEquipment.isEmpty, let hospital {
                    VStack(spacing: 8) {
                        ForEach(relatedEquipment) { item in
                            NavigationLink(value: DashboardRoute.equipment(hospital.id)) {
                                relatedRow(icon: item.symbol, title: item.title,
                                           subtitle: item.location.isBlank ? hospital.name : item.location)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .card()
                }

                if !relatedDoctors.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(relatedDoctors.prefix(4)) { doc in
                            NavigationLink {
                                DoctorDetailView(doctorID: doc.id, initialTab: tab)
                            } label: {
                                relatedRow(icon: "stethoscope", title: doc.displayName,
                                           subtitle: "\(article.category == .regional ? "Regional" : "Airway") preferences")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .card()
                }
            }
        }
    }

    private func relatedRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
}
