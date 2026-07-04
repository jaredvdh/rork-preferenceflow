//
//  ConsultantEditSession.swift
//  PreferenceFlow
//

import SwiftUI

/// Hosts an inline consultant edit surface: owns a local draft of the profile,
/// autosaves with a short debounce while the user edits, and commits any
/// outstanding change the moment the view leaves the screen (switching sections,
/// tapping Done, or navigating back).
///
/// This is what lets Edit-mode tabs render editable forms directly — the tab IS
/// the editor, with no per-section summary view or Save/Cancel sheet in between.
struct ConsultantEditSession<Content: View>: View {
    @Environment(DataStore.self) private var store

    @State private var draft: Doctor
    /// Snapshot of the last committed value, so redundant upserts (which bump
    /// `updatedAt` and flag imported profiles as locally modified) are skipped.
    @State private var lastSaved: Doctor
    @State private var saveTask: Task<Void, Never>?

    private let isValid: (Doctor) -> Bool
    private let content: (Binding<Doctor>) -> Content

    init(
        doctor: Doctor,
        isValid: @escaping (Doctor) -> Bool = { _ in true },
        @ViewBuilder content: @escaping (Binding<Doctor>) -> Content
    ) {
        _draft = State(initialValue: doctor)
        _lastSaved = State(initialValue: doctor)
        self.isValid = isValid
        self.content = content
    }

    var body: some View {
        content($draft)
            .onChange(of: draft) { _, _ in scheduleSave() }
            .onDisappear { commit() }
    }

    /// Debounced autosave — waits for a short pause in editing so the store's
    /// JSON file isn't rewritten on every keystroke.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            commit()
        }
    }

    private func commit() {
        saveTask?.cancel()
        guard draft != lastSaved, isValid(draft) else { return }
        store.upsert(draft)
        lastSaved = draft
    }
}

/// Standard footer for inline edit forms: autosave reassurance plus the safety
/// disclaimer that previously sat at the foot of each preference tab.
struct InlineEditFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Changes save automatically", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            PrefDisclaimer()
        }
    }
}
