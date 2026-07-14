//
//  SurgicalPreferences.swift
//  PreferenceFlow
//

import Foundation

/// A surgeon's / proceduralist's theatre preferences — the surgical counterpart
/// to the anaesthetic Airway / Drugs / Monitoring sections. Nested on `Doctor`
/// as an optional so anaesthetic profiles (and profiles saved before the
/// surgical module existed) decode unchanged.
nonisolated struct SurgicalPreferences: Codable, Hashable {
    var gloves: GlovesPersonal
    var trays: TraysInstruments
    var sutures: SuturesClosure
    var energy: EnergyEquipment
    var positioning: PositioningPrep

    init(
        gloves: GlovesPersonal = GlovesPersonal(),
        trays: TraysInstruments = TraysInstruments(),
        sutures: SuturesClosure = SuturesClosure(),
        energy: EnergyEquipment = EnergyEquipment(),
        positioning: PositioningPrep = PositioningPrep()
    ) {
        self.gloves = gloves
        self.trays = trays
        self.sutures = sutures
        self.energy = energy
        self.positioning = positioning
    }

    /// Decodes with per-section fallbacks so future additions never break
    /// older exports.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gloves = try container.decodeIfPresent(GlovesPersonal.self, forKey: .gloves) ?? GlovesPersonal()
        trays = try container.decodeIfPresent(TraysInstruments.self, forKey: .trays) ?? TraysInstruments()
        sutures = try container.decodeIfPresent(SuturesClosure.self, forKey: .sutures) ?? SuturesClosure()
        energy = try container.decodeIfPresent(EnergyEquipment.self, forKey: .energy) ?? EnergyEquipment()
        positioning = try container.decodeIfPresent(PositioningPrep.self, forKey: .positioning) ?? PositioningPrep()
    }

    var hasContent: Bool {
        gloves.hasContent || trays.hasContent || sutures.hasContent
            || energy.hasContent || positioning.hasContent
    }
}

// MARK: - Gloves & Personal

