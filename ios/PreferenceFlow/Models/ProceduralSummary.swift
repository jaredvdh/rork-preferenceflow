//
//  ProceduralSummary.swift
//  PreferenceFlow
//
//  The display pipeline for configured procedural workflows (Arterial Line,
//  CVC) — the exact counterpart of NeuraxialSummary. It reads the *live*
//  template-driven workflow customisation data and produces curated,
//  human-readable lines shared by the on-screen consultant profile card and the
//  PDF / theatre card exports so they can never drift out of sync.
//

import Foundation

/// A configured procedural workflow paired with its resolved (standard +
/// overrides) values and whether the consultant has deviated from the
/// department standard.
nonisolated struct ConfiguredProcedural {
    let definition: WorkflowDefinition
    let resolved: ResolvedWorkflow
    let modified: Bool
}

nonisolated enum ProceduralSummary {
    /// The procedural workflows this consultant has actively configured, in
    /// library order (Arterial Line, CVC), each with resolved values.
    static func configured(_ n: NeuraxialPreferences) -> [ConfiguredProcedural] {
        WorkflowLibrary.procedural.compactMap { definition in
            guard n.isConfigured(definition.id) else { return nil }
            let resolved = ResolvedWorkflow(definition: definition, customization: n.customization(for: definition.id))
            return ConfiguredProcedural(
                definition: definition,
                resolved: resolved,
                modified: resolved.modificationCount > 0
            )
        }
    }

    /// Curated, ordered summary lines for a configured procedural workflow.
    static func lines(for item: ConfiguredProcedural) -> [NeuraxialSummaryLine] {
        switch item.definition.id {
        case "arterialLine": return arterialLine(item.resolved)
        case "cvc": return cvc(item.resolved)
        default: return generic(item.resolved)
        }
    }

    /// A compact one-line summary for collapsed rows.
    /// Arterial line: "Right radial · Integrated guidewire · Ultrasound DNTP".
    /// CVC: "Right IJ · Arrow Quad Lumen · 16–18cm".
    static func collapsedSummary(for item: ConfiguredProcedural) -> String {
        let tokens: [String]
        switch item.definition.id {
        case "arterialLine":
            tokens = [
                siteWithLaterality(item.resolved),
                shorten(item.resolved.selection("site.cannulaType")),
                shorten(item.resolved.selection("technique.approach"))
            ]
        case "cvc":
            tokens = [
                item.resolved.selection("site.choice"),
                shorten(item.resolved.selection("site.type")),
                shorten(item.resolved.selection("site.lineLength"))
            ]
        default:
            tokens = lines(for: item).filter { !$0.isNote }.prefix(2).map { shorten($0.value) }
        }
        let cleaned = tokens.filter { !$0.isBlank }
        return cleaned.isEmpty ? "Department standard" : cleaned.prefix(3).joined(separator: " · ")
    }

    // MARK: - Arterial line

    private static func arterialLine(_ r: ResolvedWorkflow) -> [NeuraxialSummaryLine] {
        var out: [NeuraxialSummaryLine] = []
        func add(_ label: String, _ value: String, isNote: Bool = false) {
            if !value.isBlank { out.append(NeuraxialSummaryLine(label: label, value: value, isNote: isNote)) }
        }
        add("Site", r.selection("site.choice"))
        let laterality = r.multi("site.laterality")
        if !laterality.isEmpty { add("Laterality / avoidance", laterality.joined(separator: ", ")) }
        add("Cannula type", r.selection("site.cannulaType"))
        add("Gauge / length", r.selection("site.gaugeLength"))
        add("Approach", r.selection("technique.approach"))
        add("Ultrasound guided", r.boolValue("site.ultrasound") ? "Yes" : "No")
        add("Skin prep", r.selection("prep.antiseptic"))
        add("Local anaesthetic", r.selection("prep.la"))
        add("Wrist position", r.selection("positioning.wrist"))
        add("Flush solution", r.selection("transducer.flush"))
        add("Dressing", r.selection("securing.dressing"))
        // Legacy free-text saved before the model was simplified — never dropped.
        add("Positioning notes", r.note("prep.positioning"), isNote: true)
        add("Transducer notes", r.note("transducer.notes"), isNote: true)
        add("Securing notes", r.note("securing.notes"), isNote: true)
        add("Consultant notes", r.note("consultant.notes"), isNote: true)
        return out
    }

    // MARK: - CVC

    private static func cvc(_ r: ResolvedWorkflow) -> [NeuraxialSummaryLine] {
        var out: [NeuraxialSummaryLine] = []
        func add(_ label: String, _ value: String, isNote: Bool = false) {
            if !value.isBlank { out.append(NeuraxialSummaryLine(label: label, value: value, isNote: isNote)) }
        }
        add("Sterile technique", r.selection("sterile.level"))
        add("Site", r.selection("site.choice"))
        add("Line type", r.selection("site.type"))
        add("Line length", r.selection("site.lineLength"))
        add("Ultrasound guided", r.boolValue("site.ultrasound") ? "Yes" : "No")
        add("Skin prep", r.selection("prep.antiseptic"))
        add("Local anaesthetic", r.selection("prep.la"))
        add("Positioning", r.note("prep.positioning"), isNote: true)
        add("Tip confirmation", r.selection("confirm.method"))
        add("CVP transducer port", r.selection("confirm.transducerPort"))
        add("Transducer notes", r.note("confirm.transducerNotes"), isNote: true)
        add("Confirmation checks", r.note("confirm.notes"), isNote: true)
        add("Suture", r.selection("fixation.suture"))
        add("Anchoring technique", r.selection("fixation.technique"))
        add("Dressing", r.selection("fixation.dressing"))
        add("Fixation notes", r.note("fixation.notes"), isNote: true)
        add("Consultant notes", r.note("consultant.notes"), isNote: true)
        return out
    }

    // MARK: - Generic fallback (future procedural workflows)

    private static func generic(_ r: ResolvedWorkflow) -> [NeuraxialSummaryLine] {
        var out: [NeuraxialSummaryLine] = []
        for field in r.definition.allFields {
            switch field.kind {
            case .toggle, .packReference:
                out.append(NeuraxialSummaryLine(label: field.label, value: r.boolValue(field.id) ? "Yes" : "No"))
            case .singleSelect, .segmented:
                let value = r.selection(field.id)
                if !value.isBlank { out.append(NeuraxialSummaryLine(label: field.label, value: value)) }
            case .multiSelect:
                let values = r.multi(field.id)
                if !values.isEmpty { out.append(NeuraxialSummaryLine(label: field.label, value: values.joined(separator: ", "))) }
            case .note:
                let value = r.note(field.id)
                if !value.isBlank { out.append(NeuraxialSummaryLine(label: field.label, value: value, isNote: true)) }
            }
        }
        return out
    }

    // MARK: - Builders

    /// "Right radial" when a single laterality is recorded, otherwise the plain
    /// site ("Radial").
    private static func siteWithLaterality(_ r: ResolvedWorkflow) -> String {
        let laterality = r.multi("site.laterality")
        if laterality.count == 1, let only = laterality.first, only.localizedCaseInsensitiveContains("radial") {
            return only
        }
        return r.selection("site.choice")
    }

    /// Shortens a value for collapsed summaries: drops any parenthetical detail
    /// ("Integrated guidewire (e.g. Arrow…)" → "Integrated guidewire",
    /// "Ultrasound DNTP (dynamic needle tip positioning)" → "Ultrasound DNTP").
    private static func shorten(_ value: String) -> String {
        var text = value
        if let range = text.range(of: " (") { text = String(text[..<range.lowerBound]) }
        return text.trimmingCharacters(in: .whitespaces)
    }
}
