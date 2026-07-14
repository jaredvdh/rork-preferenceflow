//
//  TodayView.swift
//  PreferenceFlow
//

import SwiftUI

/// The app's dedicated home screen. Shows today's working context (hospital +
/// provider) as a card that opens the provider's preference dashboard, a
/// discipline view switcher (for ODPs and nurses who work both anaesthesia and
/// scrub sides), quick-open shortcuts, and emergency access. The daily context
/// prompt is presented over this screen on a new calendar day per the user's
/// chosen mode.
struct TodayView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    /// Retained for tab-switching compatibility from the root tab bar.
    @Binding var selectedTab: RootTab

    @State private var path = NavigationPath()
    @State private var showingPrompt = false
    @State private var promptPhase: DailyContextPhase = .hospital
    @State private var didAutoPrompt = false
    @State private var showingSettings = false

    private var activeHospital: Hospital? { store.hospital(id: settings.activeHospitalId) }

    /// Today's provider — only surfaced when they match the active discipline
    /// view, so switching views never shows a surgeon on the anaesthesia home
    /// (or vice versa). The stored context is kept, so switching back restores it.
    private var activeDoctor: Doctor? {
        guard let id = settings.activeDoctorId, let doctor = store.doctor(id: id),
              doctor.clinicianKind == settings.discipline.primaryKind else { return nil }
        return doctor
    }

    var body: some View {
        NavigationStack(path: $path) {
            homeContent
                .navigationDestination(for: UUID.self) { doctorID in
                    DoctorDetailView(
                        doctorID: doctorID,
                        dailyHospitalID: settings.activeHospitalId,
                        onChangeDay: {
                            path = NavigationPath()
                            promptPhase = .hospital
                            showingPrompt = true
                        }
                    )
                }
        }
        .adaptiveFullScreenSheet(isPresented: $showingPrompt) {
            DailyContextPromptView(startPhase: promptPhase)
                .presentationDetents([.large])
                .presentationCornerRadius(24)
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: showingPrompt) { wasShowing, isShowing in
            // After the prompt closes with a provider chosen, open straight
            // into their card — home stays one tap back. Never navigate to a
            // provider from the other discipline (e.g. a stored anaesthetist
            // while the surgical view is active).
            guard wasShowing, !isShowing, let id = settings.activeDoctorId,
                  let doctor = store.doctor(id: id),
                  doctor.clinicianKind == settings.discipline.primaryKind else { return }
            path = NavigationPath()
            path.append(id)
        }
        .onAppear {
            guard !didAutoPrompt else { return }
            didAutoPrompt = true
            if let phase = settings.dailyPromptStartPhase {
                promptPhase = phase
                showingPrompt = true
            }
        }
    }

    // MARK: - Home dashboard

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                greetingHeader

                disciplineSwitcher

                if activeDoctor != nil {
                    todayContextCard
                } else {
                    heroCard
                    if activeHospital != nil {
                        hint("Now choose who you're working with today.")
                    }
                }

                if !quickOpenDoctors.isEmpty {
                    quickOpenSection
                }

                EmergencyAccessButton(hospitalID: settings.activeHospitalId, style: .card)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView(embedInStack: false) }
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todayString.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.accent)
            Text(greetingTitle)
                .font(.largeTitle.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Discipline view switcher

    /// Quick toggle between the anaesthesia and surgical views — for ODPs and
    /// nurses who cover both sides of the drapes. Relabels the Providers tab
    /// and the daily prompt; hospitals, crisis manual and search are shared.
    private var disciplineSwitcher: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text("YOUR VIEW")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(Discipline.allCases) { discipline in
                    disciplineChip(discipline)
                }
            }

            Text("Switch anytime — hospitals, the crisis manual, search and backups are shared by both views.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .card(padding: 16)
        .sensoryFeedback(.selection, trigger: settings.discipline)
    }

    private func disciplineChip(_ discipline: Discipline) -> some View {
        let isSelected = settings.discipline == discipline
        return Button {
            guard !isSelected else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                settings.discipline = discipline
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: discipline.symbol)
                    .font(.title3.weight(.semibold))
                Text(shortName(for: discipline))
                    .font(.subheadline.weight(.semibold))
                Text(discipline.primaryKind.providerPlural(settings.region))
                    .font(.caption2)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Theme.accent : Color(.tertiarySystemFill),
                in: .rect(cornerRadius: Theme.cornerMedium)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(discipline.displayName(for: settings.region)) view")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shortName(for discipline: Discipline) -> String {
        switch discipline {
        case .anaesthesia: return settings.region.discipline
        case .surgical: return "Surgical"
        }
    }

    // MARK: - Today's context card

    private var todayContextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TODAY'S CONTEXT")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    promptPhase = .hospital
                    showingPrompt = true
                } label: {
                    Label("Change", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(Theme.accent)
            }

            if let hospital = activeHospital {
                HStack(spacing: 10) {
                    Image(systemName: "building.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                    Text(hospital.name.isBlank ? "Unnamed hospital" : hospital.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let doctor = activeDoctor {
                Button {
                    path.append(doctor.id)
                } label: {
                    HStack(spacing: 14) {
                        DoctorAvatar(doctor: doctor, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doctor.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(doctor.role.isBlank
                                 ? doctor.clinicianKind.provider(settings.region)
                                 : doctor.role)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(12)
                    .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
                }
                .buttonStyle(.plain)

                Button {
                    path.append(doctor.id)
                } label: {
                    Label("Open preference card", systemImage: "person.text.rectangle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 16)
    }

    // MARK: - Quick open (pinned + recent)

    /// Pinned favourites followed by recently viewed profiles, filtered to the
    /// active discipline and excluding today's already-featured provider.
    private var quickOpenDoctors: [Doctor] {
        let kind = settings.discipline.primaryKind
        var seen = Set<UUID>()
        if let activeID = settings.activeDoctorId { seen.insert(activeID) }
        var result: [Doctor] = []
        for id in settings.favouriteDoctorIds + settings.recentDoctorIds {
            guard !seen.contains(id), let doctor = store.doctor(id: id),
                  doctor.clinicianKind == kind else { continue }
            seen.insert(id)
            result.append(doctor)
            if result.count == 4 { break }
        }
        return result
    }

    private var quickOpenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK OPEN")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(quickOpenDoctors) { doctor in
                    Button {
                        path.append(doctor.id)
                    } label: {
                        HStack(spacing: 12) {
                            DoctorAvatar(doctor: doctor, size: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(doctor.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if !doctor.role.isBlank {
                                    Text(doctor.role)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if settings.isFavouriteDoctor(doctor.id) {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent.opacity(0.7))
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: Theme.cornerMedium))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card(padding: 16)
    }

    // MARK: - Hero card (no provider chosen yet)

    private var heroCard: some View {
        Button {
            promptPhase = settings.activeHospitalId == nil ? .hospital : .anaesthetist
            showingPrompt = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.heroGradient).frame(width: 60, height: 60)
                    Image(systemName: settings.discipline == .surgical ? "scissors" : "stethoscope")
                        .font(.title.weight(.semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start your day")
                        .font(.title2.weight(.bold))
                    Text(activeHospital == nil
                         ? "Pick today's hospital and the \(settings.providerTitle.lowercased()) you're working with to open straight into their profile."
                         : "You're at \(activeHospital?.name ?? ""). Choose the \(settings.providerTitle.lowercased()) you're working with.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Label(activeHospital == nil ? "Choose hospital" : "Choose \(settings.providerTitle.lowercased())", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: .capsule)
                    .foregroundStyle(.white)
            }
            .card(padding: 20)
        }
        .buttonStyle(.plain)
    }

    private func hint(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(Theme.accent)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
    }

    private var greetingTitle: String {
        let part = greetingTimeOfDay
        return settings.userName.isBlank ? part : "\(part), \(settings.userName)"
    }

    private var greetingTimeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }
}
