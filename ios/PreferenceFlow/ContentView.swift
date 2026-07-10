//
//  ContentView.swift
//  PreferenceFlow
//

import SwiftUI

/// Root view. Gates onboarding, applies the optional app lock, then presents
/// the main tab navigation. The lock engages on launch and again whenever the
/// app is backgrounded, and clears via Face ID / Touch ID / passcode.
struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var appLock = AppLockManager()

    var body: some View {
        Group {
            if settings.didCompleteOnboarding {
                RootTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: settings.didCompleteOnboarding)
        .appTextSize(settings.appTextSize)
        .overlay {
            if appLock.isLocked {
                AppLockScreen(manager: appLock)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if settings.isAppLockEnabled { appLock.lock() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard settings.isAppLockEnabled else { return }
            switch newPhase {
            case .background:
                appLock.lock()
            case .active:
                Task { await appLock.autoAuthenticateIfNeeded() }
            default:
                break
            }
        }
    }
}

/// Identifies the root tab bar destinations so views can switch tabs.
enum RootTab: Hashable {
    case today, providers, hospital, search
}

/// Bottom tab navigation surfaces the app's four core pillars: Today · Consultants ·
/// Hospital · Search. This bar is identical on every screen. Knowledge reference
/// content now lives inside Hospital (Emergency Resources & Standards). Settings,
/// Import/Export and About live in a secondary settings screen reached from the
/// gear in Today.
struct RootTabView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DataStore.self) private var store

    @State private var selection: RootTab = .today
    @State private var showGuidedTour = false

    var body: some View {
        TabView(selection: $selection) {
            TodayView(selectedTab: $selection)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(RootTab.today)

            DoctorsView()
                .tabItem { Label(settings.region.providerPlural, systemImage: "person.text.rectangle.fill") }
                .tag(RootTab.providers)

            HospitalsView()
                .tabItem { Label("Hospital", systemImage: "building.2.fill") }
                .tag(RootTab.hospital)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(RootTab.search)
        }
        .tint(Theme.accent)
        .onOpenURL { url in handleDeepLink(url) }
        .adaptiveFullScreenSheet(isPresented: $showGuidedTour) {
            GuidedTourView(
                onSetupHospital: {
                    settings.pendingOpenAddHospital = true
                    selection = .hospital
                    finishGuidedTour()
                },
                onAddConsultant: {
                    settings.pendingOpenAddDoctor = true
                    selection = .providers
                    finishGuidedTour()
                },
                onFinish: { finishGuidedTour() }
            )
        }
        .onAppear {
            if !settings.hasSeenGuidedTour { showGuidedTour = true }
        }
    }

    /// Marks the first-launch tour as seen and dismisses it.
    private func finishGuidedTour() {
        settings.hasSeenGuidedTour = true
        showGuidedTour = false
    }

    /// Routes a scanned preference-card QR code (preferenceflow://consultant/<id>)
    /// to the matching consultant on the Consultants tab.
    private func handleDeepLink(_ url: URL) {
        guard let id = ProfileDeepLink.doctorID(from: url), store.doctor(id: id) != nil else { return }
        settings.pendingDeepLinkDoctorID = id
        selection = .providers
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .environment(DataStore())
}
