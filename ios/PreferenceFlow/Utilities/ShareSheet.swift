//
//  ShareSheet.swift
//  PreferenceFlow
//

import SwiftUI
import UIKit

/// Bridges UIActivityViewController for AirDrop / Files / Mail / Messages sharing.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
