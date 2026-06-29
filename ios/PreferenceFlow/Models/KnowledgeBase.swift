//
//  KnowledgeBase.swift
//  PreferenceFlow
//

import Foundation

/// A top-level grouping of educational reference articles.
nonisolated enum KnowledgeCategory: String, CaseIterable, Identifiable, Hashable {
    case airway = "Airway"
    case regional = "Regional Anaesthesia"
    case ventilation = "Mechanical Ventilation"
    case emergency = "Emergency Guides"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .airway: return "lungs.fill"
        case .regional: return "scope"
        case .ventilation: return "waveform.path"
        case .emergency: return "cross.case.fill"
        }
    }

    var tint: String {
        switch self {
        case .airway: return "2E7DD1"
        case .regional: return "0E9F8E"
        case .ventilation: return "7A5CD6"
        case .emergency: return "D1576E"
        }
    }

    var blurb: String {
        switch self {
        case .airway: return "Laryngoscopy, supraglottic devices & difficult airway"
        case .regional: return "Block overviews, landmarks & complications"
        case .ventilation: return "Fundamentals, modes & waveform recognition"
        case .emergency: return "Quick-reference crisis guides"
        }
    }
}

/// One named subsection within an article (e.g. "Indications", "Equipment").
nonisolated struct KnowledgeSection: Identifiable, Hashable {
    let id = UUID()
    let heading: String
    let body: String
}

/// A single educational reference article. Content is bundled (not user data) and
/// is informational only — never clinical advice.
nonisolated struct KnowledgeArticle: Identifiable, Hashable {
    let id: String
    let category: KnowledgeCategory
    let title: String
    let symbol: String
    let summary: String
    let sections: [KnowledgeSection]

    init(id: String, category: KnowledgeCategory, title: String, symbol: String, summary: String, sections: [KnowledgeSection]) {
        self.id = id
        self.category = category
        self.title = title
        self.symbol = symbol
        self.summary = summary
        self.sections = sections
    }
}

