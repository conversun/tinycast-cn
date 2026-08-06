import SwiftUI

/// The form shown before a quicklink with placeholders opens.
struct QuicklinkArgumentsScreen: PaletteScreen {
    /// Options can repeat, so position is the identity — the key the list has always used.
    struct Choice: Identifiable {
        let id: Int
        let title: String
    }

    let session: QuicklinkArgumentSession
    let core: AppCore
    let vm: PaletteState
    let scrollToTop: () -> Void

    var rows: [Choice] {
        options.enumerated().map { Choice(id: $0.offset, title: $0.element) }
    }

    var primaryActionTitle: String { session.isLastArgument ? "Open Quicklink" : "Next" }

    /// Filtered like every other list; a free-text argument has none, so selection stays at zero.
    private var options: [String] {
        let query = vm.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return session.options }
        return session.options.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    /// The argument form has one action — submit — and it is already ↵.
    func actions(at selection: Int) -> PopoverMenuContent? { nil }

    func secondary(at selection: Int) -> Bool { false }

    func activate(at selection: Int) {
        // An options argument submits the highlighted choice; a free-text one submits the field.
        let options = options
        let value: String
        if session.options.isEmpty {
            value = vm.query
        } else {
            guard options.indices.contains(selection) else { return }
            value = options[selection]
        }
        core.quicklinkCoordinator.submitQuicklinkArgument(value)
        // More arguments to go: clear the field for the next one and reset the choice list.
        if session.isActive {
            vm.query = ""
            vm.selection = 0
            scrollToTop()
        }
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(
            QuicklinkArgumentsView(
                options: options,
                selection: selection,
                scroll: scroll,
                onSelect: { vm.selection = $0 },
                onActivate: { activate(at: vm.selection) }
            ))
    }
}
