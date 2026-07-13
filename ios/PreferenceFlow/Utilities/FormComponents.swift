//
//  FormComponents.swift
//  PreferenceFlow
//

import SwiftUI

/// A labelled single-line text field for editor forms.
struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String?

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
            }
            Text(label)
                .font(.body)
                .frame(width: 120, alignment: .leading)
            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }
}

/// A stacked label + multi-line note editor for free-text fields.
struct NotesField: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, text: $text, axis: .vertical)
                .lineLimit(3...10)
                .frame(minHeight: minHeight, alignment: .topLeading)
        }
    }
}

/// Section that only renders its detail rows if at least one has content,
/// otherwise shows a subtle "not set" hint. Used on read-only profile tabs.
struct DetailSection<Content: View>: View {
    let title: String
    var icon: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title, icon: icon)
            VStack(spacing: 8) {
                content
            }
            .card()
        }
    }
}

/// Renders a free-text block as a card paragraph, hidden when empty.
struct NotesDisplay: View {
    let title: String
    let text: String
    var icon: String = "note.text"

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title, icon: icon)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        }
    }
}

/// A pill/chip used for tags and subspecialties.
struct Chip: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                selected ? Theme.accent : Color(.tertiarySystemFill),
                in: .capsule
            )
            .foregroundStyle(selected ? .white : .primary)
    }
}

/// A small badge marking a record as Demo Mode sample data.
struct DemoBadge: View {
    var body: some View {
        Text("Demo")
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: "7A5CD6").opacity(0.15), in: .capsule)
            .foregroundStyle(Color(hex: "7A5CD6"))
    }
}

/// Helper that reports whether a value is non-empty for "empty state" decisions.
extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Structured pickers (v2)

/// A tap-to-pick dropdown that writes a preset option into a String binding.
/// Use inside a Form. Shows a checkmark on the current value and a "Not set" reset.
struct OptionPicker: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    var icon: String?
    var allowClear: Bool = true

    var body: some View {
        picker
            .sensoryFeedback(.selection, trigger: selection)
    }

    private var picker: some View {
        Menu {
            if allowClear {
                Button("Not set") { selection = "" }
            }
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if selection == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                }
                Text(label).foregroundStyle(.primary)
                Spacer()
                Text(selection.isBlank ? "Choose" : selection)
                    .foregroundStyle(selection.isBlank ? .secondary : Theme.accentDeep)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// A free-text field paired with quick-pick suggestion chips. Lets the user tap a
/// common value or type a less-common one. Designed for use inside a Form section.
struct SuggestionField: View {
    let label: String
    @Binding var text: String
    let suggestions: [String]
    var placeholder: String = ""
    var icon: String?

    @State private var chipTapCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(label: label, text: $text, placeholder: placeholder, icon: icon)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            chipTapCount += 1
                            text = suggestion
                        } label: {
                            Chip(text: suggestion, selected: text.caseInsensitiveCompare(suggestion) == .orderedSame)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: chipTapCount)
    }
}

/// A segmented control bound to a String, choosing among a small set of options.
struct SegmentedRow: View {
    let label: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(label, selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Multi-select chips that toggle membership in a `[String]` binding. Renders the
/// curated options as tappable pills; selected pills fill with the accent colour.
struct ChipMultiSelect: View {
    @Binding var selected: [String]
    let options: [String]

    @State private var tapCount = 0

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    tapCount += 1
                    toggle(option)
                } label: {
                    Chip(text: option, selected: selected.contains(option))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: tapCount)
    }

    private func toggle(_ option: String) {
        if let index = selected.firstIndex(of: option) {
            selected.remove(at: index)
        } else {
            selected.append(option)
        }
    }
}

/// A read-only row that shows a label and a wrapped set of value chips, hidden
/// when empty.
struct ChipValueRow: View {
    let label: String
    let values: [String]
    var accent: Bool = true

    var body: some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accent ? Theme.accent.opacity(0.14) : Color(.tertiarySystemFill), in: .capsule)
                            .foregroundStyle(accent ? Theme.accentDeep : .primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