/// Static, curated knowledge content. Educational reference only.
nonisolated enum KnowledgeLibrary {
    static func articles(in category: KnowledgeCategory) -> [KnowledgeArticle] {
        all.filter { $0.category == category }
    }

    static func article(id: String) -> KnowledgeArticle? {
        all.first { $0.id == id }
    }

    /// High-priority crisis guides, in the order shown on the Emergency hub.
    static var emergencyGuides: [KnowledgeArticle] {
        let order = [
            "emerg-mh", "emerg-last", "emerg-anaphylaxis", "emerg-cico",
            "emerg-haemorrhage", "emerg-difficult-airway", "emerg-cardiac-arrest"
        ]
        return order.compactMap { id in all.first { $0.id == id } }
    }

    static let all: [KnowledgeArticle] = airway + regional + ventilation + emergency

    // MARK: Airway

    private static let airway: [KnowledgeArticle] = [
        KnowledgeArticle(
            id: "air-dl", category: .airway, title: "Direct Laryngoscopy", symbol: "eye",
            summary: "Line-of-sight intubation with a Macintosh or Miller blade.",
            sections: [
                KnowledgeSection(heading: "Overview", body: "Direct laryngoscopy obtains a direct line of sight to the glottis using a rigid blade, displacing the tongue and lifting the epiglottis to expose the cords."),
                KnowledgeSection(heading: "Technique", body: "Optimal head position (sniffing), blade introduced from the right sweeping the tongue left, Macintosh tip into the vallecula or Miller tip lifting the epiglottis directly, lift along the blade axis (avoid levering on the teeth)."),
                KnowledgeSection(heading: "Optimisation", body: "External laryngeal manipulation (BURP), head elevation, bougie, and a smaller tube can all improve a difficult view. Grade the view (Cormack–Lehane) and communicate it to the team."),
                KnowledgeSection(heading: "Assistant Notes", body: "Have suction on, the next tube size down ready, a bougie immediately available, and be ready to provide laryngeal manipulation when asked.")
            ]
        ),
        KnowledgeArticle(
            id: "air-vl", category: .airway, title: "Video Laryngoscopy", symbol: "video",
            summary: "Indirect, camera-assisted view of the glottis.",
            sections: [
                KnowledgeSection(heading: "Overview", body: "A camera near the blade tip provides an indirect glottic view on a screen, often improving the view in anticipated or unexpected difficult airways."),
                KnowledgeSection(heading: "Blade Types", body: "Standard geometry (Macintosh-shaped) allows both direct and indirect viewing. Hyperangulated blades give a better view around an anterior larynx but usually require a matched rigid stylet."),
                KnowledgeSection(heading: "Common Systems", body: "McGrath, GlideScope, C-MAC and King Vision are widely used. Familiarity with the local device and its stylet/loading technique matters more than brand."),
                KnowledgeSection(heading: "Pitfalls", body: "A good view does not guarantee easy tube delivery with hyperangulated blades. Watch tube tip on screen, withdraw stylet partially as the tube enters the trachea, and avoid soft-tissue trauma off-screen.")
            ]
        ),
        KnowledgeArticle(
            id: "air-difficult", category: .airway, title: "Difficult Airway", symbol: "exclamationmark.triangle",
            summary: "Anticipation, planning and stepwise escalation.",
            sections: [
                KnowledgeSection(heading: "Overview", body: "A difficult airway may be anticipated (history, exam, prior records) or unexpected. A shared, pre-briefed plan and ready equipment reduce harm."),
                KnowledgeSection(heading: "Planning", body: "Have a stepwise plan A→D, declare it aloud, and ensure backup equipment (alternative blades, supraglottic device, front-of-neck kit) is in the room before induction."),
                KnowledgeSection(heading: "Equipment", body: "Difficult airway trolley, video laryngoscope, range of supraglottic devices, bougies/stylets, fibreoptic scope and a front-of-neck access set."),
                KnowledgeSection(heading: "Team", body: "Call for help early, allocate roles, keep oxygenation the priority, and follow recognised difficult-airway guidance from your institution.")
            ]
        ),
        KnowledgeArticle(
            id: "air-bougie", category: .airway, title: "Bougie Use", symbol: "line.diagonal",
            summary: "An introducer to railroad a tube over.",
            sections: [
                KnowledgeSection(heading: "Overview", body: "A bougie (tracheal tube introducer) is passed into the trachea first, then the tube is railroaded over it — useful with a restricted view."),
                KnowledgeSection(heading: "Confirmation", body: "Tracheal placement may be suggested by tracheal clicks (cartilage rings) and hold-up in smaller airways. Always confirm tube placement with capnography."),
                KnowledgeSection(heading: "Technique", body: "Maintain laryngoscopy while railroading, rotate the tube 90° anticlockwise if it hangs up on the arytenoids, and keep the bougie still as the assistant feeds the tube."),
                KnowledgeSection(heading: "Assistant Notes", body: "Keep the bougie clean and ready, feed the tube smoothly when asked, and hold the bougie at the lips so it does not advance too far.")
            ]
        ),
        KnowledgeArticle(
            id: "air-igel", category: .airway, title: "i-gel", symbol: "lungs",
            summary: "A non-inflatable gel-cuff supraglottic airway.",
            sections: [
                KnowledgeSection(heading: "Overview", body: "The i-gel is a second-generation supraglottic airway with a soft non-inflatable cuff that conforms to the perilaryngeal anatomy, plus a gastric channel."),
                KnowledgeSection(heading: "Sizing", body: "Sizing is commonly weight-based and printed on the device. Confirm local sizing guidance; a good seal and effective ventilation matter most."),
                KnowledgeSection(heading: "Insertion", body: "Lubricate, chin lift, insert in one smooth movement until resistance, confirm ventilation and capnography, and consider a bite block / fixation."),
                KnowledgeSection(heading: "Features", body: "The gastric channel allows passage of a suction tube. Some sizes facilitate fibreoptic-guided intubation through the device.")
            ]
        ),
        KnowledgeArticle(
            id: "air-proseal", category: .airway, title: "LMA ProSeal", symbol: "lungs",
            summary: "An inflatable-cuff second-generation LMA with a drain tube.",
            sections: [
                KnowledgeSection(heading: "Overview", body: "The LMA ProSeal has a deeper bowl, a dorsal cuff for a higher seal pressure, and a drain tube for gastric access."),
                KnowledgeSection(heading: "Insertion", body: "May be inserted digitally or with the introducer tool. Correct seating gives a good oropharyngeal seal and a patent drain tube."),
                KnowledgeSection(heading: "Confirmation", body: "Confirm with capnography and a leak test; the gastric drain can be checked for correct placement per local technique."),
                KnowledgeSection(heading: "Assistant Notes", body: "Have the introducer, lubricant, syringe for cuff inflation, and an orogastric tube ready if planned.")
            ]
        ),
        KnowledgeArticle(
            id: "air-auragain", category: .airway, title: "AuraGain", symbol: "lungs",
            summary: "An anatomically curved intubating supraglottic airway.",
            sections: [
                KnowledgeSection(heading: "Overview", body: "The Ambu AuraGain is a second-generation supraglottic device with an anatomical curve, gastric access, and a channel suitable for fibreoptic-guided intubation."),
                KnowledgeSection(heading: "Sizing", body: "Weight-based sizing is printed on the device. Confirm with local guidance and verify seal and ventilation after insertion."),
                KnowledgeSection(heading: "Use", body: "Useful as both a primary airway and a conduit for intubation; its preformed curve can aid first-pass placement."),
                KnowledgeSection(heading: "Assistant Notes", body: "Prepare lubricant, cuff syringe, a compatible tube for intubation if planned, and gastric tube for the drain channel.")
            ]
        )
    ]

    // MARK: Regional (each: Overview, Indications, Positioning, Equipment, Ultrasound landmarks, Complications)

    private static func regionalArticle(id: String, title: String, overview: String, indications: String, positioning: String, equipment: String, landmarks: String, complications: String) -> KnowledgeArticle {
        KnowledgeArticle(
            id: id, category: .regional, title: title, symbol: "scope",
            summary: overview,
            sections: [
                KnowledgeSection(heading: "Overview", body: overview),
                KnowledgeSection(heading: "Indications", body: indications),
                KnowledgeSection(heading: "Positioning", body: positioning),
                KnowledgeSection(heading: "Equipment", body: equipment),
                KnowledgeSection(heading: "Ultrasound Landmarks", body: landmarks),
                KnowledgeSection(heading: "Complications", body: complications)
            ]
        )
    }

    private static let regional: [KnowledgeArticle] = [
        regionalArticle(
            id: "reg-tap", title: "TAP Block",
            overview: "Transversus abdominis plane block deposits local anaesthetic in the fascial plane between internal oblique and transversus abdominis to cover the abdominal wall.",
            indications: "Analgesia for abdominal wall incisions — laparotomy, caesarean section, laparoscopic port sites, hernia repair.",
            positioning: "Supine, probe placed in the mid-axillary line between the costal margin and iliac crest.",
            equipment: "High-frequency linear probe, short-bevel block needle, sterile cover, local anaesthetic, extension tubing.",
            landmarks: "Identify the three muscle layers (external oblique, internal oblique, transversus abdominis) and place LA in the plane between the deeper two layers.",
            complications: "Intraperitoneal/visceral injury, intravascular injection and local anaesthetic systemic toxicity, block failure."
        ),
        regionalArticle(
            id: "reg-esp", title: "ESP Block",
            overview: "Erector spinae plane block deposits local anaesthetic deep to the erector spinae muscle against the transverse process for multi-dermatomal analgesia.",
            indications: "Thoracic and abdominal wall analgesia, rib fractures, breast and spine surgery.",
            positioning: "Sitting or lateral, probe placed in a parasagittal orientation lateral to the spinous processes.",
            equipment: "Linear (or curvilinear for deeper patients) probe, block needle, sterile cover, local anaesthetic.",
            landmarks: "Identify the transverse process and the erector spinae muscle above it; LA spreads in the plane against the transverse process.",
            complications: "Pleural puncture/pneumothorax (rare), intravascular injection, block failure."
        ),
        regionalArticle(
            id: "reg-femoral", title: "Femoral Block",
            overview: "Blocks the femoral nerve in the groin for analgesia of the anterior thigh and knee.",
            indications: "Hip and knee surgery analgesia, femoral shaft fracture.",
            positioning: "Supine, leg slightly abducted and externally rotated, probe transverse below the inguinal crease.",
            equipment: "Linear probe, short-bevel block needle, sterile cover, local anaesthetic.",
            landmarks: "Femoral artery with the hyperechoic femoral nerve lateral to it, deep to fascia iliaca and superficial to iliopsoas.",
            complications: "Intravascular injection, nerve injury, quadriceps weakness and fall risk."
        ),
        regionalArticle(
            id: "reg-fascia-iliaca", title: "Fascia Iliaca",
            overview: "A fascial plane block depositing LA beneath the fascia iliaca to reach femoral and lateral femoral cutaneous nerves.",
            indications: "Hip fracture and femoral analgesia, often as a landmark or ultrasound-guided technique.",
            positioning: "Supine, probe transverse or parallel to the inguinal ligament.",
            equipment: "Linear probe, block needle, sterile cover, local anaesthetic.",
            landmarks: "Identify fascia iliaca over iliopsoas, lateral to the femoral vessels; LA spreads beneath the fascia.",
            complications: "Intravascular injection, incomplete block, infection."
        ),
        regionalArticle(
            id: "reg-adductor", title: "Adductor Canal",
            overview: "Blocks the saphenous nerve (and contributions) in the adductor canal for knee analgesia while largely sparing quadriceps strength.",
            indications: "Knee surgery analgesia where preserving quadriceps power aids early mobilisation.",
            positioning: "Supine, leg externally rotated, probe on the medial mid-thigh.",
            equipment: "Linear probe, block needle, sterile cover, local anaesthetic.",
            landmarks: "Superficial femoral artery in the canal deep to sartorius; the saphenous nerve lies adjacent to the artery.",
            complications: "Intravascular injection, block failure, residual weakness."
        ),
        regionalArticle(
            id: "reg-popliteal", title: "Popliteal Sciatic",
            overview: "Blocks the sciatic nerve above its bifurcation in the popliteal fossa for foot and ankle analgesia.",
            indications: "Foot and ankle surgery, often combined with a saphenous/adductor canal block.",
            positioning: "Prone, lateral, or supine with leg elevated; probe in the popliteal crease then traced proximally.",
            equipment: "Linear probe, block needle, sterile cover, local anaesthetic.",
            landmarks: "Identify tibial and common peroneal nerves and follow them proximally to the point of bifurcation/common sheath.",
            complications: "Intravascular injection, nerve injury, foot drop, block failure."
        ),
        regionalArticle(
            id: "reg-interscalene", title: "Interscalene",
            overview: "Brachial plexus block at the roots/trunks in the interscalene groove for shoulder and proximal arm analgesia.",
            indications: "Shoulder and proximal humerus surgery.",
            positioning: "Supine or semi-sitting, head turned away, probe transverse at the level of the cricoid.",
            equipment: "Linear probe, block needle, sterile cover, local anaesthetic.",
            landmarks: "Hypoechoic nerve roots stacked between anterior and middle scalene muscles ('traffic light' sign).",
            complications: "Phrenic nerve palsy and dyspnoea, Horner's syndrome, hoarseness, intravascular/intrathecal injection."
        ),
        regionalArticle(
            id: "reg-supraclavicular", title: "Supraclavicular",
            overview: "Brachial plexus block at the trunks/divisions above the clavicle for analgesia of the arm below the shoulder.",
            indications: "Surgery of the arm, forearm and hand.",
            positioning: "Semi-sitting, head turned away, probe in the supraclavicular fossa angled caudally.",
            equipment: "Linear probe, block needle, sterile cover, local anaesthetic.",
            landmarks: "The plexus appears as a 'cluster of grapes' lateral and superficial to the subclavian artery, above the first rib and pleura.",
            complications: "Pneumothorax, phrenic palsy, intravascular injection, Horner's syndrome."
        )
    ]

    // MARK: Mechanical Ventilation

    private static let ventilation: [KnowledgeArticle] = [
        KnowledgeArticle(
            id: "vent-fundamentals", category: .ventilation, title: "Ventilation Fundamentals", symbol: "waveform.path",
            summary: "Compliance, resistance, PEEP and driving pressure.",
            sections: [
                KnowledgeSection(heading: "Compliance", body: "Compliance describes how easily the lungs distend (change in volume per change in pressure). Low compliance ('stiff' lungs) occurs in oedema, fibrosis and ARDS."),
                KnowledgeSection(heading: "Resistance", body: "Airway resistance opposes gas flow. It rises with bronchospasm, secretions, a kinked or small tube, and shows on the pressure waveform during inspiration."),
                KnowledgeSection(heading: "PEEP", body: "Positive end-expiratory pressure keeps alveoli open at end-expiration, improving oxygenation and reducing atelectrauma. Excessive PEEP can impair venous return."),
                KnowledgeSection(heading: "Driving Pressure", body: "Driving pressure (plateau pressure minus PEEP) reflects the cyclic strain on the lung; lower values are generally protective.")
            ]
        ),
        KnowledgeArticle(
            id: "vent-modes", category: .ventilation, title: "Ventilation Modes", symbol: "slider.horizontal.3",
            summary: "VC, PC, PSV, SIMV and ASV.",
            sections: [
                KnowledgeSection(heading: "Volume Control (VC)", body: "Delivers a set tidal volume; airway pressure varies with compliance and resistance. Guarantees volume but can generate high pressures."),
                KnowledgeSection(heading: "Pressure Control (PC)", body: "Delivers a set inspiratory pressure; tidal volume varies with lung mechanics. Limits peak pressure but volume must be monitored."),
                KnowledgeSection(heading: "Pressure Support (PSV)", body: "Patient-triggered breaths are supported to a set pressure; the patient controls rate and timing. Useful for spontaneous breathing and weaning."),
                KnowledgeSection(heading: "SIMV", body: "Synchronised intermittent mandatory ventilation delivers set mandatory breaths synchronised to patient effort, allowing spontaneous breaths between."),
                KnowledgeSection(heading: "ASV", body: "Adaptive support ventilation automatically adjusts rate and tidal volume toward a target minute ventilation based on lung mechanics.")
            ]
        ),
        KnowledgeArticle(
            id: "vent-waveforms", category: .ventilation, title: "Waveform Recognition", symbol: "waveform.path.ecg",
            summary: "Normal, bronchospasm, auto-PEEP, secretions, water in circuit.",
            sections: [
                KnowledgeSection(heading: "Normal", body: "A smooth capnograph with a clear plateau and a flow-time trace returning to baseline before the next breath indicates adequate exhalation."),
                KnowledgeSection(heading: "Bronchospasm", body: "A capnograph with an upsloping 'shark-fin' expiratory limb and a prolonged expiratory flow suggests obstruction to expiratory flow."),
                KnowledgeSection(heading: "Auto-PEEP", body: "Expiratory flow that does not return to zero before the next breath indicates incomplete exhalation and gas trapping (auto-PEEP)."),
                KnowledgeSection(heading: "Secretions", body: "A 'sawtooth' or oscillating pattern on the capnograph or flow trace can indicate secretions or water in the sampling line."),
                KnowledgeSection(heading: "Water in Circuit", body: "Erratic oscillations on the waveform may reflect condensation in the circuit or sampling line; check and clear traps.")
            ]
        )
    ]

    // MARK: Emergency Guides

    private static func emergencyArticle(id: String, title: String, symbol: String, recognition: String, immediate: String, equipment: String) -> KnowledgeArticle {
        KnowledgeArticle(
            id: id, category: .emergency, title: title, symbol: symbol,
            summary: recognition,
            sections: [
                KnowledgeSection(heading: "Recognition", body: recognition),
                KnowledgeSection(heading: "Immediate Priorities", body: immediate),
                KnowledgeSection(heading: "Equipment / Kit", body: equipment),
                KnowledgeSection(heading: "Reminder", body: "Follow your institution's current emergency protocol and crisis manual. This is an educational summary only — call for help early.")
            ]
        )
    }

    private static let emergency: [KnowledgeArticle] = [
        emergencyArticle(
            id: "emerg-mh", title: "Malignant Hyperthermia", symbol: "thermometer.sun.fill",
            recognition: "Unexplained rising end-tidal CO₂, tachycardia, masseter/generalised rigidity, hyperthermia and acidosis after triggering agents (volatiles, succinylcholine).",
            immediate: "Call for help and the MH kit, stop triggers, switch to a clean circuit and non-triggering anaesthesia, hyperventilate with 100% oxygen, and begin cooling and dantrolene preparation per protocol.",
            equipment: "MH emergency box, dantrolene with diluent and large syringes, cold fluids, cooling measures, arterial line and bloods, extra help to reconstitute drug."
        ),
        emergencyArticle(
            id: "emerg-last", title: "LAST", symbol: "bolt.heart.fill",
            recognition: "Local anaesthetic systemic toxicity — perioral tingling, agitation or drowsiness, seizures, then cardiovascular collapse/arrhythmia after local anaesthetic.",
            immediate: "Stop injecting, call for help, manage airway with 100% oxygen, control seizures, and start lipid emulsion therapy per protocol; modified ACLS if arrest.",
            equipment: "Lipid emulsion (Intralipid) kit, airway and resuscitation equipment, defibrillator, drugs for seizure control."
        ),
        emergencyArticle(
            id: "emerg-anaphylaxis", title: "Anaphylaxis", symbol: "allergens.fill",
            recognition: "Sudden hypotension, bronchospasm, high airway pressures, desaturation, flushing/urticaria or angioedema after an exposure.",
            immediate: "Call for help, remove likely trigger, give oxygen, adrenaline and IV fluids per protocol, and escalate as required; take timed tryptase samples afterward.",
            equipment: "Adrenaline, IV fluids, anaphylaxis drug pack, airway equipment, tryptase sample tubes."
        ),
        emergencyArticle(
            id: "emerg-haemorrhage", title: "Massive Haemorrhage", symbol: "drop.triangle.fill",
            recognition: "Rapid, large-volume blood loss with hypotension, tachycardia and a falling haemoglobin; activate when ongoing transfusion needs are anticipated.",
            immediate: "Call for help and activate the massive transfusion protocol, ensure large-bore access, use a rapid infuser and warmer, send coagulation/bloods, and communicate with blood bank and surgeons.",
            equipment: "Rapid infuser, fluid warmer, large-bore cannulae, blood products, cell saver, point-of-care testing, transfusion documentation."
        ),
        emergencyArticle(
            id: "emerg-cico", title: "CICO", symbol: "xmark.octagon.fill",
            recognition: "Can't Intubate, Can't Oxygenate — failure to oxygenate via facemask, supraglottic device and tracheal tube despite optimisation.",
            immediate: "Declare CICO, call for help, give 100% oxygen, and proceed to emergency front-of-neck access without delay per your difficult-airway guidance.",
            equipment: "Front-of-neck access kit (scalpel, bougie, tube), difficult airway trolley, video laryngoscope, supraglottic devices."
        ),
        emergencyArticle(
            id: "emerg-difficult-airway", title: "Difficult Airway (Crisis)", symbol: "lungs.fill",
            recognition: "Failed or failing intubation/oxygenation requiring a structured, time-critical response.",
            immediate: "Prioritise oxygenation, limit attempts, call for help and equipment, move through plan A→D, and prepare for front-of-neck access if oxygenation fails.",
            equipment: "Difficult airway trolley, video laryngoscope, range of supraglottic devices, bougies/stylets, front-of-neck kit, fibreoptic scope."
        ),
        emergencyArticle(
            id: "emerg-cardiac-arrest", title: "Theatre Cardiac Arrest", symbol: "bolt.heart.fill",
            recognition: "Loss of cardiac output in theatre — loss of pulse/plethysmograph, sudden fall in end-tidal CO₂, unrecordable blood pressure, or a shockable/non-shockable rhythm on the monitor.",
            immediate: "Call for help and the arrest trolley, start high-quality chest compressions and follow ALS, give 100% oxygen, consider and treat reversible causes (4 Hs and 4 Ts), and assign clear roles including a team leader and scribe.",
            equipment: "Arrest trolley and defibrillator, resuscitation drugs, airway and ventilation equipment, large-bore access and fluids, capnography, and a cognitive aid / crisis manual."
        )
    ]
}

