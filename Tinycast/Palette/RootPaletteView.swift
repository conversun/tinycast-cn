import SwiftUI

struct RootPaletteView: View {
    @Environment(AppCore.self) private var core
    @Environment(PaletteState.self) private var vm
    @Environment(AppIndex.self) private var appIndex
    @Environment(ClipboardStore.self) private var store
    @Environment(FavoritesStore.self) private var favorites
    @Environment(VisibilityStore.self) private var visibility
    @Environment(CalculatorHistoryStore.self) private var calcHistory
    /// Observed so the inline card re-evaluates the moment a fresh FX snapshot lands, or the user
    /// turns currency conversion on or off.
    @Environment(CurrencyRateStore.self) private var currencyRates
    @Environment(EmojiIndex.self) private var emojiIndex
    @Environment(FrequentEmojiStore.self) private var frequentEmoji
    @Environment(UninstallSession.self) private var uninstall
    @Environment(QuicklinkStore.self) private var quicklinks
    @Environment(QuicklinkArgumentSession.self) private var quicklinkArguments
    @Environment(AppSettings.self) private var settings
    @FocusState private var searchFocused: Bool
    @State private var showActions = false
    @State private var showAppMenu = false
    /// The selection's running state, sampled once by `openActions` — an app launching or quitting elsewhere must not add or drop the Quit row while the menu is up. `RunningAppsMonitor` is deliberately not observed here: only `LauncherList` needs live running state, and observing it would re-render the whole palette on every workspace launch/terminate.
    @State private var selectionIsRunning = false
    /// Highlighted row of whichever popover menu is open; reset to the first row on open, moved by ↑/↓ and hover, activated by ↵/click.
    @State private var menuSelection = 0
    /// The pending scroll request for whichever list or grid is mounted (modes are exclusive, so one piece of state serves all of them). Set only by keyboard nav and resets; mouse selection targets a visible row, so it leaves this and the scroll position put.
    @State private var scroll = ScrollIntent(kind: .top)

    /// Slim compact bar vs. full window — the single source of truth lives on `AppCore` so the window controller and this view can never disagree.
    private var isCollapsed: Bool { core.paletteCoordinator.paletteIsCollapsed }

    /// The current mode's screen: its rows are the visible order the flat selection indexes.
    private var screen: any PaletteScreen {
        switch vm.mode {
        case .launcher:
            return LauncherScreen(
                appIndex: appIndex, favorites: favorites, visibility: visibility,
                currencyRates: currencyRates, core: core, vm: vm, running: selectionIsRunning,
                openActions: openActions)
        case .uninstall:
            return UninstallScreen(
                session: uninstall, core: core, vm: vm, openActions: openActions)
        case .quicklinkArguments:
            return QuicklinkArgumentsScreen(
                session: quicklinkArguments, core: core, vm: vm,
                scrollToTop: { scroll = ScrollIntent(kind: .top) })
        case .quicklinks:
            return QuicklinkListScreen(
                store: quicklinks, core: core, vm: vm, openActions: openActions)
        case .emoji:
            return EmojiScreen(
                index: emojiIndex, frequent: frequentEmoji, core: core, vm: vm,
                tone: settings.emojiSkinTone, openActions: openActions)
        case .clipboard:
            return ClipboardScreen(
                store: store, core: core, vm: vm, openActions: openActions,
                scrollToFollow: { scroll = ScrollIntent(kind: .follow) })
        case .calculatorHistory:
            return CalculatorHistoryScreen(
                history: calcHistory, currencyRates: currencyRates, core: core, vm: vm,
                openActions: openActions)
        }
    }

    private var resultCount: Int { screen.rows.count }
    /// Selection clamped into the current results — the single source of truth for highlight, preview and activation so the list and preview can never disagree.
    private var selection: Int { resultCount == 0 ? 0 : min(max(vm.selection, 0), resultCount - 1) }

    private var menuOpen: Bool { showActions || showAppMenu }

    // MARK: - Popover menu content

