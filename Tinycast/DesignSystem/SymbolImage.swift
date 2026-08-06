import SwiftUI

/// An SF Symbol falling back to a bundled template asset of the same name: not every glyph the command
/// catalogs name is a system symbol — `toggleBluetooth` ships artwork, the logo being a SIG trademark —
/// and `Image(systemName:)` renders nothing for those. Size is explicit so both branches match.
struct SymbolImage: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size, weight: .regular))
                .symbolRenderingMode(.hierarchical)
        }
    }
}
