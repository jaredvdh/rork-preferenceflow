//
//  AppSettings.swift
//  PreferenceFlow
//

import Foundation
import Observation

/// How the app remembers the user's working context (hospital + anaesthetist)
/// between shifts. Controls whether the daily "who are you working with" prompt
/// appears on a new calendar day.
nonisolated enum DailyContextMode: String, Codable, CaseIterable, Identifiable {
    case askEachDay = "Ask me each day"
    case rememberHospital = "Remember hospital only"
    case rememberBoth = "Remember hospital and anaesthetist"
    case doNotAsk = "Do not ask again"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .askEachDay: return "Choose a hospital and anaesthetist at the start of every day."
        case .rememberHospital: return "Keep your hospital, but pick who you're working with each day."
        case .rememberBoth: return "Reuse the same hospital and anaesthetist until you change them."
        case .doNotAsk: return "Never prompt — set today's context manually from the dashboard."
        }
    }
}

/// Which step the daily prompt should open on.
nonisolated enum DailyContextPhase {
    case hospital
    case anaesthetist
}

/// User-level configuration: onboarding state and regional terminology. Persisted
/// to UserDefaults since it's tiny and needs to be available before data loads.
@MainActor
@Observable
final class AppSettings {
    private enum Keys {
        static let didOnboard = "pf.didOnboard"
        static let region = "pf.region"
        static let country = "pf.country"
        static let regionName = "pf.regionName"
        static let userName = "pf.userName"
        static let dailyMode = "pf.dailyContextMode"
        static let activeHospital = "pf.activeHospitalId"
        static let activeDoctor = "pf.activeDoctorId"
        static let contextDay = "pf.contextDay"
        static let recentDoctors = "pf.recentDoctorIds"
        static let favouriteDoctors = "pf.favouriteDoctorIds"
        static let textSize = "pf.appTextSize"
    }

    private let defaults: UserDefaults

    var didCompleteOnboarding: Bool {
        didSet { defaults.set(didCompleteOnboarding, forKey: Keys.didOnboard) }
    }

    var region: TerminologyRegion {
        didSet { defaults.set(region.rawValue, forKey: Keys.region) }
    }

    var country: String {
        didSet { defaults.set(country, forKey: Keys.country) }
    }

    /// Optional sub-region / state entered by the user.
    var regionName: String {
        didSet { defaults.set(regionName, forKey: Keys.regionName) }
    }

    /// The user's first name, used in the daily greeting. Optional.
    var userName: String {
        didSet { defaults.set(userName, forKey: Keys.userName) }
    }

    /// App-specific text size override, applied on top of the iOS system setting.
    var appTextSize: AppTextSize {
        didSet { defaults.set(appTextSize.rawValue, forKey: Keys.textSize) }
    }

    // MARK: - Daily working context

    var dailyContextMode: DailyContextMode {
        didSet { defaults.set(dailyContextMode.rawValue, forKey: Keys.dailyMode) }
    }

    /// Hospital selected for the current working context.
    var activeHospitalId: UUID? {
        didSet { defaults.set(activeHospitalId?.uuidString, forKey: Keys.activeHospital) }
    }

    /// Anaesthetist/provider selected for the current working context.
    var activeDoctorId: UUID? {
        didSet { defaults.set(activeDoctorId?.uuidString, forKey: Keys.activeDoctor) }
    }

    /// The calendar day (yyyy-MM-dd) the context was last confirmed for.
    private var contextDay: String {
        didSet { defaults.set(contextDay, forKey: Keys.contextDay) }
    }

    // MARK: - Recents & favourites

    /// IDs of the most recently viewed consultant profiles, newest first.
    private(set) var recentDoctorIds: [UUID] {
        didSet { defaults.set(recentDoctorIds.map(\.uuidString), forKey: Keys.recentDoctors) }
    }

    /// IDs of consultants the user has pinned as favourites.
    private(set) var favouriteDoctorIds: [UUID] {
        didSet { defaults.set(favouriteDoctorIds.map(\.uuidString), forKey: Keys.favouriteDoctors) }
    }

