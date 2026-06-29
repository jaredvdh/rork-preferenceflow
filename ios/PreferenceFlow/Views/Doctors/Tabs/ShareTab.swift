//
//  ShareTab.swift
//  PreferenceFlow
//

import SwiftUI

/// Share — export this provider's complete profile via the system share sheet.
struct ShareTab: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let doctor: Doctor

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showPDFOptions = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero

                includedCard

                Button(action: prepareShare) {
                    Label("Export & Share Profile", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.heroGradient, in: .capsule)
                        .foregroundStyle(.white)
                        .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 6)
                }

                Text("Shares a versioned PreferenceFlow file. The recipient can import it — no account or server needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button { showPDFOptions = true } label: {
                    Label("Export as PDF", systemImage: "doc.richtext")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemGroupedBackground), in: .capsule)
                        .foregroundStyle(Theme.accentDeep)
                        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1))
                }

                Text("Builds a polished Consultant Preference Card — choose sections, add a hospital appendix, then AirDrop, email, or print and laminate for theatre.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                SafetyBanner()
            }
            .padding(16)
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .sheet(isPresented: $showPDFOptions) {
            PreferenceCardExportView(doctor: doctor)
        }
        .alert("Export Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 88, height: 88)
                Image(systemName: "paperplane.fill").font(.system(size: 34)).foregroundStyle(Theme.accent)
            }
            Text("Share \(doctor.displayName)'s setup")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("AirDrop · Files · Mail · Messages")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var includedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Included in export", icon: "doc.text")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(exportContents, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                        Text(item).font(.subheadline)
                        Spacer()
                    }
                }
            }
            .card()
        }
    }

    private var exportContents: [String] {
        [
            "Profile & contact details",
            "General preferences",
            "Adult preferences",
            "\(settings.region.paediatric) preferences",
            "Airway preferences",
            "Regional blocks (\(doctor.regionalBlocks.count))",
            "Neuraxial preferences",
            "Procedure templates (\(doctor.operations.count))"
        ]
    }

    private func prepareShare() {
        let export = store.makeExport(doctorIDs: [doctor.id], region: settings.region, sharedBy: settings.userName)
        do {
            shareURL = try store.writeExportFile(export)
            showShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
