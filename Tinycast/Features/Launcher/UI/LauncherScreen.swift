import SwiftUI

/// The root search: favorites first, then one section per entry kind, led by the calculator card.
struct LauncherScreen: PaletteScreen {
    let appIndex: AppIndex
    let favorites: FavoritesStore
    let visibility: VisibilityStore
    let currencyRates: CurrencyRateStore
    let core: AppCore
    let vm: PaletteState
    /// Sampled by `openActions`, so the Quit row can't appear or vanish while the menu is up.
    let running: Bool
    let openActions: () -> Void

    /// The card is a row like any other, so the flat selection indexes `rows` with no offset.
    enum Row: Equatable, Identifiable {
        case calc(CalcResult)
        case entry(AppEntry)

        var id: String {
            switch self {
            case .calc: return "calc-card"
            case .entry(let app): return app.id
            }
        }
    }

    /// Ordered launcher results (the single source of truth for list, selection and activation): empty query pins favorites to the top, otherwise plain ranked matches.
    private var results: [AppEntry] {
        appIndex.orderedResults(query: vm.query, visibility: visibility, favorites: favorites)
    }
    private var calc: CalcResult? { CalcMemo.evaluate(vm.query, currency: currencyRates.source) }

    var rows: [Row] {
        let entries = results.map(Row.entry)
        guard let calc else { return entries }
        return [.calc(calc)] + entries
    }

    /// The pill carries no selection, so the screen applies the clamp the palette applies.
    private var clampedSelection: Int {
        let count = rows.count
        return count == 0 ? 0 : min(max(vm.selection, 0), count - 1)
    }

    var primaryActionTitle: String {
        switch row(at: clampedSelection) {
        case .calc: return "Copy Answer"
        case .entry(let app): return app.kind.descriptor.openVerb
        case nil: return "Open Application"
        }
    }

    private func row(at selection: Int) -> Row? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    private func entry(at selection: Int) -> AppEntry? {
        guard case .entry(let app) = row(at: selection) else { return nil }
        return app
    }

    private func isCardSelected(_ selection: Int) -> Bool {
        if case .calc = row(at: selection) { return true }
        return false
    }

    /// An error card is selectable but has no action: it must drive neither the pill nor ⌘K.
    func hasPrimaryAction(at selection: Int) -> Bool {
        guard case .calc(let result) = row(at: selection) else { return true }
        return result.isActionable
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        switch row(at: selection) {
        case .calc(let result):
            return result.isActionable ? CalcActionsMenu.content(result: result, core: core) : nil
        case .entry(let app):
            return AppActionsMenu.content(
                app: app, searchQuery: vm.query, core: core, favorites: favorites, running: running,
                onResetRanking: {
                    core.launcherCoordinator.resetRanking(for: app)
                    // Reset can move the item; keep the highlight on the item whose action ran.
                    if let index = rows.firstIndex(of: .entry(app)) { vm.selection = index }
                })
        case nil:
            return nil
        }
    }

    func activate(at selection: Int) {
        switch row(at: selection) {
        // Error cards no-op — copyCalculatorResult only acts on value payloads.
        case .calc(let result): core.calculatorCoordinator.copyCalculatorResult(result)
        case .entry(let app): core.launcherCoordinator.launch(app, searchQuery: vm.query)
        case nil: break
        }
    }

    /// ⌘↵ — only an entry backed by a file on disk has somewhere to be revealed.
    func secondary(at selection: Int) -> Bool {
        guard let app = entry(at: selection), app.canRevealInFinder else { return false }
        core.launcherCoordinator.showInFinder(app)
        return true
    }

    /// ⌃⇧Q — the screen owns the chord, but only a running application has anything to quit.
    func quit(at selection: Int) -> Bool {
        guard let app = entry(at: selection), app.kind == .application,
            core.runningApps.isRunning(app)
        else { return false }
        core.launcherCoordinator.quit(app)
        return true
    }

    /// The sample `openActions` takes; only an app row can ever carry a Quit action.
    func isRunning(at selection: Int) -> Bool {
        guard let app = entry(at: selection) else { return false }
        return core.runningApps.isRunning(app)
    }

    /// Favorite slots shown in the compact bar: up to 5 launchable apps, or the first 4 plus an overflow "…" that expands the window. Evaluated only in the compact render and on the rare ⌘N keypress.
    var compactFavoriteSlots: [CompactFavoriteSlot] {
        let ordered = appIndex.orderedResults(
            query: "", visibility: visibility, favorites: favorites)
        let favs = ordered.prefix(while: favorites.isFavorite)
        if favs.count <= 5 { return favs.map(CompactFavoriteSlot.app) }
        return favs.prefix(4).map(CompactFavoriteSlot.app) + [.more]
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(content(selection: selection, scroll: scroll))
    }

    @ViewBuilder
    private func content(selection: Int, scroll: ScrollIntent) -> some View {
        let rows = rows
        let results = results
        // Sections stand in for the ranked Results list, which a typed query collapses to.
        let showSections = vm.query.trimmingCharacters(in: .whitespaces).isEmpty
        LauncherList(
            results: results,
            selectedID: entry(at: selection)?.id,
            favoriteCount: showSections ? results.prefix(while: favorites.isFavorite).count : 0,
            showSections: showSections,
            scroll: scroll,
            calc: calc,
            calcSelected: isCardSelected(selection),
            onActivateCalc: {
                vm.selection = 0
                activate(at: 0)
            },
            onCalcActions: {
                guard let calc, case .value = calc.payload else { return }
                vm.selection = 0
                openActions()
            },
            onActivate: { core.launcherCoordinator.launch($0, searchQuery: vm.query) },
            onActions: { app in
                if let index = rows.firstIndex(of: .entry(app)) { vm.selection = index }
                openActions()
            }
        )
    }
}
