import Foundation

/// What an action is bound to: two kinds, two engines. See docs/features/hotkeys.md.
enum HotKeyBinding: Hashable, Sendable, Codable {
    case combo(KeyShortcut)
    case doubleTap(DoubleTapModifier)

    /// One string per keycap, so every display site renders both kinds through the same path.
    @MainActor var keycaps: [String] {
        switch self {
        case .combo(let shortcut): shortcut.keycaps
        case .doubleTap(let modifier): modifier.keycaps
        }
    }

    var shortcut: KeyShortcut? {
        if case .combo(let shortcut) = self { return shortcut }
        return nil
    }

    var doubleTapModifier: DoubleTapModifier? {
        if case .doubleTap(let modifier) = self { return modifier }
        return nil
    }
}
