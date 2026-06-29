//
//  EquipmentLocationDetailView.swift
//  PreferenceFlow
//
//  Read-only equipment card — built so a locum who has never set foot in this
//  hospital can recognise the item (photo) and reach it (location banner) in
//  seconds.
//

import SwiftUI

struct EquipmentLocationDetailView: View {
    @Environment(DataStore.self) private var store

    let hospitalID: UUID
    let itemID: UUID
    /// Fallback used until the live item is resolved from the store.
    private let fallback: EquipmentLocation

    @State private var editing = false

    init(hospitalID: UUID, item: EquipmentLocation) {
        self.hospitalID = hospitalID
        self.itemID = item.id
        self.fallback = item
    }

    /// Always read the freshest copy so edits reflect immediately.
    private var item: EquipmentLocation {
        store.hospital(id: hospitalID)?
            .orientationOrEmpty.equipmentLocations
            .first { $0.id == itemID } ?? fallback
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                photo
                locationBanner

                if !item.accessInstructions.isBlank {
                    infoCard(
                        title: "How to access",
                        icon: "key.fill",
                        text: item.accessInstructions
                    )
                }

                if !item.notes.isBlank {
                    infoCard(
                        title: "Notes",
                        icon: "note.text",
                        text: item.notes
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            // Show item type as a quiet subtitle under the nav title.
            HStack(spacing: 6) {
                Image(systemName: item.symbol)
                    .font(.caption.weight(.semibold))
                Text(item.kind == .other ? "Equipment" : item.kind.category.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $editing) {
            EquipmentLocationEditView(hospitalID: hospitalID, item: item)
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photo: some View {
        if let data = item.photoData, let image = UIImage(data: data) {
            Color(.secondarySystemBackground)
                .frame(height: 200)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: Theme.cornerLarge))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        } else {
            Button { editing = true } label: {
                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                    .fill(Theme.accent.opacity(0.08))
                    .frame(height: 200)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cornerLarge)
                            .strokeBorder(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                    }
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 34, weight: .medium))
                            Text("Add photo")
                                .font(.headline)
                            Text("A photo helps anyone spot it instantly")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(Theme.accent)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Location banner

    private var locationBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("WHERE TO FIND IT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.75))
                Text(item.location.isBlank ? "Location not set yet" : item.location)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            item.location.isBlank
                ? AnyShapeStyle(Color.secondary.gradient)
                : AnyShapeStyle(Theme.heroGradient)
        )
        .clipShape(.rect(cornerRadius: Theme.cornerLarge))
        .shadow(color: Theme.accent.opacity(item.location.isBlank ? 0 : 0.25), radius: 12, x: 0, y: 6)
    }

    // MARK: - Info card

    private func infoCard(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title, icon: icon)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}
