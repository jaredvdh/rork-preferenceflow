//
//  GeneralPreferences.swift
//  PreferenceFlow
//

import Foundation

/// General working preferences for a provider — theatre setup, personal touches
/// and workflow expectations. All free text / simple toggles entered by the user.
nonisolated struct GeneralPreferences: Codable, Hashable {
    // Theatre setup
    var gloveSize: String = ""
    var gownSize: String = ""
    var maskPreference: String = ""
    var theatreShoeSize: String = ""
    var roomTemperature: String = ""

    // Personal preferences
    var coffeePreference: String = ""
    var teaPreference: String = ""
    var favouriteSnacks: String = ""
    var contactPreferences: String = ""

    // Workflow preferences
    var arriveBeforePatient: Bool = false
    var prepareOwnMedications: Bool = false
    var assistantMayPrepareMedications: Bool = false
    var briefingStyle: String = ""

    var generalNotes: String = ""
}
