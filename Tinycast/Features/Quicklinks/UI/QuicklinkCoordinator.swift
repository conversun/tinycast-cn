import AppKit

/// Owns the quicklink flow: the open funnel, the argument prompt, the library and import/export.
@MainActor
final class QuicklinkCoordinator {
    private let store: QuicklinkStore
    private let argumentSession: QuicklinkArgumentSession
    private let settings: AppSettings
    private let appIndex: AppIndex
    private let injector: SnippetTextInjector
    private let hotKeys: HotKeyManager
    private let favorites: FavoritesStore
    private let visibility: VisibilityStore
    private let ranking: LauncherRankingStore
    private let windowController: PaletteWindowController
    /// `{clipboard offset=N}` reads the history a snippet expansion does; one owner, one depth.
    private let clipboardHistory: @MainActor () -> [String]
    /// Palette, Settings, dialog and HUD presentation only — never for state this type owns.
    private unowned let core: AppCore

    /// Carries the menu's default-app override across the quicklink argument prompt.
    private var pendingQuicklinkForcesDefaultApp = false

    init(
        store: QuicklinkStore,
        argumentSession: QuicklinkArgumentSession,
        settings: AppSettings,
        appIndex: AppIndex,
        injector: SnippetTextInjector,
        hotKeys: HotKeyManager,
        favorites: FavoritesStore,
        visibility: VisibilityStore,
        ranking: LauncherRankingStore,
        windowController: PaletteWindowController,
        clipboardHistory: @escaping @MainActor () -> [String],
        core: AppCore
    ) {
        self.store = store
        self.argumentSession = argumentSession
        self.settings = settings
        self.appIndex = appIndex
        self.injector = injector
        self.hotKeys = hotKeys
        self.favorites = favorites
        self.visibility = visibility
        self.ranking = ranking
        self.windowController = windowController
        self.clipboardHistory = clipboardHistory
        self.core = core
    }

    // MARK: - Feature presence

    /// The launcher section and the Quicklinks commands move together with the feature switch;
    /// "show in launcher" hides only the section, leaving the commands reachable.
    func applyQuicklinksPresence() {
        let enabled = settings.quicklinksEnabled
        appIndex.setQuicklinks(
            enabled && settings.quicklinksShowInLauncher ? store.quicklinks : [],
            commandsVisible: enabled)
    }

    // MARK: - Opening

    /// The one funnel for palette activation, the ⌘K menu and a quicklink's global shortcut, so
    /// neither the feature switch nor the argument prompt can be bypassed.
    ///
    /// `forcingDefaultApp` is the menu's "Open With Default App": it bypasses the saved handler for
    /// one open without changing what the quicklink is saved as.
    func openQuicklink(id: UUID, forcingDefaultApp: Bool = false) {
        guard settings.quicklinksEnabled, let quicklink = store.quicklink(id: id) else {
            return
        }
        // With the palette closed a shortcut still reads the selection from whatever is frontmost,
        // exactly as a system action targets the window a palette launch would have.
        let target =
            windowController.isVisible
            ? windowController.previousApp : NSWorkspace.shared.frontmostApplication
        let encoding: SnippetTemplateEngine.ValueEncoding =
            QuicklinkDestination.usesURLEncoding(quicklink.link) ? .percentEncoding : .none
        var context = injector.captureExpansionContext(
            targetApp: target, clipboardHistory: clipboardHistory())
        var arguments: [SnippetTemplateEngine.MissingArgument] = []

        // An unreadable selection is a missing value, not an empty one: substitute the clipboard, or
        // collect it through the same prompt the template's own arguments use.
        if context.selection.isEmpty, SnippetTemplateEngine.usesSelection(quicklink.link) {
            switch settings.quicklinkSelectionFallback {
            case .clipboard:
                context = context.replacingSelection(with: context.clipboard)
            case .ask:
                arguments.append(Self.selectionArgument)
            }
        }

        let expansion = SnippetTemplateEngine.expand(
            text: quicklink.link, context: context, encoding: encoding)
        arguments += expansion.missingArguments
        guard arguments.isEmpty else {
            argumentSession.begin(
                quicklink: quicklink, context: context, encoding: encoding, arguments: arguments)
            pendingQuicklinkForcesDefaultApp = forcingDefaultApp
            // Never `restoreAnyMode`: this screen is always a fresh prompt, never a restored one.
            core.showPalette(mode: .quicklinkArguments)
            return
        }
        performQuicklinkOpen(
            quicklink, link: expansion.text, forcingDefaultApp: forcingDefaultApp)
    }

