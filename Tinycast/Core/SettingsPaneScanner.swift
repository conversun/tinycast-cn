import Foundation

/// Enumerates the System Settings panes (the `.appex` bundles behind each) into launchable `AppEntry` values, off the main actor inside `AppIndex.scan()`.
enum SettingsPaneScanner {
    private static let extensionsDir = URL(
        fileURLWithPath: "/System/Library/ExtensionKit/Extensions")
    private static let settingsExtensionPoint = "com.apple.Settings.extension.ui"

    /// Panes whose bundle carries a junk or missing display name; keyed by CFBundleIdentifier.
    private static let nameOverrides: [String: String] = [
        "com.apple.Battery-Settings.extension": String(localized: "Battery"),
        "com.apple.HeadphoneSettings": String(localized: "Headphones")
    ]

    /// Panes that shouldn't appear in the launcher at all (contextual/one-shot panes).
    private static let skippedBundleIDs: Set<String> = []

    /// All Settings panes, sorted by display name.
    nonisolated static func scan() -> [AppEntry] {
        let fm = FileManager.default
        guard
            let items = try? fm.contentsOfDirectory(
                at: extensionsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return [] }

        var result: [AppEntry] = []
        for url in items where url.pathExtension == "appex" {
            guard
                let info = plist(at: url.appendingPathComponent("Contents/Info.plist")),
                isSettingsPane(info: info),
                let bundleID = info["CFBundleIdentifier"] as? String,
                !skippedBundleIDs.contains(bundleID),
                let name = displayName(appexURL: url, info: info, bundleID: bundleID)
            else { continue }
            result.append(
                AppEntry(
                    id: url.path, name: name, url: url, bundleID: bundleID,
                    kind: .systemSettings))
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func isSettingsPane(info: [String: Any]) -> Bool {
        let ex = (info["EXAppExtensionAttributes"] as? [String: Any])?["EXExtensionPointIdentifier"]
        if ex as? String == settingsExtensionPoint { return true }
        let ns = (info["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"]
        return ns as? String == settingsExtensionPoint
    }

    /// Override table → localized loctable name → Info.plist names, returning `nil` (skip the pane) when nothing usable is found.
    private static func displayName(
        appexURL: URL, info: [String: Any], bundleID: String
    ) -> String? {
        if let override = nameOverrides[bundleID] { return override }
        if let localized = loctableName(appexURL: appexURL) { return localized }
        return (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String)
    }

    /// Localized `CFBundleDisplayName` from `InfoPlist.loctable` (keyed by locale), trying the user's preferred languages then English.
    private static func loctableName(appexURL: URL) -> String? {
        let url = appexURL.appendingPathComponent("Contents/Resources/InfoPlist.loctable")
        guard let table = plist(at: url) else { return nil }
        // Apple keys these tables by its own locale IDs ("zh_CN"), never by the tag the app runs under ("zh-Hans-US"), so a literal lookup misses every Chinese pane; `preferredLocalizations` knows that equivalence.
        let wanted = Set(
            Locale.preferredLanguages.compactMap {
                Locale(identifier: $0).language.languageCode?.identifier
            })
        // Kept to a language the user actually asked for: unmatched, `preferredLocalizations` returns some unrelated locale, and falling through to English (then the Info.plist) beats naming a pane in Polish.
        var codes = Bundle.preferredLocalizations(
            from: table.keys.map { $0.replacingOccurrences(of: "_", with: "-") },
            forPreferences: Locale.preferredLanguages
        ).filter { wanted.contains(Locale(identifier: $0).language.languageCode?.identifier ?? "") }
        codes.append("en")
        for code in codes {
            let key = code.replacingOccurrences(of: "-", with: "_")
            if let entry = (table[key] ?? table[code]) as? [String: Any],
                let name = entry["CFBundleDisplayName"] as? String {
                return name
            }
        }
        return nil
    }

    private static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil))
            as? [String: Any]
    }
}
