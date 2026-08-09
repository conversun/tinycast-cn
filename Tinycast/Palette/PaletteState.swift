import Foundation

/// Palette state shared between the panel's SwiftUI tree and the coordinator.
@MainActor
@Observable
final class PaletteState {
    var mode: PaletteMode = .launcher
    var query: String = ""
    var selection: Int = 0
    /// Changes every time the palette is shown so the search field can re-focus.
    var focusToken = UUID()
    /// Bumped only by `prepare`, so lists snap to the top even when nothing else changed.
    var resetToken = UUID()
    /// Bumped when an action reorders the list, so the highlight scrolls back into view.
    var followToken = UUID()
    /// Set by the compact bar's overflow to expand without a query; cleared by `prepare`.
    var forceExpanded = false
    /// The paste target, mirrored on every show; `prepare` resets the screen, not this.
    var pasteTarget: PasteTarget?
    /// True only while the pointer physically moves; untracked, so it never re-renders.
    @ObservationIgnored var hoverHighlightArmed = false
    /// True while a footer menu is open. See docs/features/palette.md#menu-open-input-freeze.
    @ObservationIgnored var menuOpen = false { didSet { onMenuOpenChanged?(menuOpen) } }
    /// Fired when `menuOpen` flips, so the panel can hide the caret without a focus swap.
    @ObservationIgnored var onMenuOpenChanged: ((Bool) -> Void)?

    func prepare(mode: PaletteMode) {
        self.mode = mode
        query = ""
        selection = 0
        forceExpanded = false
        hoverHighlightArmed = false
        menuOpen = false
        focusToken = UUID()
        resetToken = UUID()
    }
}
