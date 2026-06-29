//
//  ProcedurePreset.swift
//  PreferenceFlow
//

import Foundation

/// A starting template for a common procedure. Selecting one pre-populates a
/// `ProcedureTemplate` with typical monitoring, lines and equipment so the user
/// edits rather than starts from a blank form. Reference defaults only — fully
/// editable and not clinical advice.
nonisolated struct ProcedurePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let location: String
    let monitoring: [MonitoringOption]
    let ivAccess: String
    let lineSetup: String
    let equipment: [String]

    /// Builds an editable template from this preset.
    func makeTemplate() -> ProcedureTemplate {
        ProcedureTemplate(
            name: name,
            typicalLocation: location,
            monitoring: Set(monitoring),
            ivCount: ivAccess,
            lineSetup: lineSetup,
            equipmentChecklist: equipment.map { ChecklistItem(text: $0) }
        )
    }

    static let library: [ProcedurePreset] = [
        ProcedurePreset(
            id: "cabg", name: "CABG", symbol: "heart.fill", location: "Cardiac Theatre",
            monitoring: [.ecg, .arterialLine, .cvp, .tee, .bis, .nirs],
            ivAccess: "2 × large bore",
            lineSetup: "Arterial line, triple-transducer setup, quad-lumen central line, introducer sheath",
            equipment: ["Arterial line set", "Triple transducer setup", "Quad lumen CVC", "Introducer sheath", "TEE machine checked", "Rapid infuser primed", "Cell saver available"]
        ),
        ProcedurePreset(
            id: "valve", name: "Valve Surgery", symbol: "heart.fill", location: "Cardiac Theatre",
            monitoring: [.ecg, .arterialLine, .cvp, .tee, .bis],
            ivAccess: "2 × large bore",
            lineSetup: "Arterial line, central line, TEE",
            equipment: ["Arterial line set", "Central line", "TEE machine checked", "Pacing equipment", "Cell saver available"]
        ),
        ProcedurePreset(
            id: "tavi", name: "TAVI", symbol: "heart.circle.fill", location: "Hybrid Theatre / Cath Lab",
            monitoring: [.ecg, .arterialLine, .tee],
            ivAccess: "2 × peripheral",
            lineSetup: "Arterial line, large-bore access, defib pads on",
            equipment: ["Arterial line set", "Defibrillator pads", "Rapid pacing setup", "Vasopressors prepared"]
        ),
        ProcedurePreset(
            id: "trauma-lap", name: "Trauma Laparotomy", symbol: "bolt.heart", location: "Emergency Theatre",
            monitoring: [.ecg, .arterialLine],
            ivAccess: "2 × 14G",
            lineSetup: "Arterial line, rapid infuser, fluid warmer",
            equipment: ["2 × 14G IV", "Rapid infuser primed", "Fluid warmer", "Massive transfusion pack alert", "Cell saver available", "Vasopressors prepared"]
        ),
        ProcedurePreset(
            id: "craniotomy", name: "Craniotomy", symbol: "brain.head.profile", location: "Neuro Theatre",
            monitoring: [.ecg, .arterialLine, .bis],
            ivAccess: "2 × peripheral",
            lineSetup: "Arterial line, head-up positioning, smooth emergence plan",
            equipment: ["Arterial line set", "BIS monitor", "Mannitol available", "Smooth emergence drugs", "Head pins / positioning"]
        ),
        ProcedurePreset(
            id: "csection", name: "C-Section", symbol: "figure.2.and.child.holdinghands", location: "Obstetric Theatre",
            monitoring: [.ecg],
            ivAccess: "1 × 16G",
            lineSetup: "Spinal / regional setup, vasopressor infusion ready",
            equipment: ["Spinal pack", "Phenylephrine / Metaraminol prepared", "Oxytocin ready", "Neonatal resus checked", "Warmer on"]
        ),
        ProcedurePreset(
            id: "paed-dental", name: "Paediatric Dental", symbol: "figure.child", location: "Day Surgery",
            monitoring: [.ecg],
            ivAccess: "1 × paediatric",
            lineSetup: "Inhalational induction, nasal airway plan",
            equipment: ["Paediatric airway sizes", "Throat pack", "Inhalational agent checked", "Paediatric IV cannulae"]
        ),
        ProcedurePreset(
            id: "mri", name: "MRI Anaesthesia", symbol: "waveform.path", location: "MRI Suite",
            monitoring: [.ecg],
            ivAccess: "1 × peripheral",
            lineSetup: "MRI-safe equipment, extended circuit, remote monitoring",
            equipment: ["MRI-safe monitoring", "MRI-safe pumps", "Extended circuit / lines", "Ear protection", "Emergency evacuation plan"]
        ),
        ProcedurePreset(
            id: "spine", name: "Spine Surgery", symbol: "figure.walk", location: "Orthopaedic / Neuro Theatre",
            monitoring: [.ecg, .arterialLine, .bis],
            ivAccess: "2 × large bore",
            lineSetup: "Arterial line, prone positioning aids, neuromonitoring if planned",
            equipment: ["Arterial line set", "Prone positioning supports", "Eye protection / checks", "Cell saver available", "Neuromonitoring liaison"]
        ),
        ProcedurePreset(
            id: "custom", name: "Custom", symbol: "square.and.pencil", location: "",
            monitoring: [.ecg],
            ivAccess: "",
            lineSetup: "",
            equipment: []
        )
    ]
}
