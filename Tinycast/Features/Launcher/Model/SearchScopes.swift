import Foundation

/// The folders (and individual bundles) `AppIndex` scans for applications. Foundation-only and pure so `Tools/scopes-test.swift` can compile it standalone.
enum SearchScopes {
    /// Seeded into `AppSettings.searchScopes` on a fresh install. Order matters: `AppIndex.scan()` dedups by bundle ID and the first hit wins.
    static let defaults: [String] = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        "/System/Library/CoreServices/Applications",
        // Safari and the other cryptex-delivered system apps; `/Applications/Safari.app` is only a symlink, and a hidden one, so `.skipsHiddenFiles` never sees it.
        "/System/Volumes/Preboot/Cryptexes/App/System/Applications",
        // The one user-facing app in CoreServices — the other ~120 bundles there are background agents with no reliable way to tell them apart, so the directory itself is not a default.
        "/System/Library/CoreServices/Finder.app",
        "~/Applications"
    ]

    /// Storage form: tilde-abbreviated and without a trailing slash, so the Settings list reads cleanly and a settings backup stays portable across machines.
    static func abbreviate(_ path: String) -> String {
        let trimmed = trimTrailingSlash(path)
        return (trimmed as NSString).abbreviatingWithTildeInPath
    }

    static func expand(_ path: String) -> String {
        (trimTrailingSlash(path) as NSString).expandingTildeInPath
    }

    /// Abbreviates every path and drops duplicates, preserving order.
    static func normalize(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.map(abbreviate).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Every `.app` bundle the scopes point at. Flat: one directory listing per scope, no recursion — a nested folder is indexed by adding it as its own scope. Missing or unreadable scopes are skipped.
    static func appBundles(in scopes: [String]) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        for scope in scopes {
            let url = URL(fileURLWithPath: expand(scope))
            if url.pathExtension == "app" {
                if fm.fileExists(atPath: url.path) { result.append(url) }
                continue
            }
            guard
                let items = try? fm.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
                )
            else { continue }
            result.append(contentsOf: items.filter { $0.pathExtension == "app" })
        }
        return result
    }

    private static func trimTrailingSlash(_ path: String) -> String {
        var path = path.trimmingCharacters(in: .whitespaces)
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
