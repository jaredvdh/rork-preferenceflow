//
//  AdaptiveSheet.swift
//  PreferenceFlow
//

import SwiftUI

/// Presents full-screen experiences correctly on both device families.
///
/// On iPhone a `.sheet` fills the screen, but on iPad the same sheet floats as
/// a small centered card that wastes the display (seen with the guided tour,
/// the daily context prompt, and the Emergency Guides hub). This helper keeps
/// the familiar swipeable sheet on iPhone and switches to a full-screen cover
/// on iPad.
///
/// Content presented this way must provide its own dismiss affordance
/// (Done / Skip / Continue button) since full-screen covers cannot be swiped away.
extension View {
    @ViewBuilder
    func adaptiveFullScreenSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            fullScreenCover(isPresented: isPresented, content: content)
        } else {
            sheet(isPresented: isPresented, content: content)
        }
    }
}

/// Constrains content to a comfortable reading column on iPad while letting it
/// use the full width on iPhone. Apply inside full-screen views whose content
/// would otherwise stretch edge-to-edge on a 10–13" display.
struct ReadableColumn: ViewModifier {
    var maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Centers the view in a readable column (default 640pt) on wide screens.
    func readableColumn(maxWidth: CGFloat = 640) -> some View {
        modifier(ReadableColumn(maxWidth: maxWidth))
    }
}
