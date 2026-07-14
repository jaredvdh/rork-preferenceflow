//
//  TodayView.swift
//  PreferenceFlow
//

import SwiftUI

/// The app's home for the current shift. Once the day's hospital and consultant
/// are chosen, this opens directly into that consultant's profile dashboard — the
/// app is centred on the consultant, not on individual procedures. The daily
/// context prompt is presented over this screen on a new calendar day per the
/// user's chosen mode.
struct TodayView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    /// Retained for tab-switching compatibility from the root tab bar.
    @Binding var selectedTab: RootTab

    @State private var showingPrompt = false
    @State private var promptPhase: DailyContextPhase = .hospital
    @State private var didAutoPrompt = false
    @State private var showingSettings = false

    private var activeHospital: Hospital? { store.hospital(id: settings.activeHospitalId) }
    private var activeDoctor: Doctor? {
        guard let id = settings.activeDoctorId else { return nil }
        return store.doctor(id: id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let doctor = activeDoctor {
                    DoctorDetailView(
                        doctorID: doctor.id,
                        dailyHospitalID: settings.activeHospitalId,
                        onChangeDay: {
                            promptPhase = .hospital
                            showingPrompt = true
                        }
                    )
                } else {
                    setupHome
                }
            }
        }
        .adaptiveFullScreenSheet(isPresented: $showingPrompt) {
            DailyContextPromptView(startPhase: promptPhase)
                .presentationDetents([.large])
                .presentationCornerRadius(24)
                .presentationDragIndicator(.hidden)
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

    // MARK: - Setup home (no consultant chosen yet)

    private var setupHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                greetingHeader

                heroCard

                if activeHospital != nil {
                    hint("Now choose who you're working with today.")
                }

                EmergencyAccessButton(hospitalID: settings.activeHospitalId, style: .card)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Today")
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
