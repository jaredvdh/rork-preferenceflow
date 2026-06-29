//
//  CameraImagePicker.swift
//  PreferenceFlow
//

import SwiftUI
import UIKit

/// A thin SwiftUI wrapper around `UIImagePickerController` for capturing a photo
/// with the device camera. Library picking is handled by `PhotosPicker`; this is
/// used only for the live-camera path so users can snap a setup/equipment photo.
///
/// On the cloud simulator there is no camera, so callers should gate presentation
/// behind `CameraImagePicker.isAvailable`.
struct CameraImagePicker: UIViewControllerRepresentable {
    /// Called with the captured image once the user takes a shot. Nil if cancelled.
    let onCapture: (UIImage?) -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onCapture(info[.originalImage] as? UIImage)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
            picker.dismiss(animated: true)
        }
    }
}
