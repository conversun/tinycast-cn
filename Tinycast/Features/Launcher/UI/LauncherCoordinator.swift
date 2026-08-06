import AppKit

/// Owns launcher activation: the one funnel from a palette row to whatever the entry's kind runs.
@MainActor
final class LauncherCoordinator {
    private let ranking: LauncherRankingStore
    private let windowController: PaletteWindowController
    private let paletteCoordinator: PaletteCoordinator
    private let customCommandCoordinator: CustomCommandCoordinator
    private let systemActionCoordinator: SystemActionCoordinator
    private let quicklinkCoordinator: QuicklinkCoordinator
    private let snippetExpansion: SnippetExpansionCoordinator
    /// Window commands only — that funnel is permanently `AppCore`'s.
    private unowned let core: AppCore

    init(
        ranking: LauncherRankingStore,
        windowController: PaletteWindowController,
        paletteCoordinator: PaletteCoordinator,
        customCommandCoordinator: CustomCommandCoordinator,
        systemActionCoordinator: SystemActionCoordinator,
        quicklinkCoordinator: QuicklinkCoordinator,
        snippetExpansion: SnippetExpansionCoordinator,
        core: AppCore
    ) {
        self.ranking = ranking
        self.windowController = windowController
        self.paletteCoordinator = paletteCoordinator
        self.customCommandCoordinator = customCommandCoordinator
        self.systemActionCoordinator = systemActionCoordinator
        self.quicklinkCoordinator = quicklinkCoordinator
        self.snippetExpansion = snippetExpansion
        self.core = core
    }

    // MARK: - Activation

    func launch(_ app: AppEntry, searchQuery: String? = nil) {
        if let searchQuery {
            ranking.record(itemKey: app.preferenceKey, query: searchQuery)
        }
        // Commands dispatch before the palette hides: mode-switching commands keep it open.
        if app.kind == .command {
            runCommand(app)
            return
        }
        if app.kind == .customCommand {
            guard let id = CustomCommand.id(fromEntryID: app.id) else { return }
            customCommandCoordinator.runCustomCommand(id: id)
            return
        }
        if app.kind == .systemAction {
            guard let action = SystemActionCatalog.action(forEntryID: app.id) else { return }
            systemActionCoordinator.runSystemAction(id: action.id)
            return
        }
        if app.kind == .windowCommand {
            guard let command = WindowCommandCatalog.command(forEntryID: app.id) else { return }
            core.runWindowCommand(id: command.id)
            return
        }
        // Also before the palette hides: a quicklink with an unfilled argument stays in the palette
        // to ask for it, and only then opens.
        if app.kind == .quicklink {
            guard let id = Quicklink.id(fromEntryID: app.id) else { return }
            quicklinkCoordinator.openQuicklink(id: id)
            return
        }
        let previous = windowController.previousApp
        paletteCoordinator.hidePalette(restoreFocus: false)
        switch app.kind {
        case .application:
            AppLauncher.launch(app.url)
        case .systemSettings:
            guard let bundleID = app.bundleID else { return }
            AppLauncher.openSettingsPane(bundleID: bundleID)
        case .snippet:
            let snippetID = String(app.id.dropFirst("snippet:".count))
            snippetExpansion.expandSnippet(id: snippetID, targetApp: previous)
        case .command, .customCommand, .systemAction, .windowCommand, .quicklink:
            break  // handled above
        }
    }

    private func runCommand(_ entry: AppEntry) {
        switch CommandCatalog.command(for: entry) {
        case .calculatorHistory:
            paletteCoordinator.showPalette(mode: .calculatorHistory)
        case .clipboardHistory:
            paletteCoordinator.showPalette(mode: .clipboard)
        case .searchEmoji:
            paletteCoordinator.showPalette(mode: .emoji)
        case .searchQuicklinks:
            paletteCoordinator.showPalette(mode: .quicklinks)
        case .createQuicklink:
            paletteCoordinator.hidePalette(restoreFocus: false)
            quicklinkCoordinator.editQuicklink(nil)
        case .importQuicklinks:
            paletteCoordinator.hidePalette(restoreFocus: false)
            Task { await quicklinkCoordinator.importQuicklinks() }
        case .exportQuicklinks:
            paletteCoordinator.hidePalette(restoreFocus: false)
            Task { await quicklinkCoordinator.exportQuicklinks() }
        case .exportSettings:
            paletteCoordinator.hidePalette(restoreFocus: false)
            Task { await BackupActions.exportSettings() }
        case .importSettings:
            paletteCoordinator.hidePalette(restoreFocus: false)
            Task { await BackupActions.importSettings() }
        case .importFromRaycast:
            paletteCoordinator.hidePalette(restoreFocus: false)
            paletteCoordinator.showBackupSettings()
        case .settings:
            paletteCoordinator.hidePalette(restoreFocus: false)
            paletteCoordinator.showSettings()
        case .about:
            paletteCoordinator.hidePalette(restoreFocus: false)
            paletteCoordinator.showAbout()
        case .quit:
            NSApp.terminate(nil)
        case nil:
            break
        }
    }

    // MARK: - Row actions

    func resetRanking(for app: AppEntry) {
        ranking.reset(itemKey: app.preferenceKey)
    }

    func showInFinder(_ app: AppEntry) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(app.url)
    }

    /// Quits the app behind an entry; a no-op (palette stays put) when it isn't running.
    func quit(_ app: AppEntry) {
        guard app.kind == .application, let bundleID = app.bundleID else { return }
        // Unlike `launch`, nothing here takes focus on its own — hand it back to where the user was, unless that's the app now on its way out.
        let quittingPreviousApp = windowController.previousApp?.bundleIdentifier == bundleID
        guard AppLauncher.quit(bundleID: bundleID) else { return }
        paletteCoordinator.hidePalette(restoreFocus: !quittingPreviousApp)
    }
}
