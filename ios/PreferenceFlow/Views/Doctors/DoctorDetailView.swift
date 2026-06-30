//
//  DoctorDetailView.swift
//  PreferenceFlow
//

import SwiftUI

/// The restructured profile sections (v2).
enum ProfileTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case details = "Details"
    case general = "General"
    case airway = "Airway"
    case drugs = "Drugs & Fluids"
    case regional = "Regional"
    case neuraxial = "Neuraxial"
    case procedures = "Procedures"
    case share = "Share"

    var id: String { rawValue }

    /// Sections shown in the single "Edit Consultant" experience, in order.
    static let editTabs: [ProfileTab] = [.details, .general, .airway, .drugs, .regional, .neuraxial, .procedures, .share]

    var icon: String {
        switch self {
        case .overview: return "person.crop.rectangle"
        case .details: return "person.crop.circle"
        case .general: return "checklist"
        case .airway: return "lungs"
        case .drugs: return "syringe"
        case .regional: return "scope"
        case .neuraxial: return "figure.walk.motion"
        case .procedures: return "cross.case"
        case .share: return "square.and.arrow.up"
        }
    }
}

/// A navigation route that opens a consultant profile straight into Edit Mode
/// (used after Quick Add when the user chooses to add full setup now).
struct ConsultantEditRoute: Hashable {
    let id: UUID
}

/// Navigation destinations reachable from the consultant dashboard.
enum DashboardRoute: Hashable {
    case equipment(UUID)
    case contacts(UUID)
    case hospital(UUID)
}

