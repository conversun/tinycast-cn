import AppKit
import Combine
import SwiftUI

enum PaletteMode: String, CaseIterable, Identifiable {
    case launcher
    case clipboard
    case calculatorHistory
    case emoji
    case uninstall
    case quicklinks
    /// Collects a quicklink's `{argument}` values before it opens; the pending request lives on
    /// `AppCore.quicklinkArguments`, the way `.uninstall`'s target lives on `UninstallSession`.
    case quicklinkArguments

    var id: String { rawValue }
    var title: String {
        switch self {
        case .launcher: return String(localized: "Apps")
        case .clipboard: return String(localized: "Clipboard")
        case .calculatorHistory: return String(localized: "Calculator History")
        case .emoji: return String(localized: "Emoji & Symbols")
        case .uninstall: return String(localized: "Uninstall Application")
        case .quicklinks: return String(localized: "Quicklinks")
        case .quicklinkArguments: return String(localized: "Open Quicklink")
        }
    }
    var systemImage: String {
        switch self {
        case .launcher: return "magnifyingglass"
        case .clipboard: return "doc.on.doc"
        case .calculatorHistory: return "plus.forwardslash.minus"
        case .emoji: return "face.smiling"
        case .uninstall: return "trash"
        case .quicklinks, .quicklinkArguments: return Quicklink.sfSymbol
        }
    }
    var placeholder: String {
        switch self {
        case .launcher: return String(localized: "Search for apps and commands…")
        case .clipboard: return String(localized: "Type to filter entries…")
        case .calculatorHistory:
            return String(localized: "Do math, convert units, or search your past calculations…")
        case .emoji: return String(localized: "Search emoji and symbols…")
        case .uninstall: return String(localized: "Filter files and folders by name…")
        case .quicklinks: return String(localized: "Search quicklinks…")
        // Replaced by the pending argument's name; only reached if the session vanished mid-render.
        case .quicklinkArguments: return String(localized: "Enter a value…")
        }
    }
}

/// The app a paste will land in, resolved once per palette show so the footer pill and menu rows can name it without re-reading `NSWorkspace` on every render.
struct PasteTarget: Equatable {
    let name: String
    /// Bundle path for `IconCache` — nil for a target with no on-disk bundle.
    let iconPath: String?

    init?(app: NSRunningApplication?) {
        guard let app, let name = app.localizedName else { return nil }
        self.name = name
        iconPath = app.bundleURL?.path
    }

    var pasteTitle: String { String(localized: "Paste to \(name)") }
}

/// View-model shared between the panel's SwiftUI tree and the coordinator.
@MainActor
final class PaletteViewModel: ObservableObject {
    @Published var mode: PaletteMode = .launcher
    @Published var query: String = ""
    @Published var selection: Int = 0
    /// Changes every time the palette is shown so the search field can re-focus.
    @Published var focusToken = UUID()
    /// Changes only when `prepare` resets the palette, so the lists snap their scroll to the top even when query/mode were already at their defaults (`focusToken` can't serve: it bumps on every reopen, which must preserve a within-timeout scroll).
    @Published var resetToken = UUID()
    /// Changes when an action reorders the list under the selection (pinning a clip lifts it into the Pinned section), so the list scrolls the highlight back into view.
    @Published var followToken = UUID()
    /// Set by the compact bar's "…" overflow to expand into the full launcher without a query; cleared on every `prepare`.
    @Published var forceExpanded = false
    /// The app a paste would land in, mirrored from `PaletteWindowController.previousApp` on every show. Deliberately *not* cleared by `prepare` — pop-to-root resets the screen, not the paste target.
    @Published var pasteTarget: PasteTarget?
    /// Gates the mouse-hover highlight: true only while the pointer is physically moving (armed on `.mouseMoved`, disarmed on any `.keyDown` in `PalettePanel.sendEvent`). Plain, not `@Published` — read at hover time, never drives a re-render.
    var hoverHighlightArmed = false
    /// True while a footer popover menu (⌘K Actions or the app menu) is open, so `PalettePanel.sendEvent` swallows text-editing keystrokes the field editor would otherwise consume — the query must stay frozen while a menu owns the keyboard (matches Raycast). Plain, not `@Published` — read at event time, mirrored from the view's menu state.
    var menuOpen = false { didSet { onMenuOpenChanged?(menuOpen) } }
    /// Fired when `menuOpen` flips so `PalettePanel` can hide/show the search field's caret while it keeps first-responder status (no focus swap, so the placeholder never reflows).
    var onMenuOpenChanged: ((Bool) -> Void)?

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

/// Single owner of every long-lived manager. Wired up once from the app delegate.
@MainActor
final class AppCore: ObservableObject {
    static let shared = AppCore()

