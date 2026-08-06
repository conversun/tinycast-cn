import SwiftUI

struct LauncherList: View {
    let results: [AppEntry]
    let selectedID: AppEntry.ID?
    let favoriteCount: Int
    let showSections: Bool
    /// Changes only when the list should scroll (keyboard nav / reset), so mouse selection never yanks the scroll position.
    let scroll: ScrollIntent
    /// Inline calculator answer; occupies flat selection index 0 when present (requires a non-empty query, so it never coexists with the sectioned view).
    var calc: CalcResult?
    var calcSelected = false
    var onActivateCalc: () -> Void = {}
    var onCalcActions: () -> Void = {}
    let onActivate: (AppEntry) -> Void
    let onActions: (AppEntry) -> Void
    @Environment(RunningAppsMonitor.self) private var runningApps

    private nonisolated static let calcRowID = "calc-card"

    private enum Row: Identifiable {
        case header(String)
        case calc(CalcResult)
        case app(AppEntry)
        var id: String {
            switch self {
            case .header(let title): return "header-" + title
            case .calc: return LauncherList.calcRowID
            case .app(let app): return app.id
            }
        }
    }

    /// Scroll target for the current selection.
    private var selectedRowID: String? { calcSelected ? Self.calcRowID : selectedID }

    /// Whether the selection sits on flat index 0 — the calc card when present, else the first result.
    private var firstRowSelected: Bool {
        calc != nil ? calcSelected : selectedID != nil && selectedID == results.first?.id
    }

    private var rows: [Row] {
        var calcRows: [Row] = []
        if let calc { calcRows = [.header("Calculator"), .calc(calc)] }
        guard showSections else {
            guard !results.isEmpty else { return calcRows }
            return calcRows + [.header("Results")] + results.map(Row.app)
        }
        var rows: [Row] = calcRows
        let favorites = results.prefix(favoriteCount)
        let rest = results.dropFirst(favoriteCount)
        // `rest` is apps, panes, quicklinks, snippets, system actions, window commands, custom
        // commands, then built-in commands by the AppIndex sort invariant, so filtering by kind
        // keeps row order identical and the flat selection index valid.
        // Annotated: with this many sections the inference pass times out.
        func section(_ kind: AppEntry.Kind) -> (String, [AppEntry]) {
            (kind.descriptor.sectionTitle, rest.filter { $0.kind == kind })
        }
        let sections: [(String, [AppEntry])] = [
            ("Favorites", Array(favorites)),
            section(.application),
            section(.systemSettings),
            section(.quicklink),
            section(.snippet),
            section(.systemAction),
            section(.windowCommand),
            section(.customCommand),
            section(.command)
        ]
        for (title, group) in sections where !group.isEmpty {
            rows.append(.header(title))
            rows.append(contentsOf: group.map(Row.app))
        }
        return rows
    }

    var body: some View {
        let rows = rows
        return Group {
            if results.isEmpty && calc == nil {
                EmptyResults(text: "No apps found")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(rows) { row in
                                switch row {
                                case .header(let title):
                                    SectionHeader(title: title, isFirst: row.id == rows.first?.id)
                                case .calc(let result):
                                    CalculatorCard(result: result, selected: calcSelected)
                                        .contentShape(Rectangle())
                                        .onTapGesture(perform: onActivateCalc)
                                        .onRightClick(perform: onCalcActions)
                                        .padding(.bottom, Theme.Spacing.xs)
                                case .app(let app):
                                    AppRow(
                                        app: app,
                                        selected: app.id == selectedID,
                                        running: runningApps.isRunning(app)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { onActivate(app) }
                                    .onRightClick { onActions(app) }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.xs)
                        .padding(.bottom, Theme.Spacing.md)
                        .hideNativeScrollers()
                        .scrollOriginAnchor()
                    }
                    .edgeDissolve()
                    .thinScrollbar()
                    .onChange(of: scroll) { _, scroll in
                        switch scroll.kind {
                        case .top:
                            proxy.scrollToOrigin()
                        case .follow:
                            // On the first row, snap to the origin so its section header shows too — a nil anchor won't, since the row is already visible.
                            if firstRowSelected {
                                proxy.scrollToOrigin()
                            } else if let selectedRowID {
                                proxy.reveal(selectedRowID)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct AppRow: View {
    let app: AppEntry
    let selected: Bool
    let running: Bool
    /// Observed so a hotkey set/cleared in Settings re-renders the row's keycaps immediately.
    @Environment(HotKeyManager.self) private var hotKeys
    @State private var hovered = false

    /// Selection wins over hover when a row is both; otherwise hover shows its fainter layer.
    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    /// Keycaps for this entry's hotkey, or `nil` if none is bound.
    private var shortcutCaps: [String]? {
        guard let action = app.hotKeyAction else { return nil }
        return hotKeys.binding(for: action)?.keycaps
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            AppIconView(app: app)
                .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                .overlay(alignment: .bottom) {
                    if running {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 3, height: 3)
                            .offset(y: 3)
                    }
                }
            Text(app.name)
                .font(Theme.Typography.rowTitle)
                .lineLimit(1)
            if let caps = shortcutCaps {
                HStack(spacing: Theme.Spacing.xxs) {
                    ForEach(Array(caps.enumerated()), id: \.offset) { _, cap in
                        KeyCapChip(text: cap, style: .outline)
                    }
                }
            }
            Spacer()
            Text(app.kindLabel.localizedUI)
                .font(Theme.Typography.rowTrailing)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(fill)
        )
        .armedHover($hovered)
    }
}
