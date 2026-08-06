import Foundation

/// What a `HotKeyAction` is bound to. Two kinds, two engines: a `.combo` is a Carbon registration, a `.doubleTap` is recognized by `DoubleTapMonitor` (Carbon can't see lone modifiers at all).
enum HotKeyBinding: Hashable, Sendable {
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

// A `.combo` encodes as the bare legacy `{"carbonKeyCode":N,"carbonModifiers":N}` record, so existing `KeyboardShortcuts_*` values and old backups load and re-save unchanged; `.doubleTap` gets its own shape, which an older build fails to decode and therefore reads as unbound — the right way to degrade.
extension HotKeyBinding: Codable {
    private enum CodingKeys: String, CodingKey {
        case doubleTapModifier
    }

    init(from decoder: Decoder) throws {
        if let shortcut = try? KeyShortcut(from: decoder) {
            self = .combo(shortcut)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = .doubleTap(try container.decode(DoubleTapModifier.self, forKey: .doubleTapModifier))
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .combo(let shortcut):
            try shortcut.encode(to: encoder)
        case .doubleTap(let modifier):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(modifier, forKey: .doubleTapModifier)
        }
    }
}
