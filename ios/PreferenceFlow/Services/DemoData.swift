//
//  DemoData.swift
//  PreferenceFlow
//

import Foundation

/// Realistic sample hospitals and consultant profiles installed by Demo Mode.
///
/// Every record uses a deterministic UUID (same idea as
/// `DepartmentTemplateLibrary.id`) so installing twice is idempotent — a second
/// install overwrites rather than duplicates, and removal is an exact match on
/// `isDemoData`. All records are stamped `isDemoData: true` so they can be
/// cleanly removed without ever touching the technician's own data.
///
/// Reference/sample content only — not clinical advice.
nonisolated enum DemoData {

    /// Deterministic UUID in a dedicated demo namespace ("DE30…").
    private static func id(_ n: Int) -> UUID {
        let hex = String(format: "%012X", n)
        return UUID(uuidString: "DE300000-0000-0000-0000-\(hex)")!
    }

    // Stable ids so installs stay idempotent.
    static let cityCentralID = id(1)
    static let mercyPrivateID = id(2)
    static let sarahMitchellID = id(11)
    static let jamesOkonkwoID = id(12)

    /// Definitive set of demo hospital ids. Removal matches on these — never on
    /// the fallible `isDemoData` flag alone — so demo cleanup can never delete a
    /// real record even if a flag were lost on decode or toggled by accident.
    static let allDemoHospitalIDs: Set<UUID> = [cityCentralID, mercyPrivateID]

    /// Definitive set of demo consultant ids (see `allDemoHospitalIDs`).
    static let allDemoDoctorIDs: Set<UUID> = [sarahMitchellID, jamesOkonkwoID]

    // MARK: - Public API

    /// Full set of demo hospitals.
    static var hospitals: [Hospital] { [cityCentral, mercyPrivate] }

    /// Full set of demo consultants.
    static var doctors: [Doctor] { [sarahMitchell, jamesOkonkwo] }

    /// The pristine demo hospital for a given id, if one exists.
    static func canonicalHospital(id: UUID) -> Hospital? {
        hospitals.first { $0.id == id }
    }

    /// The pristine demo consultant for a given id, if one exists.
    static func canonicalDoctor(id: UUID) -> Doctor? {
        doctors.first { $0.id == id }
    }

    // MARK: - Edited-demo detection

    /// True when a stored demo consultant differs from its pristine definition —
    /// i.e. the user has explored by editing it. Timestamps are ignored so an
    /// untouched record never reads as edited. Records whose id isn't a known
    /// demo id are never considered demo (returns false).
    static func isEditedDemoDoctor(_ doctor: Doctor) -> Bool {
        guard let canonical = canonicalDoctor(id: doctor.id) else { return false }
        return fingerprint(doctor) != fingerprint(canonical)
    }

    /// True when a stored demo hospital differs from its pristine definition.
    static func isEditedDemoHospital(_ hospital: Hospital) -> Bool {
        guard let canonical = canonicalHospital(id: hospital.id) else { return false }
        return fingerprint(hospital) != fingerprint(canonical)
    }

    /// Stable content fingerprint for a consultant, ignoring volatile timestamps,
    /// so pristine and stored copies compare equal when nothing meaningful changed.
    private static func fingerprint(_ doctor: Doctor) -> Data? {
        var normalized = doctor
        normalized.createdAt = Date(timeIntervalSince1970: 0)
        normalized.updatedAt = Date(timeIntervalSince1970: 0)
        return try? comparisonEncoder().encode(normalized)
    }

    /// Stable content fingerprint for a hospital, ignoring volatile timestamps.
    private static func fingerprint(_ hospital: Hospital) -> Data? {
        var normalized = hospital
        normalized.createdAt = Date(timeIntervalSince1970: 0)
        normalized.updatedAt = Date(timeIntervalSince1970: 0)
        return try? comparisonEncoder().encode(normalized)
    }

    /// Deterministic encoder (sorted keys) for content comparison.
    private static func comparisonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // MARK: - Hospitals

    private static var cityCentral: Hospital {
        var orientation = HospitalOrientation()
        orientation.equipmentLocations = [
            EquipmentLocation(
                id: id(101),
                kind: .difficultIntubationTrolley,
                spots: [
                    EquipmentSpot(id: id(1011), location: "Theatre corridor outside OR 1",
                                  accessInstructions: "Break tag — replace from stock room after use"),
                    EquipmentSpot(id: id(1012), location: "Anaesthetic technician room",
                                  accessInstructions: "Break tag — replace from stock room after use")
                ]
            ),
            EquipmentLocation(
                id: id(102),
                kind: .mhKit,
                spots: [
                    EquipmentSpot(id: id(1021), location: "Anaesthetic technician room",
                                  accessInstructions: "Top shelf")
                ]
            ),
            EquipmentLocation(
                id: id(103),
                kind: .crashCart,
                spots: [
                    EquipmentSpot(id: id(1031), location: "OR 1"),
                    EquipmentSpot(id: id(1032), location: "OR recovery / PACU"),
                    EquipmentSpot(id: id(1033), location: "ICU corridor")
                ],
                notes: "Three locations — reach the nearest one."
            ),
            EquipmentLocation(
                id: id(104),
                kind: .other,
                customLabel: "Cell saver",
                spots: [EquipmentSpot(id: id(1041), location: "Cardiac theatre store")]
            ),
            EquipmentLocation(
                id: id(105),
                kind: .other,
                customLabel: "TEE machine",
                spots: [EquipmentSpot(id: id(1051), location: "Cardiac theatre")]
            )
        ]
        orientation.contacts = [
            HospitalContact(id: id(111), role: .sickCall, phone: "On-call phone",
                            notes: "ASAP notice"),
            HospitalContact(id: id(112), role: .chargeTechnician),
            HospitalContact(id: id(113), role: .bloodBank),
            HospitalContact(id: id(114), role: .pharmacy)
        ]
        orientation.sickCall = SickCallInfo(
            whoToContact: "On-call coordinator",
            phone: "On-call phone",
            noticePeriod: "ASAP",
            notes: "Call the on-call phone as soon as you know you'll be off."
        )
        orientation.sharedFiles = [
            SharedFile(id: id(115), name: "NZ/AU Anaesthesia Crisis Manual",
                       notes: "Bundled emergency reference")
        ]
        // No check documents attached — there is no legitimate PDF to bundle for
        // demo purposes, so the honest empty state shows instead.
        orientation.anaestheticMachines = [
            AnaestheticMachine(
                id: id(106),
                model: .geAisysCS2,
                location: "Theatres 1-8"
            ),
            AnaestheticMachine(
                id: id(107),
                model: .draegerZeusIE,
                location: "Cardiac Theatre",
                notes: "TIVA/TCI module fitted — confirm connected and calibrated if in use."
            )
        ]

        return Hospital(
            id: cityCentralID,
            name: "City Central Trauma Centre",
            city: "Wellington",
            country: "New Zealand",
            department: "Anaesthesia",
            notes: "Large tertiary trauma centre · 24 operating rooms.",
            orientation: orientation,
            isDemoData: true
        )
    }

    private static var mercyPrivate: Hospital {
        var orientation = HospitalOrientation()
        orientation.equipmentLocations = [
            EquipmentLocation(
                id: id(201),
                kind: .difficultIntubationTrolley,
                spots: [EquipmentSpot(id: id(2011), location: "Theatre 1 corridor")]
            ),
            EquipmentLocation(
                id: id(202),
                kind: .crashCart,
                spots: [EquipmentSpot(id: id(2021), location: "Theatre corridor")]
            ),
            EquipmentLocation(
                id: id(203),
                kind: .mhKit,
                spots: [EquipmentSpot(id: id(2031), location: "Anaesthetic technician room")]
            )
        ]
        orientation.contacts = [
            HospitalContact(id: id(211), role: .sickCall, phone: "Sick call number"),
            HospitalContact(id: id(212), role: .theatreCoordinator, name: "Anaesthetic coordinator")
        ]
        orientation.sickCall = SickCallInfo(
            whoToContact: "Anaesthetic coordinator",
            phone: "Sick call number"
        )
        orientation.anaestheticMachines = [
            AnaestheticMachine(
                id: id(204),
                model: .mindrayA5,
                location: "Theatres 1-4"
            )
        ]

        return Hospital(
            id: mercyPrivateID,
            name: "Mercy Private Hospital",
            city: "Wellington",
            country: "New Zealand",
            department: "Anaesthesia",
            notes: "Small private hospital · 4 operating rooms.",
            orientation: orientation,
            isDemoData: true
        )
    }

    // MARK: - Consultant 1: Dr Sarah Mitchell (General + Cardiac)

    private static var sarahMitchell: Doctor {
        var general = GeneralPreferences()
        general.sterileGloveSize = "7.0"
        general.sterileGloveType = "Biogel"
        general.nonSterileGloveSize = "M"
        general.gownSize = "M"
        general.coffeePreference = "Flat white, no sugar"
        general.briefingStyle = "WHO checklist"
        general.arriveBeforePatient = true
        general.assistantMayPrepareMedications = true
        general.generalNotes = "Assistant may prepare induction drugs only."

        var airway = AirwayPreferences()
        airway.adultMale.tubeSize = "8.0"
        airway.adultMale.primaryTechnique = .video
        airway.adultMale.videoSystem = .mcGrath
        airway.adultMale.blade = .macintosh
        airway.adultMale.bladeSize = "4"
        airway.adultMale.bougiePreference = "Occasionally"
        airway.adultFemale.tubeSize = "7.0"
        airway.adultFemale.primaryTechnique = .video
        airway.adultFemale.videoSystem = .mcGrath
        airway.adultFemale.blade = .macintosh
        airway.adultFemale.bladeSize = "3"
        airway.adultFemale.bougiePreference = "Occasionally"
        airway.supraglottic.adultFemale = SupraglotticChoice(device: .igel, size: "4")
        airway.supraglottic.adultMale = SupraglotticChoice(device: .igel, size: "5")

        var drugs = DrugsFluidsSetup()
        drugs.maintenance = .volatile
        drugs.maintenanceVolatileAgent = "Sevoflurane"
        drugs.induction = DrugSelection(selected: ["Propofol"], preparedBy: .assistant)
        drugs.opioid = DrugSelection(selected: ["Fentanyl"], preparedBy: .assistant)
        drugs.vasopressor = DrugSelection(selected: ["Metaraminol"], preparedBy: .assistant)
        drugs.muscleRelaxant = DrugSelection(selected: ["Rocuronium"], preparedBy: .doctor)
        drugs.reversal = DrugSelection(selected: ["Sugammadex"], preparedBy: .doctor)
        drugs.fluids = FluidSetup(primary: "Hartmann's", givingSet: .pump)
        drugs.emergency = EmergencyDrugSetup(
            selected: ["Atropine"],
            pushDoseAdrenalineDilution: "1:100,000 (10mcg/mL)",
            preparedBy: .doctor
        )

        let fasciaIliaca = RegionalBlock(
            id: id(121),
            name: "Fascia Iliaca Block",
            drug: "Ropivacaine",
            concentration: "0.2%",
            typicalVolume: "30mL",
            adjuvant: "Dexamethasone",
            needleType: "Echogenic block needle",
            needleLength: "50mm",
            ultrasoundProbe: "Linear probe"
        )

        var neuraxial = NeuraxialPreferences()
        var spinal = neuraxial.customization(for: "spinal")
        spinal.usesStandard = false
        spinal.isConfigured = true
        spinal.setSelection("position.choice", "Sitting", default: "Sitting")
        spinal.setSelection("technique.needle", "Whitacre", default: "Whitacre")
        spinal.setSelection("technique.gauge", "25G", default: "25G")
        spinal.setBool("technique.introducer", true, default: true)
        spinal.setSelection("skinLA.agent", "Lignocaine 1%", default: "Lignocaine 1%")
        spinal.setNote("skinLA.notes", "3 mL")
        spinal.setSelection("intrathecal.agent", "0.5% Heavy Bupivacaine (Marcaine Heavy)",
                            default: "0.5% Heavy Bupivacaine (Marcaine Heavy)")
        spinal.setNote("intrathecal.notes", "2.5 mL")
        spinal.setMulti("additives.list", ["Fentanyl"], default: [])
        spinal.setNote("additives.notes", "Fentanyl 25 mcg")
        spinal.setMulti("consultant.prefs", ["Assistant maintains shoulder support"], default: [])
        neuraxial.setCustomization(spinal)

        // Arterial line — exercises the simplified cannula/technique/positioning model.
        var arterialLine = neuraxial.customization(for: "arterialLine")
        arterialLine.usesStandard = false
        arterialLine.isConfigured = true
        arterialLine.setSelection("site.choice", "Radial", default: "Radial")
        arterialLine.setMulti("site.laterality", ["Right radial", "Dominant hand avoided"], default: [])
        arterialLine.setSelection("site.cannulaType",
                                  "Integrated guidewire (e.g. Arrow Arrowg+ard, Leadercath)",
                                  default: "Integrated guidewire (e.g. Arrow Arrowg+ard, Leadercath)")
        arterialLine.setSelection("site.gaugeLength", "20G × 45mm (standard)",
                                  default: "20G × 45mm (standard)")
        arterialLine.setSelection("technique.approach",
                                  "Ultrasound DNTP (dynamic needle tip positioning)",
                                  default: "Ultrasound DNTP (dynamic needle tip positioning)")
        arterialLine.setBool("site.ultrasound", true, default: false)
        arterialLine.setSelection("prep.antiseptic", "Chlorhexidine 2% (ChloraPrep)",
                                  default: "Chlorhexidine 2% (ChloraPrep)")
        arterialLine.setSelection("prep.la", "Lignocaine 1% SC", default: "Lignocaine 1% SC")
        arterialLine.setSelection("positioning.wrist", "Rolled towel", default: "")
        arterialLine.setSelection("transducer.flush", "Heparinised normal saline",
                                  default: "Heparinised normal saline")
        arterialLine.setSelection("securing.dressing", "Tegaderm 1624 (standard)",
                                  default: "Tegaderm 1624 (standard)")
        arterialLine.setNote("consultant.notes",
                             "Maintain continuous visualisation of the needle tip — advance catheter only once tip is clearly intraluminal.")
        neuraxial.setCustomization(arterialLine)

        // CVC — exercises line type/length, prep and confirmation extras.
        var cvc = neuraxial.customization(for: "cvc")
        cvc.usesStandard = false
        cvc.isConfigured = true
        cvc.setSelection("site.choice", "Right IJ", default: "Right IJ")
        cvc.setSelection("site.type", "Arrow Quad Lumen", default: "Arrow Triple Lumen")
        cvc.addCustomOption("site.lineLength", "16–18cm")
        cvc.setSelection("site.lineLength", "16–18cm",
                         default: "Standard (16–20cm from right IJ)")
        cvc.setSelection("prep.antiseptic", "Chlorhexidine 2% (ChloraPrep)",
                         default: "Chlorhexidine 2% (ChloraPrep)")
        cvc.setSelection("prep.la", "Lignocaine 1% SC", default: "Lignocaine 1% SC")
        cvc.setNote("prep.positioning", "Trendelenburg 15°, head turned left")
        cvc.setSelection("confirm.method", "CXR post-insertion", default: "CXR post-insertion")
        cvc.setSelection("confirm.transducerPort", "Distal port (brown)", default: "Distal port (brown)")
        cvc.setNote("confirm.transducerNotes",
                    "Transduce off distal (brown) port \u{2014} leave medial for drug infusions.")
        cvc.setSelection("fixation.suture", "2-0 silk (standard)", default: "2-0 silk (standard)")
        cvc.setSelection("fixation.technique", "Suture + CHG-impregnated dressing",
                         default: "Suture + CHG-impregnated dressing")
        cvc.setSelection("fixation.dressing", "Tegaderm CHG Large (9.5cm \u{00D7} 10cm)",
                         default: "Tegaderm CHG (chlorhexidine-impregnated, standard)")
        cvc.setNote("fixation.notes",
                    "Loop silk through CVC hub wing before dressing. Label all ports with colour-coded stickers.")
        neuraxial.setCustomization(cvc)

        // Monitoring — exercises the expanded display: 5-lead ECG, BIS depth
        // monitoring, standalone TOF, and routine extras consistent with her
        // cardiac specialty setup equipment.
        let monitoring = MonitoringPreferences(
            ecgLeads: .fiveLead,
            depthMonitoring: .bis,
            tofMonitoring: .standaloneStimulator,
            bpCuffPlacement: .oppositeArmFromIV,
            additional: [
                "Arterial line (routine)", "CVP (routine)",
                "Temperature (continuous)", "Cerebral oximetry (NIRS)"
            ]
        )

        let cardiac = SpecialtySetup(
            id: id(122),
            specialty: .cardiac,
            additionalMonitoring: [
                "Arterial line", "TEE", "BIS / Entropy (depth of anaesthesia)",
                "Cardiac output", "Cerebral oximetry (NIRS)", "Temperature", "Urinary catheter"
            ],
            linesAndAccess: ["Quad lumen CVC", "Arterial line", "Large-bore IV", "Rapid infuser"],
            equipment: ["Cell saver", "Forced-air warmer (lower body)", "Defibrillator pads", "Pacing"],
            specialNotes: "Patient to theatre 30 min early. Bair Hugger lower body warmer prior to induction. Large bore IV right arm (unless LIMA harvest — use left). Art line LA and insertion prior to induction. Induce, intubate. Quad lumen CVC right IJ. TEE probe inserted and checked. Arms tucked, eyes padded."
        )

        return Doctor(
            id: sarahMitchellID,
            fullName: "Dr Sarah Mitchell",
            phone: "",
            email: "",
            hospitalId: cityCentralID,
            department: "Anaesthesia",
            role: "Consultant Anaesthetist",
            subspecialties: [.cardiac, .trauma, .regional],
            biography: "Cardiac and trauma consultant with a regional anaesthesia interest.",
            isDemoData: true,
            general: general,
            adultDrugs: drugs,
            monitoring: monitoring,
            airway: airway,
            regionalBlocks: [fasciaIliaca],
            neuraxial: neuraxial,
            specialtySetups: [cardiac]
        )
    }

    // MARK: - Consultant 2: Dr James Okonkwo (Paediatric)

    private static var jamesOkonkwo: Doctor {
        var general = GeneralPreferences()
        general.sterileGloveSize = "6.5"
        general.sterileGloveType = "Gammex latex-free"
        general.nonSterileGloveSize = "S"
        general.gownSize = "S"
        general.coffeePreference = "Long black, no milk or sugar"
        general.briefingStyle = "WHO checklist"
        general.arriveBeforePatient = true
        general.prepareOwnMedications = true
        general.assistantMayPrepareMedications = false
        general.generalNotes = "Arrives 20 minutes early. Consultant prepares all drugs."

        var airway = AirwayPreferences()
        airway.adultMale.tubeSize = "7.5"
        airway.adultMale.primaryTechnique = .video
        airway.adultMale.videoSystem = .mcGrath
        airway.adultMale.blade = .macintosh
        airway.adultMale.bladeSize = "4"
        airway.adultMale.bougiePreference = "Always available"
        airway.adultFemale.tubeSize = "7.0"
        airway.adultFemale.primaryTechnique = .video
        airway.adultFemale.videoSystem = .mcGrath
        airway.adultFemale.blade = .macintosh
        airway.adultFemale.bladeSize = "4"
        airway.adultFemale.bougiePreference = "Always available"
        airway.supraglottic.adultFemale = SupraglotticChoice(device: .igel, size: "3")
        airway.supraglottic.adultMale = SupraglotticChoice(device: .igel, size: "4")

        // Paediatric airway: C-MAC + Miller for infants, taping detail + photo placeholder.
        airway.paediatric.primaryTechnique = .video
        airway.paediatric.videoSystem = .cMac
        airway.paediatric.blade = .miller
        airway.paediatric.tubeSecuring = "Zinc oxide tape"
        airway.paediatric.tapingTape = "1.5cm zinc oxide (Elastoplast brand preferred)"
        airway.paediatric.tapingTechnique = "Trouser leg technique — single strip split lengthways, wrapped above and below lip corners, tube secured at right corner of mouth"
        airway.paediatric.notes = "C-MAC with Miller blade for infants; Macintosh for older children. i-gel sized by weight per manufacturer table."

        var adultDrugs = DrugsFluidsSetup()
        adultDrugs.maintenance = .tiva
        adultDrugs.tciAgent = "Propofol/Remifentanil"
        adultDrugs.tciModel = "Schnider"
        adultDrugs.induction = DrugSelection(selected: ["Propofol", "Ketamine"], preparedBy: .doctor)
        adultDrugs.opioid = DrugSelection(selected: ["Fentanyl", "Remifentanil"], preparedBy: .doctor)
        adultDrugs.vasopressor = DrugSelection(selected: ["Phenylephrine"], preparedBy: .doctor)
        adultDrugs.muscleRelaxant = DrugSelection(selected: ["Rocuronium"], preparedBy: .doctor)
        adultDrugs.fluids = FluidSetup(primary: "Plasma-Lyte")

        var paediatricDrugs = DrugsFluidsSetup()
        // Buretrol for paediatric volume control; more dilute push-dose
        // adrenaline appropriate for smaller patients.
        paediatricDrugs.fluids = FluidSetup(primary: "Plasma-Lyte", givingSet: .buretrol)
        paediatricDrugs.emergency = EmergencyDrugSetup(
            selected: ["Atropine", "Suxamethonium"],
            pushDoseAdrenalineDilution: "1:1,000,000 (1mcg/mL)",
            paediatricSuxamethonium: true,
            preparedBy: .doctor,
            notes: "Sux drawn up and labelled for every paediatric case regardless of airway plan."
        )
        paediatricDrugs.gasInduction = GasInductionPreferences(
            enabled: true,
            volatileAgent: "Sevoflurane",
            carrierGas: "Oxygen",
            stepUpSequence: ["2%", "4%", "6%", "8%"],
            notes: "Parent present preferred. Scented mask (strawberry/bubblegum). IV access post-induction. Air/O₂ for maintenance."
        )

        let paediatric = SpecialtySetup(
            id: id(123),
            specialty: .paediatrics,
            additionalMonitoring: ["Temperature (continuous)", "BIS / Entropy (depth of anaesthesia)"],
            linesAndAccess: ["Small-bore IV (22G or 24G)", "IO access available"],
            equipment: [
                "Forced-air warmer (lower body Bair Hugger)", "Fluid warmer",
                "Paediatric breathing circuit", "Humidifier/HME"
            ],
            specialNotes: "Gas induction with parent present if possible. Sevoflurane in 100% O2, step up 2→4→6→8%. IV access once asleep. Ketamine 1mg/kg IV if cannulation difficult. Ondansetron routinely. Temperature management priority — lower body Bair Hugger throughout."
        )

        return Doctor(
            id: jamesOkonkwoID,
            fullName: "Dr James Okonkwo",
            phone: "",
            email: "",
            hospitalId: cityCentralID,
            department: "Anaesthesia",
            role: "Consultant Anaesthetist",
            subspecialties: [.paediatrics],
            biography: "Paediatric and neonatal anaesthetist with a difficult-airway interest. Also works at Mercy Private Hospital.",
            isDemoData: true,
            general: general,
            adultDrugs: adultDrugs,
            paediatricDrugs: paediatricDrugs,
            airway: airway,
            specialtySetups: [paediatric]
        )
    }
}
