//
//  NeuraxialSummary.swift
//  PreferenceFlow
//
//  A single source of truth for summarising a consultant's configured neuraxial
//  workflows (Spinal, Epidural, Combined Spinal Epidural). It reads the *live*
//  template-driven workflow customisation data — the same data the dedicated
//  guided workflow screens edit and display — and produces curated, human-readable
//  lines. Shared by the on-screen consultant profile card and the PDF / theatre
//  card exports so they can never drift out of sync.
//

import Foundation

/// One line of a neuraxial workflow summary: a label and value, with a flag for
/// whether the value is a longer free-text note (rendered stacked) rather than a
/// short inline value.
nonisolated struct NeuraxialSummaryLine: Hashable {
    let label: String
    let value: String
    var isNote: Bool = false
    /// True for a value that flags a missing-but-expected field (e.g. a CSE
    /// intrathecal agent that was never recorded). Rendered as a visible warning
    /// rather than silently omitted so incomplete setups are never invisible.
    var isWarning: Bool = false
}

/// A configured neuraxial workflow paired with its resolved (standard + overrides)
/// values and whether the consultant has deviated from the department standard.
nonisolated struct ConfiguredNeuraxial {
    let definition: WorkflowDefinition
    let resolved: ResolvedWorkflow
    let modified: Bool
    /// True when this is a CSE whose intrathecal agent was never explicitly
    /// recorded (e.g. migrated from the legacy struct). Drives a visible
    /// "not recorded" nudge rather than silently showing the department default.
    var intrathecalAgentMissing: Bool = false
}

