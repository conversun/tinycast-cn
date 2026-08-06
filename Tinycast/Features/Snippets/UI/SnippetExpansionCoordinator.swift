import AppKit

/// Owns snippet expansion: the keyword listener, the argument prompt, delivery, feature presence.
@MainActor
final class SnippetExpansionCoordinator {
    private let store: SnippetsStore
    private let listener: SnippetKeywordListener
    private let injector: SnippetTextInjector
    private let clipboardStore: ClipboardStore
    private let appIndex: AppIndex
    private let settings: AppSettings
    /// Routed out so `MessageHUDController` stays owned by `AppCore`.
    private let showMessage: @MainActor (String) -> Void
    /// The consent dialog only — never for state this type owns.
    private unowned let core: AppCore

    init(
        store: SnippetsStore,
        listener: SnippetKeywordListener,
        injector: SnippetTextInjector,
        clipboardStore: ClipboardStore,
        appIndex: AppIndex,
        settings: AppSettings,
        showMessage: @escaping @MainActor (String) -> Void,
        core: AppCore
    ) {
        self.store = store
        self.listener = listener
        self.injector = injector
        self.clipboardStore = clipboardStore
        self.appIndex = appIndex
        self.settings = settings
        self.showMessage = showMessage
        self.core = core
    }

    // MARK: - Feature switch

    func revealSnippetsInFinder() {
        NSWorkspace.shared.open(store.snippetsDirectory)
    }

    /// The pane's switch funnels through here so enabling — which is also keyword-expansion consent — confirms first. The settings sink then reconciles the store, listener and launcher presence.
    func setSnippetsEnabled(_ enabled: Bool) {
        guard enabled != settings.snippetsEnabled else { return }
        if !enabled {
            settings.snippetsEnabled = false
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        Task {
            guard
                await core.confirm(
                    title: String(localized: "Enable snippets?"),
                    message: String(
                        localized:
                            "Keyword expansion requires the Accessibility permission. Keystrokes stay on this Mac."
                    ),
                    symbol: "curlybraces", confirmTitle: String(localized: "Continue"), tone: .neutral,
                    confirmRole: .standard)
            else { return }

            settings.snippetsEnabled = true
            // The one prompt for this feature, raised from the gesture that asked for it.
            Permissions.ensureAccessibility()
        }
    }

    // MARK: - Feature presence

    func applySnippetsLauncherPresence() {
        let visible = settings.snippetsEnabled && settings.snippetsShowInLauncher
        appIndex.updateSnippets(visible ? store.snippets : [])
    }

    /// Reconciles everything the snippets switch owns. Off tears down in dependency order; hotkey-free, so nothing else needs unwinding.
    func applySnippetsEnabled() {
        if settings.snippetsEnabled {
            Task { await store.start() }
            // A stop/start round-trip over an unchanged library publishes no snapshot, so re-project the records the store already holds.
            applySnippetsLauncherPresence()
            startSnippetKeywordListener()
            return
        }
        listener.stop()
        injector.cancelAutomaticExpansion()
        store.stop()
        appIndex.updateSnippets([])
    }

    // MARK: - Expansion

    /// How far back `{clipboard offset=N}` can reach; deeper offsets aren't a snippet idiom and this keeps the per-expansion sort trivial.
    private static let clipboardHistoryDepth = 20

    func startSnippetKeywordListener() {
        // `beginAutomaticExpansion` is the gate: it re-checks consent, permission, Secure Event Input and the target on the injector side, so this callback doesn't duplicate it.
        listener.start { [weak self] id, keyword, keywordLength, targetApp in
            guard let self,
                let generation = self.injector.beginAutomaticExpansion(
                    targetApp: targetApp)
            else { return }
            self.expandSnippet(
                id: id,
                targetApp: targetApp,
                expectedKeyword: keyword,
                keywordLength: keywordLength,
                automaticGeneration: generation)
        }
    }

    /// Recent text copies, newest first, for `{clipboard offset=N}`. The live pasteboard leads because the poller may not have recorded the newest copy yet.
    func clipboardHistoryForExpansion() -> [String] {
        var history = clipboardStore.items
            .filter { $0.kind == .text }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(Self.clipboardHistoryDepth)
            .compactMap(\.text)
        if let current = NSPasteboard.general.string(forType: .string), current != history.first {
            history.insert(current, at: 0)
        }
        return history
    }

    func expandSnippet(
        id: StoredSnippet.ID,
        targetApp: NSRunningApplication?,
        expectedKeyword: String? = nil,
        keywordLength: Int = 0,
        automaticGeneration: UInt? = nil
    ) {
        let records = store.snippets
        guard let record = records.first(where: { $0.id == id }) else {
            injector.cancelArgumentPrompt(
                automaticGeneration: automaticGeneration,
                targetApp: targetApp)
            return
        }
        // The automatic path was gated by `beginAutomaticExpansion` in the same turn, and `deliver` gates both again. Only the interactive path needs a check here: it must fail before the argument prompt, not after it.
        if automaticGeneration == nil {
            guard injector.prepareInteractiveExpansion(targetApp: targetApp) else { return }
        }
        let confirmation = record.snippet.showsConfirmation
            ? String(localized: "Inserted \(record.snippet.name)") : nil
        let context = injector.captureExpansionContext(
            targetApp: targetApp,
            clipboardHistory: clipboardHistoryForExpansion())
        let result = SnippetTemplateEngine.expand(
            record,
            snippets: records,
            context: context)
        if !result.missingArguments.isEmpty {
            promptSnippetArguments(
                record: record,
                records: records,
                context: context,
                missingArgs: result.missingArguments,
                targetApp: targetApp,
                expectedKeyword: expectedKeyword,
                keywordLength: keywordLength,
                automaticGeneration: automaticGeneration,
                confirmation: confirmation)
            return
        }
        completeSnippetExpansion(
            result,
            targetApp: targetApp,
            expectedKeyword: expectedKeyword,
            keywordLength: keywordLength,
            automaticGeneration: automaticGeneration,
            confirmation: confirmation)
    }

    private func promptSnippetArguments(
        record: StoredSnippet,
        records: [StoredSnippet],
        context: SnippetTemplateEngine.ExpansionContext,
        missingArgs: [SnippetTemplateEngine.MissingArgument],
        targetApp: NSRunningApplication?,
        expectedKeyword: String?,
        keywordLength: Int,
        automaticGeneration: UInt?,
        confirmation: String?
    ) {
        guard let arguments = SnippetArgumentsPrompt.run(
            snippetName: record.snippet.name,
            arguments: missingArgs)
        else {
            injector.cancelArgumentPrompt(
                automaticGeneration: automaticGeneration,
                targetApp: targetApp)
            return
        }

        let result = SnippetTemplateEngine.expand(
            record,
            snippets: records,
            context: context,
            userArguments: arguments)
        completeSnippetExpansion(
            result,
            targetApp: targetApp,
            expectedKeyword: expectedKeyword,
            keywordLength: keywordLength,
            automaticGeneration: automaticGeneration,
            confirmation: confirmation)
    }

    private func completeSnippetExpansion(
        _ result: SnippetTemplateEngine.ExpansionResult,
        targetApp: NSRunningApplication?,
        expectedKeyword: String?,
        keywordLength: Int,
        automaticGeneration: UInt?,
        confirmation: String?
    ) {
        injector.deliver(
            result,
            targetApp: targetApp,
            expectedKeyword: expectedKeyword,
            keywordLength: keywordLength,
            automaticGeneration: automaticGeneration,
            onDelivered: { [weak self] in
                guard let self, let confirmation else { return }
                self.showMessage(confirmation)
            })
    }
}