    /// `{selection}` promoted to an argument when there is nothing to read and the setting says ask.
    private static let selectionArgument = SnippetTemplateEngine.MissingArgument(
        name: String(localized: "Selected Text"), options: [])

    /// ↵ in the argument form. Returns false while more arguments remain.
    @discardableResult
    func submitQuicklinkArgument(_ value: String) -> Bool {
        guard let request = argumentSession.request else { return false }
        guard let values = argumentSession.submit(value) else { return false }

        var context = request.context
        if let selection = values[Self.selectionArgument.name] {
            context = context.replacingSelection(with: selection)
        }
        let expansion = SnippetTemplateEngine.expand(
            text: request.quicklink.link, context: context, userArguments: values,
            encoding: request.encoding)
        let forcesDefault = pendingQuicklinkForcesDefaultApp
        cancelQuicklinkArguments()
        performQuicklinkOpen(
            request.quicklink, link: expansion.text, forcingDefaultApp: forcesDefault)
        return true
    }

    func cancelQuicklinkArguments() {
        argumentSession.cancel()
        pendingQuicklinkForcesDefaultApp = false
    }

    private func performQuicklinkOpen(
        _ quicklink: Quicklink, link: String, forcingDefaultApp: Bool
    ) {
        if windowController.isVisible { core.hidePalette(restoreFocus: false) }
        let openWith = forcingDefaultApp ? nil : quicklink.openWithBundleID
        Task {
            do throws(QuicklinkLauncher.Failure) {
                try await QuicklinkLauncher.open(
                    link, openWithBundleID: openWith,
                    inNewWindow: settings.quicklinkOpensNewWindow)
            } catch {
                await presentQuicklinkFailure(quicklink, link: link, failure: error)
            }
        }
    }

    private func presentQuicklinkFailure(
        _ quicklink: Quicklink, link: String, failure: QuicklinkLauncher.Failure
    ) async {
        let symbol = quicklink.iconSymbol ?? Quicklink.sfSymbol
        guard let bundleID = failure.missingApplicationBundleID else {
            await core.showNotice(
                title: String(localized: "Couldn’t Open \(quicklink.name)"),
                message: failure.localizedDescription, symbol: symbol, tone: .danger)
            return
        }
        // The only failure with a usable second option, so it offers it rather than dead-ending.
        let name = applicationName(forBundleID: bundleID) ?? bundleID
        guard
            await core.reportFailure(
                title: String(localized: "Couldn’t Open \(quicklink.name)"),
                message: String(localized: "\(name) isn’t installed any more."), symbol: symbol,
                recovery: "Open with Default")
        else { return }
        performQuicklinkOpen(quicklink, link: link, forcingDefaultApp: true)
    }

    private func applicationName(forBundleID bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap { FileManager.default.displayName(atPath: $0.path) }
    }

    // MARK: - Library

    @discardableResult
    func addQuicklink(_ draft: Quicklink) throws -> Quicklink {
        try store.add(draft)
    }

    func updateQuicklink(_ draft: Quicklink) throws {
        try store.update(draft)
    }

    /// Confirms unless the user turned the gate off, then deletes and unwinds every reference the
    /// quicklink owned. `confirming: false` is for the Settings pane, which already asked.
    func deleteQuicklink(id: UUID, confirming: Bool = true) async {
        guard let quicklink = store.quicklink(id: id) else { return }
        if confirming, settings.quicklinkConfirmsBeforeDelete {
            guard
                await core.confirm(
                    title: "Delete “\(quicklink.name)”?",
                    message: "Its shortcut, favorite slot and learned ranking go with it.",
                    symbol: quicklink.iconSymbol ?? Quicklink.sfSymbol, confirmTitle: "Delete")
            else { return }
        }
        removeQuicklinkReferences(ids: [id], entryIDs: [quicklink.entryID])
        try? store.remove(id: id)
    }