/// Provider profile with a horizontal section switcher and detail content.
struct DoctorDetailView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctorID: UUID

    /// When set, the profile acts as the daily home — shows a hospital context
    /// strip and a "Change" affordance that runs this closure.
    var onChangeDay: (() -> Void)?
    /// Hospital to use for the day's context strip and hospital links.
    var dailyHospitalID: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var tab: ProfileTab
    @State private var migrating = false
    @State private var exportingPDF = false
    @State private var confirmingDelete = false
    /// View Mode (read-only laminated card) vs Edit Mode (section editor tabs).
    @State private var isEditing = false
    /// Exported profile file, presented in the system share sheet for peer-to-peer
    /// sharing (AirDrop, Messages, Files) — no cloud sync. Uses an Identifiable
    /// payload with `.sheet(item:)` so the sheet presents reliably (a boolean +
    /// separate URL races and causes the sheet to flicker/dismiss).
    @State private var sharePayload: SharePayload?
    @State private var shareError: String?
    /// Presents the Emergency / Crisis quick-reference sheet. Held here (not on
    /// the toolbar button) because a `.sheet` attached to a view inside a
    /// `ToolbarItem` is hoisted out of the hierarchy and often fails to present.
    @State private var showingEmergency = false

    init(
        doctorID: UUID,
        initialTab: ProfileTab = .overview,
        startEditing: Bool = false,
        dailyHospitalID: UUID? = nil,
        onChangeDay: (() -> Void)? = nil
    ) {
        self.doctorID = doctorID
        self.dailyHospitalID = dailyHospitalID
        self.onChangeDay = onChangeDay
        _tab = State(initialValue: startEditing ? .details : initialTab)
        _isEditing = State(initialValue: startEditing)
    }

    private var doctor: Doctor? { store.doctor(id: doctorID) }
    private var template: DepartmentTemplate? {
        guard let doctor else { return nil }
        return store.template(for: doctor)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                tabBar
                Divider()
            }
            content
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(doctor?.displayName ?? "Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { settings.recordRecentDoctor(doctorID) }
        .navigationDestination(for: DashboardRoute.self) { route in
            dashboardDestination(route)
        }
        .navigationDestination(for: KnowledgeCategory.self) { KnowledgeCategoryView(category: $0) }
        .navigationDestination(for: KnowledgeArticle.self) { KnowledgeArticleView(article: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isEditing {
                    Button {
                        showingEmergency = true
                    } label: {
                        Image(systemName: "cross.case.fill").foregroundStyle(Color(hex: "D1576E"))
                    }
                    .accessibilityLabel("Emergency quick reference")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Done") { withAnimation(.spring(response: 0.3)) { isEditing = false; tab = .overview } }
                        .fontWeight(.semibold)
                } else {
                    Menu {
                        Button { withAnimation(.spring(response: 0.3)) { isEditing = true; tab = .details } } label: { Label("Edit", systemImage: "pencil") }
                        Button { shareProfileFile() } label: { Label("Share Profile", systemImage: "square.and.arrow.up") }
                        Button { exportingPDF = true } label: { Label("Export as PDF", systemImage: "doc.richtext") }
                        Button { duplicateProfile() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        Divider()
                        Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEmergency) {
            EmergencyGuidesHubView(hospitalID: dailyHospitalID ?? doctor?.hospitalId, presentedAsSheet: true)
        }
        .sheet(isPresented: $migrating) {
            if let doctor { ProfileMigrationView(source: doctor) }
        }
        .sheet(isPresented: $exportingPDF) {
            if let doctor { PreferenceCardExportView(doctor: doctor) }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
        }
        .alert("Share Failed", isPresented: .constant(shareError != nil)) {
            Button("OK") { shareError = nil }
        } message: {
            Text(shareError ?? "")
        }
        .confirmationDialog(
            "Delete this consultant?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Consultant", role: .destructive) {
                if let doctor { store.deleteDoctor(doctor); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes \(doctor?.displayName ?? "this consultant") and all their preferences.")
        }
    }

    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProfileTab.editTabs) { item in
                        let title = tabTitle(item)
                        Button {
                            withAnimation(.spring(response: 0.3)) { tab = item }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: item.icon).font(.caption)
                                Text(title).font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                tab == item ? Theme.accent : Color(.secondarySystemGroupedBackground),
                                in: .capsule
                            )
                            .foregroundStyle(tab == item ? .white : .primary)
                        }
                        .id(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onChange(of: tab) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func tabTitle(_ item: ProfileTab) -> String {
        item.rawValue
    }

    /// Exports this profile to a shareable PreferenceFlow file and opens the
    /// system share sheet (AirDrop, Messages, Files). Peer-to-peer only — a
    /// colleague imports it on their own device; nothing syncs to a server.
    private func shareProfileFile() {
        guard let doctor else { return }
        let export = store.makeExport(doctorIDs: [doctor.id], region: settings.region, sharedBy: settings.userName)
        do {
            let url = try store.writeExportFile(export)
            sharePayload = SharePayload(url: url)
        } catch {
            shareError = error.localizedDescription
        }
    }

    /// Creates an independent copy of this profile (all sections) under the same
    /// hospital so the user can adapt it without affecting the original.
    private func duplicateProfile() {
        guard let doctor else { return }
        store.copyProfile(doctor, toHospital: doctor.hospitalId, scope: .full)
    }

    @ViewBuilder
    private func dashboardDestination(_ route: DashboardRoute) -> some View {
        switch route {
        case .equipment(let id):
            EquipmentLocationsTab(hospitalID: id)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Equipment Locations")
                .navigationBarTitleDisplayMode(.inline)
        case .contacts(let id):
            HospitalContactsTab(hospitalID: id)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Contacts & Emergency")
                .navigationBarTitleDisplayMode(.inline)
        case .hospital(let id):
            HospitalDetailView(hospitalID: id)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let doctor {
            switch tab {
            case .overview:
                OverviewTab(
                    doctor: doctor,
                    onNavigate: { target in withAnimation(.spring(response: 0.3)) { isEditing = true; tab = target } },
                    hospitalID: dailyHospitalID,
                    editMode: isEditing,
                    template: template
                )
            case .details: DetailsTab(doctor: doctor)
            case .general: GeneralTab(doctor: doctor)
            case .airway: AirwayTab(doctor: doctor)
            case .drugs: DrugsFluidsTab(doctor: doctor)
            case .regional: RegionalTab(doctor: doctor)
            case .neuraxial: NeuraxialTab(doctor: doctor)
            case .procedures: OperationsTab(doctor: doctor)
            case .share: ShareTab(doctor: doctor)
            }
        } else {
            Spacer()
            Text("Profile not found").foregroundStyle(.secondary)
            Spacer()
        }
    }
}