/// Glove sizing/brand, gown, loupes/headlight and personal working style.
nonisolated struct GlovesPersonal: Codable, Hashable {
    /// Outer glove size, e.g. "7.5".
    var gloveSize: String = ""
    /// Preferred glove brand/type, e.g. "Biogel", "Gammex latex-free".
    var gloveBrand: String = ""
    /// Whether the surgeon routinely double-gloves.
    var doubleGloves: Bool = false
    /// Under-glove size when double-gloving (often a half size up).
    var underGloveSize: String = ""
    /// Gown preference, e.g. "Wrap-around XL", "Reinforced L".
    var gownPreference: String = ""
    var wearsLoupes: Bool = false
    var wearsHeadlight: Bool = false
    /// Music in theatre, e.g. "Classical during closing, none at induction".
    var musicPreference: String = ""
    /// Communication style, e.g. "Quiet room during anastomosis".
    var communicationStyle: String = ""
    var notes: String = ""

    var hasContent: Bool {
        !gloveSize.isEmptyOrWhitespace || !gloveBrand.isEmptyOrWhitespace
            || doubleGloves || !underGloveSize.isEmptyOrWhitespace
            || !gownPreference.isEmptyOrWhitespace || wearsLoupes || wearsHeadlight
            || !musicPreference.isEmptyOrWhitespace
            || !communicationStyle.isEmptyOrWhitespace
            || !notes.isEmptyOrWhitespace
    }

    /// One-line glove summary for the card, e.g. "7.5 Biogel (double, under 8.0)".
    var gloveDisplay: String {
        var parts: [String] = []
        if !gloveSize.isEmptyOrWhitespace { parts.append(gloveSize) }
        if !gloveBrand.isEmptyOrWhitespace { parts.append(gloveBrand) }
        var line = parts.joined(separator: " ")
        if doubleGloves {
            line += underGloveSize.isEmptyOrWhitespace
                ? " (double gloves)"
                : " (double, under \(underGloveSize))"
        }
        return line.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Trays & Instruments

/// Instrument sets to open, favourite extras and standby instruments.
nonisolated struct TraysInstruments: Codable, Hashable {
    /// Trays/sets opened for a standard list, e.g. "Major set", "Lap chole set".
    var traysToOpen: [String] = []
    /// Favourite individual extras opened routinely.
    var favouriteExtras: [String] = []
    /// Instruments kept in the room unopened, available on request.
    var haveAvailableUnopened: [String] = []
    var notes: String = ""
    /// Optional photo of the preferred instrument/back-table layout (resized JPEG).
    var setupPhoto: Data?

    var hasContent: Bool {
        !traysToOpen.isEmpty || !favouriteExtras.isEmpty
            || !haveAvailableUnopened.isEmpty
            || !notes.isEmptyOrWhitespace || setupPhoto != nil
    }
}

// MARK: - Sutures & Closure

/// Suture preferences by layer, staplers, drains and dressings.
nonisolated struct SuturesClosure: Codable, Hashable {
    /// Fascia / deep layer, e.g. "1 PDS loop".
    var fascia: String = ""
    /// Subcutaneous layer, e.g. "2-0 Vicryl".
    var subcutaneous: String = ""
    /// Skin closure, e.g. "3-0 Monocryl subcuticular", "Staples".
    var skin: String = ""
    /// Staplers and loads used, e.g. "Endo GIA 60 purple".
    var staplers: [String] = []
    /// Drain preferences, e.g. "Blake 19Fr", "No drain routinely".
    var drains: [String] = []
    /// Dressing preferences, e.g. "Comfeel", "PICO".
    var dressings: [String] = []
    var notes: String = ""

    var hasContent: Bool {
        !fascia.isEmptyOrWhitespace || !subcutaneous.isEmptyOrWhitespace
            || !skin.isEmptyOrWhitespace || !staplers.isEmpty
            || !drains.isEmpty || !dressings.isEmpty
            || !notes.isEmptyOrWhitespace
    }
}

// MARK: - Energy & Equipment

/// Diathermy settings, energy devices, tourniquet, irrigation and imaging.
nonisolated struct EnergyEquipment: Codable, Hashable {
    /// Diathermy cut setting, e.g. "30".
    var diathermyCut: String = ""
    /// Diathermy coag setting, e.g. "35".
    var diathermyCoag: String = ""
    /// Additional energy devices, e.g. "Harmonic scalpel", "LigaSure".
    var energyDevices: [String] = []
    /// Tourniquet pressure, e.g. "250 mmHg".
    var tourniquetPressure: String = ""
    /// Tourniquet time limits / reminders, e.g. "Notify at 90 min".
    var tourniquetNotes: String = ""
    /// Irrigation preference, e.g. "Warm saline", "Pulse lavage".
    var irrigation: String = ""
    /// Imaging and heavy equipment in room, e.g. "C-arm", "Microscope".
    var imaging: [String] = []
    var notes: String = ""

    var hasContent: Bool {
        !diathermyCut.isEmptyOrWhitespace || !diathermyCoag.isEmptyOrWhitespace
            || !energyDevices.isEmpty || !tourniquetPressure.isEmptyOrWhitespace
            || !tourniquetNotes.isEmptyOrWhitespace
            || !irrigation.isEmptyOrWhitespace || !imaging.isEmpty
            || !notes.isEmptyOrWhitespace
    }

    /// One-line diathermy summary, e.g. "Cut 30 / Coag 35".
    var diathermyDisplay: String {
        var parts: [String] = []
        if !diathermyCut.isEmptyOrWhitespace { parts.append("Cut \(diathermyCut)") }
        if !diathermyCoag.isEmptyOrWhitespace { parts.append("Coag \(diathermyCoag)") }
        return parts.joined(separator: " / ")
    }
}

// MARK: - Positioning & Prep

/// Patient position, table setup, skin prep, draping and catheter usage.
nonisolated struct PositioningPrep: Codable, Hashable {
    /// Patient position, e.g. "Supine", "Lloyd-Davies", "Beach chair".
    var patientPosition: String = ""
    /// Table attachments and padding, e.g. "Arm boards", "Bean bag".
    var tableAttachments: [String] = []
    /// Skin prep solution, e.g. "ChloraPrep", "Betadine".
    var prepSolution: String = ""
    /// Draping style, e.g. "Standard laparotomy drapes + Ioban".
    var drapingStyle: String = ""
    /// Urinary catheter routine, e.g. "Foley 14Fr for cases > 2h".
    var catheter: String = ""
    var notes: String = ""
    /// Optional photo of the finished positioning setup (resized JPEG).
    var setupPhoto: Data?

    var hasContent: Bool {
        !patientPosition.isEmptyOrWhitespace || !tableAttachments.isEmpty
            || !prepSolution.isEmptyOrWhitespace
            || !drapingStyle.isEmptyOrWhitespace
            || !catheter.isEmptyOrWhitespace
            || !notes.isEmptyOrWhitespace || setupPhoto != nil
    }
}

// MARK: - Curated option lists

/// Quick-pick chips and suggestions for the surgical editors. Suggestions only —
/// free text is always allowed and nothing here is clinical advice.
nonisolated enum SurgicalOptions {
    static let gloveBrands = [
        "Biogel", "Biogel PI", "Gammex", "Gammex latex-free",
        "Ansell Encore", "Medline SensiCare"
    ]
    static let gownPreferences = [
        "Standard gown", "Wrap-around gown", "Reinforced gown", "Sterile sleeves"
    ]
    static let trays = [
        "Major set", "Minor set", "Laparotomy set", "Laparoscopic set",
        "Basic orthopaedic set", "Arthroscopy set", "Vascular set",
        "Plastics set", "Cysto set", "D&C set", "Craniotomy set", "Spinal set"
    ]
    static let instrumentExtras = [
        "Extra Babcocks", "Long instruments", "Deep retractors (Deavers)",
        "Bookwalter retractor", "Omni-Tract", "Headlight", "Skin hooks",
        "Vessel loops", "Bone wax", "Raytec on a stick"
    ]
    static let standbyInstruments = [
        "Vascular clamps", "Sternal saw", "GIA stapler", "Cell saver",
        "Extra suction", "Laparotomy tray (during lap case)", "Tracheostomy set"
    ]
    static let fasciaSutures = [
        "1 PDS loop", "0 PDS", "0 Vicryl", "1 Nylon", "0 Prolene"
    ]
    static let subcutaneousSutures = [
        "2-0 Vicryl", "3-0 Vicryl", "3-0 Monocryl", "2-0 Vicryl Rapide"
    ]
    static let skinClosure = [
        "3-0 Monocryl subcuticular", "4-0 Monocryl subcuticular",
        "Staples", "3-0 Nylon interrupted", "Glue (Dermabond)", "Steri-Strips only"
    ]
    static let staplers = [
        "Skin stapler", "Linear stapler (GIA)", "Endo GIA", "Circular stapler (EEA)",
        "TA stapler", "Purple loads", "Tan loads", "Green loads"
    ]
    static let drains = [
        "No drain routinely", "Blake drain", "Redivac", "Jackson-Pratt",
        "Penrose", "Chest drain", "Pigtail catheter"
    ]
    static let dressings = [
        "Opsite", "Comfeel", "Mepore", "Steri-Strips + Tegaderm",
        "PICO (negative pressure)", "Glue only", "Pressure dressing"
    ]
    static let energyDevices = [
        "Monopolar diathermy", "Bipolar diathermy", "Harmonic scalpel",
        "LigaSure", "Thunderbeat", "PlasmaJet", "Argon beam"
    ]
    static let imaging = [
        "C-arm (image intensifier)", "Mini C-arm", "Microscope",
        "Laparoscopic stack", "Robot (da Vinci)", "Navigation system", "Ultrasound"
    ]
    static let irrigation = [
        "Warm saline", "Saline + betadine", "Pulse lavage", "Water (cytology)", "None routinely"
    ]
    static let positions = [
        "Supine", "Lithotomy", "Lloyd-Davies", "Lateral", "Prone",
        "Beach chair", "Trendelenburg", "Reverse Trendelenburg",
        "Jack-knife", "Fracture table"
    ]
    static let tableAttachments = [
        "Arm boards", "Arms tucked", "Lithotomy stirrups", "Beach chair attachment",
        "Traction table", "Leg holder", "Bean bag", "Gel padding",
        "Side supports", "Head ring", "Table break"
    ]
    static let prepSolutions = [
        "ChloraPrep (2% CHG in alcohol)", "Betadine (povidone-iodine)",
        "Aqueous chlorhexidine 0.5%", "Alcoholic betadine", "DuraPrep"
    ]
    static let drapingStyles = [
        "Standard drapes", "Laparotomy drapes + Ioban", "Extremity drape",
        "Split sheet", "U-drape", "Craniotomy drape", "Ophthalmic drape"
    ]
    static let catheters = [
        "No catheter routinely", "Foley 14Fr", "Foley 16Fr",
        "3-way catheter", "In-out catheter only", "Catheter for cases > 2h"
    ]
    static let diathermySettings = ["20", "25", "30", "35", "40", "45", "50"]
    static let tourniquetPressures = ["200 mmHg", "250 mmHg", "280 mmHg", "300 mmHg", "Twice systolic"]
}

/// Local whitespace helper — mirrors `String.isBlank` (defined in the app UI
/// layer) so the model file stays standalone.
private extension String {
    var isEmptyOrWhitespace: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
