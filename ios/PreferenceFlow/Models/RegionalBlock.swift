//
//  RegionalBlock.swift
//  PreferenceFlow
//

import Foundation

/// A reusable regional anaesthesia block template. Users can create unlimited
/// blocks per provider. All fields are user-entered reference text.
nonisolated struct RegionalBlock: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String

    // Local anaesthetic
    var drug: String
    var concentration: String
    var typicalVolume: String

    // Equipment
    var needleType: String
    var needleLength: String
    var ultrasoundProbe: String
    var sterileCover: String

    var setupNotes: String
    var positioningNotes: String
    var assistantNotes: String
    var safetyNotes: String
    var specialNotes: String

    init(
        id: UUID = UUID(),
        name: String = "",
        drug: String = "",
        concentration: String = "",
        typicalVolume: String = "",
        needleType: String = "",
        needleLength: String = "",
        ultrasoundProbe: String = "",
        sterileCover: String = "",
        setupNotes: String = "",
        positioningNotes: String = "",
        assistantNotes: String = "",
        safetyNotes: String = "",
        specialNotes: String = ""
    ) {
        self.id = id
        self.name = name
        self.drug = drug
        self.concentration = concentration
        self.typicalVolume = typicalVolume
        self.needleType = needleType
        self.needleLength = needleLength
        self.ultrasoundProbe = ultrasoundProbe
        self.sterileCover = sterileCover
        self.setupNotes = setupNotes
        self.positioningNotes = positioningNotes
        self.assistantNotes = assistantNotes
        self.safetyNotes = safetyNotes
        self.specialNotes = specialNotes
    }

    /// Common block names offered as quick suggestions in the editor.
    static let suggestions = [
        "TAP Block", "Femoral", "Fascia Iliaca", "ESP Block",
        "Adductor Canal", "Interscalene", "Supraclavicular", "Popliteal Sciatic"
    ]
}
