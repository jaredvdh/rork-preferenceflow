//
//  TextScaling.swift
//  PreferenceFlow
//

import SwiftUI

/// An app-specific text size override, applied on top of the user's iOS system
/// text size setting. Lets a technician quickly enlarge text for this app alone
/// in a busy theatre without changing their phone-wide accessibility setting.
nonisolated enum AppTextSize: String, Codable, CaseIterable, Identifiable {
    case small
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .standard: return "Default"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// How many Dynamic Type steps to shift relative to the system setting.
    var step: Int {
        switch self {
        case .small: return -1
        case .standard: return 0
        case .large: return 1
        case .extraLarge: return 2
        }
    }
}

/// Reads the inherited (system) Dynamic Type size and re-applies it shifted by
/// the app's chosen override, so every descendant scales relative to the user's
/// own iOS setting rather than replacing it.
struct AppTextSizeModifier: ViewModifier {
    let mode: AppTextSize
    @Environment(\.dynamicTypeSize) private var systemSize

    func body(content: Content) -> some View {
        content.dynamicTypeSize(scaled)
    }

    private var scaled: DynamicTypeSize {
        let all = DynamicTypeSize.allCases
        guard let index = all.firstIndex(of: systemSize) else { return systemSize }
        let target = min(max(index + mode.step, 0), all.count - 1)
        return all[target]
    }
}

extension View {
    /// Applies the app-wide text size override on top of the system setting.
    func appTextSize(_ mode: AppTextSize) -> some View {
        modifier(AppTextSizeModifier(mode: mode))
    }
}
