//
//  DailyContextPromptView.swift
//  PreferenceFlow
//

import SwiftUI

/// Start-of-shift prompt that captures the day's working context: first the
/// hospital, then the anaesthetist/provider you're working with. Presented over
/// the Today dashboard on a new calendar day (per the user's daily-context mode).
struct DailyContextPromptView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let startPhase: DailyContextPhase

    @State private var phase: DailyContextPhase = .hospital
    @State private var chosenHospitalId: UUID?
    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.inkGradient.ignoresSafeArea()
            backgroundGlow

            VStack(alignment: .leading, spacing: 0) {
                topBar

                if phase == .hospital {
                    hospitalStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    anaesthetistStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .readableColumn(maxWidth: 600)
        }
        .onAppear {
            phase = startPhase
            chosenHospitalId = settings.activeHospitalId
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }

    // MARK: - Chrome

    private var backgroundGlow: some View {
        Circle()
            .fill(Theme.accent.opacity(0.28))
            .frame(width: 320, height: 320)
            .blur(radius: 90)
            .offset(x: -120, y: -280)
            .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            if phase == .anaesthetist && startPhase == .hospital {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .hospital }
                } label: {
                    Label("Hospital", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
            Button("Skip") { finish(doctorId: settings.activeDoctorId) }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Hospital step

    private var greetingName: String {
        settings.userName.isBlank ? "" : ", \(settings.userName)"
    }

    private var hospitalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(
                eyebrow: greeting,
                title: "Hello\(greetingName).",
                subtitle: "What hospital are you working at today?"
            )

            if store.hospitals.isEmpty {
                emptyCard(
                    icon: "building.2",
                    text: "No hospitals yet. You can still continue — add hospitals from More › Hospitals."
                )
                Spacer()
                continueWithoutButton
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.hospitals) { hospital in
                            selectRow(
                                title: hospital.name.isBlank ? "Unnamed hospital" : hospital.name,
                                subtitle: hospital.locationLine,
                                icon: "building.2.fill",
                                selected: chosenHospitalId == hospital.id
                            ) {
                                chosenHospitalId = hospital.id
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .anaesthetist }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Anaesthetist step

    private var hospitalDoctors: [Doctor] {
        guard let id = chosenHospitalId else { return store.doctors }
        let linked = store.doctors(forHospital: id)
        return linked.isEmpty ? store.doctors : linked
    }

    private var chosenHospitalName: String {
        store.hospital(id: chosenHospitalId)?.name ?? ""
    }

    private var anaesthetistStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(
                eyebrow: chosenHospitalName.isBlank ? "Today's team" : chosenHospitalName,
                title: "Who are you working with today?",
                subtitle: "Pick the \(settings.region.provider.lowercased()) you're supporting."
            )

            if hospitalDoctors.isEmpty {
                emptyCard(
                    icon: "person.text.rectangle",
                    text: "No \(settings.region.providerPlural.lowercased()) yet. Continue and add a profile from the \(settings.region.providerPlural) tab."
                )
                Spacer()
                continueWithoutButton
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(hospitalDoctors) { doctor in
                            doctorRow(doctor)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func doctorRow(_ doctor: Doctor) -> some View {
        Button {
            finish(doctorId: doctor.id)
        } label: {
            HStack(spacing: 14) {
                DoctorAvatar(doctor: doctor, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(doctor.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if !doctor.role.isBlank {
                        Text(doctor.role)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accentBright)
            }
            .padding(14)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func header(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.accentBright)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 12)
    }

    private func selectRow(
        title: String,
        subtitle: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .fill(.white.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Theme.accentBright)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if !subtitle.isBlank {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .font(selected ? .title3 : .subheadline)
                    .foregroundStyle(selected ? Theme.accentBright : .white.opacity(0.5))
            }
            .padding(14)
            .background(
                selected ? Theme.accent.opacity(0.22) : Color.white.opacity(0.08),
                in: .rect(cornerRadius: Theme.cornerMedium)
            )
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.accentBright)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var continueWithoutButton: some View {
        Button {
            finish(doctorId: settings.activeDoctorId)
        } label: {
            Text("Continue to dashboard")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.heroGradient, in: .capsule)
                .shadow(color: Theme.accent.opacity(0.4), radius: 14, y: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private func finish(doctorId: UUID?) {
        settings.confirmDailyContext(hospitalId: chosenHospitalId, doctorId: doctorId)
        dismiss()
    }
}
