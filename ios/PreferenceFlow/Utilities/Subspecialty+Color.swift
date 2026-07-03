//
//  Subspecialty+Color.swift
//  PreferenceFlow
//

import SwiftUI

/// Specialty identity colours. A cardiac consultant should feel visually
/// different from a paediatric one before reading any text — these tints drive
/// the avatar ring, specialty badges, setup cards and read-mode specialty tabs.
/// Core section tabs (General, Airway, Drugs…) keep `Theme.accent`.
extension Subspecialty {
    var color: Color {
        switch self {
        case .cardiac: return Color(hex: "D1576E")      // red
        case .paediatrics: return Color(hex: "4A90D9")  // blue
        case .neuro: return Color(hex: "7B68EE")        // purple
        case .regional: return Color(hex: "2ECC71")     // green
        case .obstetrics: return Color(hex: "F39C12")   // amber
        case .trauma: return Color(hex: "E67E22")       // orange
        case .icu: return Color(hex: "1ABC9C")          // teal variant
        default: return Theme.accent
        }
    }
}
