import Foundation

/// Owns all global shortcut bindings: persistence, registration with the two engines (`HotKeyCenter` for combos, `DoubleTapMonitor` for double-tapped modifiers), conflict lookup, and dispatch.
@MainActor
@Observable
final class HotKeyManager {
    var onTogglePalette: (() -> Void)?
    var onToggleClipboard: (() -> Void)?
    var onToggleEmoji: (() -> Void)?
    var onRunCustomCommand: ((UUID) -> Void)?
    var onRunSystemAction: ((SystemAction.ID) -> Void)?
    var onRunWindowCommand: ((WindowCommand.ID) -> Void)?
    var onOpenQuicklink: ((UUID) -> Void)?
    /// Names what only the stores know; the fixed catalogs resolve here. Set in `AppCore.start()`.
    var displayName: ((HotKeyAction) -> String?)?

    /// The recorder currently capturing keystrokes, or `nil`; keeping this as plain app state makes recorders glitch-free, and any active recorder pauses both engines so the shortcut being typed can't fire the binding it's replacing. Setting it also starts/stops `capture`.
    var recordingAction: HotKeyAction? {
        didSet {
            guard recordingAction != oldValue else { return }
            let recording = recordingAction != nil
            center.isPaused = recording
            doubleTapMonitor.isPaused = recording
            if let recordingAction {
                capture.start(action: recordingAction, hotKeys: self)
            } else {
                capture.stop()
            }
        }
    }

    let doubleTapMonitor = DoubleTapMonitor()
    /// Live state of the open recorder, read by its callout.
    let capture = ShortcutCaptureSession()

    private let center = HotKeyCenter()
    private var doubleTaps: [DoubleTapModifier: HotKeyAction] = [:]
    /// Every binding, loaded once in `start()` and written through on change.
    private var bindings: [HotKeyAction: HotKeyBinding] = [:]
    @ObservationIgnored private var candidateActionsCache: [HotKeyAction]?
    // Reused: the startup load decodes once per candidate action.
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let boundKey = "boundAppBundleIDs"
    private let boundPaneKey = "boundPaneBundleIDs"
    private let boundCustomCommandKey = "boundCustomCommandIDs"
    private let boundQuicklinkKey = "boundQuicklinkIDs"

    func start(customCommandIDs: Set<UUID>, quicklinkIDs: Set<UUID>) {
        prune(key: boundCustomCommandKey, live: customCommandIDs) { .customCommand(id: $0) }
        prune(key: boundQuicklinkKey, live: quicklinkIDs) { .quicklink(id: $0) }
        // After the prunes, so a dropped record can't survive in memory this session.
        for action in candidateActions { bindings[action] = storedBinding(for: action) }

        // `register` no-ops on an unbound item, so the fixed catalogs need no index of their own.
        for action in candidateActions { register(action) }

        doubleTapMonitor.onDoubleTap = { [weak self] modifier in
            guard let self, let action = doubleTaps[modifier] else { return }
            perform(action)
        }
        doubleTapMonitor.start()
        syncDoubleTaps()
    }