    /// The bottom-right Actions menu content for the current mode's selection, or nil when the selection has no actions.
    private var actionsContent: PopoverMenuContent? { screen.actions(at: selection) }

    /// The bottom-left app menu content (About / Settings).
    private var appMenuContent: PopoverMenuContent {
        PopoverMenuContent(items: [
            PopoverMenuItem(title: "About Tinycast", systemImage: "info.circle") {
                core.paletteCoordinator.showAbout()
            },
            PopoverMenuItem(title: "Settings", systemImage: "gearshape", shortcut: "⌘,") {
                core.paletteCoordinator.showSettings()
            }
        ])
    }

    /// Whichever menu is open (Actions takes precedence; the two are kept mutually exclusive) — the source for keyboard navigation and activation.
    private var menuContent: PopoverMenuContent? {
        if showActions { return actionsContent }
        if showAppMenu { return appMenuContent }
        return nil
    }

    var body: some View {
        // Resolve the screen once per render: its rows are the visible order, so the flat selection index can't drift from what's drawn.
        let screen = screen
        let count = screen.rows.count
        let sel = count == 0 ? 0 : min(max(vm.selection, 0), count - 1)
        // The argument form has no rows to count when its argument takes free text, but ↵ still
        // does something — and the pill is the only thing that says what.
        let showActionGroup =
            (count > 0 || vm.mode == .quicklinkArguments) && screen.hasPrimaryAction(at: sel)

        // The `header` (and its single search field) is always attached in the same position via safeAreaInset so its focus survives the compact↔expanded swap — only the results below it toggle. Collapsed shows the bar alone; expanded floats header + action bar over the list with edge-dissolve (see docs/ui.md).
        return Group {
            if isCollapsed {
                Color.clear
            } else {
                screen.body(selection: sel, scroll: scroll)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isCollapsed {
                bottomBar(
                    pillLabel: screen.primaryActionTitle, showActionGroup: showActionGroup)
            }
        }
        // Menus are in-window overlays anchored to a bottom corner, so they stay clipped inside the panel — never a system popover spilling outside the window.
        .overlay {
            if showAppMenu || showActions {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeMenus)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showAppMenu {
                let content = appMenuContent
                PopoverMenu(
                    header: content.header, items: content.items, selection: $menuSelection,
                    onActivate: activateMenuItem
                )
                .padding(Self.menuInset)
                .transition(Self.menuTransition(.bottomLeading))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showActions, let content = actionsContent {
                PopoverMenu(
                    header: content.header, items: content.items, selection: $menuSelection,
                    onActivate: activateMenuItem
                )
                .padding(Self.menuInset)
                .transition(Self.menuTransition(.bottomTrailing))
            }
        }
        // The window's own frame (driven by `PaletteWindowController`) is the size source of truth; filling it keeps the glass background and corner clip matched to the current compact/expanded window height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(Theme.Colors.panelDimming))
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        // Every show bumps focusToken — refocus search and drop any menu left open from last time (e.g. dismissed by clicking away with a context menu up).
        .onChange(of: vm.focusToken) {
            searchFocused = true
            showActions = false
            showAppMenu = false
        }
        .onChange(of: vm.query) {
            vm.selection = 0
            scroll = ScrollIntent(kind: .top)
        }
        .onChange(of: vm.mode) {
            vm.selection = 0
            showActions = false
            scroll = ScrollIntent(kind: .top)
            // Every way out of the Uninstall screen: back chevron, bare backspace, a fresh summon.
            if vm.mode != .uninstall { uninstall.cancel() }
            // Same for a half-filled argument form: leaving the screen abandons the pending open.
            if vm.mode != .quicklinkArguments { core.quicklinkCoordinator.cancelQuicklinkArguments() }
        }
        // Pop-to-root: `prepare` clears query/selection, but if both were already at their defaults the handlers above never fire — this intent guarantees the scroll itself snaps back to the origin.
        .onChange(of: vm.resetToken) {
            scroll = ScrollIntent(kind: .top)
        }
        // Opening either menu highlights its first row and closes the other, so exactly one menu is ever open and always has a highlight.
        .onChange(of: showActions) {
            if showActions {
                showAppMenu = false
                menuSelection = 0
            }
            vm.menuOpen = menuOpen
        }
        .onChange(of: showAppMenu) {
            if showAppMenu {
                showActions = false
                menuSelection = 0
            }
            vm.menuOpen = menuOpen
        }
        .onAppear { searchFocused = true }
        // Typing/clearing/overflow/settings all flip `paletteIsCollapsed`; resize the window to match.
        .onChange(of: core.paletteCoordinator.paletteIsCollapsed) {
            core.paletteCoordinator.syncPaletteSize()
        }
        // ⌘1–⌘5 launch the compact bar's favorite slots (or expand, for the "…" overflow slot).
        .onKeyPress(keys: ["1", "2", "3", "4", "5"], phases: .down) { press in
            guard isCollapsed, settings.showFavoritesInCompactMode,
                press.modifiers.contains(.command),
                let digit = press.key.character.wholeNumberValue,
                let launcher = screen as? LauncherScreen
            else { return .ignored }
            let slots = launcher.compactFavoriteSlots
            let index = digit - 1
            guard slots.indices.contains(index) else { return .ignored }
            switch slots[index] {
            case .app(let app): core.launcherCoordinator.launch(app)
            case .more: core.paletteCoordinator.expandFromCompact()
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if isCollapsed {
                // The compact bar has no visible selection; Down reveals the list at its first row
                // while the shared search field stays mounted and focused.
                vm.selection = 0
                core.paletteCoordinator.expandFromCompact()
                return .handled
            }
            if menuOpen {
                moveMenu(1)
                return .handled
            }
            moveVertically(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            if isCollapsed { return .ignored }
            if menuOpen {
                moveMenu(-1)
                return .handled
            }
            moveVertically(-1)
            return .handled
        }
        // Horizontal arrows step the emoji grid; everywhere else they stay with the field editor's caret. An open menu swallows them so the list behind never moves.
        .onKeyPress(.leftArrow) {
            if menuOpen { return .handled }
            return moveHorizontally(-1) ? .handled : .ignored
        }
        .onKeyPress(.rightArrow) {
            if menuOpen { return .handled }
            return moveHorizontally(1) ? .handled : .ignored
        }
        // With a menu open, plain ↵ activates its highlighted row. A modified ↵ always runs the selection's own action regardless of menu state: ⌘↵ the advertised secondary action, ⌥↵ paste-in-place; plain ↵ (no menu) falls through to the field's onSubmit.
        .onKeyPress(keys: [.return], phases: .down) { press in
            let command = press.modifiers.contains(.command)
            let option = press.modifiers.contains(.option)
            if menuOpen, !command, !option {
                activateMenuItem(menuSelection)
                return .handled
            }
            guard command || option else { return .ignored }
            if command { return screen.secondary(at: selection) ? .handled : .ignored }
            guard let emoji = screen as? EmojiScreen else { return .ignored }
            return emoji.pasteKeepingWindowOpen(at: selection) ? .handled : .ignored
        }
        .onKeyPress(.escape) {
            if showActions || showAppMenu {
                closeMenus()
                return .handled
            }
            core.paletteCoordinator.hidePalette()
            return .handled
        }
        .onKeyPress(.tab) {
            if menuOpen { return .handled }
            toggleMode()
            return .handled
        }
        // ⌘K toggles the actions panel for the current selection.
        .onKeyPress(keys: ["k"], phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            // The Actions menu has no anchor in the compact bar (no bottom bar); swallow ⌘K there.
            guard !isCollapsed else { return .handled }
            guard resultCount > 0 else { return .handled }
            // An error calc card is the selection but has no actions — don't open an empty panel.
            guard screen.hasPrimaryAction(at: selection) else { return .handled }
            toggleActions()
            return .handled
        }
        // Bare backspace (back out of a sub-screen when the search is empty) is intercepted by PalettePanel.sendEvent — the field editor consumes it before onKeyPress could fire.
        .onKeyPress(keys: [.delete, .deleteForward], phases: .down) { press in
            if menuOpen { return .handled }
            guard press.modifiers.contains(.command) else { return .ignored }
            if let quicklinks = screen as? QuicklinkListScreen {
                return quicklinks.delete(at: selection) ? .handled : .ignored
            }
            if let clipboard = screen as? ClipboardScreen {
                clipboard.delete(at: selection)
                return .handled
            }
            if let history = screen as? CalculatorHistoryScreen {
                history.delete(at: selection)
                return .handled
            }
            return .ignored
        }
        // ⌘P pins/unpins the selected clip — mirrors the Actions menu row, and works while that menu is open like the other advertised chords.
        .onKeyPress(keys: ["p"], phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            if let clipboard = screen as? ClipboardScreen {
                return clipboard.pin(at: selection) ? .handled : .ignored
            }
            if let quicklinks = screen as? QuicklinkListScreen {
                return quicklinks.pin(at: selection) ? .handled : .ignored
            }
            return .ignored
        }
        // Both cases are listed because Shift uppercases the reported key. The compact bar is excluded like ⌘K — it shows no selection to aim a destructive action at.
        .onKeyPress(keys: ["q", "Q"], phases: .down) { press in
            guard press.modifiers.contains(.control), press.modifiers.contains(.shift),
                !isCollapsed, let launcher = screen as? LauncherScreen
            else { return .ignored }
            return launcher.quit(at: selection) ? .handled : .ignored
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            // Clipboard and Calculator History are sub-screens of the root search, so their header icon is a back chevron instead of a mode glyph.
            if vm.mode != .launcher {
                Button(action: exitToLauncher) {
                    Image(systemName: "chevron.left")
                        .font(Theme.Typography.headerIcon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: Theme.Size.headerIconSlot)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: vm.mode.systemImage)
                    .font(Theme.Typography.headerIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: Theme.Size.headerIconSlot)
            }
            searchField
            // Compact bar pins favorites to the right of the field; expanded shows them as list rows instead.
            if isCollapsed, settings.showFavoritesInCompactMode,
                let launcher = screen as? LauncherScreen {
                let slots = launcher.compactFavoriteSlots
                if !slots.isEmpty {
                    CompactFavoritesRow(
                        slots: slots,
                        onLaunch: { core.launcherCoordinator.launch($0) },
                        onOverflow: { core.paletteCoordinator.expandFromCompact() }
                    )
                }
            }
        }
        // Align the search icon with the list rows and section headers below (list inset + row inset).
        .padding(.horizontal, Theme.Spacing.md * 2)
        // Fixed row height + top padding, identical in both states, so typing (which flips compact→expanded) can't move the search bar. Compact centers the row in symmetric slack; expanded floats the same row over the list.
        .frame(height: Theme.Size.headerHeight)
        .padding(.top, Theme.Size.headerPadding)
        .frame(maxWidth: .infinity)
    }

    /// In the argument form the field *is* the current argument's input, so it names that argument
    /// rather than the screen.
    private var searchPrompt: String {
        vm.mode == .quicklinkArguments ? quicklinkArguments.prompt : vm.mode.placeholder
    }

    /// The one search field, kept in a single tree position (the `header`) so its focus survives the compact↔expanded swap.
    ///
    /// The placeholder is drawn here rather than passed as the field's `prompt`. AppKit gives an
    /// `NSTextField` a field editor one point taller than the field itself, and a prompt is rendered
    /// by whichever of the two currently owns the text — so the *same* placeholder glyphs sit a point
    /// higher once the field takes the panel's shared field editor. That editor is created lazily and
    /// then cached on the window, which is why the step was only ever visible on the first summon
    /// after launch. Drawing it here pins it to SwiftUI's layout, where nothing can move it —
    /// measured identical in both focus states, against a one-point step for the real prompt.
    ///
    /// A background rather than an overlay, so the caret still draws over it.
    private var searchField: some View {
        @Bindable var vm = vm
        return TextField("", text: $vm.query)
            .textFieldStyle(.plain)
            .font(Theme.Typography.searchField)
            .tint(.white)
            .focused($searchFocused)
            .onSubmit(activateSelection)
            .background(alignment: .leading) {
                if vm.query.isEmpty {
                    Text(searchPrompt)
                        .font(Theme.Typography.searchField)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                        // Never a click target: tapping the placeholder must still land the caret.
                        .allowsHitTesting(false)
                }
            }
            // The prompt used to carry this; without it the field would be unlabelled.
            .accessibilityLabel(Text(searchPrompt))
    }

    /// The Uninstall screen's primary action is destructive, so its pill isn't white.
    private var pillTint: Color {
        vm.mode == .uninstall ? Theme.Colors.destructive : .primary
    }

    private func bottomBar(pillLabel: String, showActionGroup: Bool) -> some View {
        // No bar — just floating glass controls over the list; the edge dissolve ghosts rows passing beneath, so the buttons read clearly without a hard-edged strip.
        HStack(spacing: 0) {
            appMenuButton
            Spacer()
            if showActionGroup { actionGroup(pillLabel: pillLabel) }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: Theme.Size.bottomBarHeight)
        .frame(maxWidth: .infinity)
    }

    private var appMenuButton: some View {
        MenuCircleButton {
            withAnimation(Self.menuAnimation) { showAppMenu.toggle() }
        }
    }

    /// The footer control group: primary action and the Actions toggle sharing one glass capsule.
    private func actionGroup(pillLabel: String) -> some View {
        HStack(spacing: 2) {
            BarButton(action: activateSelection) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(pillLabel.localizedUI)
                        .font(Theme.Typography.bar)
                        .foregroundStyle(pillTint)
                    KeyCapChip(text: "↵", style: .outline)
                }
            }
            BarButton(action: toggleActions) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Actions")
                        .font(Theme.Typography.bar)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    HStack(spacing: Theme.Spacing.xxs) {
                        KeyCapChip(text: "⌘", style: .outline)
                        KeyCapChip(text: "K", style: .outline)
                    }
                }
            }
        }
        .padding(Theme.Spacing.xs)
        .frosted(in: Capsule())
    }

