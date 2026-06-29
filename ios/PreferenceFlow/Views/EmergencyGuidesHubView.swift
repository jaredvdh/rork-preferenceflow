//
//  EmergencyGuidesHubView.swift
//  PreferenceFlow
//

import SwiftUI

/// High-priority crisis hub reachable from Today, a consultant profile, a hospital
/// and the Knowledge library. Surfaces the curated emergency guides plus any PDFs
/// the user has pinned to Emergency, and links to the active hospital's emergency
/// equipment locations. Educational reference only.
struct EmergencyGuidesHubView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// Hospital whose emergency equipment locations to surface (defaults to the
    /// active daily hospital).
    var hospitalID: UUID?
    /// When presented as a sheet, show a Done button.
    var presentedAsSheet: Bool = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var resolvedHospital: Hospital? {
        store.hospital(id: hospitalID ?? settings.activeHospitalId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    guideGrid
                    pinnedDocuments
                    emergencyEquipment
                    emergencyContacts
                    note
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Emergency Guides")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: KnowledgeArticle.self) { KnowledgeArticleView(article: $0) }
            .navigationDestination(for: KnowledgeDocument.self) { DocumentReaderView(documentID: $0.id) }
            .toolbar {
                if presentedAsSheet {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var intro: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "D1576E")).frame(width: 56, height: 56)
                Image(systemName: "cross.case.fill")
                    .font(.title2.weight(.semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Crisis quick-reference").font(.headline)
                Text("Tap a guide for recognition, immediate priorities and kit.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }

    private var guideGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(KnowledgeLibrary.emergencyGuides) { article in
                NavigationLink(value: article) {
                    EmergencyGuideCard(article: article)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var pinnedDocuments: some View {
        let pinned = store.pinnedEmergencyDocuments
        if !pinned.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Pinned documents", icon: "pin.fill")
                ForEach(pinned) { document in
                    NavigationLink(value: document) {
                        DocumentRow(document: document, hospitalName: store.hospital(id: document.hospitalId)?.name)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var emergencyEquipment: some View {
        if let hospital = resolvedHospital {
            let kinds: Set<EquipmentKind> = [.crashCart, .mhKit, .difficultIntubationTrolley, .emergencyAirway, .rapidInfuser, .belmont]
            let items = hospital.orientationOrEmpty.equipmentLocations.filter { kinds.contains($0.kind) }
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("\(hospital.name) emergency equipment", icon: "mappin.and.ellipse")
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol).foregroundStyle(Color(hex: "D1576E")).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.subheadline.weight(.medium))
                                    if !item.location.isBlank {
                                        Text(item.location).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .card()
                }
            }
        }
    }

    @ViewBuilder
    private var emergencyContacts: some View {
        if let hospital = resolvedHospital {
            let contacts = hospital.orientationOrEmpty.contacts.filter {
                !$0.phone.isBlank || !$0.extensionNumber.isBlank || !$0.pager.isBlank
            }
            if !contacts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Key contacts", icon: "phone.fill")
                    VStack(spacing: 8) {
                        ForEach(contacts.prefix(5)) { contact in
                            HStack(spacing: 12) {
                                Image(systemName: contact.symbol).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.roleTitle).font(.subheadline.weight(.medium))
                                    let number = [contact.phone, contact.extensionNumber.isBlank ? "" : "ext \(contact.extensionNumber)", contact.pager.isBlank ? "" : "pager \(contact.pager)"].filter { !$0.isBlank }.joined(separator: " · ")
                                    if !number.isBlank {
                                        Text(number).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .card()
                }
            }
        }
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(hex: "D1576E"))
            Text("Educational summaries only. Always follow your institution's current emergency protocols and crisis manuals, and call for help early.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "D1576E").opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
    }
}

/// A bold crisis card used in the Emergency hub grid.
struct EmergencyGuideCard: View {
    let article: KnowledgeArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(Color(hex: "D1576E").opacity(0.16)).frame(width: 44, height: 44)
                Image(systemName: article.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: "D1576E"))
            }
            Text(article.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Text("Open guide")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(hex: "D1576E"))
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(Color(hex: "D1576E").opacity(0.18), lineWidth: 1)
        )
    }
}

/// A compact, reusable button that opens the Emergency Guides hub as a sheet.
/// Used on Today, the consultant profile and the hospital screens.
struct EmergencyAccessButton: View {
    var hospitalID: UUID?
    var style: Style = .card
    @State private var presenting = false

    enum Style { case card, compactToolbar }

    var body: some View {
        Group {
            switch style {
            case .card:
                Button { presenting = true } label: { cardLabel }
                    .buttonStyle(.plain)
            case .compactToolbar:
                Button { presenting = true } label: {
                    Image(systemName: "cross.case.fill").foregroundStyle(Color(hex: "D1576E"))
                }
            }
        }
        .sheet(isPresented: $presenting) {
            EmergencyGuidesHubView(hospitalID: hospitalID, presentedAsSheet: true)
        }
    }

    private var cardLabel: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "D1576E")).frame(width: 44, height: 44)
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Emergency Guides").font(.headline)
                Text("MH · LAST · Anaphylaxis · CICO · Arrest").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(Color(hex: "D1576E").opacity(0.22), lineWidth: 1)
        )
    }
}
