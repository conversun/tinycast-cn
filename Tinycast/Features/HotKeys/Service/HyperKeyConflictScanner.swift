import AppKit

@MainActor
enum HyperKeyConflictScanner {
    static func runningBlocker() -> String? {
        runningConflicts().first { $0.severity == .blocking }?.name
    }

    static func runningConflicts() -> [HyperKeyDiagnostics.ConflictingApp] {
        HyperKeyConflictPolicy.knownApps.flatMap { known in
            NSRunningApplication.runningApplications(withBundleIdentifier: known.bundleID).map {
                HyperKeyDiagnostics.ConflictingApp(
                    name: $0.localizedName ?? known.bundleID, severity: known.severity)
            }
        }
    }

    static func karabinerRemaps(_ key: HyperKeyPhysicalKey) -> Bool {
        let config = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/karabiner/karabiner.json")
        guard key != .none, let data = try? Data(contentsOf: config) else { return false }
        return HyperKeyConflictPolicy.karabinerRemaps(key.rawValue, config: data)
    }

    /// Modifier Keys is stored per keyboard, per host, in the global preferences domain.
    static func capsLockRemaps() -> [HyperKeyConflictPolicy.KeyboardIdentity] {
        let domain = ".GlobalPreferences" as CFString
        let keys =
            CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
            as? [String] ?? []
        let preferences = Dictionary(
            uniqueKeysWithValues: keys.filter { $0.hasPrefix(HyperKeyConflictPolicy.modifierMappingPrefix) }
                .compactMap { key in
                    CFPreferencesCopyValue(
                        key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost
                    ).map { (key, $0 as Any) }
                })
        return HyperKeyConflictPolicy.capsLockRemaps(in: preferences)
    }
}
