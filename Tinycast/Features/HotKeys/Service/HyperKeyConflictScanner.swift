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

    static func keyboardTaps() -> [HyperKeyDiagnostics.KeyboardTap] {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success, count > 0 else { return [] }
        var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        guard CGGetEventTapList(count, &taps, &count) == .success else { return [] }
        let keyboard: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        var latencies: [String: Float] = [:]
        for tap in taps.prefix(Int(count))
        where tap.options == .defaultTap && tap.eventsOfInterest & keyboard != 0
            && tap.tappingProcess != getpid()
        {
            guard let name = NSRunningApplication(processIdentifier: tap.tappingProcess)?.localizedName
            else { continue }
            latencies[name] = max(latencies[name] ?? 0, tap.avgUsecLatency)
        }
        return latencies.map { name, latency in
            HyperKeyDiagnostics.KeyboardTap(
                appName: name, isSlow: latency >= HyperKeyConflictPolicy.slowTapMicroseconds)
        }
        .sorted { $0.appName.localizedStandardCompare($1.appName) == .orderedAscending }
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