// MARK: - Article relations

/// Maps a knowledge article to the in-app data it relates to so reading a guide
/// can surface the current consultant's preferences and the active hospital's
/// equipment locations (e.g. a Direct Laryngoscopy article links to airway
/// preferences and the difficult airway trolley location).
nonisolated enum KnowledgeRelations {
    /// Equipment kinds worth surfacing for an article, by category.
    static func relatedEquipmentKinds(for article: KnowledgeArticle) -> [EquipmentKind] {
        switch article.category {
        case .airway:
            return [.difficultIntubationTrolley, .videoLaryngoscopes, .emergencyAirway]
        case .regional:
            return [.regionalEquipment, .ultrasound]
        case .ventilation:
            return [.anaestheticWorkroom]
        case .emergency:
            return [.crashCart, .mhKit, .rapidInfuser, .belmont, .difficultIntubationTrolley, .emergencyAirway]
        }
    }

    /// Which profile tab a "related consultant preference" link should open.
    static func relatedProfileTab(for article: KnowledgeArticle) -> ProfileTabRef {
        switch article.category {
        case .airway: return .airway
        case .regional: return .regional
        case .ventilation: return .general
        case .emergency: return .overview
        }
    }
}

/// Lightweight, model-layer reference to a profile section so the relations helper
/// stays free of view types. Mapped to `ProfileTab` in the view layer.
nonisolated enum ProfileTabRef: String {
    case overview, general, airway, regional
}