    /// The single path that opens the Actions menu: samples the state its rows depend on, then shows it. Callers set `vm.selection` first, so the sample matches the row the menu is for.
    private func openActions() {
        selectionIsRunning = (screen as? LauncherScreen)?.isRunning(at: selection) ?? false
        withAnimation(Self.menuAnimation) { showActions = true }
    }

    private func toggleActions() {
        if showActions {
            withAnimation(Self.menuAnimation) { showActions = false }
        } else {
            openActions()
        }
    }

    private func closeMenus() {
        withAnimation(Self.menuAnimation) {
            showActions = false
            showAppMenu = false
        }
    }

    /// Inset of the menu panels from the window's bottom corners, kept just inside the rounded corner so the menu's own corner isn't clipped.
    private static let menuInset: CGFloat = 8
    private static let menuAnimation: Animation = .easeOut(duration: 0.14)

    private static func menuTransition(_ anchor: UnitPoint) -> AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96, anchor: anchor))
    }

    // MARK: - Actions

    private func move(_ delta: Int) {
        guard resultCount > 0 else { return }
        vm.selection = min(max(selection + delta, 0), resultCount - 1)
        scroll = ScrollIntent(kind: .follow)
    }

    /// ↑/↓: the screen's own move (the emoji grid's, so far), else a linear step through the rows.
    private func moveVertically(_ delta: Int) {
        guard let next = screen.move(delta, axis: .vertical, from: selection) else {
            move(delta)
            return
        }
        vm.selection = next
        scroll = ScrollIntent(kind: .follow)
    }

    /// ←/→: consumed only by a screen that navigates horizontally; otherwise the caret keeps them.
    private func moveHorizontally(_ delta: Int) -> Bool {
        guard let next = screen.move(delta, axis: .horizontal, from: selection) else {
            return false
        }
        vm.selection = next
        scroll = ScrollIntent(kind: .follow)
        return true
    }

    /// Move the open menu's highlight, clamped at the ends (no wrap — consistent with `move`).
    private func moveMenu(_ delta: Int) {
        guard let count = menuContent?.items.count, count > 0 else { return }
        menuSelection = min(max(menuSelection + delta, 0), count - 1)
    }

    /// The single activation path for a menu row, shared by a click and Return: run the row's action, then close.
    private func activateMenuItem(_ index: Int) {
        guard let items = menuContent?.items, items.indices.contains(index) else { return }
        items[index].action()
        closeMenus()
    }

    /// Tab flips launcher↔clipboard; Calculator History (entered via its command) exits back to the launcher rather than joining the cycle.
    private func toggleMode() {
        vm.mode = vm.mode == .launcher ? .clipboard : .launcher
    }

    /// Back out to a fresh root search — `prepare` is the same reset used when the palette is shown (clears query/selection, bumps focusToken to refocus the field).
    private func exitToLauncher() {
        vm.prepare(mode: .launcher)
    }

    private func activateSelection() {
        // Nothing is visibly selected in the collapsed compact bar; launch only via ⌘1–⌘5 or by typing.
        guard !isCollapsed else { return }
        screen.activate(at: selection)
    }
}

