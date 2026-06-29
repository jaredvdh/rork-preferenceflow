//
//  HospitalDetailView.swift
//  PreferenceFlow
//

import SwiftUI

/// Hospital dashboard — the department's digital operating manual. Opens to a
/// scannable landing page answering "where am I working, where is critical
/// equipment, what are the standards, where are emergency resources, who do I
/// contact, what should I read?" Each module is a card that pushes its own screen.
struct HospitalDetailView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let hospitalID: UUID

    @State private var editing = false
    @State private var showingEmergency = false
    @State private var showingSearch = false

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    /// The fixed set of emergency resources surfaced in the hub.
    private let emergencyResourceCount = 7

    var body: some View {
        ScrollView {
            if let hospital {
                VStack(spacing: 22) {
                    emergencyBanner
                    header(hospital)
                    searchBar
                    quickActions(hospital)
                    departmentSections(hospital)
                    DisclaimerNote().padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 12) {
                    Spacer(minLength: 120)
                    Text("Hospital not found").foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(hospital?.name ?? "Hospital")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            HospitalManageView(hospitalID: hospitalID)
        }
        .sheet(isPresented: $showingEmergency) {
            EmergencyGuidesHubView(hospitalID: hospitalID, presentedAsSheet: true)
        }
        .sheet(isPresented: $showingSearch) {
            NavigationStack {
                HospitalSearchView(hospitalID: hospitalID)
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        Button { showingSearch = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("Search equipment, contacts, policies…")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerMedium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Emergency banner

    /// A bold, full-width emergency shortcut — always the first, most distinct
    /// action so critical resources are never buried.
    private var emergencyBanner: some View {
        Button { showingEmergency = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.22)).frame(width: 50, height: 50)
                    Image(systemName: "cross.case.fill")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Emergency Resources")
                        .font(.headline).foregroundStyle(.white)
                    Text("MH · LAST · Anaphylaxis · CICO · Haemorrhage")
                        .font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Color(hex: "E0556E"), Color(hex: "C0392B")],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: Theme.cornerLarge)
            )
            .shadow(color: Color(hex: "C0392B").opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Header

    private func header(_ hospital: Hospital) -> some View {
        let o = hospital.orientationOrEmpty
        let providers = store.doctorCount(forHospital: hospitalID)
        let standards = store.templates(forHospital: hospitalID).count
        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.heroGradient)
                        .frame(width: 64, height: 64)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(hospital.name.isBlank ? "Untitled Hospital" : hospital.name)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    Text(hospital.department.isBlank ? "Anaesthesia" : hospital.department)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accentDeep)
                    if !hospital.locationLine.isEmpty {
                        Text(hospital.locationLine)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                NavigationLink {
                    HospitalProvidersTab(hospitalID: hospitalID)
                        .navigationTitle(settings.region.providerPlural).navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    HeaderStatBox(value: "\(providers)", label: settings.region.providerPlural, icon: "stethoscope", tint: Color(hex: "0B7A6D"))
                }
                .buttonStyle(PressableStatStyle())

                NavigationLink {
                    EquipmentLocationsTab(hospitalID: hospitalID)
                        .navigationTitle("Equipment & Locations").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    HeaderStatBox(value: "\(o.equipmentLocations.count)", label: "Equipment", icon: "shippingbox.fill", tint: Theme.accent)
                }
                .buttonStyle(PressableStatStyle())

                NavigationLink {
                    DepartmentTemplatesTab(hospitalID: hospitalID)
                        .navigationTitle("Department Standards").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    HeaderStatBox(value: "\(standards)", label: "Standards", icon: "doc.on.doc.fill", tint: Color(hex: "5E7CE2"))
                }
                .buttonStyle(PressableStatStyle())

                Button { showingEmergency = true } label: {
                    HeaderStatBox(value: "\(emergencyResourceCount)", label: "Emergency", icon: "cross.case.fill", tint: Color(hex: "D1576E"))
                }
                .buttonStyle(PressableStatStyle())
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath").font(.caption2)
                Text("Updated \(hospital.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerLarge))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }



    // MARK: - Quick actions

    private func quickActions(_ hospital: Hospital) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Quick access", icon: "bolt.fill").padding(.horizontal, 16)
            LazyVGrid(columns: columns, spacing: 12) {
                Button { showingEmergency = true } label: {
                    QuickActionCard(title: "Emergency", subtitle: "MH · LAST · CICO", icon: "cross.case.fill", tint: Color(hex: "D1576E"))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    EquipmentLocationsTab(hospitalID: hospitalID)
                        .navigationTitle("Equipment").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    QuickActionCard(title: "Equipment", subtitle: "Find critical kit", icon: "mappin.and.ellipse", tint: Theme.accent)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DepartmentTemplatesTab(hospitalID: hospitalID)
                        .navigationTitle("Standards").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    QuickActionCard(title: "Standards", subtitle: "Department setups", icon: "doc.on.doc.fill", tint: Color(hex: "5E7CE2"))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HospitalContactsTab(hospitalID: hospitalID)
                        .navigationTitle("Contacts").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    QuickActionCard(title: "Contacts", subtitle: "Who to call", icon: "phone.fill", tint: Color(hex: "E08B3E"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Department sections

    private func departmentSections(_ hospital: Hospital) -> some View {
        let o = hospital.orientationOrEmpty
        let standards = store.templates(forHospital: hospitalID).count
        let providers = store.doctorCount(forHospital: hospitalID)
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Department", icon: "square.grid.2x2.fill").padding(.horizontal, 16)
            VStack(spacing: 10) {
                NavigationLink {
                    EquipmentLocationsTab(hospitalID: hospitalID)
                        .navigationTitle("Equipment & Locations").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    SectionRow(icon: "shippingbox.fill", tint: Theme.accent, title: "Equipment & Locations",
                               subtitle: "Where to find critical kit", count: o.equipmentLocations.count)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DepartmentTemplatesTab(hospitalID: hospitalID)
                        .navigationTitle("Department Standards").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    SectionRow(icon: "doc.on.doc.fill", tint: Color(hex: "5E7CE2"), title: "Department Standards",
                               subtitle: "Default setups consultants inherit", count: standards)
                }
                .buttonStyle(.plain)

                Button { showingEmergency = true } label: {
                    SectionRow(icon: "cross.case.fill", tint: Color(hex: "D1576E"), title: "Emergency Resources",
                               subtitle: "MH · LAST · Anaphylaxis · CICO", count: nil)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HospitalContactsTab(hospitalID: hospitalID)
                        .navigationTitle("Key Contacts").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    SectionRow(icon: "phone.fill", tint: Color(hex: "E08B3E"), title: "Key Contacts",
                               subtitle: "Charge tech · duty · pharmacy · blood", count: o.contacts.count)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HospitalPoliciesTab(hospitalID: hospitalID)
                        .navigationTitle("Policies & Guidelines").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    SectionRow(icon: "doc.text.fill", tint: Color(hex: "9B7CC9"), title: "Policies & Guidelines",
                               subtitle: "Local workflows & routines", count: o.policies.count)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HospitalOrientationScreen(hospitalID: hospitalID)
                        .navigationTitle("Orientation").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    SectionRow(icon: "map.fill", tint: Color(hex: "2FA98C"), title: "Orientation",
                               subtitle: "Sick call · site notes", count: nil)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HospitalProvidersTab(hospitalID: hospitalID)
                        .navigationTitle(settings.region.providerPlural).navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    SectionRow(icon: "stethoscope", tint: Color(hex: "0B7A6D"), title: settings.region.providerPlural,
                               subtitle: "Based at this site", count: providers)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HospitalFilesTab(hospitalID: hospitalID)
                        .navigationTitle("Shared Files").navigationBarTitleDisplayMode(.inline)
                        .background(Color(.systemGroupedBackground))
                } label: {
                    SectionRow(icon: "folder.fill", tint: Color(hex: "8A8F98"), title: "Shared Files",
                               subtitle: "Packs, maps & checklists", count: o.sharedFiles.count)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Header stat box

/// A compact, tappable metric box under the hospital header. Shows a value,
/// label and icon with a subtle chevron so it reads as interactive.
private struct HeaderStatBox: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(tint)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: Theme.cornerMedium))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .padding(7)
        }
    }
}

/// Press feedback for the header metric boxes — a gentle scale on tap.
private struct PressableStatStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Quick action card

/// A bold, coloured shortcut card used in the dashboard's quick-access grid.
private struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(tint).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Department section row

/// A large module row with icon, subtitle and optional item count.
private struct SectionRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let count: Int?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16)).frame(width: 46, height: 46)
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let count {
                Text("\(count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 26)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
    }
}

// MARK: - Orientation screen

/// Consolidated orientation reference — sick-call workflow and site notes.
struct HospitalOrientationScreen: View {
    @Environment(DataStore.self) private var store
    let hospitalID: UUID

    @State private var editingSickCall = false

    private var hospital: Hospital? { store.hospital(id: hospitalID) }

    var body: some View {
        let o = hospital?.orientationOrEmpty ?? HospitalOrientation()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button { editingSickCall = true } label: { sickCallCard(o.sickCall) }
                    .buttonStyle(.plain)

                if let hospital, !hospital.notes.isBlank {
                    NotesDisplay(title: "Site notes", text: hospital.notes, icon: "note.text")
                }

                DisclaimerNote()
            }
            .padding(16)
        }
        .sheet(isPresented: $editingSickCall) {
            SickCallEditView(hospitalID: hospitalID, info: o.sickCall)
        }
    }

    private func sickCallCard(_ info: SickCallInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Calling in sick", icon: "phone.badge.waveform")
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            if info.hasContent {
                VStack(spacing: 8) {
                    ValueRow(label: "Contact", value: info.whoToContact, icon: "person")
                    ValueRow(label: "Phone", value: info.phone, icon: "phone")
                    ValueRow(label: "Notice", value: info.noticePeriod, icon: "clock")
                    ValueRow(label: "Backup", value: info.backupContact, icon: "person.2")
                    if !info.notes.isBlank {
                        Text(info.notes).font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("Tap to set how to report illness at this site.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

// MARK: - Providers

private struct HospitalProvidersTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let hospitalID: UUID

    var body: some View {
        let providers = store.doctors(forHospital: hospitalID)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if providers.isEmpty {
                    EmptyStateView(
                        icon: "stethoscope",
                        title: "No \(settings.region.providerPlural.lowercased()) here yet",
                        message: "Link a profile to this hospital, or copy an existing profile across from another site."
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(providers) { doctor in
                            NavigationLink {
                                DoctorDetailView(doctorID: doctor.id)
                            } label: {
                                HospitalProviderRow(doctor: doctor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
    }
}

/// Provider row that flags hospital-specific copies.
private struct HospitalProviderRow: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor

    var body: some View {
        HStack(spacing: 14) {
            DoctorAvatar(doctor: doctor, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(doctor.displayName).font(.headline).foregroundStyle(.primary)
                if !doctor.role.isBlank {
                    Text(doctor.role).font(.subheadline).foregroundStyle(.secondary)
                }
                if doctor.isHospitalVersion {
                    HospitalSpecificBadge(hospitalName: doctor.hospitalId.flatMap { store.hospital(id: $0)?.name })
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .card()
    }
}

// MARK: - Shared building blocks

/// Small "Hospital-specific profile" pill used wherever a hospital copy appears.
/// Tappable — opens a short explanation sheet so users understand what the badge
/// means rather than guessing.
struct HospitalSpecificBadge: View {
    var hospitalName: String? = nil
    @State private var showingInfo = false

    var body: some View {
        Button { showingInfo = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "building.2.crop.circle")
                Text("Hospital-specific profile")
                Image(systemName: "info.circle").font(.system(size: 9, weight: .bold)).opacity(0.7)
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.accent.opacity(0.14), in: .capsule)
            .foregroundStyle(Theme.accentDeep)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingInfo) {
            HospitalSpecificInfoSheet(hospitalName: hospitalName)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }
}

/// Explains what a hospital-specific profile means.
struct HospitalSpecificInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    var hospitalName: String?

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.14)).frame(width: 64, height: 64)
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 30)).foregroundStyle(Theme.accent)
            }
            .padding(.top, 28)

            Text("Hospital-specific profile").font(.title3.weight(.bold))

            Text("This profile is configured for \(hospitalName ?? "this hospital"). Setup details may differ at other sites.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer(minLength: 0)

            Button { dismiss() } label: {
                Text("Got it")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: .capsule)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

/// A tappable link row that opens an external URL when possible.
struct LinkRow: View {
    let label: String
    let value: String

    var body: some View {
        if let url = normalizedURL {
            Link(destination: url) {
                HStack(spacing: 12) {
                    Image(systemName: "link").font(.subheadline).foregroundStyle(Theme.accent).frame(width: 22)
                    Text(label).font(.subheadline).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.accentDeep)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        } else {
            ValueRow(label: label, value: value, icon: "link")
        }
    }

    private var normalizedURL: URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") { return URL(string: trimmed) }
        return URL(string: "https://\(trimmed)")
    }
}

/// The shared educational/reference safety note.
struct DisclaimerNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text("Orientation reference only — confirm equipment locations, contacts and policies against current local information.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cornerMedium))
    }
}