nonisolated enum NeuraxialSummary {
    /// The neuraxial workflows this consultant has actively configured, in library
    /// order (Spinal, Epidural, CSE), each with resolved values.
    static func configured(_ n: NeuraxialPreferences) -> [ConfiguredNeuraxial] {
        WorkflowLibrary.neuraxial.compactMap { definition in
            guard n.isConfigured(definition.id) else { return nil }
            let resolved = ResolvedWorkflow(definition: definition, customization: n.customization(for: definition.id))
            let agentMissing = definition.id == "cse" && n.cseIntrathecalAgentMissing
            return ConfiguredNeuraxial(
                definition: definition,
                resolved: resolved,
                modified: resolved.modificationCount > 0,
                intrathecalAgentMissing: agentMissing
            )
        }
    }

    /// Curated, ordered summary lines for a configured workflow. Takes the whole
    /// `ConfiguredNeuraxial` so CSE rendering can flag a missing intrathecal agent.
    static func lines(for item: ConfiguredNeuraxial) -> [NeuraxialSummaryLine] {
        switch item.definition.id {
        case "spinal": return spinal(item.resolved)
        case "epidural": return epidural(item.resolved)
        case "cse": return cse(item.resolved, agentMissing: item.intrathecalAgentMissing)
        default: return generic(item.resolved)
        }
    }

    /// A compact one-line summary for collapsed rows ("Whitacre 25G · Heavy Bupivacaine").
    static func collapsedSummary(for item: ConfiguredNeuraxial) -> String {
        let tokens = lines(for: item)
            .filter { !$0.isNote }
            .prefix(2)
            .map { $0.isWarning ? $0.value : shorten($0.value) }
        return tokens.isEmpty ? "Department standard" : tokens.joined(separator: " · ")
    }

    // MARK: - Spinal

    private static func spinal(_ r: ResolvedWorkflow) -> [NeuraxialSummaryLine] {
        var out: [NeuraxialSummaryLine] = []
        func add(_ label: String, _ value: String, isNote: Bool = false) {
            if !value.isBlank { out.append(NeuraxialSummaryLine(label: label, value: value, isNote: isNote)) }
        }

        add("Local anaesthetic (skin)", r.selection("skinLA.agent"))
        add("Intrathecal agent", r.selection("intrathecal.agent"))

        let additives = r.multi("additives.list")
        if !additives.isEmpty {
            var value = additives.joined(separator: ", ")
            value += prepSuffix(r.selection("additives.prep"))
            add("Intrathecal additives", value)
        }

        add("Position", r.selection("position.choice"))
        add("Needle", needleAndGauge(r, needle: "technique.needle", gauge: "technique.gauge"))
        add("Introducer", r.boolValue("technique.introducer") ? "Yes" : "No")
        add("Equipment", equipment(r, packField: "pack.use", packLabel: "Standard spinal pack", extrasField: "additional.items"), isNote: true)
        add("Consultant notes", consultantNotes(r), isNote: true)
        return out
    }

    // MARK: - Epidural

    private static func epidural(_ r: ResolvedWorkflow) -> [NeuraxialSummaryLine] {
        var out: [NeuraxialSummaryLine] = []
        func add(_ label: String, _ value: String, isNote: Bool = false) {
            if !value.isBlank { out.append(NeuraxialSummaryLine(label: label, value: value, isNote: isNote)) }
        }
        add("Sterile technique", r.selection("sterile.level"))
        add("Position", r.selection("position.choice"))
        add("Kit", r.selection("kit.choice"))
        add("Loss of resistance", r.selection("lor.method"))
        add("Catheter", r.selection("catheter.type"))
        add("Dressing", r.selection("dressing.choice"))
        add("Test dose", r.boolValue("testdose.use") ? "Yes" : "No")
        add("Catheter notes", r.note("catheter.notes"), isNote: true)
        add("Infusion setup", r.note("infusion.notes"), isNote: true)
        add("Assistant tasks", r.note("assistant.notes"), isNote: true)
        add("Consultant notes", r.note("consultant.notes"), isNote: true)
        return out
    }

    // MARK: - Combined Spinal Epidural

    private static func cse(_ r: ResolvedWorkflow, agentMissing: Bool = false) -> [NeuraxialSummaryLine] {
        var out: [NeuraxialSummaryLine] = []
        func add(_ label: String, _ value: String, isNote: Bool = false) {
            if !value.isBlank { out.append(NeuraxialSummaryLine(label: label, value: value, isNote: isNote)) }
        }
        add("Sterile technique", r.selection("sterile.level"))
        add("CSE kit", r.selection("kit.choice"))
        add("Dressing", r.selection("dressing.choice"))
        if agentMissing {
            // Never silently fall back to the department default for a migrated
            // profile — surface it as incomplete instead.
            out.append(NeuraxialSummaryLine(label: "Intrathecal agent", value: "Not recorded", isWarning: true))
        } else {
            add("Intrathecal agent", r.selection("spinal.agent"))
        }

        let additives = r.multi("spinal.additives")
        if !additives.isEmpty { add("Additives", additives.joined(separator: ", ")) }

        add("Position", r.selection("position.choice"))
        add("Spinal needle", needleAndGauge(r, needle: "spinal.needle", gauge: "spinal.gauge"))
        add("Loss of resistance", r.selection("epidural.lor"))
        add("Catheter", r.selection("epidural.catheter"))
        add("Assistant tasks", r.note("assistant.notes"), isNote: true)
        add("Consultant notes", r.note("consultant.notes"), isNote: true)
        return out
    }

    // MARK: - Generic fallback (future neuraxial workflows)

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

    private static func needleAndGauge(_ r: ResolvedWorkflow, needle: String, gauge: String) -> String {
        let n = r.selection(needle)
        let g = r.selection(gauge)
        if n.isBlank { return g }
        return g.isBlank ? n : "\(n) \(g)"
    }

    private static func equipment(_ r: ResolvedWorkflow, packField: String, packLabel: String, extrasField: String) -> String {
        var parts: [String] = []
        if r.boolValue(packField) { parts.append(packLabel) }
        parts.append(contentsOf: r.multi(extrasField))
        return parts.joined(separator: ", ")
    }

    private static func consultantNotes(_ r: ResolvedWorkflow) -> String {
        var parts = r.multi("consultant.prefs")
        let free = r.note("consultant.notes")
        if !free.isBlank { parts.append(free) }
        return parts.joined(separator: "; ")
    }

    private static func prepSuffix(_ prep: String) -> String {
        switch prep {
        case "Consultant prepares": return " (consultant prepares)"
        case "Yes": return " (assistant may prepare)"
        default: return ""
        }
    }

    /// Shortens a drug name for collapsed summaries: drops a parenthetical brand
    /// and a leading concentration ("0.5% Heavy Bupivacaine (Marcaine Heavy)" →
    /// "Heavy Bupivacaine").
    private static func shorten(_ value: String) -> String {
        var text = value
        if let range = text.range(of: " (") { text = String(text[..<range.lowerBound]) }
        let parts = text.split(separator: " ")
        if let first = parts.first, first.contains("%") {
            text = parts.dropFirst().joined(separator: " ")
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}