    /// A consultant a deep link (e.g. a scanned preference-card QR code) asked to
    /// open. Transient — the Consultants tab consumes it and clears it. Not
    /// persisted: it only routes a single navigation.
    var pendingDeepLinkDoctorID: UUID?

    /// The last age/weight the technician dialled into a paediatric airway
    /// reference, remembered for the session so it carries between profiles.
    /// Deliberately NOT persisted: each profile still opens on the Adult cohort.
    var airwayPaedReference: PaediatricPatient = PaediatricPatient()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.didCompleteOnboarding = defaults.bool(forKey: Keys.didOnboard)
        self.country = defaults.string(forKey: Keys.country) ?? ""
        self.regionName = defaults.string(forKey: Keys.regionName) ?? ""
        self.userName = defaults.string(forKey: Keys.userName) ?? ""
        if let raw = defaults.string(forKey: Keys.textSize),
           let parsed = AppTextSize(rawValue: raw) {
            self.appTextSize = parsed
        } else {
            self.appTextSize = .standard
        }
        if let raw = defaults.string(forKey: Keys.region),
           let parsed = TerminologyRegion(rawValue: raw) {
            self.region = parsed
        } else {
            self.region = .commonwealth
        }
        if let raw = defaults.string(forKey: Keys.dailyMode),
           let parsed = DailyContextMode(rawValue: raw) {
            self.dailyContextMode = parsed
        } else {
            self.dailyContextMode = .askEachDay
        }
        self.activeHospitalId = defaults.string(forKey: Keys.activeHospital).flatMap(UUID.init)
        self.activeDoctorId = defaults.string(forKey: Keys.activeDoctor).flatMap(UUID.init)
        self.contextDay = defaults.string(forKey: Keys.contextDay) ?? ""
        self.recentDoctorIds = (defaults.stringArray(forKey: Keys.recentDoctors) ?? []).compactMap(UUID.init)
        self.favouriteDoctorIds = (defaults.stringArray(forKey: Keys.favouriteDoctors) ?? []).compactMap(UUID.init)
    }

    /// Records a consultant as just viewed, keeping the most recent five.
    func recordRecentDoctor(_ id: UUID) {
        var list = recentDoctorIds.filter { $0 != id }
        list.insert(id, at: 0)
        recentDoctorIds = Array(list.prefix(5))
    }

    /// Whether a consultant is pinned as a favourite.
    func isFavouriteDoctor(_ id: UUID) -> Bool {
        favouriteDoctorIds.contains(id)
    }

    /// Toggles a consultant's favourite (pinned) status.
    func toggleFavouriteDoctor(_ id: UUID) {
        if favouriteDoctorIds.contains(id) {
            favouriteDoctorIds.removeAll { $0 == id }
        } else {
            favouriteDoctorIds.insert(id, at: 0)
        }
    }

    /// Convenience accessor used throughout the UI for terminology strings.
    var terms: TerminologyRegion { region }

    // MARK: - Daily context logic

    /// Today's calendar day key (yyyy-MM-dd, POSIX) used to detect day rollover.
    static var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Whether the working context was already confirmed today.
    var isContextCurrent: Bool { contextDay == AppSettings.todayKey }

    /// Which step the daily prompt should open on, or nil if no prompt is needed.
    var dailyPromptStartPhase: DailyContextPhase? {
        switch dailyContextMode {
        case .doNotAsk:
            return nil
        case .rememberBoth:
            // Only prompt the very first time, or once a selection is cleared.
            return activeHospitalId == nil ? .hospital : nil
        case .rememberHospital:
            if isContextCurrent { return nil }
            return activeHospitalId == nil ? .hospital : .anaesthetist
        case .askEachDay:
            return isContextCurrent ? nil : .hospital
        }
    }

    /// Records the chosen working context and marks it confirmed for today.
    func confirmDailyContext(hospitalId: UUID?, doctorId: UUID?) {
        activeHospitalId = hospitalId
        activeDoctorId = doctorId
        contextDay = AppSettings.todayKey
    }

    /// Clears the saved working context (used by "Do not ask" resets).
    func clearDailyContext() {
        activeHospitalId = nil
        activeDoctorId = nil
        contextDay = ""
    }
}
