//
//  OnboardingView.swift
//  PreferenceFlow
//

import SwiftUI

/// First-run flow: welcome → country/region → terminology confirmation → safety.
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings

    @State private var step = 0
    @State private var country = ""
    @State private var regionName = ""
    @State private var region: TerminologyRegion? = nil
    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.inkGradient.ignoresSafeArea()
            backgroundGlow

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 24)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    locationStep.tag(1)
                    terminologyStep.tag(2)
                    safetyStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
            .readableColumn(maxWidth: 600)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appear = true } }
    }

    private var backgroundGlow: some View {
        Circle()
            .fill(Theme.accent.opacity(0.25))
            .frame(width: 320, height: 320)
            .blur(radius: 90)
            .offset(x: 120, y: -260)
            .ignoresSafeArea()
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Theme.accentBright : Color.white.opacity(0.25))
                    .frame(width: index == step ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    // MARK: Steps

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
                Text("ORPrep")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("The preference book for theatre teams.\nEvery provider's setup, ready before they arrive.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
            primaryButton("Get Started") { advance() }
        }
        .padding(.bottom, 50)
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepHeader(
                title: "Where do you work?",
                subtitle: "We'll match the right terminology for your region."
            )

            VStack(spacing: 12) {
                ForEach(CountryOption.allCases) { option in
                    countryRow(option)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Or enter manually")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                glassField("Country", text: $country)
                glassField("Region / State (optional)", text: $regionName)
            }

            Spacer()
            primaryButton("Continue") {
                if let suggested = TerminologyRegion.suggested(for: country) {
                    region = suggested
                }
                // else: no keyword match — leave `region` at whatever the user
                // last touched (or nil) and let the terminology step present
                // all options with equal weight, no false default.
                advance()
            }
            .disabled(country.isEmpty)
            .opacity(country.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    private var terminologyStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepHeader(
                title: hasTerminologySuggestion ? "Confirm terminology" : "Choose terminology",
                subtitle: hasTerminologySuggestion
                    ? "This updates titles and spelling across the whole app."
                    : "We don't have a tailored preset for \(countryDisplayLabel) yet — pick whichever set of titles and spelling feels closest. You can change this anytime in Settings."
            )

            VStack(spacing: 12) {
                ForEach(TerminologyRegion.allCases) { option in
                    terminologyRow(option)
                }
            }

            previewCard

            Spacer()
            primaryButton("Continue") { advance() }
                .disabled(region == nil)
                .opacity(region == nil ? 0.5 : 1)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    /// Whether the entered country maps to one of the three maintained presets.
    private var hasTerminologySuggestion: Bool {
        TerminologyRegion.suggested(for: country) != nil
    }

    /// Country name for the honest "no preset" subtitle. Falls back to a
    /// generic phrase when empty or "Other / not listed" was picked.
    private var countryDisplayLabel: String {
        if country.isEmpty || country == CountryOption.other.rawValue {
            return "your country"
        }
        return country
    }

    private var safetyStep: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accentBright)

            Text("Reference tool only")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(SafetyText.disclaimer)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(20)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: Theme.cornerLarge))

            Text("No dose calculations. No clinical recommendations. Stores your preferences only.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)

            Spacer()
            primaryButton("I Understand — Start") { finish() }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 44)
    }

    // MARK: Components

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func countryRow(_ option: CountryOption) -> some View {
        Button {
            country = option.rawValue
            region = option.region // nil for "Other / not listed" — explicit choice next step
        } label: {
            HStack {
                Text(option.flag).font(.title2)
                Text(option.rawValue)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
                if country == option.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accentBright)
                }
            }
            .padding(14)
            .background(
                country == option.rawValue ? Theme.accent.opacity(0.25) : Color.white.opacity(0.07),
                in: .rect(cornerRadius: Theme.cornerMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(country == option.rawValue ? Theme.accentBright : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func terminologyRow(_ option: TerminologyRegion) -> some View {
        Button { region = option } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(option.provider) · \(option.assistant)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: region == option ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(region == option ? Theme.accentBright : .white.opacity(0.4))
            }
            .padding(14)
            .background(
                region == option ? Theme.accent.opacity(0.22) : Color.white.opacity(0.07),
                in: .rect(cornerRadius: Theme.cornerMedium)
            )
        }
        .buttonStyle(.plain)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PREVIEW")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
            if let region {
                Text("You are an \(region.assistant), saving setups for \(region.providerPlural.lowercased()).")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text("Select an option above to see how titles will read.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: Theme.cornerMedium))
    }

    private func glassField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
            .foregroundStyle(.white)
            .padding(14)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: Theme.cornerMedium))
    }

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

    private func finish() {
        settings.country = country == CountryOption.other.rawValue ? "" : country
        settings.regionName = regionName
        settings.region = region ?? .commonwealth
        withAnimation { settings.didCompleteOnboarding = true }
    }
}

/// Centralised safety disclaimer text reused across the app.
enum SafetyText {
    static let disclaimer = "This application is a preference and setup reference tool only. It does not provide clinical advice, medication recommendations, dosing guidance, or replace clinical judgement, local policy, medication checking, or direct instruction from the responsible anaesthetist/anesthesiologist."
}
