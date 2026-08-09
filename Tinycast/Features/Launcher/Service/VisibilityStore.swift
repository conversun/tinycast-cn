import Foundation

/// Which items and categories are hidden; the launcher list only, not bindings.
@MainActor
@Observable
final class VisibilityStore {
    private let defaults = UserDefaults.standard
    private let itemsKey = "hiddenLauncherItems"
    private let kindsKey = "hiddenLauncherKinds"

    private(set) var hiddenItemKeys: Set<String>
    private(set) var hiddenKinds: Set<String>
    /// AppIndex includes this in its result key, invalidating a list when the visible set moves.
    private(set) var revision = 0

    init() {
        hiddenItemKeys = Set(defaults.stringArray(forKey: itemsKey) ?? [])
        hiddenKinds = Set(defaults.stringArray(forKey: kindsKey) ?? [])
    }

    /// Replace both exclusion sets at once (used when importing a settings backup).
    func replace(hiddenItems: [String], hiddenKinds newKinds: [String]) {
        hiddenItemKeys = Set(hiddenItems)
        hiddenKinds = Set(newKinds)
        revision &+= 1
        defaults.set(Array(hiddenItemKeys), forKey: itemsKey)
        defaults.set(Array(hiddenKinds), forKey: kindsKey)
    }

    func key(for entry: AppEntry) -> String { entry.preferenceKey }

    /// Whether the entry appears in the launcher: its category and the item itself must be on.
    func isVisible(_ entry: AppEntry) -> Bool {
        isKindVisible(entry.kind) && isItemVisible(entry)
    }

    func isItemVisible(_ entry: AppEntry) -> Bool {
        !hiddenItemKeys.contains(key(for: entry))
    }

    func setItemVisible(_ visible: Bool, for entry: AppEntry) {
        let k = key(for: entry)
        if visible { hiddenItemKeys.remove(k) } else { hiddenItemKeys.insert(k) }
        revision &+= 1
        defaults.set(Array(hiddenItemKeys), forKey: itemsKey)
    }

    func removeItemKeys(_ keys: Set<String>) {
        guard !keys.isEmpty else { return }
        let previous = hiddenItemKeys
        hiddenItemKeys.subtract(keys)
        guard hiddenItemKeys != previous else { return }
        revision &+= 1
        defaults.set(Array(hiddenItemKeys), forKey: itemsKey)
    }

    func isKindVisible(_ kind: AppEntry.Kind) -> Bool {
        !hiddenKinds.contains(kind.rawValue)
    }

    func setKindVisible(_ visible: Bool, for kind: AppEntry.Kind) {
        if visible { hiddenKinds.remove(kind.rawValue) } else { hiddenKinds.insert(kind.rawValue) }
        revision &+= 1
        defaults.set(Array(hiddenKinds), forKey: kindsKey)
    }
}