    /// Bundle IDs that currently have a per-app hotkey — lets `start()` know which records to load and lets launcher rows show keycaps.
    var boundBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundKey) ?? []
    }

    /// Settings-pane bundle IDs with a hotkey — same role as `boundBundleIDs`, own namespace.
    var boundPaneBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundPaneKey) ?? []
    }

    /// Custom-command UUIDs with a binding, indexed separately so startup can re-register them.
    var boundCustomCommandIDs: [UUID] { boundIDs(key: boundCustomCommandKey) }

    /// Quicklink UUIDs with a binding — the same index, its own namespace.
    var boundQuicklinkIDs: [UUID] { boundIDs(key: boundQuicklinkKey) }

    func binding(for action: HotKeyAction) -> HotKeyBinding? { bindings[action] }

    private func storedBinding(for action: HotKeyAction) -> HotKeyBinding? {
        // The stored value is a JSON *string* (a legacy package format); anything else reads as unbound.
        guard
            let json = UserDefaults.standard.string(forKey: action.defaultsKey),
            let data = json.data(using: .utf8)
        else { return nil }
        return try? decoder.decode(HotKeyBinding.self, from: data)
    }

    /// Persists or clears the binding and swaps live registration; the `bindings` mutation notifies.
    func setBinding(_ binding: HotKeyBinding?, for action: HotKeyAction) {
        let previous = bindings[action]
        if let binding,
            let data = try? encoder.encode(binding),
            let json = String(data: data, encoding: .utf8) {
            bindings[action] = binding
            UserDefaults.standard.set(json, forKey: action.defaultsKey)
        } else {
            bindings[action] = nil
            UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        }
        // Unregister unconditionally: the previous binding may have been a combo even when the new one isn't.
        center.unregister(id: action.defaultsKey)
        register(action)

        switch action {
        case .app(let bundleID):
            var set = Set(boundBundleIDs)
            if binding == nil { set.remove(bundleID) } else { set.insert(bundleID) }
            UserDefaults.standard.set(Array(set), forKey: boundKey)
        case .settingsPane(let bundleID):
            var set = Set(boundPaneBundleIDs)
            if binding == nil { set.remove(bundleID) } else { set.insert(bundleID) }
            UserDefaults.standard.set(Array(set), forKey: boundPaneKey)
        case .customCommand(let id):
            index(id, bound: binding != nil, key: boundCustomCommandKey)
        case .quicklink(let id):
            index(id, bound: binding != nil, key: boundQuicklinkKey)
        case .togglePalette, .toggleClipboard, .toggleEmoji, .systemAction, .windowCommand:
            break
        }
        candidateActionsCache = nil
        // A rebuild walks every candidate; only a double-tap entering or leaving changes the map.
        if previous?.doubleTapModifier != nil || binding?.doubleTapModifier != nil {
            syncDoubleTaps()
        }
    }

    /// The display name of whatever else `binding` is bound to (or `nil` if free), driving the recorder's "Used by …" message. Comparing whole bindings means double-taps get conflict detection on the same terms as combos — two actions can never claim the same modifier.
    func conflictOwner(of binding: HotKeyBinding, excluding action: HotKeyAction) -> String? {
        for candidate in candidateActions
        where candidate != action && self.binding(for: candidate) == binding {
            return displayName(of: candidate)
        }
        return nil
    }

    /// Every action that could currently hold a binding — the search space for conflicts and for rebuilding the double-tap map.
    private var candidateActions: [HotKeyAction] {
        if let candidateActionsCache { return candidateActionsCache }
        var actions: [HotKeyAction] = [.togglePalette, .toggleClipboard, .toggleEmoji]
        actions += boundBundleIDs.map { .app(bundleID: $0) }
        actions += boundPaneBundleIDs.map { .settingsPane(bundleID: $0) }
        actions += boundCustomCommandIDs.map { .customCommand(id: $0) }
        actions += boundQuicklinkIDs.map { .quicklink(id: $0) }
        actions += SystemAction.ID.allCases.map { .systemAction(id: $0) }
        actions += WindowCommand.ID.allCases.map { .windowCommand(id: $0) }
        candidateActionsCache = actions
        return actions
    }

    private func displayName(of action: HotKeyAction) -> String {
        switch action {
        case .togglePalette:
            return "App Launcher"
        case .toggleClipboard:
            return "Clipboard History"
        case .toggleEmoji:
            return "Emoji & Symbols"
        case .app(let bundleID), .settingsPane(let bundleID):
            return displayName?(action) ?? bundleID
        case .customCommand:
            return displayName?(action) ?? "Custom Command"
        case .systemAction(let id):
            return SystemActionCatalog.action(id: id).name
        case .windowCommand(let id):
            return WindowCommandCatalog.command(id: id)?.name ?? "Window Command"
        case .quicklink:
            return displayName?(action) ?? "Quicklink"
        }
    }

    /// Hands a combo to Carbon; a double-tap needs no per-action registration — `syncDoubleTaps` rebuilds the whole modifier map instead.
    private func register(_ action: HotKeyAction) {
        guard let shortcut = binding(for: action)?.shortcut else { return }
        center.register(id: action.defaultsKey, shortcut: shortcut) { [weak self] in
            self?.perform(action)
        }
    }

    /// Rebuilt wholesale rather than patched, so the map can't drift from what's on disk. Conflict detection keeps it one action per modifier.
    private func syncDoubleTaps() {
        doubleTaps = [:]
        for action in candidateActions {
            guard let modifier = binding(for: action)?.doubleTapModifier else { continue }
            doubleTaps[modifier] = action
        }
        doubleTapMonitor.update(bound: Set(doubleTaps.keys))
    }

    private func perform(_ action: HotKeyAction) {
        switch action {
        case .togglePalette: onTogglePalette?()
        case .toggleClipboard: onToggleClipboard?()
        case .toggleEmoji: onToggleEmoji?()
        case .app(let bundleID): AppLauncher.toggle(bundleID: bundleID)
        case .settingsPane(let bundleID): AppLauncher.openSettingsPane(bundleID: bundleID)
        case .customCommand(let id): onRunCustomCommand?(id)
        case .systemAction(let id): onRunSystemAction?(id)
        case .windowCommand(let id): onRunWindowCommand?(id)
        case .quicklink(let id): onOpenQuicklink?(id)
        }
    }

    // MARK: - UUID-keyed indexes
    //
    // Custom commands and quicklinks are bound per item rather than per fixed catalog entry, so each
    // needs an index of the UUIDs that currently hold a binding for `start()` to re-register.

    private func boundIDs(key: String) -> [UUID] {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:))
    }

    private func index(_ id: UUID, bound: Bool, key: String) {
        var set = Set(boundIDs(key: key))
        if bound { set.insert(id) } else { set.remove(id) }
        persist(set, key: key)
    }

    /// Drops bindings whose item no longer exists — a record deleted while Tinycast wasn't running.
    private func prune(key: String, live: Set<UUID>, action: (UUID) -> HotKeyAction) {
        let stored = Set(boundIDs(key: key))
        for id in stored.subtracting(live) {
            UserDefaults.standard.removeObject(forKey: action(id).defaultsKey)
        }
        persist(stored.intersection(live), key: key)
    }

    private func persist(_ ids: Set<UUID>, key: String) {
        UserDefaults.standard.set(ids.map { $0.uuidString.lowercased() }.sorted(), forKey: key)
    }
}