/// The footer's glass menu circle; hover lives here so a mouse sweep never re-renders the palette body.
private struct MenuCircleButton: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Capsule().frame(width: 14, height: 1.5)
                Capsule().frame(width: 8, height: 1.5)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(width: Theme.Size.menuButton, height: Theme.Size.menuButton)
            .background(Circle().fill(hovered ? Theme.Colors.rowHover : Color.clear))
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .frosted(in: Circle())
    }
}

/// Footer button: bare label at rest, a faint capsule fill on hover.
private struct BarButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 28)
                .contentShape(Capsule())
                .background(Capsule().fill(hovered ? Theme.Colors.rowHover : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct ArmedHover: ViewModifier {
    @Environment(PaletteState.self) private var palette
    @Binding var hovered: Bool

    func body(content: Content) -> some View {
        content.onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active: hovered = palette.hoverHighlightArmed
            case .ended: hovered = false
            }
        }
    }
}

extension View {
    /// Faint mouse-hover highlight for a palette row, lit only while the pointer is physically moving (`hoverHighlightArmed`) so it never fires on open or when rows slide under a still pointer during keyboard nav. Independent of the keyboard selection, so both coexist.
    func armedHover(_ hovered: Binding<Bool>) -> some View {
        modifier(ArmedHover(hovered: hovered))
    }
}

