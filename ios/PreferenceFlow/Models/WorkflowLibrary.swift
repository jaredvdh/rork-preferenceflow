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
        static let aLineSite = ["Radial", "Brachial", "Femoral", "Dorsalis pedis"]
        static let aLineGauge = ["20G", "22G", "Integrated kit"]
        static let cvcSite = ["Right IJ", "Left IJ", "Subclavian", "Femoral"]
        static let cvcType = ["Triple lumen", "Quad lumen", "Introducer sheath", "Vascath"]
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
                    WorkflowField(id: "site.gauge", label: "Cannula / kit", kind: .singleSelect,
                                  options: Opt.aLineGauge, allowsCustom: true, defaultSelection: "20G"),
                    WorkflowField(id: "site.ultrasound", label: "Ultrasound guided", kind: .toggle,
                                  icon: "dot.radiowaves.left.and.right")
                ]
            ),
            WorkflowStep(
                id: "transducer", title: "Transducer & Securing", icon: "waveform.path",
                fields: [
                    WorkflowField(id: "transducer.notes", label: "Transducer setup notes", kind: .note),
                    WorkflowField(id: "securing.dressing", label: "Securing / dressing", kind: .singleSelect,
                                  icon: "bandage", options: Opt.dressing, allowsCustom: true,
                                  defaultSelection: "Transparent")
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
        summary: "Site, line type, ultrasound and securing preferences.",
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
                                  options: Opt.cvcType, allowsCustom: true, defaultSelection: "Triple lumen"),
                    WorkflowField(id: "site.ultrasound", label: "Ultrasound guided", kind: .toggle,
                                  icon: "dot.radiowaves.left.and.right", defaultBool: true)
                ]
            ),
            WorkflowStep(
                id: "confirm", title: "Confirmation & Securing", icon: "checkmark.seal",
                fields: [
                    WorkflowField(id: "confirm.notes", label: "Tip confirmation / checks", kind: .note),
                    WorkflowField(id: "securing.dressing", label: "Securing / dressing", kind: .singleSelect,
                                  icon: "bandage", options: Opt.dressing, allowsCustom: true,
                                  defaultSelection: "Transparent")
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
