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
    case monitoring = "Monitoring & Lines"
    case regional = "Regional"
    case neuraxial = "Neuraxial"
    case procedures = "Procedures"
    case share = "Share"
    // Surgeon / proceduralist sections.
    case gloves = "Gloves & Personal"
    case trays = "Trays & Instruments"
    case sutures = "Sutures & Closure"
    case energy = "Energy & Equipment"
    case positioning = "Positioning & Prep"

    var id: String { rawValue }

    /// Sections shown in the single "Edit Consultant" experience, in order.
    static let editTabs: [ProfileTab] = [.details, .general, .airway, .drugs, .monitoring, .regional, .neuraxial, .procedures, .share]

    /// Sections shown when editing a surgeon / proceduralist profile.
    static let surgeonEditTabs: [ProfileTab] = [.details, .gloves, .trays, .sutures, .energy, .positioning, .procedures, .share]

    /// The edit sections for a given profile type.
    static func editTabs(for kind: ClinicianKind) -> [ProfileTab] {
        kind == .surgeon ? surgeonEditTabs : editTabs
    }

    var icon: String {
        switch self {
        case .overview: return "person.crop.rectangle"
        case .details: return "person.crop.circle"
        case .general: return "checklist"
        case .airway: return "lungs"
        case .drugs: return "syringe"
        case .monitoring: return "waveform.path.ecg"
        case .regional: return "scope"
        case .neuraxial: return "figure.walk.motion"
        case .procedures: return "cross.case"
        case .share: return "square.and.arrow.up"
        case .gloves: return "hand.raised.fill"
        case .trays: return "tray.2.fill"
        case .sutures: return "bandage.fill"
        case .energy: return "bolt.fill"
        case .positioning: return "bed.double.fill"
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
    /// Read-mode section selection: Overview or a specific specialty setup (by id).
    /// Core sections are not promoted to read-mode tabs — they stay on Overview.
    @State private var readTab: ReadTab = .overview
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
    /// Presents the local change-history list for this profile.
    @State private var showingChangeHistory = false

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
            } else if showReadTabBar {
                readTabBar
                Divider()
            }
            if !isEditing, let doctor, !doctor.isVerifiedProfile {
                unverifiedBanner(doctor)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            content
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isEditing)
        .sensoryFeedback(.impact(weight: .heavy), trigger: showingEmergency) { _, newValue in newValue }
        .sensoryFeedback(.warning, trigger: confirmingDelete) { _, newValue in newValue }
        .sensoryFeedback(.selection, trigger: readTab)
        .sensoryFeedback(.success, trigger: isEditing) { oldValue, newValue in oldValue && !newValue }
        .sensoryFeedback(.success, trigger: sharePayload?.id) { _, newValue in newValue != nil }
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
                        Button { withAnimation(.spring(response: 0.3)) { readTab = .overview; isEditing = true; tab = .details } } label: { Label("Edit", systemImage: "pencil") }
                        Button { shareProfileFile() } label: { Label("Share Profile", systemImage: "square.and.arrow.up") }
                        Button { exportingPDF = true } label: { Label("Export / Print PDF", systemImage: "printer") }
                        Button { duplicateProfile() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        Button { showingChangeHistory = true } label: { Label("Change History", systemImage: "clock.arrow.circlepath") }
                        Divider()
                        Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .adaptiveFullScreenSheet(isPresented: $showingEmergency) {
            EmergencyGuidesHubView(hospitalID: dailyHospitalID ?? doctor?.hospitalId, presentedAsSheet: true)
        }
        .sheet(isPresented: $migrating) {
            if let doctor { ProfileMigrationView(source: doctor) }
        }
        .sheet(isPresented: $exportingPDF) {
            if let doctor { PreferenceCardExportView(doctor: doctor, hospitalID: dailyHospitalID) }
        }
        .sheet(isPresented: $showingChangeHistory) {
            ProfileChangeHistoryView(doctorID: doctorID)
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

    /// Non-alarming banner shown on unverified profiles (built from memory or a
    /// second-hand card). A single tap marks the profile verified.
    private func unverifiedBanner(_ doctor: Doctor) -> some View {
        Button {
            markVerified(doctor)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: "E0883B"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unverified profile")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Created from memory or second-hand. Confirm preferences with the consultant before relying on this profile. Tap to mark verified.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(Color(hex: "E0883B"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "E0883B").opacity(0.13))
            .overlay(alignment: .bottom) { Divider() }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Marks this profile as verified")
    }

    private func markVerified(_ doctor: Doctor) {
        var updated = doctor
        updated.isVerified = true
        withAnimation(.spring(response: 0.3)) { store.upsert(updated) }
    }

    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProfileTab.editTabs(for: doctor?.clinicianKind ?? .anaesthetist)) { item in
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
                            .animation(.easeInOut(duration: 0.15), value: tab == item)
                            .scaleEffect(tab == item ? 1.03 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: tab == item)
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

    /// Read-mode tab bar: General/Overview plus one tab per procedure card
    /// (surgeons) and per active specialty setup. Core sections stay reachable
    /// from the Overview card and via Edit mode.
    private var showReadTabBar: Bool {
        !(doctor?.activeSpecialtySetups.isEmpty ?? true)
            || !(doctor?.surgicalProcedures.isEmpty ?? true)
            || !(doctor?.operations.isEmpty ?? true)
    }

    private var readTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    readTabChip(
                        title: doctor?.isSurgeon == true ? "General" : "Overview",
                        icon: "person.crop.rectangle",
                        tint: Theme.accent,
                        selected: readTab == .overview
                    ) { withAnimation(.spring(response: 0.3)) { readTab = .overview } }
                    .id(ReadTab.overview)

                    // Surgeon operation cards — one tab per procedure, right
                    // after General so "look up the operation" is one tap.
                    ForEach(doctor?.surgicalProcedures ?? []) { procedure in
                        readTabChip(
                            title: procedure.displayName,
                            icon: "cross.case.fill",
                            tint: Color(hex: "2E7DD1"),
                            selected: readTab == .procedure(procedure.id)
                        ) { withAnimation(.spring(response: 0.3)) { readTab = .procedure(procedure.id) } }
                        .id(ReadTab.procedure(procedure.id))
                    }

                    // Anaesthetist operation cards — same one-tap lookup for
                    // per-operation anaesthetic setups (e.g. CABG, Craniotomy).
                    ForEach(doctor?.operations ?? []) { procedure in
                        readTabChip(
                            title: procedure.displayName,
                            icon: "cross.case.fill",
                            tint: Color(hex: "2E7DD1"),
                            selected: readTab == .procedure(procedure.id)
                        ) { withAnimation(.spring(response: 0.3)) { readTab = .procedure(procedure.id) } }
                        .id(ReadTab.procedure(procedure.id))
                    }

                    ForEach(doctor?.activeSpecialtySetups ?? []) { setup in
                        readTabChip(
                            title: setup.specialty.rawValue,
                            icon: setup.specialty.symbol,
                            tint: setup.specialty.color,
                            selected: readTab == .specialty(setup.id)
                        ) { withAnimation(.spring(response: 0.3)) { readTab = .specialty(setup.id) } }
                        .id(ReadTab.specialty(setup.id))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onChange(of: readTab) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func readTabChip(
        title: String,
        icon: String,
        tint: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                selected ? tint : Color(.secondarySystemGroupedBackground),
                in: .capsule
            )
            .overlay(
                Capsule().stroke(tint.opacity(selected ? 0 : 0.4), lineWidth: 1)
            )
            .foregroundStyle(selected ? .white : tint)
            .animation(.easeInOut(duration: 0.15), value: selected)
            .scaleEffect(selected ? 1.03 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: selected)
        }
        .buttonStyle(.plain)
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
            if isEditing {
                editContent(doctor)
            } else {
                readContent(doctor)
            }
        } else {
            Spacer()
            Text("Profile not found").foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func readContent(_ doctor: Doctor) -> some View {
        ZStack {
            switch readTab {
            case .specialty(let id):
                if let setup = doctor.activeSpecialtySetups.first(where: { $0.id == id }) {
                    SpecialtySetupTab(doctor: doctor, setup: setup, hospitalID: dailyHospitalID)
                        .transition(.opacity)
                } else {
                    overviewContent(doctor)
                        .transition(.opacity)
                }
            case .procedure(let id):
                if let procedure = doctor.surgicalProcedures.first(where: { $0.id == id }) {
                    SurgeonProcedureTab(
                        doctor: doctor,
                        procedure: procedure,
                        hospitalID: dailyHospitalID
                    )
                    .transition(.opacity)
                } else if let procedure = doctor.operations.first(where: { $0.id == id }) {
                    AnaesthetistProcedureTab(
                        doctor: doctor,
                        procedure: procedure,
                        hospitalID: dailyHospitalID
                    )
                    .transition(.opacity)
                } else {
                    overviewContent(doctor)
                        .transition(.opacity)
                }
            case .overview:
                overviewContent(doctor)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: readTab)
    }

    @ViewBuilder
    private func overviewContent(_ doctor: Doctor) -> some View {
        if doctor.isSurgeon {
            SurgeonOverviewTab(
                doctor: doctor,
                onNavigate: { target in withAnimation(.spring(response: 0.3)) { isEditing = true; tab = target } },
                onSelectSpecialty: { setup in withAnimation(.spring(response: 0.3)) { readTab = .specialty(setup.id) } },
                onSelectProcedure: { procedure in withAnimation(.spring(response: 0.3)) { readTab = .procedure(procedure.id) } },
                hospitalID: dailyHospitalID,
                editMode: isEditing
            )
        } else {
            OverviewTab(
                doctor: doctor,
                onNavigate: { target in withAnimation(.spring(response: 0.3)) { isEditing = true; tab = target } },
                onSelectSpecialty: { setup in withAnimation(.spring(response: 0.3)) { readTab = .specialty(setup.id) } },
                onSelectProcedure: { procedure in withAnimation(.spring(response: 0.3)) { readTab = .procedure(procedure.id) } },
                hospitalID: dailyHospitalID,
                editMode: isEditing,
                template: template
            )
        }
    }

    @ViewBuilder
    private func editContent(_ doctor: Doctor) -> some View {
        switch tab {
        case .overview:
            overviewContent(doctor)
        case .details: DetailsTab(doctor: doctor)
        case .general: GeneralTab(doctor: doctor)
        case .airway: AirwayTab(doctor: doctor)
        case .drugs: DrugsFluidsTab(doctor: doctor)
        case .monitoring: MonitoringLinesTab(doctor: doctor)
        case .regional: RegionalTab(doctor: doctor)
        case .neuraxial: NeuraxialTab(doctor: doctor)
        case .procedures:
            if doctor.isSurgeon {
                SurgeonProceduresTab(doctor: doctor)
            } else {
                OperationsTab(doctor: doctor)
            }
        case .share: ShareTab(doctor: doctor)
        case .gloves: GlovesPersonalTab(doctor: doctor)
        case .trays: TraysInstrumentsTab(doctor: doctor)
        case .sutures: SuturesClosureTab(doctor: doctor)
        case .energy: EnergyEquipmentTab(doctor: doctor)
        case .positioning: PositioningPrepTab(doctor: doctor)
        }
    }
}

/// Read-mode section selection in the profile switcher: the full Overview card,
/// a consultant specialty setup, or a surgeon procedure card promoted to its
/// own tab.
enum ReadTab: Hashable {
    case overview
    case specialty(UUID)
    case procedure(UUID)
}
