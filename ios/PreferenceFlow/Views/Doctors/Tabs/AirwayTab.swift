//
//  AirwayTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Airway management — a direct inline editor reached from Edit mode. The
/// Adult / Paediatric cohort picker stays pinned at the top as a navigation aid;
/// everything below it is immediately editable. The read presentation lives on
/// the Overview card and read-mode specialty tabs.
struct AirwayTab: View {
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor

    @State private var cohort: Cohort = .adult

    enum Cohort: String, CaseIterable, Identifiable {
        case adult, paediatric
        var id: String { rawValue }
    }

    var body: some View {
        ConsultantEditSession(doctor: doctor) { $draft in
            VStack(spacing: 0) {
                Picker("Cohort", selection: $cohort) {
                    Text("Adult").tag(Cohort.adult)
                    Text(settings.region.paediatric).tag(Cohort.paediatric)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Form {
                    AirwayFormSections(draft: $draft, cohort: cohort)
                    Section {
                    } footer: {
                        InlineEditFooter()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemGroupedBackground))
            .sensoryFeedback(.selection, trigger: cohort)
        }
    }
}

/// The shared “Paediatric Patient” summary card. Age is the primary input and
/// drives an estimated weight via the standard formula; an optional actual
/// weight overrides it. This single profile feeds every paediatric calculation
/// on the page (ETT, supraglottic, gas induction).
struct PaediatricPatientCard: View {
    @Binding var patient: PaediatricPatient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Paediatric Patient", icon: "figure.child")
            VStack(spacing: 14) {
                HStack {
                    Text("Age").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(patient.ageLabel)
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .contentTransition(.numericText())
                    Stepper("", value: $patient.ageYears, in: 1...16, step: 1)
                        .labelsHidden()
                }

                Divider()

                HStack {
                    Text("Estimated Weight").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(patient.estimatedWeightLabel)
                        .font(patient.useActualWeight ? .subheadline.weight(.medium) : .headline)
                        .foregroundStyle(patient.useActualWeight ? .secondary : Theme.accentDeep)
                        .contentTransition(.numericText())
                }

                Toggle("Use Actual Patient Weight", isOn: $patient.useActualWeight.animation(.easeInOut(duration: 0.2)))
                    .font(.subheadline)
                    .tint(Theme.accent)

                if patient.useActualWeight {
                    HStack {
                        Text("Actual Weight").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(patient.actualWeightKg.rounded())) kg")
                            .font(.headline)
                            .foregroundStyle(Theme.accentDeep)
                            .contentTransition(.numericText())
                        Stepper("", value: $patient.actualWeightKg, in: 2...120, step: 1)
                            .labelsHidden()
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: patient.useActualWeight ? "scalemass.fill" : "function")
                        .font(.caption2)
                    Text(patient.usingLabel)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 10))

                Text("Estimated weight = (age × 2) + 10. Reference estimate only — confirm against the patient and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
        }
    }
}

/// Age-based paediatric ETT size reference. The patient age is supplied by the
/// shared Paediatric Patient card; sizing uses the consultant's cuffed/uncuffed
/// preference. ETT sizing stays age-based by design.
struct PaediatricETTCard: View {
    let ageYears: Double
    let cuffedPreference: String

    private var prefersUncuffed: Bool { cuffedPreference == "Uncuffed" }

    private var ageLabel: String {
        ageYears < 1 ? "<1 yr" : "\(Int(ageYears)) yr\(ageYears >= 2 ? "s" : "")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Endotracheal Tube", icon: "lungs.fill")
            VStack(spacing: 16) {
                HStack {
                    Text("For age").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(ageLabel)
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .contentTransition(.numericText())
                }
                HStack(spacing: 12) {
                    ettTile("Cuffed", size: PaediatricETT.formatted(ageYears: ageYears, cuffed: true), preferred: !prefersUncuffed)
                    ettTile("Uncuffed", size: PaediatricETT.formatted(ageYears: ageYears, cuffed: false), preferred: prefersUncuffed)
                }
                Text("Cuffed = age ÷ 4 + 3.5 · Uncuffed = age ÷ 4 + 4 (mm ID). Age-based reference estimate only — confirm against the patient and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
        }
    }

    private func ettTile(_ title: String, size: String, preferred: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                if preferred {
                    Image(systemName: "star.fill").font(.system(size: 8))
                }
            }
            .foregroundStyle(preferred ? Theme.accentDeep : .secondary)
            Text(size)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(preferred ? Theme.accentDeep : .primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            (preferred ? Theme.accent.opacity(0.12) : Color(.tertiarySystemFill)),
            in: .rect(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(preferred ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}

/// Age/weight-based laryngoscope blade size reference for paediatric airways.
struct PaediatricBladeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Paediatric Blade Sizes", icon: "rectangle.portrait.on.rectangle.portrait")
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Age / Weight")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Miller")
                        .frame(width: 84, alignment: .leading)
                    Text("Macintosh")
                        .frame(width: 84, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accentDeep)
                .padding(.bottom, 8)

                ForEach(Array(PaediatricBlade.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider() }
                    HStack(spacing: 8) {
                        Text(row.ageGroup)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.miller)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 84, alignment: .leading)
                        Text(row.macintosh)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 84, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                }

                Text("Straight (Miller) blades are commonly preferred in infants. Reference estimate only — confirm against the patient and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .card()
        }
    }
}

/// Weight-based paediatric supraglottic (i-gel / LMA) size reference. The weight
/// comes from the shared Paediatric Patient card (estimated or actual) — never
/// from age. Highlights the provider's selected device family and shows the
/// manufacturer weight range for the recommended size.
struct PaediatricSupraglotticCard: View {
    let weightKg: Double
    var usingActual: Bool = false
    let device: SupraglotticDevice

    private var prefersIgel: Bool { device == .igel }
    private var prefersLma: Bool {
        switch device {
        case .lmaClassic, .lmaProSeal, .lmaSupreme, .auraGain: return true
        default: return false
        }
    }

    /// Whichever device family the consultant prefers drives the headline.
    private var recommended: (name: String, size: String, range: String) {
        if prefersLma {
            return ("LMA", PaediatricSupraglottic.lmaSize(weightKg: weightKg), PaediatricSupraglottic.lmaRange(weightKg: weightKg))
        }
        return ("i-gel", PaediatricSupraglottic.igelSize(weightKg: weightKg), PaediatricSupraglottic.igelRange(weightKg: weightKg))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Supraglottic Airway", icon: "lungs")
            VStack(spacing: 16) {
                HStack {
                    Text("For weight").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(weightKg.rounded())) kg")
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                        .contentTransition(.numericText())
                    Text(usingActual ? "actual" : "est.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    sgTile("i-gel", size: PaediatricSupraglottic.igelSize(weightKg: weightKg), preferred: prefersIgel)
                    sgTile("LMA", size: PaediatricSupraglottic.lmaSize(weightKg: weightKg), preferred: prefersLma)
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.caption)
                    Text("Recommended: \(recommended.name) Size \(recommended.size)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(recommended.range)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 12))

                Text("Sizes are weight-based per the manufacturer table — never calculated from age. Reference estimate only; confirm against the patient, device packaging and local policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card()
        }
    }

    private func sgTile(_ title: String, size: String, preferred: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                if preferred {
                    Image(systemName: "star.fill").font(.system(size: 8))
                }
            }
            .foregroundStyle(preferred ? Theme.accentDeep : .secondary)
            Text(size)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(preferred ? Theme.accentDeep : .primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            (preferred ? Theme.accent.opacity(0.12) : Color(.tertiarySystemFill)),
            in: .rect(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(preferred ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }
}
