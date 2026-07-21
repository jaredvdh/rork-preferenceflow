//
//  ProfileChangeRecord.swift
//  PreferenceFlow
//

import Foundation

/// One entry in a consultant/surgeon profile's local change history. Records who
/// edited the profile (as saved in Settings), a plain-English summary of which
/// sections changed, and a full snapshot of the profile as it looked *before*
/// the edit — enough to revert. Entirely on-device; no accounts or networking.
nonisolated struct ProfileChangeRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var doctorID: UUID
    var timestamp: Date = Date()
    var editorName: String
    var editorRole: ContributorRole
    var summary: String
    /// The previous `Doctor`, encoded with `PreferenceCoding.encoder()`.
    var snapshotBefore: Data

    /// "Sam · Charge Nurse / Team Leader" — falls back to just the role when no
    /// name is saved in Settings (expected on a shared device).
    var editorLine: String {
        editorName.isBlank ? editorRole.rawValue : "\(editorName) · \(editorRole.rawValue)"
    }

    /// Relative timestamp for history rows — mirrors the day-math pattern used
    /// by `Doctor.updatedSummary`, with times for very recent entries.
    var timestampSummary: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
        let time = timestamp.formatted(date: .omitted, time: .shortened)
        if days <= 0 { return "Today at \(time)" }
        if days == 1 { return "Yesterday at \(time)" }
        if days < 30 { return "\(days) days ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: timestamp)
    }
}
