import AppKit
import SwiftUI

/// Owns summoning and the aux windows: which mode shows. Where and how big stays with the controller.
@MainActor
final class PaletteCoordinator {
    private let palette: PaletteState
    private let settings: AppSettings
    private let appIndex: AppIndex
    private let windowController: PaletteWindowController
    private let auxWindows = AuxWindowController()
    /// Settings' environment injection only — never for state this type owns.
    private unowned let core: AppCore

    init(
        palette: PaletteState,
        settings: AppSettings,
        appIndex: AppIndex,
        windowController: PaletteWindowController,
        core: AppCore
    ) {
        self.palette = palette
        self.settings = settings
        self.appIndex = appIndex
        self.windowController = windowController
        self.core = core
    }

    // MARK: - Palette control

    var isVisible: Bool { windowController.isVisible }

    /// The app an action acts on: the one the palette displaced, else whatever a hotkey found frontmost.
    var targetApp: NSRunningApplication? {
        windowController.isVisible
            ? windowController.previousApp : NSWorkspace.shared.frontmostApplication
    }

    var previousApp: NSRunningApplication? { windowController.previousApp }

    func togglePalette() {
        if windowController.isVisible, palette.mode == .launcher {
            hidePalette()
        } else {
            showPalette(mode: .launcher, restoreAnyMode: true)
        }
    }

    func toggleClipboard() {
        if windowController.isVisible, palette.mode == .clipboard {
            hidePalette()
        } else {
            showPalette(mode: .clipboard)
        }
    }

    func toggleEmoji() {
        if windowController.isVisible, palette.mode == .emoji {
            hidePalette()
        } else {
            showPalette(mode: .emoji)
        }
    }

    /// Shows the palette, honoring Pop to Root Search: a reopen within the timeout restores the pre-close state — any mode for the generic summon (`restoreAnyMode`), else only when the preserved mode already matches the requested one.
    func showPalette(mode: PaletteMode, restoreAnyMode: Bool = false) {
        let preserved = windowController.consumePreservedState()
        if !(preserved && (restoreAnyMode || palette.mode == mode)) {
            palette.prepare(mode: mode)
        }
        windowController.show()
        // Re-scan on open so an app uninstalled since the last scan drops out of the launcher.
        if palette.mode == .launcher { Task { await appIndex.refresh() } }
    }

    func hidePalette(restoreFocus: Bool = true) {
        windowController.hide(restoreFocus: restoreFocus)
    }

    /// True when the palette should render as the slim compact bar: compact mode on, launcher root, empty query, and not force-expanded via the "…" overflow.
    var paletteIsCollapsed: Bool {
        settings.compactMode
            && !palette.forceExpanded
            && palette.mode == .launcher
            && palette.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The compact bar's "…" overflow: expand into the full favorites-pinned launcher without typing.
    func expandFromCompact() {
        palette.forceExpanded = true
    }

    /// Resize the panel to match the current collapsed state; called by the view when `paletteIsCollapsed` flips while open.
    func syncPaletteSize() {
        windowController.applyCollapsed(paletteIsCollapsed)
    }

    /// Dock-icon / reopen: focus an open aux window (About/Settings/Onboarding), else summon the launcher. Decoupled from the individual show paths so activation always works.
    func handleReopen() {
        if auxWindows.focusExisting() { return }
        showPalette(mode: .launcher, restoreAnyMode: true)
    }

    // MARK: - Auxiliary windows

    /// Settings runs in its own window (the SwiftUI `Settings` scene is unreliable for accessory apps). A fresh window mounts directly on `tab` (no first-frame flicker); an already-open one is switched in place.
    func showSettings(tab: SettingsTab = .general) {
        let isNew = auxWindows.show(
            id: "settings", title: String(localized: "Settings"),
            size: CGSize(width: 720, height: 550),
            seamlessTitleBar: true
        ) {
            SettingsRootView(initialTab: tab)
                .environment(self.core)
                .environment(self.settings)
                .environment(self.appIndex)
                .environment(self.core.hotKeys)
                .environment(self.core.visibility)
                .environment(self.core.customCommands)
                .environment(self.core.snippetsStore)
                .environment(self.core.quicklinks)
        }
        if !isNew {
            NotificationCenter.default.post(name: .tinycastSelectSettingsTab, object: tab)
        }
    }

    func showBackupSettings() {
        showSettings(tab: .backup)
    }

    func showAbout() {
        showSettings(tab: .about)
    }

    /// The first-run wizard: palette shortcut, Accessibility, Raycast import. Also re-runnable from Settings.
    func showOnboarding() {
        auxWindows.show(
            id: "onboarding", title: String(localized: "Welcome to Tinycast"),
            size: OnboardingView.windowSize, seamlessTitleBar: true
        ) {
            OnboardingView()
                .environment(self.core)
                .environment(self.settings)
                .environment(self.core.hotKeys)
        }
    }

    /// Final onboarding step: close the wizard and drop straight into the launcher.
    func finishOnboarding() {
        auxWindows.close(id: "onboarding")
        showPalette(mode: .launcher)
    }
}
