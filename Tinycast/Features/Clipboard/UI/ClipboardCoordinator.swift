import AppKit

/// Owns clipboard-history actions: paste, copy, reveal, pin — and the selection that follows.
@MainActor
final class ClipboardCoordinator {
    private let clipboardStore: ClipboardStore
    private let palette: PaletteState
    private let windowController: PaletteWindowController
    private let paletteCoordinator: PaletteCoordinator

    init(
        clipboardStore: ClipboardStore,
        palette: PaletteState,
        windowController: PaletteWindowController,
        paletteCoordinator: PaletteCoordinator
    ) {
        self.clipboardStore = clipboardStore
        self.palette = palette
        self.windowController = windowController
        self.paletteCoordinator = paletteCoordinator
    }

    func paste(_ item: ClipboardItem) {
        let previous = windowController.previousApp
        paletteCoordinator.hidePalette(restoreFocus: false)
        // A successful write promotes the item to the head of its section; follow it so any preserved (pop-to-root) or open clipboard state highlights the row that moved.
        if Paster.paste(item, store: clipboardStore, previousApp: previous) {
            selectClip(item)
        }
    }

    func pasteKeepingWindowOpen(_ item: ClipboardItem) {
        if windowController.pasteKeepingWindowOpen(item, store: clipboardStore) {
            selectClip(item)
        }
    }

    func copyToClipboard(_ item: ClipboardItem) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        if Paster.copy(item, store: clipboardStore) {
            selectClip(item)
        }
    }

    func revealClipboardImage(_ item: ClipboardItem) {
        guard let url = clipboardStore.imageURL(for: item) else { return }
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(url)
    }

    /// Pin or unpin a clipboard entry: the row jumps into (or out of) the Pinned section at the top, so the selection and the scroll follow it.
    func togglePinnedClip(_ item: ClipboardItem) {
        clipboardStore.togglePinned(item)
        selectClip(item)
        palette.followToken = UUID()
    }

    /// Put the selection on `item`'s row in the list as currently filtered — pinned rows hold the top, so a row that moved isn't always index 0.
    private func selectClip(_ item: ClipboardItem) {
        palette.selection = clipboardStore.rowIndex(of: item, in: palette.query) ?? 0
    }
}
