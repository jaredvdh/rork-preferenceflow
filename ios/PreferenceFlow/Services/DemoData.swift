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
    static let samuelAdeyemiID = id(13)
    static let elenaVasquezID = id(14)

    /// Definitive set of demo hospital ids. Removal matches on these — never on
    /// the fallible `isDemoData` flag alone — so demo cleanup can never delete a
    /// real record even if a flag were lost on decode or toggled by accident.
    static let allDemoHospitalIDs: Set<UUID> = [cityCentralID, mercyPrivateID]

    /// Definitive set of demo consultant ids (see `allDemoHospitalIDs`).
    static let allDemoDoctorIDs: Set<UUID> = [sarahMitchellID, jamesOkonkwoID, samuelAdeyemiID, elenaVasquezID]

    // MARK: - Public API

    /// Full set of demo hospitals.
    static var hospitals: [Hospital] { [cityCentral, mercyPrivate] }

    /// Full set of demo consultants and surgeons.
    static var doctors: [Doctor] { [sarahMitchell, jamesOkonkwo, samuelAdeyemi, elenaVasquez] }

    // MARK: - Edited-demo detection

    /// How far `updatedAt` may drift past `createdAt` before a demo record counts
    /// as user-edited. Untouched records keep the two stamps within milliseconds
    /// of each other (both default to "now" at install); every user edit flows
    /// through `DataStore.upsert`, which bumps `updatedAt` well past this window.
    private static let editDetectionTolerance: TimeInterval = 10

    /// True when a stored demo consultant has been edited by the user. Detection
    /// is timestamp-based (`updatedAt` bumped past `createdAt` by an edit), NOT a
    /// content comparison against the current in-code definition — app updates
    /// routinely revise the demo content itself, which would otherwise make every
    /// previously installed record read as "edited" and block clean removal.
    /// Records whose id isn't a known demo id are never considered demo.
    static func isEditedDemoDoctor(_ doctor: Doctor) -> Bool {
        guard allDemoDoctorIDs.contains(doctor.id) else { return false }
        return doctor.updatedAt.timeIntervalSince(doctor.createdAt) > editDetectionTolerance
    }

    /// True when a stored demo hospital has been edited by the user (see
    /// `isEditedDemoDoctor` for why this is timestamp-based).
    static func isEditedDemoHospital(_ hospital: Hospital) -> Bool {
        guard allDemoHospitalIDs.contains(hospital.id) else { return false }
        return hospital.updatedAt.timeIntervalSince(hospital.createdAt) > editDetectionTolerance
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

        // Procedural lines (Arterial Line, CVC) — stored in their own
        // `procedural` preferences, not neuraxial.
        var procedural = ProceduralPreferences()

        // Arterial line — exercises the simplified cannula/technique/positioning model.
        var arterialLine = procedural.customization(for: "arterialLine")
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
        procedural.setCustomization(arterialLine)

        // CVC — exercises line type/length, prep and confirmation extras.
        var cvc = procedural.customization(for: "cvc")
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
        procedural.setCustomization(cvc)

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
            procedural: procedural,
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

    // MARK: - Surgeon 1: Mr Samuel Adeyemi (General / Hepatobiliary)

    private static var samuelAdeyemi: Doctor {
        var surgical = SurgicalPreferences()
        surgical.gloves.gloveSize = "8.0"
        surgical.gloves.gloveBrand = "Biogel"
        surgical.gloves.doubleGloves = true
        surgical.gloves.underGloveSize = "8.5"
        surgical.gloves.gownPreference = "Wrap-around L"
        surgical.gloves.wearsLoupes = true
        surgical.gloves.wearsHeadlight = true
        surgical.gloves.musicPreference = "Low background music \u{2014} off during hilar dissection"
        surgical.gloves.communicationStyle = "Quiet room during liver transection. Blood loss called out every 15 minutes."

        surgical.trays.traysToOpen = ["Laparotomy set", "Laparoscopic set"]
        surgical.trays.favouriteExtras = ["Bookwalter retractor", "Long instruments", "Deep retractors (Deavers)", "Vessel loops"]
        surgical.trays.haveAvailableUnopened = ["Vascular clamps", "Cell saver", "GIA stapler"]
        surgical.trays.notes = "Lap chole: standard 4-port setup. Open HPB: Bookwalter mounted before knife to skin, CUSA checked and in the room."

        surgical.sutures.fascia = "1 PDS loop"
        surgical.sutures.subcutaneous = "3-0 Vicryl"
        surgical.sutures.skin = "4-0 Monocryl subcuticular"
        surgical.sutures.staplers = ["Endo GIA", "Purple loads"]
        surgical.sutures.drains = ["Blake drain", "No drain for routine lap chole"]
        surgical.sutures.dressings = ["Comfeel", "Opsite"]
        surgical.sutures.notes = "Any bile leak concern \u{2014} drain to the gallbladder fossa before closing."

        surgical.energy.diathermyCut = "30"
        surgical.energy.diathermyCoag = "35"
        surgical.energy.energyDevices = ["Monopolar diathermy", "Bipolar diathermy", "LigaSure", "Argon beam"]
        surgical.energy.irrigation = "Warm saline"
        surgical.energy.imaging = ["Laparoscopic stack", "Ultrasound"]
        surgical.energy.notes = "CUSA for parenchymal transection; argon beam ready for the raw liver surface."

        surgical.positioning.patientPosition = "Supine"
        surgical.positioning.tableAttachments = ["Arm boards", "Table break", "Gel padding"]
        surgical.positioning.prepSolution = "ChloraPrep (2% CHG in alcohol)"
        surgical.positioning.drapingStyle = "Laparotomy drapes + Ioban"
        surgical.positioning.catheter = "Foley 14Fr"
        surgical.positioning.notes = "Reverse Trendelenburg with left tilt for lap chole. Warming blanket from the start for long resections."

        let hpb = SpecialtySetup(
            id: id(126),
            specialty: .hepatobiliary,
            additionalMonitoring: [],
            linesAndAccess: ["Large-bore IV \u{00D7}2"],
            equipment: ["CUSA", "Cell saver", "Argon beam", "Intra-operative ultrasound"],
            specialNotes: "Major liver resection: anaesthetist runs low CVP during transection \u{2014} confirmed at time-out. Pringle tape and sloop ready on the tray. Blood availability checked before knife to skin."
        )

        return Doctor(
            id: samuelAdeyemiID,
            fullName: "Mr Samuel Adeyemi",
            phone: "",
            email: "",
            hospitalId: cityCentralID,
            department: "General Surgery",
            role: "Consultant General & HPB Surgeon",
            kind: .surgeon,
            subspecialties: [.generalSurgery, .hepatobiliary],
            biography: "General and hepatobiliary surgeon \u{2014} from laparoscopic cholecystectomy to major liver resection.",
            personalNotes: "Wants the intra-op ultrasound in the room for every liver case, even if it stays unopened.",
            isDemoData: true,
            surgical: surgical,
            specialtySetups: [hpb]
        )
    }

    // MARK: - Surgeon 2: Prof Elena Vasquez (Cardiothoracic)

    private static var elenaVasquez: Doctor {
        var surgical = SurgicalPreferences()
        surgical.gloves.gloveSize = "7.0"
        surgical.gloves.gloveBrand = "Biogel PI"
        surgical.gloves.doubleGloves = true
        surgical.gloves.underGloveSize = "7.5"
        surgical.gloves.gownPreference = "Reinforced gown"
        surgical.gloves.wearsLoupes = true
        surgical.gloves.wearsHeadlight = true
        surgical.gloves.musicPreference = "Classical during closing \u{2014} silence going on and coming off bypass"
        surgical.gloves.communicationStyle = "Closed-loop with perfusion. Bypass and cross-clamp times read back aloud."

        surgical.trays.traysToOpen = ["Cardiac major set", "Sternotomy set"]
        surgical.trays.favouriteExtras = ["Internal defibrillator paddles", "Vessel loops", "Bone wax", "Pacing wires"]
        surgical.trays.haveAvailableUnopened = ["Vascular clamps", "Cell saver", "Spare sternal saw"]
        surgical.trays.notes = "Leg vein harvest trolley set up separately for CABG. Aortic punch and side-biting clamp on the top shelf of the set."

        surgical.sutures.subcutaneous = "2-0 Vicryl"
        surgical.sutures.skin = "3-0 Monocryl subcuticular"
        surgical.sutures.drains = ["Mediastinal drain 28Fr", "Pleural drain if opened"]
        surgical.sutures.dressings = ["Mepore", "Pressure dressing to leg wounds"]
        surgical.sutures.notes = "Sternum closed with stainless steel wires \u{00D7}6; fascia and subcut in layers over the top."

        surgical.energy.diathermyCut = "40"
        surgical.energy.diathermyCoag = "40"
        surgical.energy.energyDevices = ["Monopolar diathermy", "Bipolar diathermy", "Harmonic scalpel"]
        surgical.energy.irrigation = "Warm saline"
        surgical.energy.imaging = ["Ultrasound"]
        surgical.energy.notes = "Internal paddles connected and tested before going on bypass. TOE by anaesthesia for all valve cases."

        surgical.positioning.patientPosition = "Supine"
        surgical.positioning.tableAttachments = ["Arms tucked", "Gel padding", "Head ring"]
        surgical.positioning.prepSolution = "ChloraPrep (2% CHG in alcohol)"
        surgical.positioning.drapingStyle = "Chin-to-knees cardiac draping \u{2014} both legs prepped for vein harvest"
        surgical.positioning.catheter = "Foley 16Fr with temperature probe"
        surgical.positioning.notes = "External defib pads on before draping for redo sternotomy. Groins kept accessible for emergency femoral cannulation."

        let cardiothoracic = SpecialtySetup(
            id: id(127),
            specialty: .cardiothoracic,
            additionalMonitoring: ["Arterial line", "CVP"],
            linesAndAccess: ["Large-bore IV \u{00D7}2"],
            equipment: ["Bypass machine (perfusion)", "Cell saver", "IABP console", "External pacing box"],
            specialNotes: "Heparin on surgeon's call \u{2014} ACT confirmed above target before cannulation, read back aloud. Protamine only once decannulated and perfusion confirms."
        )

        return Doctor(
            id: elenaVasquezID,
            fullName: "Prof Elena Vasquez",
            phone: "",
            email: "",
            hospitalId: cityCentralID,
            department: "Cardiothoracic Surgery",
            role: "Consultant Cardiothoracic Surgeon",
            kind: .surgeon,
            subspecialties: [.cardiothoracic],
            biography: "Cardiothoracic surgeon \u{2014} CABG, valve surgery and thoracic work.",
            personalNotes: "Runs the pump checklist with perfusion personally before every case.",
            isDemoData: true,
            surgical: surgical,
            specialtySetups: [cardiothoracic]
        )
    }
}
