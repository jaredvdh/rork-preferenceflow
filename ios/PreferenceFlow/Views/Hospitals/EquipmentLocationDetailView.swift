//
//  EquipmentLocationDetailView.swift
//  PreferenceFlow
//
//  Read-only equipment card — built so a locum who has never set foot in this
//  hospital can recognise the item (photo) and reach the nearest of its
//  locations in seconds. Emergency items show every location fully, no tapping.
//

import SwiftUI

struct EquipmentLocationDetailView: View {
    @Environment(DataStore.self) private var store

    let hospitalID: UUID
    let itemID: UUID
    /// Fallback used until the live item is resolved from the store.
    private let fallback: EquipmentLocation

    @State private var editing = false
    @State private var expandedSpots: Set<UUID> = []

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

    private var spots: [EquipmentSpot] {
        let located = item.locatedSpots
        return located.isEmpty ? Array(item.spots.prefix(1)) : located
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if item.isEmergency { emergencyBanner }
                heroPhoto
                whereToFindHeader

                ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                    locationRow(index: index, spot: spot)
                }

                // When access is the same everywhere, show it once below the list.
                if item.accessIsUniform, let access = spots.first?.accessInstructions, !access.isBlank {
                    infoCard(title: "How to access", icon: "key.fill", text: access)
                }

                if !item.notes.isBlank {
                    infoCard(title: "Notes", icon: "note.text", text: item.notes)
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

    // MARK: - Emergency banner

    private var emergencyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.headline)
            Text("EMERGENCY ITEM · \(spots.count) location\(spots.count == 1 ? "" : "s")")
                .font(.subheadline.weight(.bold))
                .tracking(0.5)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.gradient)
        .clipShape(.rect(cornerRadius: Theme.cornerMedium))
    }

    // MARK: - Hero photo (first available)

    @ViewBuilder
    private var heroPhoto: some View {
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

    // MARK: - Where to find it

    private var whereToFindHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text("WHERE TO FIND IT")
                .font(.subheadline.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer()
            if spots.count > 1 {
                Text("\(spots.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Theme.accent, in: .capsule)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func locationRow(index: Int, spot: EquipmentSpot) -> some View {
        let emergency = item.isEmergency
        // Emergency items always show everything; others can expand per-spot.
        let perSpotAccess = !item.accessIsUniform && !spot.accessInstructions.isBlank
        let isExpanded = emergency || expandedSpots.contains(spot.id)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(index + 1)")
                    .font(emergency ? .title3.weight(.bold) : .headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: emergency ? 36 : 30, height: emergency ? 36 : 30)
                    .background(emergency ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(Theme.heroGradient), in: .circle)

                Text(spot.location.isBlank ? "Location not set yet" : spot.location)
                    .font(emergency ? .system(size: 20, weight: .bold) : .system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !emergency && (perSpotAccess || spot.photoData != nil) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }

            if isExpanded {
                if let data = spot.photoData, let image = UIImage(data: data) {
                    Color(.secondarySystemBackground)
                        .frame(height: 150)
                        .overlay { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false) }
                        .clipShape(.rect(cornerRadius: Theme.cornerMedium))
                }
                if perSpotAccess {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.caption).foregroundStyle(Theme.accent).padding(.top, 2)
                        Text(spot.accessInstructions)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: Theme.cornerSmall))
                }
            }
        }
        .card()
        .overlay {
            if emergency {
                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                    .strokeBorder(Color.red.opacity(0.35), lineWidth: 1.5)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            guard !emergency, perSpotAccess || spot.photoData != nil else { return }
            if expandedSpots.contains(spot.id) { expandedSpots.remove(spot.id) }
            else { expandedSpots.insert(spot.id) }
        }
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
