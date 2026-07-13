//
//  CloudBackupService.swift
//  PreferenceFlow
//

import Foundation
import Observation

/// Errors surfaced by the iCloud backup pipeline, with user-friendly text.
nonisolated enum CloudBackupError: LocalizedError {
    case iCloudUnavailable
    case downloadTimedOut

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud isn't available. Sign in to iCloud in the Settings app and make sure iCloud Drive is on."
        case .downloadTimedOut:
            return "This backup is still downloading from iCloud. Check your connection and try again in a moment."
        }
    }
}

/// One backup file living in the app's iCloud Drive container.
nonisolated struct CloudBackupItem: Identifiable, Hashable {
    /// The real JSON file URL (even if only a placeholder exists locally yet).
    let fileURL: URL
    let date: Date?
    /// False when the file exists in iCloud but hasn't downloaded to this device.
    let isDownloaded: Bool

    var id: String { fileURL.lastPathComponent }
}

/// Manages backups of the full profile export to the user's private iCloud
/// Drive container. No accounts, no third-party servers — files live in the
/// user's own iCloud, so a lost or new device can restore everything.
///
/// Backups are versioned `PreferenceExport` JSON files (the same format as
/// manual exports) written to `Documents/Backups` inside the ubiquity
/// container; the newest `maxBackups` are kept and older ones pruned.
@MainActor
@Observable
final class CloudBackupManager {
    enum Availability {
        case unknown
        case available
        case noAccount
    }

    private(set) var availability: Availability = .unknown
    private(set) var isWorking = false
    private(set) var lastBackupDate: Date?

    private var cachedBackupsDirectory: URL?

    private static let lastBackupKey = "pf.lastCloudBackupDate"
    private static let maxBackups = 10
    private static let filePrefix = "ORPrep Backup "

    init() {
        lastBackupDate = UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date
        refreshAvailability()
    }

    /// Re-checks whether an iCloud account is signed in on this device.
    func refreshAvailability() {
        availability = FileManager.default.ubiquityIdentityToken != nil ? .available : .noAccount
    }

    // MARK: - Backup

    /// Writes the export to iCloud Drive as a new timestamped backup file and
    /// prunes old backups beyond the retention limit.
    func backUp(_ export: PreferenceExport) async throws {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let directory = try await backupsDirectory()
        let data = try PreferenceCoding.encoder().encode(export)
        let fileName = Self.backupFileName(for: Date())
        let maxKeep = Self.maxBackups
        let prefix = Self.filePrefix

        try await Task.detached(priority: .utility) {
            let url = directory.appendingPathComponent(fileName)
            try data.write(to: url, options: [.atomic])
            Self.pruneOldBackups(in: directory, prefix: prefix, keeping: maxKeep)
        }.value

        lastBackupDate = Date()
        UserDefaults.standard.set(lastBackupDate, forKey: Self.lastBackupKey)
    }

    // MARK: - Listing & restore

    /// Lists all backups in the iCloud container, newest first, including ones
    /// not yet downloaded to this device (e.g. right after a device migration).
    func loadBackups() async throws -> [CloudBackupItem] {
        let directory = try await backupsDirectory()
        let prefix = Self.filePrefix

        return try await Task.detached(priority: .utility) { () -> [CloudBackupItem] in
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: []
            )
            var items: [CloudBackupItem] = []
            for url in contents {
                let name = url.lastPathComponent
                if name.hasPrefix(prefix), name.hasSuffix(".json") {
                    let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    items.append(CloudBackupItem(fileURL: url, date: date, isDownloaded: true))
                } else if name.hasPrefix("."), name.hasSuffix(".icloud") {
                    // Placeholder for a not-yet-downloaded file: ".<name>.json.icloud"
                    let realName = String(name.dropFirst().dropLast(".icloud".count))
                    guard realName.hasPrefix(prefix), realName.hasSuffix(".json") else { continue }
                    let realURL = directory.appendingPathComponent(realName)
                    let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    items.append(CloudBackupItem(fileURL: realURL, date: date, isDownloaded: false))
                }
            }
            return items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        }.value
    }

    /// Reads and decodes a backup, downloading it from iCloud first if this
    /// device only has a placeholder.
    func readBackup(_ item: CloudBackupItem) async throws -> PreferenceExport {
        let url = item.fileURL
        return try await Task.detached(priority: .userInitiated) { () -> PreferenceExport in
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                var waited: Double = 0
                while !FileManager.default.fileExists(atPath: url.path) {
                    if waited >= 30 { throw CloudBackupError.downloadTimedOut }
                    try await Task.sleep(for: .milliseconds(500))
                    waited += 0.5
                }
            }
            let data = try Data(contentsOf: url)
            return try PreferenceCoding.decoder().decode(PreferenceExport.self, from: data)
        }.value
    }

    /// Deletes a backup file from the iCloud container.
    func deleteBackup(_ item: CloudBackupItem) async throws {
        let url = item.fileURL
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: url)
        }.value
    }

    // MARK: - Container plumbing

    /// Resolves (and caches) the `Documents/Backups` folder inside the app's
    /// ubiquity container. `url(forUbiquityContainerIdentifier:)` can block, so
    /// it always runs off the main actor.
    private func backupsDirectory() async throws -> URL {
        if let cachedBackupsDirectory { return cachedBackupsDirectory }
        let directory = try await Task.detached(priority: .utility) { () -> URL in
            guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                throw CloudBackupError.iCloudUnavailable
            }
            let dir = base.appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("Backups", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }.value
        cachedBackupsDirectory = directory
        return directory
    }

    /// "ORPrep Backup 2026-07-13 14.30.05.json"
    private nonisolated static func backupFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "\(filePrefix)\(formatter.string(from: date)).json"
    }

    /// Keeps the newest `keeping` backups and removes the rest. Best-effort —
    /// pruning failures never fail the backup itself.
    private nonisolated static func pruneOldBackups(in directory: URL, prefix: String, keeping: Int) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let backups = contents
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return l > r
            }
        for stale in backups.dropFirst(keeping) {
            try? FileManager.default.removeItem(at: stale)
        }
    }
}
