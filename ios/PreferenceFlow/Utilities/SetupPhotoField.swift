//
//  SetupPhotoField.swift
//  PreferenceFlow
//
//  One reusable "setup photo" capture field, wrapping the proven pattern from
//  the paediatric taping photo (AirwayEditView) and equipment location photos:
//  Take Photo (camera, when available) / Choose from Library, resized to a
//  portable JPEG before storing as Data so the local store never bloats with
//  full-resolution images. Used by workflow customisations (Arterial Line, CVC,
//  Spinal, CSE, Epidural), specialty setups and regional blocks.
//

import SwiftUI
import PhotosUI

/// Editable photo field: shows Take Photo / Choose from Library when empty,
/// and a full-width preview with Replace / Remove actions when set.
struct SetupPhotoField: View {
    var label: String = "Setup photo (optional)"
    var help: String = "A photo of the finished setup helps a technician match it exactly."
    @Binding var photoData: Data?

    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingLibrary = false

    var body: some View {
        Group {
            if let data = photoData, let image = UIImage(data: data) {
                preview(image)
            } else {
                emptyState
            }
        }
        .onChange(of: photoItem) { _, item in Task { await loadPhoto(item) } }
        .photosPicker(isPresented: $showingLibrary, selection: $photoItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker { image in
                if let resized = image?.resizedJPEG(maxDimension: 1000, quality: 0.8) {
                    photoData = resized
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Preview (photo set)

    private func preview(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Color(.secondarySystemBackground)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: Theme.cornerMedium))
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 8) {
                        Menu {
                            if CameraImagePicker.isAvailable {
                                Button { showingCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                            }
                            Button { showingLibrary = true } label: { Label("Choose from Library", systemImage: "photo") }
                        } label: {
                            Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: .capsule)
                                .foregroundStyle(.primary)
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { photoData = nil }
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: .capsule)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                }
        }
    }

    // MARK: - Empty state (no photo yet)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if CameraImagePicker.isAvailable {
                    photoButton("Take Photo", icon: "camera.fill") { showingCamera = true }
                }
                photoButton("Choose from Library", icon: "photo.fill") { showingLibrary = true }
            }
            Text(help)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func photoButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.accent.opacity(0.12), in: .capsule)
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Library loading

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let resized = image.resizedJPEG(maxDimension: 1000, quality: 0.8) {
            photoData = resized
        }
        photoItem = nil
    }
}

/// Read-only, full-width display of a stored setup photo, used inside the
/// expandable profile rows and specialty/regional detail cards.
struct SetupPhotoDisplay: View {
    let data: Data
    var caption: String = "Setup photo"

    @State private var viewing = false

    var body: some View {
        if let image = UIImage(data: data) {
            VStack(alignment: .leading, spacing: 6) {
                Text(caption.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Button { viewing = true } label: {
                    Color(.secondarySystemBackground)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: Theme.cornerMedium))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(7)
                                .background(.black.opacity(0.45), in: .circle)
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
            }
            .fullScreenCover(isPresented: $viewing) {
                SetupPhotoViewer(image: image)
            }
        }
    }
}

/// Full-screen viewer for a setup photo.
private struct SetupPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: .circle)
            }
            .padding(16)
        }
    }
}
