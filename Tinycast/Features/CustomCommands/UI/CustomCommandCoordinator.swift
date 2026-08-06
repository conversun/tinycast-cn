import AppKit

/// Owns custom commands: the library, the one run funnel with its gate, and a deletion's cleanup.
@MainActor
final class CustomCommandCoordinator {
    private let store: CustomCommandStore
    private let settings: AppSettings
    private let appIndex: AppIndex
    private let paletteCoordinator: PaletteCoordinator
    private let hotKeys: HotKeyManager
    private let favorites: FavoritesStore
    private let visibility: VisibilityStore
    private let ranking: LauncherRankingStore
    /// Dialog and message-HUD presentation only — never for state this type owns.
    private unowned let core: AppCore

    init(
        store: CustomCommandStore,
        settings: AppSettings,
        appIndex: AppIndex,
        paletteCoordinator: PaletteCoordinator,
        hotKeys: HotKeyManager,
        favorites: FavoritesStore,
        visibility: VisibilityStore,
        ranking: LauncherRankingStore,
        core: AppCore
    ) {
        self.store = store
        self.settings = settings
        self.appIndex = appIndex
        self.paletteCoordinator = paletteCoordinator
        self.hotKeys = hotKeys
        self.favorites = favorites
        self.visibility = visibility
        self.ranking = ranking
        self.core = core
    }

    // MARK: - Feature presence

    func applyCustomCommandsPresence() {
        let visible = settings.customCommandsEnabled && settings.customCommandsShowInLauncher
        appIndex.setCustomCommands(visible ? store.commands : [])
    }

    // MARK: - Library

    @discardableResult
    func addCustomCommand(_ draft: CustomCommand) throws -> CustomCommand {
        try store.add(draft)
    }

    func updateCustomCommand(_ draft: CustomCommand) throws {
        try store.update(draft)
    }

    func deleteCustomCommand(id: UUID) {
        guard let command = store.command(id: id) else { return }
        removeCustomCommandReferences(ids: [id], entryIDs: [command.entryID])
        store.remove(id: id)
    }

    @discardableResult
    func replaceCustomCommands(_ commands: [CustomCommand]) -> Int {
        let previous = Dictionary(uniqueKeysWithValues: store.commands.map { ($0.id, $0) })
        let count = store.replace(with: commands)
        let liveIDs = Set(store.commands.map(\.id))
        let removed = Set(previous.keys).subtracting(liveIDs)
        let removedEntryIDs = Set(removed.compactMap { previous[$0]?.entryID })
        removeCustomCommandReferences(ids: removed, entryIDs: removedEntryIDs)
        return count
    }

    // MARK: - Running

    /// The one funnel for both palette activation and the command's global hotkey, so the confirmation gate can't be bypassed by either.
    func runCustomCommand(id: UUID) {
        // Also the feature switch: with custom commands off a still-registered global hotkey must not run anything.
        guard settings.customCommandsEnabled else { return }
        guard let command = store.command(id: id) else { return }
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette(restoreFocus: false) }
        Task {
            if command.requiresConfirmation {
                guard
                    // Neutral, not destructive: running a shell command the user wrote themselves is
                    // not a warning, it just wants a deliberate second tap.
                    await core.confirm(
                        title: command.name,
                        message: String(
                            localized: "Are you sure you want to run this command?\n\n\(command.command)"),
                        symbol: CustomCommand.sfSymbol, confirmTitle: String(localized: "Run"),
                        tone: .neutral, confirmRole: .standard)
                else { return }
            }
            let outcome = await ShellCommandRunner.run(
                command.command, loadingShellEnvironment: command.loadsShellEnvironment)
            guard outcome != .success else {
                // Fires when the command finishes, not when it starts, so a slow one confirms late rather than lying early.
                if command.showsConfirmation {
                    core.showMessage(String(localized: "Ran \(command.name)"))
                }
                return
            }
            await presentCustomCommandFailure(command: command, outcome: outcome)
        }
    }

    private func removeCustomCommandReferences(ids: Set<UUID>, entryIDs: Set<String>) {
        for id in ids {
            let action = HotKeyAction.customCommand(id: id)
            if hotKeys.recordingAction == action { hotKeys.recordingAction = nil }
            hotKeys.setBinding(nil, for: action)
        }
        favorites.remove(keys: entryIDs)
        visibility.removeItemKeys(entryIDs)
        for entryID in entryIDs {
            ranking.reset(itemKey: entryID)
        }
    }

    private func presentCustomCommandFailure(
        command: CustomCommand, outcome: ShellCommandOutcome
    ) async {
        let message: String
        // `127` is the shell's "command not found", so an alias or function that only exists in the user's config lands here.
        var suggestsShellEnvironment = false
        switch outcome {
        case .success:
            return
        case .launchFailure(let detail):
            message = String(localized: "The shell could not be started.\n\n\(detail)")
        case .nonZeroExit(let status, let stderr):
            suggestsShellEnvironment = status == 127 && !command.loadsShellEnvironment
            message =
                String(localized: "The command exited with status \(status).")
                + (stderr.map { "\n\n" + $0 } ?? "")
                + (suggestsShellEnvironment
                    ? "\n\n" + String(
                        localized:
                            "If this is a shell alias or function, turn on Load Shell Environment for this command."
                    ) : "")
        }
        guard
            await core.reportFailure(
                title: String(localized: "“\(command.name)” Failed"), message: message,
                symbol: CustomCommand.sfSymbol,
                recovery: suggestsShellEnvironment ? String(localized: "Open Settings…") : nil)
        else { return }
        paletteCoordinator.showSettings(tab: .commands)
    }
}
