//
//  KnowledgeDocumentViews.swift
//  PreferenceFlow
//

import SwiftUI

// MARK: - Cards & rows

/// A rich guide card for an imported PDF: title, category, hospital association and
/// date added, with an actions menu.
struct DocumentCard: View {
    @Environment(DataStore.self) private var store
    let document: KnowledgeDocument
    var onOpen: () -> Void
    var onSearch: () -> Void

    private var hospitalName: String? { store.hospital(id: document.hospitalId)?.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: document.category.tint).opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: document.category.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: document.category.tint))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.displayTitle).font(.headline).foregroundStyle(.primary).lineLimit(2)
                    Text(document.category.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                actionsMenu
            }

            HStack(spacing: 8) {
                if document.pinnedToEmergency {
                    metaTag("Emergency", icon: "pin.fill", tint: Color(hex: "D1576E"))
                }
                if let hospitalName {
                    metaTag(hospitalName, icon: "building.2", tint: Theme.accent)
                }
                metaTag(dateString, icon: "calendar", tint: .secondary)
                if document.pageCount > 0 {
                    metaTag("\(document.pageCount) pp", icon: "doc", tint: .secondary)
                }
            }

            HStack(spacing: 10) {
                actionButton("Open PDF", icon: "doc.text.magnifyingglass", action: onOpen)
                actionButton("Search", icon: "magnifyingglass", action: onSearch)
            }
        }
        .card()
    }

    private var actionsMenu: some View {
        DocumentActionsMenu(document: document, onOpen: onOpen, onSearch: onSearch) {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accent.opacity(0.12), in: .capsule)
                .foregroundStyle(Theme.accentDeep)
        }
        .buttonStyle(.plain)
    }

    private func metaTag(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(.caption2.weight(.semibold)).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(tint.opacity(0.14), in: .capsule)
        .foregroundStyle(tint)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: document.dateAdded)
    }
}

/// A compact row used in lists (search results, emergency pins).
struct DocumentRow: View {
    let document: KnowledgeDocument
    var hospitalName: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: document.category.tint).opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: document.category.symbol).foregroundStyle(Color(hex: document.category.tint))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(document.displayTitle).font(.subheadline.weight(.medium)).lineLimit(1)
                Text([document.category.rawValue, hospitalName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .card(padding: 14)
    }
}

/// Shared actions menu for a document, used on cards and the reader toolbar.
struct DocumentActionsMenu<LabelContent: View>: View {
    @Environment(DataStore.self) private var store
    let document: KnowledgeDocument
    var onOpen: (() -> Void)?
    var onSearch: (() -> Void)?
    @ViewBuilder var label: () -> LabelContent

    @State private var choosingHospital = false
    @State private var sharing = false

    var body: some View {
        Menu {
            if let onOpen {
                Button { onOpen() } label: { Label("Open PDF", systemImage: "doc.text.magnifyingglass") }
            }
            if let onSearch {
                Button { onSearch() } label: { Label("Search within PDF", systemImage: "magnifyingglass") }
            }
            Button { store.toggleEmergencyPin(document) } label: {
                Label(document.pinnedToEmergency ? "Unpin from Emergency" : "Pin to Emergency",
                      systemImage: document.pinnedToEmergency ? "pin.slash" : "pin")
            }
            if !store.hospitals.isEmpty {
                Button { choosingHospital = true } label: {
                    Label("Add to Hospital Orientation", systemImage: "building.2")
                }
            }
            Button { sharing = true } label: { Label("Share", systemImage: "square.and.arrow.up") }
        } label: {
            label()
        }
        .confirmationDialog("Add to which hospital?", isPresented: $choosingHospital, titleVisibility: .visible) {
            ForEach(store.hospitals) { hospital in
                Button(hospital.name) { store.addDocumentToOrientation(document, hospitalID: hospital.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [store.documentURL(for: document)])
        }
    }
}

// MARK: - Reader (with search-within)

/// Full-screen PDF reader with an in-document search field.
struct DocumentReaderView: View {
    @Environment(DataStore.self) private var store
    let documentID: UUID
    /// When true, focuses the search field on appear.
    var startSearching: Bool = false

    @State private var searching = false
    @State private var searchText = ""

    private var document: KnowledgeDocument? { store.documents.first { $0.id == documentID } }

    var body: some View {
        Group {
            if let document {
                VStack(spacing: 0) {
                    if searching {
                        searchBar
                        Divider()
                    }
                    PDFKitView(url: store.documentURL(for: document), searchText: searching ? searchText : "")
                        .ignoresSafeArea(edges: .bottom)
                }
                .navigationTitle(document.displayTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack {
                            Button {
                                withAnimation { searching.toggle() }
                                if !searching { searchText = "" }
                            } label: {
                                Image(systemName: searching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                            }
                            DocumentActionsMenu(document: document, onOpen: nil, onSearch: nil) {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .onAppear { if startSearching { searching = true } }
            } else {
                EmptyStateView(icon: "doc", title: "Document unavailable", message: "This file may have been removed.")
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search within document", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }
}
