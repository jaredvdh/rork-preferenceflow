//
//  DepartmentTemplateLibrary.swift
//  PreferenceFlow
//

import Foundation

/// Seeded department standard templates. Each hospital starts with these defaults
/// (General Theatre, Cardiac, Paediatric, Obstetrics, Neuro, Regional) until a
/// department customises them. IDs are deterministic so a consultant created from
/// a built-in standard keeps resolving even before the hospital saves edits.
nonisolated enum DepartmentTemplateLibrary {
    private static func id(_ suffix: String) -> UUID {
        UUID(uuidString: "0E9F8E00-0000-0000-0000-0000000000\(suffix)")!
    }

    /// The default set of standards for a hospital that has none stored yet.
    static var defaults: [DepartmentTemplate] {
        [generalTheatre, cardiac, paediatric, obstetrics, neuro, regional]
    }

    // MARK: - General Theatre (the everyday standard)

    static var generalTheatre: DepartmentTemplate {
        var general = GeneralPreferences()
        general.assistantMayPrepareMedications = true
        general.arriveBeforePatient = true

        var airway = AirwayPreferences()
        airway.adultMale.tubeSize = "7.5"
        airway.adultMale.primaryTechnique = .video
        airway.adultMale.videoSystem = .mcGrath
        airway.adultMale.blade = .macintosh
        airway.adultMale.bladeSize = "4"
        airway.adultMale.bougiePreference = "Available"
        airway.adultFemale.tubeSize = "7.0"
        airway.adultFemale.primaryTechnique = .video
        airway.adultFemale.videoSystem = .mcGrath
        airway.adultFemale.blade = .macintosh
        airway.adultFemale.bladeSize = "3"
        airway.adultFemale.bougiePreference = "Available"
        airway.supraglottic.adultFemale = SupraglotticChoice(device: .igel, size: "4")
        airway.supraglottic.adultMale = SupraglotticChoice(device: .igel, size: "5")
        airway.supraglottic.largeAdult = SupraglotticChoice(device: .igel, size: "5")

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .assistant)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .assistant)
        drugs.vasopressor = DrugSelection(selected: ["Metaraminol"], preparedBy: .assistant)
        drugs.fluids = DrugSelection(selected: ["Hartmann's"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("01"),
            name: "General Theatre",
            icon: "rectangle.stack.fill",
            isBuiltIn: true,
            general: general,
            airway: airway,
            adultDrugs: drugs,
            notes: "Standard adult general list setup."
        )
    }

    // MARK: - Cardiac

    static var cardiac: DepartmentTemplate {
        var airway = AirwayPreferences()
        airway.adultMale.tubeSize = "8.0"
        airway.adultMale.primaryTechnique = .video
        airway.adultMale.videoSystem = .cMac
        airway.adultMale.blade = .macintosh
        airway.adultMale.bladeSize = "4"
        airway.adultFemale.tubeSize = "7.5"
        airway.adultFemale.primaryTechnique = .video
        airway.adultFemale.videoSystem = .cMac

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol", "Ketamine"], preparedBy: .doctor)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .doctor)
        drugs.vasopressor = DrugSelection(selected: ["Metaraminol", "Noradrenaline"], preparedBy: .doctor)
        drugs.muscleRelaxant = DrugSelection(selected: ["Rocuronium"], preparedBy: .doctor)
        drugs.fluids = DrugSelection(selected: ["Plasma-Lyte"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("02"),
            name: "Cardiac",
            icon: "heart.fill",
            isBuiltIn: true,
            airway: airway,
            adultDrugs: drugs,
            notes: "Cardiac list standard — invasive monitoring, large-bore access and rapid infuser typically required."
        )
    }

    // MARK: - Paediatric

    static var paediatric: DepartmentTemplate {
        var airway = AirwayPreferences()
        airway.paediatric.primaryTechnique = .direct
        airway.paediatric.blade = .miller
        airway.supraglottic.adultFemale = SupraglotticChoice(device: .igel, size: "4")
        airway.supraglottic.adultMale = SupraglotticChoice(device: .igel, size: "5")

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .assistant)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .assistant)
        drugs.fluids = DrugSelection(selected: ["Plasma-Lyte"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("03"),
            name: "Paediatric",
            icon: "figure.child",
            isBuiltIn: true,
            airway: airway,
            adultDrugs: drugs,
            notes: "Paediatric list standard — tube and supraglottic sizes are weight/age based."
        )
    }

    // MARK: - Obstetrics

    static var obstetrics: DepartmentTemplate {
        var spinal = SpinalPreferences()
        spinal.preferredPack = "Standard spinal pack"
        spinal.needleType = "Whitacre"
        spinal.needleGauge = "25G"
        spinal.position = "Sitting"
        spinal.intrathecalAgent = "0.5% Heavy Bupivacaine"
        var neuraxial = NeuraxialPreferences()
        neuraxial.spinal = spinal

        var drugs = DrugsFluidsSetup()
        drugs.vasopressor = DrugSelection(selected: ["Phenylephrine", "Metaraminol"], preparedBy: .assistant)
        drugs.fluids = DrugSelection(selected: ["Hartmann's"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("04"),
            name: "Obstetrics",
            icon: "figure.2.and.child.holdinghands",
            isBuiltIn: true,
            adultDrugs: drugs,
            neuraxial: neuraxial,
            notes: "Obstetric list standard — spinal for caesarean, phenylephrine for blood pressure support."
        )
    }

    // MARK: - Neuro

    static var neuro: DepartmentTemplate {
        var airway = AirwayPreferences()
        airway.adultMale.tubeSize = "8.0"
        airway.adultMale.primaryTechnique = .video
        airway.adultMale.videoSystem = .cMac
        airway.adultFemale.tubeSize = "7.5"

        var drugs = DrugsFluidsSetup()
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .doctor)
        drugs.opioid = DrugSelection(selected: ["Remifentanil"], preparedBy: .doctor)
        drugs.vasopressor = DrugSelection(selected: ["Metaraminol", "Noradrenaline"], preparedBy: .doctor)
        drugs.fluids = DrugSelection(selected: ["Plasma-Lyte"], preparedBy: .assistant)

        return DepartmentTemplate(
            id: id("05"),
            name: "Neuro",
            icon: "brain.head.profile",
            isBuiltIn: true,
            airway: airway,
            adultDrugs: drugs,
            notes: "Neuro list standard — arterial line and tight haemodynamic control typical."
        )
    }

    // MARK: - Regional

    static var regional: DepartmentTemplate {
        let blocks = [
            RegionalBlock(name: "TAP Block", drug: "Ropivacaine", concentration: "0.375%", typicalVolume: "20 mL/side", needleType: "Echogenic block needle", ultrasoundProbe: "Linear high-frequency"),
            RegionalBlock(name: "Femoral", drug: "Ropivacaine", concentration: "0.375%", typicalVolume: "20 mL", needleType: "Echogenic block needle", ultrasoundProbe: "Linear high-frequency")
        ]
        return DepartmentTemplate(
            id: id("06"),
            name: "Regional",
            icon: "scope",
            isBuiltIn: true,
            regionalBlocks: blocks,
            notes: "Regional list standard — ultrasound-guided blocks with echogenic needles."
        )
    }
}