struct EmptyResults: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.largeTitle)
                .symbolRenderingMode(.hierarchical).foregroundStyle(.tertiary)
            Text(text.localizedUI).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A slot in the compact bar's favorites strip: a launchable app, or the "…" overflow that expands the window.
enum CompactFavoriteSlot {
    case app(AppEntry)
    case more

    // Stable identity so a slot keeps its icon tied to its app, not its position, when favorites reorder.
    var id: String {
        switch self {
        case .app(let app): return app.id
        case .more: return "__tinycast.more__"
        }
    }
}

/// The compact bar's favorites strip — up to 5 icon buttons, ⌘1–⌘5 mirrored in each tooltip.
private struct CompactFavoritesRow: View {
    let slots: [CompactFavoriteSlot]
    let onLaunch: (AppEntry) -> Void
    let onOverflow: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                switch slot {
                case .app(let app):
                    CompactFavoriteButton(help: "\(app.name)  ⌘\(index + 1)") {
                        onLaunch(app)
                    } content: {
                        AppIconView(app: app)
                            .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                    }
                case .more:
                    CompactFavoriteButton(help: "Show all  ⌘\(index + 1)", action: onOverflow) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Theme.Colors.controlSurface)
                                    .padding(Theme.Spacing.xxs)
                            )
                    }
                }
            }
        }
    }
}

/// A single compact favorite icon: bare icon, native tooltip, click action — no hover chrome, kept tight so the strip reads as one cluster.
private struct CompactFavoriteButton<Content: View>: View {
    let help: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