    let launcherRanking: LauncherRankingStore
    let appIndex: AppIndex
    let customCommands = CustomCommandStore()
    let quicklinks = QuicklinkStore()
    let clipboardStore = ClipboardStore()
    let clipboardManager: ClipboardManager
    let snippetsStore: SnippetsStore
    let snippetListener = SnippetKeywordListener(
        syntheticEventTag: Paster.tinycastEventTag)
    let snippetTextInjector: SnippetTextInjector
    let hotKeys = HotKeyManager()
    let hyperKeyTap = HyperKeyTap()
    let windowMover = WindowMover()
    let settings: AppSettings
    let favorites = FavoritesStore()
    let visibility = VisibilityStore()
    let calcHistory = CalculatorHistoryStore()
    let currencyRates = CurrencyRateStore()
    let emojiIndex = EmojiIndex()
    let frequentEmoji = FrequentEmojiStore()
    let runningApps = RunningAppsMonitor()
    let palette = PaletteViewModel()
    let uninstall = UninstallSession()
    let quicklinkArguments = QuicklinkArgumentSession()

    /// Set when a quicklink editor should open as the Settings window appears; the pane consumes it.
    @Published var pendingQuicklinkEdit: QuicklinkEditRequest?
    /// Carries the menu's default-app override across the quicklink argument prompt.
    private var pendingQuicklinkForcesDefaultApp = false

    private lazy var windowController = PaletteWindowController(core: self)
    private lazy var messageHUD = MessageHUDController(settings: settings)
    private let volumeHUD = VolumeHUDController()
    private let auxWindows = AuxWindowController()
    /// Every confirmation, failure report and value prompt in the app; it also guards against a held hotkey stacking dialogs.
    private let dialogs = DialogController()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let launcherRanking = LauncherRankingStore()
        let settings = AppSettings()
        self.launcherRanking = launcherRanking
        self.settings = settings
        appIndex = AppIndex(ranking: launcherRanking)
        let clipboardManager = ClipboardManager(store: clipboardStore, settings: settings)
        self.clipboardManager = clipboardManager
        snippetsStore = SnippetsStore()
        snippetTextInjector = SnippetTextInjector(
            clipboardManager: clipboardManager,
            settings: settings)
    }

