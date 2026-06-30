//
//  DepartmentTemplateLibrary.swift
//  PreferenceFlow
//

import Foundation

/// Seeded department starting templates. Each hospital starts with these defaults
/// (General Theatre, Cardiac, Paediatric, Obstetrics, Neuro, Regional). They ship
/// pre-filled with clinically reasonable, commonly-used starting values so that a
/// technician creating a brand-new consultant from any template gets a genuinely
/// useful starting point with zero prior configuration — not an empty shell.
///
/// These are starting points only, fully editable per hospital/consultant, and
/// carry the same "reference only — not clinical advice" framing as the rest of
/// the app. IDs are deterministic so a consultant created from a built-in starting
/// template keeps resolving even before the hospital saves edits.
nonisolated enum DepartmentTemplateLibrary {
    private static func id(_ suffix: String) -> UUID {
        UUID(uuidString: "0E9F8E00-0000-0000-0000-0000000000\(suffix)")!
    }

    /// The default set of starting templates for a hospital that has none stored yet.
    static var defaults: [DepartmentTemplate] {
        [generalTheatre, cardiac, paediatric, obstetrics, neuro, regional]
    }

    // MARK: - Shared builders

    /// A configured neuraxial workflow that adopts the department-standard defaults
    /// defined in `WorkflowLibrary` (e.g. Lignocaine 1% skin, Heavy Bupivacaine
    /// intrathecal, Whitacre 25G, sitting). `usesStandard` keeps it as a clean
    /// starting point — the consultant records only their deviations later — while
    /// `isConfigured` makes it surface on the profile, in summaries and in exports.
    private static func standardWorkflow(_ id: String) -> WorkflowCustomization {
        var c = WorkflowCustomization(id: id)
        c.usesStandard = true
        c.isConfigured = true
        return c
    }

    /// A standard adult airway with sensible defaults for both cohorts and the
    /// common supraglottic sizes — the everyday baseline most lists start from.
    private static func standardAdultAirway(
        maleTube: String = "8.0",
        femaleTube: String = "7.0",
        video: VideoLaryngoscopeSystem = .mcGrath
    ) -> AirwayPreferences {
        var airway = AirwayPreferences()
        airway.adultMale.tubeSize = maleTube
        airway.adultMale.cuffedPreference = "Cuffed"
        airway.adultMale.primaryTechnique = video == .none ? .direct : .video
        airway.adultMale.videoSystem = video
        airway.adultMale.blade = .macintosh
        airway.adultMale.bladeSize = "4"
        airway.adultMale.bougiePreference = "Available"
        airway.adultMale.tubeSecuring = "Tie"

        airway.adultFemale.tubeSize = femaleTube
        airway.adultFemale.cuffedPreference = "Cuffed"
        airway.adultFemale.primaryTechnique = video == .none ? .direct : .video
        airway.adultFemale.videoSystem = video
        airway.adultFemale.blade = .macintosh
        airway.adultFemale.bladeSize = "3"
        airway.adultFemale.bougiePreference = "Available"
        airway.adultFemale.tubeSecuring = "Tie"

        airway.supraglottic.adultFemale = SupraglotticChoice(device: .igel, size: "4")
        airway.supraglottic.adultMale = SupraglotticChoice(device: .igel, size: "5")
        airway.supraglottic.largeAdult = SupraglotticChoice(device: .igel, size: "5")
        return airway
    }

    // MARK: - General Theatre (the everyday standard)

    static var generalTheatre: DepartmentTemplate {
        var general = GeneralPreferences()
        general.assistantMayPrepareMedications = true
        general.arriveBeforePatient = true
        general.sterileGloveSize = "7.5"
        general.sterileGloveType = "Biogel"
        general.briefingStyle = "WHO checklist before knife-to-skin"

        let airway = standardAdultAirway(maleTube: "8.0", femaleTube: "7.0", video: .mcGrath)

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .assistant)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .assistant)
        drugs.vasopressor = DrugSelection(selected: ["Metaraminol"], preparedBy: .assistant)
        drugs.muscleRelaxant = DrugSelection(selected: ["Rocuronium"], preparedBy: .assistant)
        drugs.fluids = DrugSelection(selected: ["Hartmann's"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("01"),
            name: "General Theatre",
            icon: "rectangle.stack.fill",
            isBuiltIn: true,
            general: general,
            airway: airway,
            adultDrugs: drugs,
            notes: "Standard adult general list setup. Starting point only — adjust for the consultant and case."
        )
    }

    // MARK: - Cardiac

    static var cardiac: DepartmentTemplate {
        var general = GeneralPreferences()
        general.assistantMayPrepareMedications = false
        general.arriveBeforePatient = true

        var airway = standardAdultAirway(maleTube: "8.0", femaleTube: "7.5", video: .cMac)
        airway.adultMale.bladeSize = "4"

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol", "Ketamine"], preparedBy: .doctor)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .doctor)
        drugs.vasopressor = DrugSelection(selected: ["Metaraminol", "Noradrenaline"], preparedBy: .doctor)
        drugs.muscleRelaxant = DrugSelection(selected: ["Rocuronium"], preparedBy: .doctor)
        drugs.fluids = DrugSelection(selected: ["Plasma-Lyte"], preparedBy: .assistant)

        // Invasive lines are routine — start with an arterial line and CVC configured.
        var neuraxial = NeuraxialPreferences()
        neuraxial.setCustomization(standardWorkflow("arterialLine"))
        neuraxial.setCustomization(standardWorkflow("cvc"))

        return DepartmentTemplate(
            id: id("02"),
            name: "Cardiac",
            icon: "heart.fill",
            isBuiltIn: true,
            general: general,
            airway: airway,
            adultDrugs: drugs,
            neuraxial: neuraxial,
            notes: "Cardiac list standard — invasive monitoring, large-bore access and rapid infuser typically required."
        )
    }

    // MARK: - Paediatric

    static var paediatric: DepartmentTemplate {
        var general = GeneralPreferences()
        general.assistantMayPrepareMedications = true
        general.arriveBeforePatient = true

        var airway = AirwayPreferences()
        airway.paediatric.primaryTechnique = .direct
        airway.paediatric.blade = .miller
        airway.paediatric.cuffedPreference = "Cuffed (microcuff)"
        airway.paediatric.notes = "Tube and supraglottic sizes are weight/age based — see the paediatric reference."
        // Adolescent / larger child supraglottic starting sizes.
        airway.supraglottic.adultFemale = SupraglotticChoice(device: .igel, size: "3")
        airway.supraglottic.adultMale = SupraglotticChoice(device: .igel, size: "4")

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .assistant)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .assistant)
        drugs.vasopressor = DrugSelection(selected: ["Ephedrine"], preparedBy: .assistant)
        drugs.muscleRelaxant = DrugSelection(selected: ["Rocuronium"], preparedBy: .assistant)
        drugs.fluids = DrugSelection(selected: ["Plasma-Lyte"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("03"),
            name: "Paediatric",
            icon: "figure.child",
            isBuiltIn: true,
            general: general,
            airway: airway,
            adultDrugs: drugs,
            notes: "Paediatric list standard — tube and supraglottic sizes are weight/age based. Confirm against the patient and local policy."
        )
    }

    // MARK: - Obstetrics

    static var obstetrics: DepartmentTemplate {
        var general = GeneralPreferences()
        general.assistantMayPrepareMedications = true
        general.arriveBeforePatient = true

        // Spinal for caesarean is the workhorse — keep the populated legacy struct for
        // backward-compatible exports, and configure the live spinal workflow so the
        // full medication/technique detail surfaces everywhere.
        var spinal = SpinalPreferences()
        spinal.preferredPack = "Standard spinal pack"
        spinal.topicalSkinAnaesthetic = "Lignocaine 1%"
        spinal.intrathecalAgent = "0.5% Heavy Bupivacaine (Marcaine Heavy)"
        spinal.additives = "Fentanyl, Morphine"
        spinal.needleType = "Whitacre"
        spinal.needleGauge = "25G"
        spinal.position = "Sitting"

        var neuraxial = NeuraxialPreferences()
        neuraxial.spinal = spinal
        neuraxial.setCustomization(standardWorkflow("spinal"))

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol", "Thiopentone"], preparedBy: .doctor)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .doctor)
        drugs.vasopressor = DrugSelection(selected: ["Phenylephrine", "Metaraminol"], preparedBy: .assistant)
        drugs.muscleRelaxant = DrugSelection(selected: ["Succinylcholine", "Rocuronium"], preparedBy: .doctor)
        drugs.fluids = DrugSelection(selected: ["Hartmann's"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("04"),
            name: "Obstetrics",
            icon: "figure.2.and.child.holdinghands",
            isBuiltIn: true,
            general: general,
            airway: standardAdultAirway(maleTube: "7.0", femaleTube: "6.5", video: .cMac),
            adultDrugs: drugs,
            neuraxial: neuraxial,
            notes: "Obstetric list standard — spinal for caesarean, phenylephrine for blood pressure support. Anticipate difficult airway."
        )
    }

    // MARK: - Neuro

    static var neuro: DepartmentTemplate {
        var general = GeneralPreferences()
        general.assistantMayPrepareMedications = false
        general.arriveBeforePatient = true

        let airway = standardAdultAirway(maleTube: "8.0", femaleTube: "7.5", video: .cMac)

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .doctor)
        drugs.opioid = DrugSelection(selected: ["Remifentanil"], preparedBy: .doctor)
        drugs.vasopressor = DrugSelection(selected: ["Metaraminol", "Noradrenaline"], preparedBy: .doctor)
        drugs.muscleRelaxant = DrugSelection(selected: ["Rocuronium"], preparedBy: .doctor)
        drugs.fluids = DrugSelection(selected: ["Plasma-Lyte"], preparedBy: .assistant)

        // Arterial line for tight haemodynamic control is routine.
        var neuraxial = NeuraxialPreferences()
        neuraxial.setCustomization(standardWorkflow("arterialLine"))

        return DepartmentTemplate(
            id: id("05"),
            name: "Neuro",
            icon: "brain.head.profile",
            isBuiltIn: true,
            general: general,
            airway: airway,
            adultDrugs: drugs,
            neuraxial: neuraxial,
            notes: "Neuro list standard — arterial line and tight haemodynamic control typical."
        )
    }

    // MARK: - Regional

    static var regional: DepartmentTemplate {
        var general = GeneralPreferences()
        general.assistantMayPrepareMedications = true
        general.arriveBeforePatient = true

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .assistant)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .assistant)
        drugs.fluids = DrugSelection(selected: ["Hartmann's"], preparedBy: .assistant)

        let blocks = [
            RegionalBlock(
                name: "TAP Block",
                drug: "Ropivacaine",
                concentration: "0.375%",
                typicalVolume: "20 mL/side",
                needleType: "Echogenic block needle",
                needleLength: "80 mm",
                ultrasoundProbe: "Linear high-frequency",
                sterileCover: "Sterile probe cover",
                setupNotes: "Ultrasound-guided, in-plane.",
                positioningNotes: "Supine."
            ),
            RegionalBlock(
                name: "Fascia Iliaca",
                drug: "Ropivacaine",
                concentration: "0.2%",
                typicalVolume: "30 mL",
                needleType: "Echogenic block needle",
                needleLength: "80 mm",
                ultrasoundProbe: "Linear high-frequency",
                sterileCover: "Sterile probe cover",
                setupNotes: "Suprainguinal approach, in-plane.",
                positioningNotes: "Supine."
            ),
            RegionalBlock(
                name: "Adductor Canal",
                drug: "Ropivacaine",
                concentration: "0.2%",
                typicalVolume: "20 mL",
                needleType: "Echogenic block needle",
                needleLength: "50 mm",
                ultrasoundProbe: "Linear high-frequency",
                sterileCover: "Sterile probe cover",
                setupNotes: "Mid-thigh, in-plane.",
                positioningNotes: "Supine, leg slightly externally rotated."
            )
        ]
        return DepartmentTemplate(
            id: id("06"),
            name: "Regional",
            icon: "scope",
            isBuiltIn: true,
            general: general,
            adultDrugs: drugs,
            regionalBlocks: blocks,
            notes: "Regional list standard — ultrasound-guided blocks with echogenic needles. Confirm doses and concentrations locally."
        )
    }
}
