//
//  GuidedTourView.swift
//  PreferenceFlow
//

import SwiftUI

/// Minimal first-launch guided tour shown once after setup: welcome, then a nudge
/// to add a hospital and a first consultant. Each step can be skipped straight to
/// the app. Presented from `RootTabView`, gated by `AppSettings.hasSeenGuidedTour`.
struct GuidedTourView: View {
    var onSetupHospital: () -> Void
    var onAddConsultant: () -> Void
    var onFinish: () -> Void

    @State private var step = 0
    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.inkGradient.ignoresSafeArea()
            backgroundGlow

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    hospitalStep.tag(1)
                    consultantStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
        }
        .interactiveDismissDisabled()
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appear = true } }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            progressDots
            Spacer()
            Button("Skip for now") { onFinish() }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Theme.accentBright : Color.white.opacity(0.25))
                    .frame(width: index == step ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    private var backgroundGlow: some View {
        Circle()
            .fill(Theme.accent.opacity(0.25))
            .frame(width: 320, height: 320)
            .blur(radius: 90)
            .offset(x: 120, y: -260)
            .ignoresSafeArea()
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.heroGradient)
                    .frame(width: 110, height: 110)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 24, y: 8)
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appear ? 1 : 0.7)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 12) {
                Text("Welcome to ORPrep")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Digital preference cards for the anaesthetic team")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Text("ORPrep replaces the physical preference cards in your theatre folder. Keep a consultant's setup preferences in your pocket, share with colleagues, and access emergency guides anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
            primaryButton("Get started") { advance() }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 50)
    }

    private var hospitalStep: some View {
        stepScaffold(
            icon: "building.2.fill",
            title: "Start with your hospital",
            body: "Add the hospital or department you work in. This organises your consultants and gives you access to emergency resources and equipment locations.",
            primaryTitle: "Set up hospital",
            primaryAction: onSetupHospital
        )
    }

    private var consultantStep: some View {
        stepScaffold(
            icon: "person.text.rectangle.fill",
            title: "Add your first consultant",
            body: "Create a preference card for an anaesthetist you work with. Start from a built-in template and fill in what you know — you can always update it later.",
            primaryTitle: "Add consultant",
            primaryAction: onAddConsultant
        )
    }

    private func stepScaffold(
        icon: String,
        title: String,
        body: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Theme.accentBright)
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 14) {
                primaryButton(primaryTitle, action: primaryAction)
                Button(step == 2 ? "Explore on my own" : "Skip for now") {
                    if step == 2 { onFinish() } else { advance() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 44)
    }

    // MARK: - Components

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.heroGradient, in: .capsule)
                .shadow(color: Theme.accent.opacity(0.4), radius: 14, y: 6)
        }
    }

    private func advance() {
        withAnimation { step += 1 }
    }
}