    func start() {
        // AppKit's default tooltip delay is ~2–3s; shorten it (in ms) so the compact-bar favorite tooltips appear promptly. Registration domain — never overrides a user default.
        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 250])
        NSApp.setActivationPolicy(.accessory)
        // Force dark: the Liquid Glass material is tuned for a deep dark surface and renders washed-out in Light mode.
        NSApp.appearance = NSAppearance(named: .darkAqua)

        clipboardStore.maxAge = settings.clipboardRetention.maxAge
        // Defer the initial SQLite read + stale-image prune off the synchronous launch path so the menu bar is interactive immediately; `items` is @Published, so the palette fills in when it lands.
        Task { clipboardStore.load() }
        clipboardManager.start()

        appIndex.start(settings: settings)
        customCommands.onChange = { [weak self] _ in
            self?.applyCustomCommandsPresence()
        }
        applyCustomCommandsPresence()
        applyWindowCommandsPresence()
        quicklinks.onChange = { [weak self] _ in
            self?.applyQuicklinksPresence()
        }
        // Loaded even while the feature is off, and before `hotKeys.start`: its stale-binding prune
        // reads this list, so an unloaded store would look like "every quicklink was deleted" and
        // throw away the user's shortcuts. The library is small, so this is one short read.
        quicklinks.load()
        applyQuicklinksPresence()
        Task { await appIndex.refresh() }
        Task { await emojiIndex.load() }
        currencyRates.start()

        hotKeys.onTogglePalette = { [weak self] in self?.togglePalette() }
        hotKeys.onToggleClipboard = { [weak self] in self?.toggleClipboard() }
        hotKeys.onToggleEmoji = { [weak self] in self?.toggleEmoji() }
        hotKeys.onRunCustomCommand = { [weak self] id in self?.runCustomCommand(id: id) }
        hotKeys.onRunSystemAction = { [weak self] id in self?.runSystemAction(id: id) }
        hotKeys.onRunWindowCommand = { [weak self] id in self?.runWindowCommand(id: id) }
        hotKeys.onOpenQuicklink = { [weak self] id in self?.openQuicklink(id: id) }
        hotKeys.start(
            customCommandIDs: Set(customCommands.commands.map(\.id)),
            quicklinkIDs: Set(quicklinks.quicklinks.map(\.id)))
        // Deliberately keeps running while `hotKeys.recordingAction` pauses Carbon: the recorder relies on the tap's rewritten flags to capture Hyper shortcuts.
        hyperKeyTap.start(settings: settings)

        snippetsStore.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.applySnippetsLauncherPresence()
            self.snippetListener.update(snapshot.records)
        }
        // Off out of the box, so a user who never enables snippets pays for no load, no watcher and no tap.
        if settings.snippetsEnabled {
            Task { await snippetsStore.start() }
            startSnippetKeywordListener()
        }

        // @Published emits synchronously before the property is written (as in `AppIndex.start`), so every re-projection defers to a task that reads the settled value.
        for publisher in [
            settings.$windowManagementEnabled, settings.$windowManagementShowInLauncher
        ] {
            publisher.dropFirst()
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        Task { self.applyWindowCommandsPresence() }
                    }
                }
                .store(in: &cancellables)
        }
        for publisher in [settings.$customCommandsEnabled, settings.$customCommandsShowInLauncher] {
            publisher.dropFirst()
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        Task { self.applyCustomCommandsPresence() }
                    }
                }
                .store(in: &cancellables)
        }
        for publisher in [settings.$quicklinksEnabled, settings.$quicklinksShowInLauncher] {
            publisher.dropFirst()
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        Task { self.applyQuicklinksPresence() }
                    }
                }
                .store(in: &cancellables)
        }
        settings.$snippetsEnabled.dropFirst()
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task { self.applySnippetsEnabled() }
                }
            }
            .store(in: &cancellables)
        settings.$snippetsShowInLauncher.dropFirst()
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task { self.applySnippetsLauncherPresence() }
                }
            }
            .store(in: &cancellables)

        // First launch has no palette hotkey bound and shows nothing but the menu-bar icon; guide the user once. Marker is written at show-time so it stays one-time even if they Cmd-Q mid-flow.
        if !OnboardingState.hasOnboarded {
            OnboardingState.markShown()
            showOnboarding()
        }
    }

    func prepareForTermination() {
        // Caps Lock first: its HID remap is the only teardown that outlives the process, so nothing else may come before it.
        hyperKeyTap.prepareForTermination()
        snippetTextInjector.prepareForTermination()
        snippetListener.stop()
        snippetsStore.stop()
    }

    // MARK: - Feature switches

    private func applyCustomCommandsPresence() {
        let visible = settings.customCommandsEnabled && settings.customCommandsShowInLauncher
        appIndex.setCustomCommands(visible ? customCommands.commands : [])
    }

    private func applyWindowCommandsPresence() {
        let visible = settings.windowManagementEnabled && settings.windowManagementShowInLauncher
        appIndex.setWindowCommandsVisible(visible)
    }

    /// The launcher section and the Quicklinks commands move together with the feature switch;
    /// "show in launcher" hides only the section, leaving the commands reachable.
    private func applyQuicklinksPresence() {
        let enabled = settings.quicklinksEnabled
        appIndex.setQuicklinks(
            enabled && settings.quicklinksShowInLauncher ? quicklinks.quicklinks : [],
            commandsVisible: enabled)
    }

    private func applySnippetsLauncherPresence() {
        let visible = settings.snippetsEnabled && settings.snippetsShowInLauncher
        appIndex.updateSnippets(visible ? snippetsStore.snippets : [])
    }

    /// Reconciles everything the snippets switch owns. Off tears down in dependency order; hotkey-free, so nothing else needs unwinding.
    private func applySnippetsEnabled() {
        if settings.snippetsEnabled {
            Task { await snippetsStore.start() }
            // A stop/start round-trip over an unchanged library publishes no snapshot, so re-project the records the store already holds.
            applySnippetsLauncherPresence()
            startSnippetKeywordListener()
            return
        }
        snippetListener.stop()
        snippetTextInjector.cancelAutomaticExpansion()
        snippetsStore.stop()
        appIndex.updateSnippets([])
    }

    // MARK: - Palette control

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

    /// Settings runs in its own window (the SwiftUI `Settings` scene is unreliable for accessory apps). A fresh window mounts directly on `tab` (no first-frame flicker); an already-open one is switched in place.
    func showSettings(tab: SettingsTab = .general) {
        let isNew = auxWindows.show(
            id: "settings", title: String(localized: "Settings"),
            size: CGSize(width: 720, height: 550),
            seamlessTitleBar: true
        ) {
            SettingsRootView(initialTab: tab)
                .environmentObject(self)
                .environmentObject(self.appIndex)
                .environmentObject(self.visibility)
                .environmentObject(self.customCommands)
                .environmentObject(self.snippetsStore)
                .environmentObject(self.quicklinks)
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
        }
    }

    /// Final onboarding step: close the wizard and drop straight into the launcher.
    func finishOnboarding() {
        auxWindows.close(id: "onboarding")
        showPalette(mode: .launcher)
    }

    // MARK: - Actions invoked from the palette UI

    func launch(_ app: AppEntry, searchQuery: String? = nil) {
        if let searchQuery {
            launcherRanking.record(itemKey: app.preferenceKey, query: searchQuery)
        }
        // Commands dispatch before the palette hides: mode-switching commands keep it open.
        if app.kind == .command {
            runCommand(app)
            return
        }
        if app.kind == .customCommand {
            guard let id = CustomCommand.id(fromEntryID: app.id) else { return }
            runCustomCommand(id: id)
            return
        }
        if app.kind == .systemAction {
            guard let action = SystemActionCatalog.action(forEntryID: app.id) else { return }
            runSystemAction(id: action.id)
            return
        }
        if app.kind == .windowCommand {
            guard let command = WindowCommandCatalog.command(forEntryID: app.id) else { return }
            runWindowCommand(id: command.id)
            return
        }
        // Also before the palette hides: a quicklink with an unfilled argument stays in the palette
        // to ask for it, and only then opens.
        if app.kind == .quicklink {
            guard let id = Quicklink.id(fromEntryID: app.id) else { return }
            openQuicklink(id: id)
            return
        }
        let previous = windowController.previousApp
        hidePalette(restoreFocus: false)
        switch app.kind {
        case .application:
            AppLauncher.launch(app.url)
        case .systemSettings:
            guard let bundleID = app.bundleID else { return }
            AppLauncher.openSettingsPane(bundleID: bundleID)
        case .snippet:
            let snippetID = String(app.id.dropFirst("snippet:".count))
            expandSnippet(id: snippetID, targetApp: previous)
        case .command, .customCommand, .systemAction, .windowCommand, .quicklink:
            break  // handled above
        }
    }

    func resetRanking(for app: AppEntry) {
        launcherRanking.reset(itemKey: app.preferenceKey)
    }

    // MARK: - Window commands

    /// The one funnel for both palette activation and a command's global hotkey, so the feature switch
    /// can't be bypassed by either — a shortcut stays registered while the feature is off and must move
    /// nothing.
    ///
    /// The command acts on the app the user was in, so the palette hands focus back before dispatching,
    /// the same dance the paste path does. Focus is restored rather than dropped: the window being moved
    /// is the one they want to keep working in.
    func runWindowCommand(id: WindowCommand.ID) {
        guard settings.windowManagementEnabled else { return }
        let target =
            windowController.isVisible
            ? windowController.previousApp : NSWorkspace.shared.frontmostApplication
        if windowController.isVisible { hidePalette(restoreFocus: true) }
        windowMover.perform(
            id, target: target, gap: CGFloat(settings.windowGap),
            cycleOnRepeat: settings.windowCycleOnRepeat)
    }

    // MARK: - System actions

    /// The one funnel for both palette activation and an action's global hotkey, so the confirmation
    /// gate can't be bypassed by either — nor by a favorite slot or the compact bar.
    ///
    /// Some actions target the app the user was in (Hide Others, Quit All), so the palette hands back the
    /// app it displaced; a hotkey pressed with the palette closed targets whatever is frontmost.
    func runSystemAction(id: SystemAction.ID) {
        let target =
            windowController.isVisible
            ? windowController.previousApp : NSWorkspace.shared.frontmostApplication
        if windowController.isVisible { hidePalette(restoreFocus: false) }
        Task { await perform(SystemActionCatalog.action(id: id), previousApp: target) }
    }

    private func perform(_ action: SystemAction, previousApp: NSRunningApplication?) async {
        switch action.confirmation {
        case .computed:
            await quitAllApps()
            return
        case .required(let title, let message):
            guard
                await confirm(
                    title: title, message: message, symbol: action.sfSymbol,
                    confirmTitle: action.name)
            else { return }
        case .none:
            break
        }
        do {
            var feedback: SystemActionFeedback?
            if action.id == .setVolume {
                let current = try SystemActionRunner.currentVolume()
                guard let selected = await dialogs.pickVolume(current: current) else { return }
                try SystemActionRunner.setVolume(selected)
            } else {
                feedback = try await SystemActionRunner.run(action.id, previousApp: previousApp)
            }
            if Self.showsVolumeFeedback.contains(action.id) {
                let state = try SystemActionRunner.outputState()
                volumeHUD.show(level: state.level, muted: state.muted)
            } else if let feedback {
                messageHUD.show(
                    message: feedback.title, tone: feedback.isNoOp ? .neutral : .success)
            }
        } catch let failure as SystemActionFailure {
            await presentFailure(action: action, failure: failure)
        } catch {
            await presentFailure(
                action: action, failure: SystemActionFailure(error.localizedDescription))
        }
    }

    /// Actions that change the output level or mute state; macOS only draws its own HUD for real media keys, so these get Tinycast's.
    private static let showsVolumeFeedback: Set<SystemAction.ID> = [
        .setVolume, .volumeUp, .volumeDown, .toggleMute,
        .volume0, .volume25, .volume50, .volume75, .volume100
    ]

    // MARK: - Dialogs
    //
    // Routed through `AppCore` so `dialogs` stays the single owner; flows outside the palette (the backup
    // actions) reach the same dialogs instead of falling back to an `NSAlert`.

    func showNotice(title: String, message: String, symbol: String, tone: DialogTone) async {
        await dialogs.notice(title: title, message: message, symbol: symbol, tone: tone)
    }

    /// `tone` is what the dialog looks like; `confirmRole` is what the confirm button looks like. They
    /// are separate on purpose — a red-glyph security warning can still carry a plain white button.
    func confirm(
        title: String, message: String, symbol: String, confirmTitle: String,
        tone: DialogTone = .danger, confirmRole: DialogAction.Role = .destructive
    ) async -> Bool {
        await dialogs.confirm(
            title: title, message: message, symbol: symbol, tone: tone, confirmTitle: confirmTitle,
            confirmRole: confirmRole)
    }

    /// Sync entry point for the runner's own async completion handlers, which can't await.
    func presentSystemActionFailure(id: SystemAction.ID, failure: SystemActionFailure) {
        Task { await presentFailure(action: SystemActionCatalog.action(id: id), failure: failure) }
    }

    private func presentFailure(action: SystemAction, failure: SystemActionFailure) async {
        guard
            await dialogs.reportFailure(
                title: String(localized: "“\(action.name)” Failed"), message: failure.message,
                symbol: action.sfSymbol,
                recovery: failure.settings == nil ? nil : String(localized: "Open System Settings…")),
            let settings = failure.settings
        else { return }
        let pane: String
        switch settings {
        case .accessibility: pane = "Privacy_Accessibility"
        case .automation: pane = "Privacy_Automation"
        case .bluetooth: pane = "Privacy_Bluetooth"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Quicklinks

    /// The one funnel for palette activation, the ⌘K menu and a quicklink's global shortcut, so
    /// neither the feature switch nor the argument prompt can be bypassed.
    ///
    /// `forcingDefaultApp` is the menu's "Open With Default App": it bypasses the saved handler for
    /// one open without changing what the quicklink is saved as.
    func openQuicklink(id: UUID, forcingDefaultApp: Bool = false) {
        guard settings.quicklinksEnabled, let quicklink = quicklinks.quicklink(id: id) else {
            return
        }
        // With the palette closed a shortcut still reads the selection from whatever is frontmost,
        // exactly as a system action targets the window a palette launch would have.
        let target =
            windowController.isVisible
            ? windowController.previousApp : NSWorkspace.shared.frontmostApplication
        let encoding: SnippetTemplateEngine.ValueEncoding =
            QuicklinkDestination.usesURLEncoding(quicklink.link) ? .percentEncoding : .none
        var context = snippetTextInjector.captureExpansionContext(
            targetApp: target, clipboardHistory: clipboardHistoryForExpansion())
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
            quicklinkArguments.begin(
                quicklink: quicklink, context: context, encoding: encoding, arguments: arguments)
            pendingQuicklinkForcesDefaultApp = forcingDefaultApp
            // Never `restoreAnyMode`: this screen is always a fresh prompt, never a restored one.
            showPalette(mode: .quicklinkArguments)
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
        guard let request = quicklinkArguments.request else { return false }
        guard let values = quicklinkArguments.submit(value) else { return false }

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
        quicklinkArguments.cancel()
        pendingQuicklinkForcesDefaultApp = false
    }

    private func performQuicklinkOpen(
        _ quicklink: Quicklink, link: String, forcingDefaultApp: Bool
    ) {
        if windowController.isVisible { hidePalette(restoreFocus: false) }
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
            await showNotice(
                title: String(localized: "Couldn’t Open \(quicklink.name)"),
                message: failure.localizedDescription, symbol: symbol, tone: .danger)
            return
        }
        // The only failure with a usable second option, so it offers it rather than dead-ending.
        let name = applicationName(forBundleID: bundleID) ?? bundleID
        guard
            await dialogs.reportFailure(
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

    // MARK: - Quicklink library

    @discardableResult
    func addQuicklink(_ draft: Quicklink) throws -> Quicklink {
        try quicklinks.add(draft)
    }

    func updateQuicklink(_ draft: Quicklink) throws {
        try quicklinks.update(draft)
    }

    /// Confirms unless the user turned the gate off, then deletes and unwinds every reference the
    /// quicklink owned. `confirming: false` is for the Settings pane, which already asked.
    func deleteQuicklink(id: UUID, confirming: Bool = true) async {
        guard let quicklink = quicklinks.quicklink(id: id) else { return }
        if confirming, settings.quicklinkConfirmsBeforeDelete {
            guard
                await confirm(
                    title: "Delete “\(quicklink.name)”?",
                    message: "Its shortcut, favorite slot and learned ranking go with it.",
                    symbol: quicklink.iconSymbol ?? Quicklink.sfSymbol, confirmTitle: "Delete")
            else { return }
        }
        removeQuicklinkReferences(ids: [id], entryIDs: [quicklink.entryID])
        try? quicklinks.remove(id: id)
    }

    func toggleQuicklinkPinned(id: UUID) {
        try? quicklinks.togglePinned(id: id)
    }

    func setQuicklinkShowsInRootSearch(_ shows: Bool, id: UUID) {
        try? quicklinks.setShowsInRootSearch(shows, id: id)
    }

    func duplicateQuicklink(id: UUID) {
        _ = try? quicklinks.duplicate(id: id)
    }

    /// Opens Settings on the Quicklinks pane with the editor showing `quicklink` (nil for a new one).
    func editQuicklink(_ quicklink: Quicklink?) {
        pendingQuicklinkEdit = QuicklinkEditRequest(quicklink: quicklink)
        showSettings(tab: .quicklinks)
    }

    @discardableResult
    func replaceQuicklinks(_ incoming: [Quicklink]) -> Int {
        let previous = quicklinks.quicklinks
        let count = quicklinks.replace(with: incoming)
        let liveIDs = Set(quicklinks.quicklinks.map(\.id))
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
            launcherRanking.reset(itemKey: entryID)
        }
    }

    // MARK: - Quicklink import & export

    func exportQuicklinks() async {
        guard !quicklinks.quicklinks.isEmpty else {
            await showNotice(
                title: "Nothing to Export", message: "You haven’t created any quicklinks yet.",
                symbol: Quicklink.sfSymbol, tone: .neutral)
            return
        }
        guard let url = BackupActions.chooseSaveLocation(named: "Tinycast-Quicklinks") else {
            return
        }
        do {
            try QuicklinkArchive.encode(quicklinks.quicklinks).write(to: url, options: .atomic)
            messageHUD.show(
                message: String(localized: "Exported \(quicklinks.quicklinks.count) Quicklinks"))
        } catch {
            await showNotice(
                title: "Export Failed", message: error.localizedDescription,
                symbol: Quicklink.sfSymbol, tone: .danger)
        }
    }

    func importQuicklinks() async {
        guard let url = BackupActions.chooseJSONFile() else { return }
        do {
            let incoming = try QuicklinkArchive.decode(Data(contentsOf: url))
            let merge = QuicklinkArchive.merge(incoming, into: quicklinks.quicklinks)
            let added = quicklinks.append(merge.additions)
            // Everything the file offered was already here — say so rather than showing "0 imported".
            guard !added.isEmpty else {
                await showNotice(
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
            await showNotice(
                title: "Quicklinks Imported", message: summary, symbol: Quicklink.sfSymbol,
                tone: .success)
        } catch {
            await showNotice(
                title: "Import Failed", message: error.localizedDescription,
                symbol: Quicklink.sfSymbol, tone: .danger)
        }
    }

    // MARK: - Custom commands

    @discardableResult
    func addCustomCommand(_ draft: CustomCommand) throws -> CustomCommand {
        try customCommands.add(draft)
    }

    func updateCustomCommand(_ draft: CustomCommand) throws {
        try customCommands.update(draft)
    }

    func deleteCustomCommand(id: UUID) {
        guard let command = customCommands.command(id: id) else { return }
        removeCustomCommandReferences(ids: [id], entryIDs: [command.entryID])
        customCommands.remove(id: id)
    }

    @discardableResult
    func replaceCustomCommands(_ commands: [CustomCommand]) -> Int {
        let previous = Dictionary(uniqueKeysWithValues: customCommands.commands.map { ($0.id, $0) })
        let count = customCommands.replace(with: commands)
        let liveIDs = Set(customCommands.commands.map(\.id))
        let removed = Set(previous.keys).subtracting(liveIDs)
        let removedEntryIDs = Set(removed.compactMap { previous[$0]?.entryID })
        removeCustomCommandReferences(ids: removed, entryIDs: removedEntryIDs)
        return count
    }

    /// The one funnel for both palette activation and the command's global hotkey, so the confirmation gate can't be bypassed by either.
    func runCustomCommand(id: UUID) {
        // Also the feature switch: with custom commands off a still-registered global hotkey must not run anything.
        guard settings.customCommandsEnabled else { return }
        guard let command = customCommands.command(id: id) else { return }
        if windowController.isVisible { hidePalette(restoreFocus: false) }
        Task {
            if command.requiresConfirmation {
                guard
                    // Neutral, not destructive: running a shell command the user wrote themselves is
                    // not a warning, it just wants a deliberate second tap.
                    await confirm(
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
                    self.messageHUD.show(message: String(localized: "Ran \(command.name)"))
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
            launcherRanking.reset(itemKey: entryID)
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
            await dialogs.reportFailure(
                title: String(localized: "“\(command.name)” Failed"), message: message,
                symbol: CustomCommand.sfSymbol,
                recovery: suggestsShellEnvironment ? String(localized: "Open Settings…") : nil)
        else { return }
        showSettings(tab: .commands)
    }

    /// Quits the app behind an entry; a no-op (palette stays put) when it isn't running.
    func quit(_ app: AppEntry) {
        guard app.kind == .application, let bundleID = app.bundleID else { return }
        // Unlike `launch`, nothing here takes focus on its own — hand it back to where the user was, unless that's the app now on its way out.
        let quittingPreviousApp = windowController.previousApp?.bundleIdentifier == bundleID
        guard AppLauncher.quit(bundleID: bundleID) else { return }
        hidePalette(restoreFocus: !quittingPreviousApp)
    }

    // MARK: - Uninstall

    /// The palette is already up when this runs, so it swaps the sub-screen in place rather than re-showing the window.
    func beginUninstall(_ app: AppEntry) {
        guard app.kind == .application else { return }
        // What stops a name or a shared bundle-ID namespace being misattributed; see `UninstallIdentity`.
        let others = appIndex.apps.filter { $0.kind == .application && $0.id != app.id }
        uninstall.begin(
            app: app, otherAppNames: others.map(\.name),
            otherBundleIDs: others.compactMap(\.bundleID), isRunning: runningApps.isRunning(app))
        palette.prepare(mode: .uninstall)
    }

    /// The one funnel for the screen's ↵ and its Actions row, so neither can skip the confirmation.
    func performUninstall() {
        guard let app = uninstall.app, let plan = uninstall.plan, uninstall.canConfirm else { return }
        let items = uninstall.selectedCandidates
        guard !items.isEmpty else { return }
        Task {
            let running = plan.isTargetRunning || runningApps.isRunning(app)
            let size = MeasuredSize(bytes: items.reduce(0) { $0 + $1.size.bytes }).formatted
            let count = items.count == 1
                ? String(localized: "1 item") : String(localized: "\(items.count) items")
            guard
                await confirm(
                    title: String(localized: "Uninstall “\(app.name)”?"),
                    message: String(
                        localized:
                            "\(count) (\(size)) will be moved to the Trash, where you can put them back."
                    ) + (running ? " " + String(localized: "\(app.name) will quit first.") : ""),
                    symbol: "trash", confirmTitle: String(localized: "Move to Trash"))
            else { return }

            if running, let bundleID = app.bundleID { _ = AppLauncher.quit(bundleID: bundleID) }
            uninstall.setTrashing(true)
            let report = await UninstallRunner.moveToTrash(items)
            uninstall.setTrashing(false)

            if report.removedBundle {
                removeUninstalledReferences(app)
                await appIndex.refresh()
            }
            palette.prepare(mode: .launcher)
            await presentUninstallReport(report)
        }
    }

    /// Stays on the screen: losing a whole scan to copy one path is a poor trade.
    func copyUninstallPath(_ candidate: UninstallCandidate) {
        Paster.copyPlainText(candidate.path)
        messageHUD.show(message: String(localized: "Copied path"))
    }

    func showUninstallItemInFinder(_ candidate: UninstallCandidate) {
        hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(candidate.url)
    }

    func showUninstallItemInfo(_ candidate: UninstallCandidate) {
        hidePalette(restoreFocus: false)
        Task {
            guard !AppLauncher.showInfoInFinder(candidate.url) else { return }
            await showNotice(
                title: String(localized: "Couldn’t Open Get Info"),
                message: String(
                    localized:
                        "Allow Tinycast to control Finder in System Settings › Privacy & Security › Automation, then try again."
                ),
                symbol: "info.circle", tone: .danger)
        }
    }

    private func removeUninstalledReferences(_ app: AppEntry) {
        if let action = app.hotKeyAction {
            if hotKeys.recordingAction == action { hotKeys.recordingAction = nil }
            hotKeys.setBinding(nil, for: action)
        }
        favorites.remove(keys: [app.preferenceKey])
        visibility.removeItemKeys([app.preferenceKey])
        launcherRanking.reset(itemKey: app.preferenceKey)
    }

    private func presentUninstallReport(_ report: UninstallReport) async {
        guard report.hasFailures else {
            guard report.trashedCount > 0 else { return }
            let count = report.trashedCount == 1
                ? String(localized: "1 item")
                : String(localized: "\(report.trashedCount) items")
            let freed = MeasuredSize(bytes: report.freedBytes).formatted
            messageHUD.show(message: String(localized: "Moved \(count) to the Trash · \(freed)"))
            return
        }
        let listed = report.failed.prefix(5).map { "\($0.name) — \($0.reason)" }
        let remaining = report.failed.count - listed.count
        await showNotice(
            title: report.trashedCount > 0
                ? String(localized: "Some Items Weren’t Moved")
                : String(localized: "Nothing Was Moved"),
            message: listed.joined(separator: "\n")
                + (remaining > 0 ? "\n" + String(localized: "and \(remaining) more.") : ""),
            symbol: "trash", tone: .danger)
    }

    /// Quit All: the one action whose blast radius reaches outside Tinycast, so it confirms first. The target list is resolved once and both counted and terminated, so the set the user approves is the set that quits.
    private func quitAllApps() async {
        let targets = AppLauncher.quitAllTargets()
        guard !targets.isEmpty,
            await confirm(
                title: targets.count == 1
                    ? String(localized: "Quit 1 application?")
                    : String(localized: "Quit \(targets.count) applications?"),
                message: String(localized: "Applications with unsaved changes will ask you to save."),
                symbol: SystemActionCatalog.action(id: .quitAllApps).sfSymbol,
                confirmTitle: String(localized: "Quit All"))
        else { return }
        for app in targets { app.terminate() }
    }

    private func runCommand(_ entry: AppEntry) {
        switch CommandRegistry.command(for: entry) {
        case .calculatorHistory:
            showPalette(mode: .calculatorHistory)
        case .clipboardHistory:
            showPalette(mode: .clipboard)
        case .searchEmoji:
            showPalette(mode: .emoji)
        case .searchQuicklinks:
            showPalette(mode: .quicklinks)
        case .createQuicklink:
            hidePalette(restoreFocus: false)
            editQuicklink(nil)
        case .importQuicklinks:
            hidePalette(restoreFocus: false)
            Task { await importQuicklinks() }
        case .exportQuicklinks:
            hidePalette(restoreFocus: false)
            Task { await exportQuicklinks() }
        case .exportSettings:
            hidePalette(restoreFocus: false)
            Task { await BackupActions.exportSettings() }
        case .importSettings:
            hidePalette(restoreFocus: false)
            Task { await BackupActions.importSettings() }
        case .importFromRaycast:
            hidePalette(restoreFocus: false)
            showBackupSettings()
        case .settings:
            hidePalette(restoreFocus: false)
            showSettings()
        case .about:
            hidePalette(restoreFocus: false)
            showAbout()
        case .quit:
            NSApp.terminate(nil)
        case nil:
            break
        }
    }

    /// Enter on the inline calculator card: copy the answer, remember the calculation, dismiss.
    func copyCalculatorResult(_ result: CalcResult) {
        guard case .value(let display, let copyText) = result.payload else { return }
        calcHistory.record(expression: result.expression, result: display)
        hidePalette(restoreFocus: false)
        Paster.copyPlainText(copyText)
    }

    /// Enter on a Calculator History row: re-copy the stored answer (no re-record).
    func copyHistoryEntry(_ entry: CalcHistoryEntry) {
        hidePalette(restoreFocus: false)
        Paster.copyPlainText(entry.result.replacingOccurrences(of: ",", with: ""))
    }

    func copyHistoryExpression(_ entry: CalcHistoryEntry) {
        hidePalette(restoreFocus: false)
        Paster.copyPlainText(entry.expression)
    }

    func showInFinder(_ app: AppEntry) {
        hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(app.url)
    }

    func paste(_ item: ClipboardItem) {
        let previous = windowController.previousApp
        hidePalette(restoreFocus: false)
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
        hidePalette(restoreFocus: false)
        if Paster.copy(item, store: clipboardStore) {
            selectClip(item)
        }
    }

    func revealClipboardImage(_ item: ClipboardItem) {
        guard let url = clipboardStore.imageURL(for: item) else { return }
        hidePalette(restoreFocus: false)
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

    // MARK: - Emoji actions (frequency is tallied on the base glyph; the configured tone is applied at copy time)

    func pasteEmoji(_ entry: EmojiEntry) {
        frequentEmoji.record(entry.glyph)
        let previous = windowController.previousApp
        hidePalette(restoreFocus: false)
        Paster.pasteString(entry.display(tone: settings.emojiSkinTone), previousApp: previous)
    }

    func copyEmoji(_ entry: EmojiEntry) {
        frequentEmoji.record(entry.glyph)
        hidePalette(restoreFocus: false)
        Paster.copyString(entry.display(tone: settings.emojiSkinTone))
    }

    func pasteEmojiKeepingWindowOpen(_ entry: EmojiEntry) {
        frequentEmoji.record(entry.glyph)
        windowController.pasteStringKeepingWindowOpen(entry.display(tone: settings.emojiSkinTone))
    }

    // MARK: - Snippets

    /// How far back `{clipboard offset=N}` can reach; deeper offsets aren't a snippet idiom and this keeps the per-expansion sort trivial.
    private static let clipboardHistoryDepth = 20

    func revealSnippetsInFinder() {
        NSWorkspace.shared.open(snippetsStore.snippetsDirectory)
    }

    /// The pane's switch funnels through here so enabling — which is also keyword-expansion consent — confirms first. The settings sink then reconciles the store, listener and launcher presence.
    func setSnippetsEnabled(_ enabled: Bool) {
        guard enabled != settings.snippetsEnabled else { return }
        if !enabled {
            settings.snippetsEnabled = false
            return
        }

        Task {
            guard
                await confirm(
                    title: String(localized: "Enable snippets?"),
                    message: String(
                        localized:
                            "Keyword expansion requires the Accessibility permission. Keystrokes stay on this Mac."
                    ),
                    symbol: "text.quote", confirmTitle: String(localized: "Continue"),
                    tone: .neutral, confirmRole: .standard)
            else { return }
            settings.snippetsEnabled = true
            // The one prompt for this feature, raised from the gesture that asked for it.
            Permissions.ensureAccessibility()
        }
    }

    private func startSnippetKeywordListener() {
        // `beginAutomaticExpansion` is the gate: it re-checks consent, permission, Secure Event Input and the target on the injector side, so this callback doesn't duplicate it.
        snippetListener.start { [weak self] id, keyword, keywordLength, targetApp in
            guard let self,
                let generation = self.snippetTextInjector.beginAutomaticExpansion(
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
    private func clipboardHistoryForExpansion() -> [String] {
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

    private func expandSnippet(
        id: StoredSnippet.ID,
        targetApp: NSRunningApplication?,
        expectedKeyword: String? = nil,
        keywordLength: Int = 0,
        automaticGeneration: UInt? = nil
    ) {
        let records = snippetsStore.snippets
        guard let record = records.first(where: { $0.id == id }) else {
            snippetTextInjector.cancelArgumentPrompt(
                automaticGeneration: automaticGeneration,
                targetApp: targetApp)
            return
        }
        // The automatic path was gated by `beginAutomaticExpansion` in the same turn, and `deliver` gates both again. Only the interactive path needs a check here: it must fail before the argument prompt, not after it.
        if automaticGeneration == nil {
            guard snippetTextInjector.prepareInteractiveExpansion(targetApp: targetApp) else { return }
        }
        let confirmation = record.snippet.showsConfirmation
            ? String(localized: "Inserted \(record.snippet.name)") : nil
        let context = snippetTextInjector.captureExpansionContext(
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
            snippetTextInjector.cancelArgumentPrompt(
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
        snippetTextInjector.deliver(
            result,
            targetApp: targetApp,
            expectedKeyword: expectedKeyword,
            keywordLength: keywordLength,
            automaticGeneration: automaticGeneration,
            onDelivered: { [weak self] in
                guard let self, let confirmation else { return }
                self.messageHUD.show(message: confirmation)
            })
    }
}
