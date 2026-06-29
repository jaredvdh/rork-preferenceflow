//
//  Theme.swift
//  PreferenceFlow
//

import SwiftUI

/// Central design tokens. Surgical-teal accent over soft clinical neutrals —
/// calm, premium, and instantly familiar to anyone who uses Apple Health.
enum Theme {
    /// Primary brand accent (surgical teal).
    static let accent = Color(hex: "0E9F8E")
    static let accentBright = Color(hex: "16C2A8")
    static let accentDeep = Color(hex: "0B7A6D")

    /// Deep clinical ink used in hero gradients.
    static let ink = Color(hex: "0E2A33")
    static let inkDeep = Color(hex: "08171C")

    static let cornerLarge: CGFloat = 20
    static let cornerMedium: CGFloat = 14
    static let cornerSmall: CGFloat = 10

    /// Hero gradient used on headers and onboarding.
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accentBright, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var inkGradient: LinearGradient {
        LinearGradient(
            colors: [ink, inkDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    /// Creates a colour from a hex string ("RRGGBB" or "#RRGGBB").
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        } else {
            r = 0; g = 0.62; b = 0.55
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Reusable surfaces

/// A soft, elevated card surface used across the app.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: Theme.cornerLarge))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// Small uppercase section label, Health-style.
struct SectionLabel: View {
    let text: String
    var icon: String?

    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            Text(text.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
    }
}

/// Displays a labelled value row; hides itself when the value is empty.
struct ValueRow: View {
    let label: String
    let value: String
    var icon: String?

    var body: some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(alignment: .top, spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                }
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 2)
        }
    }
}

/// Empty-state placeholder with an icon, title, message and optional action.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Circular provider avatar — photo if present, otherwise coloured initials.
struct DoctorAvatar: View {
    let doctor: Doctor
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            if let data = doctor.photoData, let image = UIImage(data: data) {
                Color.clear
                    .frame(width: size, height: size)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.circle)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: doctor.avatarColorHex).opacity(0.9),
                                     Color(hex: doctor.avatarColorHex)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Text(doctor.initials.isEmpty ? "?" : doctor.initials)
                            .font(.system(size: size * 0.38, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
        }
    }
}