    func toggleQuicklinkPinned(id: UUID) {
        try? store.togglePinned(id: id)
    }

    func setQuicklinkShowsInRootSearch(_ shows: Bool, id: UUID) {
        try? store.setShowsInRootSearch(shows, id: id)
    }

    func duplicateQuicklink(id: UUID) {
        _ = try? store.duplicate(id: id)
    }

    /// Opens Settings on the Quicklinks pane with the editor showing `quicklink` (nil for a new one).
    func editQuicklink(_ quicklink: Quicklink?) {
        core.pendingQuicklinkEdit = QuicklinkEditRequest(quicklink: quicklink)
        core.showSettings(tab: .quicklinks)
    }

    @discardableResult
    func replaceQuicklinks(_ incoming: [Quicklink]) -> Int {
        let previous = store.quicklinks
        let count = store.replace(with: incoming)
        let liveIDs = Set(store.quicklinks.map(\.id))
        let removed = previous.filter { !liveIDs.contains($0.id) }
        removeQuicklinkReferences(
            ids: Set(removed.map(\.id)), entryIDs: Set(removed.map(\.entryID)))
        return count
    }

    private func removeQuicklinkReferences(ids: Set<UUID>, entryIDs: Set<String>) {
        for id in ids {
            let action = HotKeyAction.quicklink(id: id)
            if hotKeys.recordingAction == action { hotKeys.recordingAction = nil }
            hotKeys.setBinding(nil, for: action)
        }
        favorites.remove(keys: entryIDs)
        visibility.removeItemKeys(entryIDs)
        for entryID in entryIDs {
            ranking.reset(itemKey: entryID)
        }
    }

    // MARK: - Import & export

    func exportQuicklinks() async {
        guard !store.quicklinks.isEmpty else {
            await core.showNotice(
                title: "Nothing to Export", message: "You haven’t created any quicklinks yet.",
                symbol: Quicklink.sfSymbol, tone: .neutral)
            return
        }
        guard let url = BackupActions.chooseSaveLocation(named: "Tinycast-Quicklinks") else {
            return
        }
        do {
            try QuicklinkArchive.encode(store.quicklinks).write(to: url, options: .atomic)
            core.showMessage(String(localized: "Exported \(store.quicklinks.count) Quicklinks"))
        } catch {
            await core.showNotice(
                title: "Export Failed", message: error.localizedDescription,
                symbol: Quicklink.sfSymbol, tone: .danger)
        }
    }

    func importQuicklinks() async {
        guard let url = BackupActions.chooseJSONFile() else { return }
        do {
            let incoming = try QuicklinkArchive.decode(Data(contentsOf: url))
            let merge = QuicklinkArchive.merge(incoming, into: store.quicklinks)
            let added = store.append(merge.additions)
            // Everything the file offered was already here — say so rather than showing "0 imported".
            guard !added.isEmpty else {
                await core.showNotice(
                    title: "Nothing to Import",
                    message: "Every quicklink in this file is already in your library.",
                    symbol: Quicklink.sfSymbol, tone: .neutral)
                return
            }
            let skipped = merge.skipped + (merge.additions.count - added.count)
            let summary =
                skipped == 0
                ? String(localized: "Imported \(added.count) quicklinks.")
                : String(
                    localized:
                        "Imported \(added.count) quicklinks. Skipped \(skipped) already in your library."
                )
            await core.showNotice(
                title: "Quicklinks Imported", message: summary, symbol: Quicklink.sfSymbol,
                tone: .success)
        } catch {
            await core.showNotice(
                title: "Import Failed", message: error.localizedDescription,
                symbol: Quicklink.sfSymbol, tone: .danger)
        }
    }
}
