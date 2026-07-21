//
//  ProfileChangeHistoryView.swift
//  PreferenceFlow
//

import SwiftUI

/// Local change history for one profile: who edited it, when, and which sections
/// changed — with the ability to revert to how the profile looked before any
/// entry. Everything stays on-device; the editor identity is simply whatever
/// name and role are saved in Settings.
struct ProfileChangeHistoryView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let doctorID: UUID

    /// The record awaiting revert confirmation.
    @State private var pendingRevert: ProfileChangeRecord?

    private var records: [ProfileChangeRecord] {
        store.changeRecords(for: doctorID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Changes Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Edits to this profile will appear here, showing who made them and letting you revert.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(records) { record in
                                row(record)
                            }
                        } footer: {
                            Text("The last 20 changes are kept on this device. Reverting restores how the profile looked before that change — nothing is removed from history. Editor names come from Settings → Your name.")
                        }
                    }
                }
            }
            .navigationTitle("Change History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Revert to how this profile looked before this change? A new entry will be added to the history.",
                isPresented: revertDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Revert Profile") {
                    if let record = pendingRevert {
                        store.revertDoctor(doctorID, to: record)
                    }
                    pendingRevert = nil
                }
                Button("Cancel", role: .cancel) { pendingRevert = nil }
            }
        }
    }

    /// Drives the confirmation dialog off the pending record so the dialog and
    /// its target can never get out of sync.
    private var revertDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingRevert != nil },
            set: { if !$0 { pendingRevert = nil } }
        )
    }

    private func row(_ record: ProfileChangeRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.summary)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(record.editorLine)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(record.timestampSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Revert to this version") {
                    pendingRevert = record
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
