//
//  TraysInstrumentsTab.swift
//  PreferenceFlow
//
//  Surgeon edit tab: instrument sets/trays to open, favourite extras and
//  instruments kept available unopened, plus a back-table setup photo.
//

import SwiftUI

/// Trays & Instruments — a direct inline editor for a surgeon profile.
struct TraysInstrumentsTab: View {
    let doctor: Doctor

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            Form {
                traysSection(surgicalBinding($draft))
                extrasSection(surgicalBinding($draft))
                standbySection(surgicalBinding($draft))
                photoSection(surgicalBinding($draft))
                Section {
                } footer: {
                    InlineEditFooter()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func surgicalBinding(_ draft: Binding<Doctor>) -> Binding<SurgicalPreferences> {
        Binding(
            get: { draft.wrappedValue.surgical ?? SurgicalPreferences() },
            set: { draft.wrappedValue.surgical = $0 }
        )
    }

    private func traysSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.trays.traysToOpen,
                                options: SurgicalOptions.trays)
                CustomListEditor(items: surgical.trays.traysToOpen,
                                 curated: SurgicalOptions.trays,
                                 addLabel: "Add custom tray / set")
            }
            .padding(.vertical, 4)
        } header: {
            Label("Trays to Open", systemImage: "tray.2.fill")
        } footer: {
            Text("Sets opened for a standard list. Tray names vary by hospital — add your local set names.")
        }
    }

    private func extrasSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.trays.favouriteExtras,
                                options: SurgicalOptions.instrumentExtras)
                CustomListEditor(items: surgical.trays.favouriteExtras,
                                 curated: SurgicalOptions.instrumentExtras,
                                 addLabel: "Add custom extra")
            }
            .padding(.vertical, 4)
        } header: {
            Label("Favourite Extras", systemImage: "star")
        } footer: {
            Text("Individual instruments this surgeon always wants opened.")
        }
    }

    private func standbySection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChipMultiSelect(selected: surgical.trays.haveAvailableUnopened,
                                options: SurgicalOptions.standbyInstruments)
                CustomListEditor(items: surgical.trays.haveAvailableUnopened,
                                 curated: SurgicalOptions.standbyInstruments,
                                 addLabel: "Add standby item")
            }
            .padding(.vertical, 4)
            NotesField(label: "Notes", text: surgical.trays.notes, minHeight: 60)
        } header: {
            Label("Available Unopened", systemImage: "shippingbox")
        } footer: {
            Text("Kept in the room but not opened unless asked for.")
        }
    }

    private func photoSection(_ surgical: Binding<SurgicalPreferences>) -> some View {
        Section {
            SetupPhotoField(
                label: "Back-table photo (optional)",
                help: "A photo of the preferred instrument / back-table layout helps a scrub nurse match it exactly.",
                photoData: surgical.trays.setupPhoto
            )
        } header: {
            Label("Setup Photo", systemImage: "photo")
        }
    }
}

/// Free-text additions to a `[String]` chip list. Entries not in the curated
/// options render as removable chips; a "+ Add" field appends new ones. The
/// curated selections themselves are handled by the `ChipMultiSelect` above.
struct CustomListEditor: View {
    @Binding var items: [String]
    let curated: [String]
    var addLabel: String = "Add custom item"

    @State private var isAdding = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    /// Items the user typed themselves (not in the curated chip set).
    private var customItems: [String] {
        items.filter { !curated.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !customItems.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(customItems, id: \.self) { item in
                        Button { remove(item) } label: {
                            HStack(spacing: 4) {
                                Text(item)
                                Image(systemName: "xmark.circle.fill")
                            }
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.14), in: .capsule)
                            .foregroundStyle(Theme.accentDeep)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if isAdding {
                HStack(spacing: 8) {
                    TextField(addLabel, text: $draft)
                        .textInputAutocapitalization(.sentences)
                        .focused($focused)
                        .onSubmit(commit)
                    Button("Add", action: commit)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Button {
                    isAdding = true
                    focused = true
                } label: {
                    Label(addLabel, systemImage: "plus.circle.fill")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func commit() {
        let value = draft.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        if !items.contains(value) { items.append(value) }
        draft = ""
        isAdding = false
        focused = false
    }

    private func remove(_ item: String) {
        items.removeAll { $0 == item }
    }
}
