import Foundation

/// What an uninstall is aimed at. Pure, for `Tools/uninstall-test.swift`.
struct UninstallTarget: Hashable, Sendable {
    let bundleURL: URL
    let bundleID: String?
    let displayName: String
    /// Some apps name their support folder after `CFBundleName` rather than the display name.
    let bundleName: String?
}

/// How a candidate was attributed to the target.
enum UninstallEvidence: String, Hashable, Sendable, CaseIterable {
    case bundle
    case bundleID
    case groupContainer
    case displayName
    case binSymlink

    /// Weak evidence names itself on the row; proof-grade matches stay silent.
    var label: String? {
        switch self {
        case .displayName: return String(localized: "matched by name")
        case .binSymlink: return String(localized: "command-line tool")
        case .bundle, .bundleID, .groupContainer: return nil
        }
    }
}

/// Matching-ready form of a target. `make` applies every guard rail, leaving `UninstallRules` no judgement to exercise.
struct UninstallIdentity: Hashable, Sendable {
    /// Case-folded bundle ID, or nil when the target has none.
    let bundleID: String?
    /// False for a two-component ID: `com.adobe` names a vendor, and prefix-matching it would sweep every app they ship.
    let allowsBundleIDPrefixMatch: Bool
    /// Other installed apps' folded IDs: a longer-ID sibling owns its own artifacts, so one channel can't claim another's.
    let otherBundleIDs: Set<String>
    /// Case-folded names safe enough to claim a whole directory.
    let names: [String]
    let bundleURL: URL

    /// Three, not four: Zed and IINA name their own folders. The guards below carry the safety, not the length.
    static let minimumNameLength = 3

    /// Standard Library subdirectories, so an app sharing the name can never claim them.
    static let reservedNames: Set<String> = [
        "apple", "application support", "application scripts", "autosave information", "caches",
        "containers", "cookies", "crashreporter", "fonts", "frameworks", "group containers",
        "httpstorages", "keychains", "launchagents", "launchdaemons", "logs", "metadata",
        "mobilesync", "preferences", "privilegedhelpertools", "scripts", "services", "sync",
        "syncservices", "webkit"
    ]

    /// Nil refuses the uninstall: Tinycast never plans its own, and a target with no ID and no safe name can attribute nothing.
    /// `ownBundleID` is the *running* identity, so the Dev channel refuses itself too.
    static func make(
        target: UninstallTarget, otherAppNames: [String], otherBundleIDs: [String] = [],
        ownBundleID: String?, ownBundleURL: URL
    ) -> UninstallIdentity? {
        if let ownBundleID, let bundleID = target.bundleID,
            folded(bundleID) == folded(ownBundleID)
        {
            return nil
        }
        if target.bundleURL.standardizedFileURL == ownBundleURL.standardizedFileURL { return nil }

        let bundleID = target.bundleID.map(folded).flatMap { $0.isEmpty ? nil : $0 }
        let names = safeNames(
            displayName: target.displayName, bundleName: target.bundleName,
            otherAppNames: otherAppNames)
        guard bundleID != nil || !names.isEmpty else { return nil }

        return UninstallIdentity(
            bundleID: bundleID,
            allowsBundleIDPrefixMatch: (bundleID?.split(separator: ".").count ?? 0) >= 3,
            otherBundleIDs: Set(otherBundleIDs.map(folded)).subtracting([bundleID].compactMap { $0 }),
            names: names,
            bundleURL: target.bundleURL.standardizedFileURL)
    }

    /// Gates a name must clear: long enough, not a macOS folder name, and not shared with another installed app.
    static func safeNames(
        displayName: String, bundleName: String?, otherAppNames: [String]
    ) -> [String] {
        let taken = Set(otherAppNames.map(folded))
        var result: [String] = []
        for candidate in [displayName, bundleName].compactMap({ $0 }) {
            let name = folded(candidate)
            guard name.count >= minimumNameLength, !reservedNames.contains(name),
                !taken.contains(name), !result.contains(name)
            else { continue }
            result.append(name)
        }
        return result
    }

    static func folded(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespaces)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
