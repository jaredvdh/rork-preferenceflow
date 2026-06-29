//
//  NeuraxialTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Neuraxial — guided, template-driven Spinal, Epidural and Combined Spinal
/// Epidural workflows. Each begins from the department standard; consultants
/// record only their deviations.
struct NeuraxialTab: View {
    @Environment(DataStore.self) private var store
    let doctor: Doctor

    @State private var active: WorkflowDefinition?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                intro

                ForEach(WorkflowLibrary.neuraxial) { definition in
                    WorkflowCardButton(
                        definition: definition,
                        customization: doctor.neuraxial.customization(for: definition.id)
                    ) {
                        active = definition
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $active) { definition in
            WorkflowSummaryView(
                doctorID: doctor.id,
                definition: definition
            )
        }
    }

    private var intro: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
            Text("Start from the standard setup. Only customise what is different.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }
}

/// A tappable card summarising a workflow's status for a provider.
struct WorkflowCardButton: View {
    let definition: WorkflowDefinition
    let customization: WorkflowCustomization
    let action: () -> Void

    private var resolved: ResolvedWorkflow {
        ResolvedWorkflow(definition: definition, customization: customization)
    }

    private var statusText: String {
        guard customization.isConfigured else { return "Not set up" }
        let count = resolved.modificationCount
        if count == 0 { return "Department standard" }
        return "^[\(count) custom change](inflect: true)"
    }

    private var statusColor: Color {
        guard customization.isConfigured else { return .secondary }
        return resolved.modificationCount == 0 ? Theme.accent : .orange
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: definition.icon)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(definition.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(definition.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: customization.isConfigured
                              ? (resolved.modificationCount == 0 ? "checkmark.seal.fill" : "slider.horizontal.3")
                              : "circle.dashed")
                            .font(.caption2)
                        Text(statusText)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(statusColor)
                    .padding(.top, 2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
