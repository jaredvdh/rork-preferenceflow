//
//  ProfileScore.swift
//  PreferenceFlow
//

import Foundation

/// One line in the Theatre Ready breakdown.
nonisolated struct ProfileCheck: Identifiable, Hashable {
    let id: String
    let title: String
    let isComplete: Bool
    let symbol: String
}

/// Computes a "Theatre Ready" completeness score for a provider profile by
/// inspecting which preference sections have meaningful content. Pure, testable,
/// and reused by both the Overview card and Quick Setup.
nonisolated enum ProfileScore {
    static func checks(for doctor: Doctor, paediatricTerm: String = "Paediatric") -> [ProfileCheck] {
        let g = doctor.general
        let generalDone = !g.validSterileGloveSize.isBlank || !g.nonSterileGloveSize.isBlank || !g.gownSize.isBlank || !g.maskPreference.isBlank
            || !g.briefingStyle.isBlank || g.arriveBeforePatient || g.prepareOwnMedications
            || !g.generalNotes.isBlank

        let air = doctor.airway
        let airwayDone = !air.adultMale.tubeSize.isBlank || !air.adultFemale.tubeSize.isBlank
            || !air.supraglottic.adultMale.isEmpty || !air.supraglottic.adultFemale.isEmpty
            || !air.supraglottic.largeAdult.isEmpty

        let adultDrugsDone = doctor.adultDrugs?.hasContent ?? false || !doctor.adult.medications.isEmpty
        let paedDrugsDone = doctor.paediatricDrugs?.hasContent ?? false || !doctor.paediatric.medications.isEmpty

        let regionalDone = !doctor.regionalBlocks.isEmpty

        let spinalDone = doctor.neuraxial.isConfigured("spinal")
            || !doctor.neuraxial.spinal.needleType.isBlank
            || !doctor.neuraxial.spinal.localAnaesthetic.isBlank
            || !doctor.neuraxial.spinal.position.isBlank
        let epiduralDone = doctor.neuraxial.isConfigured("epidural")
            || doctor.neuraxial.isConfigured("cse")
            || !doctor.neuraxial.epidural.epiduralKit.isBlank
            || doctor.neuraxial.epidural.lossOfResistanceMethod != .notSpecified
            || !doctor.neuraxial.epidural.catheterSetup.isBlank

        let proceduresDone = !doctor.operations.isEmpty

        return [
            ProfileCheck(id: "general", title: "General Setup", isComplete: generalDone, symbol: "checklist"),
            ProfileCheck(id: "airway", title: "Airway Setup", isComplete: airwayDone, symbol: "lungs"),
            ProfileCheck(id: "adult", title: "Adult Preferences", isComplete: adultDrugsDone, symbol: "syringe"),
            ProfileCheck(id: "paed", title: "\(paediatricTerm) Preferences", isComplete: paedDrugsDone, symbol: "figure.child"),
            ProfileCheck(id: "regional", title: "Regional Blocks", isComplete: regionalDone, symbol: "scope"),
            ProfileCheck(id: "spinal", title: "Spinal Preferences", isComplete: spinalDone, symbol: "arrow.down.to.line"),
            ProfileCheck(id: "epidural", title: "Epidural Preferences", isComplete: epiduralDone, symbol: "minus.plus.batteryblock"),
            ProfileCheck(id: "procedures", title: "Procedure Templates", isComplete: proceduresDone, symbol: "cross.case")
        ]
    }

    /// 0.0–1.0 completeness fraction.
    static func fraction(for doctor: Doctor) -> Double {
        let list = checks(for: doctor)
        guard !list.isEmpty else { return 0 }
        let done = list.filter { $0.isComplete }.count
        return Double(done) / Double(list.count)
    }

    /// Whole-number percentage 0–100.
    static func percent(for doctor: Doctor) -> Int {
        Int((fraction(for: doctor) * 100).rounded())
    }
}
