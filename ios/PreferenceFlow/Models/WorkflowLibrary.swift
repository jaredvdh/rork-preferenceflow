//
//  WorkflowLibrary.swift
//  PreferenceFlow
//
//  The catalogue of department-standard workflow templates. Each definition is
//  the "start with the standard setup" baseline; consultants record only their
//  deviations. New procedures are added here without touching the UI.
//

import Foundation

nonisolated enum WorkflowLibrary {

    /// Reusable option lists shared across workflows.
    private enum Opt {
        static let sterile = ["Sterile gloves only", "Full sterile gown and gloves", "Other"]
        static let position = ["Sitting", "Lateral"]
        static let spinalNeedle = ["Whitacre", "Sprotte", "Quincke", "Other"]
        static let gauge = ["25G", "26G", "27G"]
        static let skinLocal = ["Lignocaine 1%", "Lignocaine 2%", "Other"]
        static let intrathecal = [
            "0.5% Heavy Bupivacaine (Marcaine Heavy)",
            "0.5% Plain Bupivacaine",
            "Other"
        ]
        static let additives = ["Morphine", "Fentanyl", "Clonidine", "Other"]
        static let assistantPrep = ["Yes", "No", "Consultant prepares"]
        static let additionalEquip = [
            "2 mL Luer Lock syringe", "5 mL syringe", "10 mL syringe",
            "Blunt filter needle", "Drawing-up needle", "Sterile marker",
            "Additional sterile drape", "Extra gauze", "Chlorhexidine applicator"
        ]
        static let dressing = ["Transparent", "Tegaderm", "Gauze + tape"]
        static let arterialDressing = [
            "Transparent film (generic)", "Tegaderm 1624 (standard)", "Tegaderm 1633 (bordered)",
            "IV3000 (large)", "Opsite Flexifix", "Mefix + gauze",
            "Elastoplast / tape + gauze", "BD Nexiva integrated dressing"
        ]
        static let cvcDressing = [
            "Tegaderm CHG (chlorhexidine-impregnated, standard)",
            "Tegaderm CHG Large (9.5cm \u{00D7} 10cm)",
            "IV3000 Large (10cm \u{00D7} 12cm)",
            "Biopatch + Tegaderm (CHG disc plus transparent film)",
            "Opsite Post-Op (bordered)",
            "Mefix + gauze (for tunnelled or sutured sites)",
            "Chlorhexidine-impregnated disc + transparent film",
            "Gauze + tape (short-term only)"
        ]
        static let lor = ["Saline", "Air"]
        static let epiduralKit = ["Standard epidural", "Combined kit", "Department pack"]
        static let catheter = ["Threaded 3-5cm", "Multi-orifice", "Wire-reinforced"]
        static let cseKit = ["Needle-through-needle", "Separate spaces", "Department CSE pack"]
        static let consultantPrefs = [
            "Keep patient sitting until fixation",
            "Assistant maintains shoulder support",
            "Aspirate before injection",
            "Wait for free CSF flow before injection",
            "Ultrasound in obese patients"
        ]
        static let aLineSite = ["Radial", "Ulnar", "Brachial", "Axillary", "Femoral", "Dorsalis pedis"]
        static let aLineCannulaType = [
            "Standard cannula-over-needle", "Integrated arterial kit (Seldinger)",
            "Arrow arterial kit", "Vygon Leader-Cath", "BD Arterioscan",
            "Radifocus / wire-assisted"
        ]
        static let aLineGaugeLength = [
            "20G × 30mm (short)", "20G × 45mm (standard)", "20G × 48mm (long)",
            "18G × 45mm", "22G × 25mm (paediatric)"
        ]
        static let antiseptic = [
            "Chlorhexidine 2% (ChloraPrep)", "Chlorhexidine 0.5% in alcohol",
            "Povidone-iodine", "Alcohol 70%"
        ]
        static let prepLA = ["Lignocaine 1% SC", "EMLA cream", "None"]
        static let flushSolution = ["Heparinised normal saline", "Normal saline (no heparin)"]
        static let cvcSite = ["Right IJ", "Left IJ", "Subclavian", "Left subclavian", "Femoral"]
        static let cvcType = [
            "Arrow Triple Lumen", "Arrow Quad Lumen", "Arrow Double Lumen",
            "Vygon Triple Lumen", "BD Triple Lumen", "Quad lumen (generic)",
            "Introducer sheath (Cordis)", "Vascath / dialysis catheter", "Tunnelled line"
        ]
        static let cvcLineLength = [
            "Standard (16–20cm from right IJ)", "15cm", "18cm", "20cm",
            "Measured from insertion point"
        ]
        static let tipConfirmation = [
            "CXR post-insertion", "Intracavitary ECG", "Ultrasound tip confirmation", "Fluoroscopy"
        ]
        static let cvcTransducerPort = [
            "Distal port (brown)", "Medial port (blue)", "Proximal port (white)",
            "Any — label as used", "Per line labelling"
        ]
        static let suture = [
            "2-0 silk (standard)", "3-0 silk", "2-0 prolene (non-absorbable)", "3-0 prolene",
            "Stat-Lock (sutureless securement device)", "Grip-Lok (sutureless)",
            "SecurAcath (subcutaneous anchor)", "Steri-strips only (no suture)",
            "No suture \u{2014} dressing only"
        ]
        static let anchoringTechnique = [
            "Suture only",
            "Suture + transparent film dressing",
            "Suture + CHG-impregnated dressing",
            "Sutureless device (Stat-Lock / Grip-Lok) + dressing",
            "SecurAcath + dressing",
            "Dressing only (no suture)"
        ]
    }

    private static let standardSpinalPack = [
        "Skin prep", "Sterile drapes", "Gauze", "Introducer needle",
        "Spinal needle", "Syringes supplied in pack"
    ]

    // MARK: - Spinal

    static let spinal = WorkflowDefinition(
        id: "spinal",
        title: "Spinal Anaesthesia",
        icon: "arrow.down.to.line",
        summary: "Guided sterile prep, pack, drugs and technique.",
        steps: [
            WorkflowStep(
                id: "sterile", title: "Sterile Preparation", icon: "hands.and.sparkles",
                fields: [
                    WorkflowField(id: "sterile.level", label: "Sterile technique", kind: .singleSelect,
                                  icon: "hands.and.sparkles", options: Opt.sterile, allowsCustom: true,
                                  defaultSelection: "Full sterile gown and gloves")
                ]
            ),
            WorkflowStep(
                id: "position", title: "Patient Position", icon: "figure.seated.side",
                fields: [
                    WorkflowField(id: "position.choice", label: "Position", kind: .segmented,
                                  options: Opt.position, defaultSelection: "Sitting"),
                    WorkflowField(id: "position.notes", label: "Positioning notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "pack", title: "Standard Spinal Pack", icon: "shippingbox",
                subtitle: "Standard pack contents are assumed — only record extras below.",
                fields: [
                    WorkflowField(id: "pack.use", label: "Use standard spinal pack", kind: .packReference,
                                  icon: "shippingbox", referenceItems: standardSpinalPack, defaultBool: true)
                ]
            ),
            WorkflowStep(
                id: "additional", title: "Additional Equipment", icon: "plus.square.on.square",
                subtitle: "Only items outside the standard pack.",
                fields: [
                    WorkflowField(id: "additional.items", label: "Extra equipment", kind: .multiSelect,
                                  options: Opt.additionalEquip, allowsCustom: true)
                ]
            ),
            WorkflowStep(
                id: "skinLA", title: "Local Anaesthetic for Skin", icon: "syringe",
                fields: [
                    WorkflowField(id: "skinLA.agent", label: "Agent", kind: .singleSelect, icon: "syringe",
                                  options: Opt.skinLocal, allowsCustom: true, defaultSelection: "Lignocaine 1%"),
                    WorkflowField(id: "skinLA.notes", label: "Typical volume & draw-up notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "intrathecal", title: "Intrathecal Anaesthetic", icon: "drop",
                fields: [
                    WorkflowField(id: "intrathecal.agent", label: "Agent", kind: .singleSelect, icon: "drop",
                                  options: Opt.intrathecal, allowsCustom: true,
                                  defaultSelection: "0.5% Heavy Bupivacaine (Marcaine Heavy)"),
                    WorkflowField(id: "intrathecal.notes", label: "Institution-specific product notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "additives", title: "Intrathecal Additives", icon: "plus.diamond",
                fields: [
                    WorkflowField(id: "additives.list", label: "Additives", kind: .multiSelect,
                                  options: Opt.additives, allowsCustom: true),
                    WorkflowField(id: "additives.prep", label: "Assistant may prepare additives", kind: .singleSelect,
                                  icon: "person.fill.checkmark", options: Opt.assistantPrep,
                                  defaultSelection: "Consultant prepares"),
                    WorkflowField(id: "additives.notes", label: "Preparation notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "technique", title: "Technique Preferences", icon: "scope",
                fields: [
                    WorkflowField(id: "technique.needle", label: "Needle type", kind: .singleSelect,
                                  icon: "line.diagonal", options: Opt.spinalNeedle, allowsCustom: true,
                                  defaultSelection: "Whitacre"),
                    WorkflowField(id: "technique.gauge", label: "Gauge", kind: .segmented,
                                  options: Opt.gauge, defaultSelection: "25G"),
                    WorkflowField(id: "technique.introducer", label: "Introducer", kind: .toggle,
                                  icon: "arrow.down.to.line.compact", defaultBool: true),
                    WorkflowField(id: "technique.interspace", label: "Preferred interspace", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "consultant", title: "Special Consultant Preferences", icon: "star",
                fields: [
                    WorkflowField(id: "consultant.prefs", label: "Common preferences", kind: .multiSelect,
                                  options: Opt.consultantPrefs, allowsCustom: true),
                    WorkflowField(id: "consultant.notes", label: "Other notes", kind: .note)
                ]
            )
        ]
    )

    // MARK: - Epidural

    static let epidural = WorkflowDefinition(
        id: "epidural",
        title: "Epidural",
        icon: "minus.plus.batteryblock",
        summary: "Sterile prep, kit, loss of resistance, catheter and infusion.",
        steps: [
            WorkflowStep(
                id: "sterile", title: "Sterile Preparation", icon: "hands.and.sparkles",
                fields: [
                    WorkflowField(id: "sterile.level", label: "Sterile technique", kind: .singleSelect,
                                  icon: "hands.and.sparkles", options: Opt.sterile, allowsCustom: true,
                                  defaultSelection: "Full sterile gown and gloves")
                ]
            ),
            WorkflowStep(
                id: "position", title: "Patient Position", icon: "figure.seated.side",
                fields: [
                    WorkflowField(id: "position.choice", label: "Position", kind: .segmented,
                                  options: Opt.position, defaultSelection: "Sitting"),
                    WorkflowField(id: "position.notes", label: "Positioning notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "kit", title: "Epidural Kit", icon: "shippingbox",
                fields: [
                    WorkflowField(id: "kit.choice", label: "Kit", kind: .singleSelect, icon: "shippingbox",
                                  options: Opt.epiduralKit, allowsCustom: true, defaultSelection: "Standard epidural")
                ]
            ),
            WorkflowStep(
                id: "lor", title: "Loss of Resistance", icon: "gauge.with.dots.needle.bottom.50percent",
                fields: [
                    WorkflowField(id: "lor.method", label: "Loss of resistance", kind: .segmented,
                                  options: Opt.lor, defaultSelection: "Saline")
                ]
            ),
            WorkflowStep(
                id: "catheter", title: "Catheter", icon: "cable.connector",
                fields: [
                    WorkflowField(id: "catheter.type", label: "Catheter", kind: .singleSelect,
                                  icon: "cable.connector", options: Opt.catheter, allowsCustom: true,
                                  defaultSelection: "Threaded 3-5cm"),
                    WorkflowField(id: "catheter.notes", label: "Catheter notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "dressing", title: "Dressing", icon: "bandage",
                fields: [
                    WorkflowField(id: "dressing.choice", label: "Dressing", kind: .singleSelect, icon: "bandage",
                                  options: Opt.dressing, allowsCustom: true, defaultSelection: "Transparent")
                ]
            ),
            WorkflowStep(
                id: "testdose", title: "Test Dose", icon: "checkmark.shield",
                fields: [
                    WorkflowField(id: "testdose.use", label: "Give test dose", kind: .toggle,
                                  icon: "checkmark.shield", defaultBool: true),
                    WorkflowField(id: "testdose.notes", label: "Test dose notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "infusion", title: "Infusion Setup", icon: "drop",
                fields: [
                    WorkflowField(id: "infusion.notes", label: "Infusion setup notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "assistant", title: "Assistant Tasks", icon: "person.fill.checkmark",
                fields: [
                    WorkflowField(id: "assistant.notes", label: "Assistant tasks", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "consultant", title: "Consultant-Specific Notes", icon: "star",
                fields: [
                    WorkflowField(id: "consultant.notes", label: "Notes", kind: .note)
                ]
            )
        ]
    )

    // MARK: - Combined Spinal Epidural

    static let cse = WorkflowDefinition(
        id: "cse",
        title: "Combined Spinal Epidural",
        icon: "arrow.triangle.merge",
        summary: "Combined spinal and epidural setup in one guided flow.",
        steps: [
            WorkflowStep(
                id: "sterile", title: "Sterile Preparation", icon: "hands.and.sparkles",
                fields: [
                    WorkflowField(id: "sterile.level", label: "Sterile technique", kind: .singleSelect,
                                  icon: "hands.and.sparkles", options: Opt.sterile, allowsCustom: true,
                                  defaultSelection: "Full sterile gown and gloves")
                ]
            ),
            WorkflowStep(
                id: "position", title: "Patient Position", icon: "figure.seated.side",
                fields: [
                    WorkflowField(id: "position.choice", label: "Position", kind: .segmented,
                                  options: Opt.position, defaultSelection: "Sitting"),
                    WorkflowField(id: "position.notes", label: "Positioning notes", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "kit", title: "CSE Kit", icon: "shippingbox",
                fields: [
                    WorkflowField(id: "kit.choice", label: "Kit", kind: .singleSelect, icon: "shippingbox",
                                  options: Opt.cseKit, allowsCustom: true, defaultSelection: "Needle-through-needle")
                ]
            ),
            WorkflowStep(
                id: "spinal", title: "Spinal Component", icon: "arrow.down.to.line",
                fields: [
                    WorkflowField(id: "spinal.needle", label: "Spinal needle", kind: .singleSelect,
                                  icon: "line.diagonal", options: Opt.spinalNeedle, allowsCustom: true,
                                  defaultSelection: "Whitacre"),
                    WorkflowField(id: "spinal.gauge", label: "Gauge", kind: .segmented,
                                  options: Opt.gauge, defaultSelection: "27G"),
                    WorkflowField(id: "spinal.agent", label: "Intrathecal agent", kind: .singleSelect,
                                  icon: "drop", options: Opt.intrathecal, allowsCustom: true,
                                  defaultSelection: "0.5% Heavy Bupivacaine (Marcaine Heavy)"),
                    WorkflowField(id: "spinal.additives", label: "Additives", kind: .multiSelect,
                                  options: Opt.additives, allowsCustom: true)
                ]
            ),
            WorkflowStep(
                id: "epidural", title: "Epidural Component", icon: "minus.plus.batteryblock",
                fields: [
                    WorkflowField(id: "epidural.lor", label: "Loss of resistance", kind: .segmented,
                                  options: Opt.lor, defaultSelection: "Saline"),
                    WorkflowField(id: "epidural.catheter", label: "Catheter", kind: .singleSelect,
                                  icon: "cable.connector", options: Opt.catheter, allowsCustom: true,
                                  defaultSelection: "Threaded 3-5cm")
                ]
            ),
            WorkflowStep(
                id: "dressing", title: "Dressing", icon: "bandage",
                fields: [
                    WorkflowField(id: "dressing.choice", label: "Dressing", kind: .singleSelect, icon: "bandage",
                                  options: Opt.dressing, allowsCustom: true, defaultSelection: "Transparent")
                ]
            ),
            WorkflowStep(
                id: "assistant", title: "Assistant Tasks", icon: "person.fill.checkmark",
                fields: [
                    WorkflowField(id: "assistant.notes", label: "Assistant tasks", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "consultant", title: "Consultant-Specific Notes", icon: "star",
                fields: [
                    WorkflowField(id: "consultant.notes", label: "Notes", kind: .note)
                ]
            )
        ]
    )

    // MARK: - Arterial Line (demonstrates the extensible library)

    static let arterialLine = WorkflowDefinition(
        id: "arterialLine",
        title: "Arterial Line",
        icon: "waveform.path.ecg",
        summary: "Site, kit, transducer and securing preferences.",
        steps: [
            WorkflowStep(
                id: "sterile", title: "Sterile Preparation", icon: "hands.and.sparkles",
                fields: [
                    WorkflowField(id: "sterile.level", label: "Sterile technique", kind: .singleSelect,
                                  icon: "hands.and.sparkles", options: Opt.sterile, allowsCustom: true,
                                  defaultSelection: "Sterile gloves only")
                ]
            ),
            WorkflowStep(
                id: "site", title: "Site & Cannula", icon: "hand.point.up.braille",
                fields: [
                    WorkflowField(id: "site.choice", label: "Site", kind: .singleSelect,
                                  options: Opt.aLineSite, allowsCustom: true, defaultSelection: "Radial"),
                    WorkflowField(id: "site.cannulaType", label: "Cannula type", kind: .singleSelect,
                                  options: Opt.aLineCannulaType, allowsCustom: true,
                                  defaultSelection: "Standard cannula-over-needle"),
                    WorkflowField(id: "site.gaugeLength", label: "Gauge and length", kind: .singleSelect,
                                  options: Opt.aLineGaugeLength, allowsCustom: true,
                                  defaultSelection: "20G × 45mm (standard)"),
                    WorkflowField(id: "site.ultrasound", label: "Ultrasound guided", kind: .toggle,
                                  icon: "dot.radiowaves.left.and.right")
                ]
            ),
            WorkflowStep(
                id: "prep", title: "Site Preparation", icon: "cross.vial",
                fields: [
                    WorkflowField(id: "prep.antiseptic", label: "Skin prep agent", kind: .singleSelect,
                                  icon: "drop.degreesign", options: Opt.antiseptic,
                                  defaultSelection: "Chlorhexidine 2% (ChloraPrep)"),
                    WorkflowField(id: "prep.la", label: "Local anaesthetic", kind: .singleSelect,
                                  icon: "syringe", options: Opt.prepLA, allowsCustom: true,
                                  defaultSelection: "Lignocaine 1% SC"),
                    WorkflowField(id: "prep.positioning", label: "Patient positioning", kind: .note,
                                  help: "e.g. Rolled towel under dorsum of wrist with pronation; wrist dorsiflexed on arm board; arm abducted, supinated")
                ]
            ),
            WorkflowStep(
                id: "transducer", title: "Transducer & Securing", icon: "waveform.path",
                fields: [
                    WorkflowField(id: "transducer.flush", label: "Flush solution", kind: .singleSelect,
                                  icon: "drop", options: Opt.flushSolution, allowsCustom: true,
                                  defaultSelection: "Heparinised normal saline"),
                    WorkflowField(id: "transducer.notes", label: "Transducer setup notes", kind: .note),
                    WorkflowField(id: "securing.dressing", label: "Securing / dressing", kind: .singleSelect,
                                  icon: "bandage", options: Opt.arterialDressing, allowsCustom: true,
                                  defaultSelection: "Tegaderm 1624 (standard)"),
                    WorkflowField(id: "securing.notes", label: "Securing notes", kind: .note,
                                  help: "e.g. Loop suture through cannula hub if long case; arm board with IV3000")
                ]
            ),
            WorkflowStep(
                id: "consultant", title: "Consultant-Specific Notes", icon: "star",
                fields: [
                    WorkflowField(id: "consultant.notes", label: "Notes", kind: .note)
                ]
            )
        ]
    )

    // MARK: - Central Venous Catheter

    static let cvc = WorkflowDefinition(
        id: "cvc",
        title: "Central Venous Catheter",
        icon: "cable.connector.horizontal",
        summary: "Site, line type, ultrasound, fixation and dressing preferences.",
        steps: [
            WorkflowStep(
                id: "sterile", title: "Sterile Preparation", icon: "hands.and.sparkles",
                fields: [
                    WorkflowField(id: "sterile.level", label: "Sterile technique", kind: .singleSelect,
                                  icon: "hands.and.sparkles", options: Opt.sterile, allowsCustom: true,
                                  defaultSelection: "Full sterile gown and gloves")
                ]
            ),
            WorkflowStep(
                id: "site", title: "Site & Line", icon: "point.topleft.down.curvedto.point.bottomright.up",
                fields: [
                    WorkflowField(id: "site.choice", label: "Site", kind: .singleSelect,
                                  options: Opt.cvcSite, allowsCustom: true, defaultSelection: "Right IJ"),
                    WorkflowField(id: "site.type", label: "Line type", kind: .singleSelect,
                                  options: Opt.cvcType, allowsCustom: true,
                                  defaultSelection: "Arrow Triple Lumen"),
                    WorkflowField(id: "site.lineLength", label: "Line length", kind: .singleSelect,
                                  icon: "ruler", options: Opt.cvcLineLength, allowsCustom: true,
                                  defaultSelection: "Standard (16–20cm from right IJ)"),
                    WorkflowField(id: "site.ultrasound", label: "Ultrasound guided", kind: .toggle,
                                  icon: "dot.radiowaves.left.and.right", defaultBool: true)
                ]
            ),
            WorkflowStep(
                id: "prep", title: "Site Preparation", icon: "cross.vial",
                fields: [
                    WorkflowField(id: "prep.antiseptic", label: "Skin prep agent", kind: .singleSelect,
                                  icon: "drop.degreesign", options: Opt.antiseptic,
                                  defaultSelection: "Chlorhexidine 2% (ChloraPrep)"),
                    WorkflowField(id: "prep.la", label: "Local anaesthetic", kind: .singleSelect,
                                  icon: "syringe", options: Opt.prepLA, allowsCustom: true,
                                  defaultSelection: "Lignocaine 1% SC"),
                    WorkflowField(id: "prep.positioning", label: "Patient positioning", kind: .note,
                                  help: "e.g. Trendelenburg 15°; head turned left for right IJ; rolled towel between scapulae for subclavian")
                ]
            ),
            WorkflowStep(
                id: "confirm", title: "Confirmation & Securing", icon: "checkmark.seal",
                fields: [
                    WorkflowField(id: "confirm.method", label: "Tip confirmation method", kind: .singleSelect,
                                  icon: "checkmark.seal", options: Opt.tipConfirmation, allowsCustom: true,
                                  defaultSelection: "CXR post-insertion"),
                    WorkflowField(id: "confirm.transducerPort", label: "CVP transducer port", kind: .singleSelect,
                                  icon: "cable.connector", options: Opt.cvcTransducerPort, allowsCustom: true,
                                  defaultSelection: "Distal port (brown)"),
                    WorkflowField(id: "confirm.transducerNotes", label: "Transducer notes", kind: .note,
                                  help: "e.g. Transduce off distal (brown) port — leave medial for drug infusions, proximal for CVP sampling"),
                    WorkflowField(id: "confirm.notes", label: "Tip confirmation / checks", kind: .note)
                ]
            ),
            WorkflowStep(
                id: "fixation", title: "Fixation & Dressing", icon: "bandage",
                fields: [
                    WorkflowField(id: "fixation.suture", label: "Suture", kind: .singleSelect,
                                  icon: "link", options: Opt.suture, allowsCustom: true,
                                  defaultSelection: "2-0 silk (standard)"),
                    WorkflowField(id: "fixation.technique", label: "Anchoring technique", kind: .singleSelect,
                                  icon: "pin", options: Opt.anchoringTechnique, allowsCustom: true,
                                  defaultSelection: "Suture + CHG-impregnated dressing"),
                    WorkflowField(id: "fixation.dressing", label: "Dressing", kind: .singleSelect,
                                  icon: "bandage", options: Opt.cvcDressing, allowsCustom: true,
                                  defaultSelection: "Tegaderm CHG (chlorhexidine-impregnated, standard)"),
                    WorkflowField(id: "fixation.notes", label: "Fixation notes", kind: .note,
                                  help: "e.g. Loop silk suture through hub before dressing; wipe port hubs with ChloraPrep before capping; label all lumens with port colour")
                ]
            ),
            WorkflowStep(
                id: "consultant", title: "Consultant-Specific Notes", icon: "star",
                fields: [
                    WorkflowField(id: "consultant.notes", label: "Notes", kind: .note)
                ]
            )
        ]
    )

    /// Workflows surfaced on the Neuraxial tab.
    static let neuraxial: [WorkflowDefinition] = [spinal, epidural, cse]

    /// Additional procedural workflows (the growing library).
    static let procedural: [WorkflowDefinition] = [arterialLine, cvc]

    static let all: [WorkflowDefinition] = neuraxial + procedural

    static func definition(id: String) -> WorkflowDefinition? {
        all.first { $0.id == id }
    }
}
