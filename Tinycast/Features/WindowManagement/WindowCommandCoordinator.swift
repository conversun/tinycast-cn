import AppKit

/// The one funnel from a palette row or a global hotkey to the mover.
@MainActor
final class WindowCommandCoordinator {
    private let settings: AppSettings
    private let paletteCoordinator: PaletteCoordinator
    private let windowMover: WindowMover

    init(
        settings: AppSettings, paletteCoordinator: PaletteCoordinator, windowMover: WindowMover
    ) {
        self.settings = settings
        self.paletteCoordinator = paletteCoordinator
        self.windowMover = windowMover
    }

    /// The one funnel for palette and hotkey alike. See docs/features/window-management.md#wiring.
    func runWindowCommand(id: WindowCommand.ID) {
        guard settings.windowManagementEnabled else { return }
        let target = paletteCoordinator.targetApp
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette(restoreFocus: true) }
        windowMover.perform(
            id, target: target, gap: CGFloat(settings.windowGap),
            cycleOnRepeat: settings.windowCycleOnRepeat)
    }
}
