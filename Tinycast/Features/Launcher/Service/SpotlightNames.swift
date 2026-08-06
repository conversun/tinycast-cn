import CoreServices
import Foundation

/// The aliases macOS itself knows an app by — `iBooks` for Books, `Codex` for ChatGPT — which no Info.plist key exposes.
enum SpotlightNames {
    /// `MDItem.h` exports a constant for `kMDItemDisplayName` but not for this one, so it's named directly.
    private static let attribute = "kMDItemAlternateNames"

    /// Empty when the path isn't indexed — a volume with Spotlight off is a thinner index, never a failure.
    nonisolated static func alternateNames(for url: URL, displayName: String) -> [String] {
        guard let item = MDItemCreateWithURL(nil, url as CFURL),
            let raw = MDItemCopyAttribute(item, attribute as CFString) as? [String]
        else { return [] }
        return SearchFields.usableAlternateNames(
            raw, displayName: displayName, fileName: url.lastPathComponent)
    }

    /// A Spotlight round trip measured ~0.8 ms per bundle and the scan reruns on every launcher open, so a pass re-reads only bundles whose modification date moved (76 ms cold, 0.2 ms after).
    struct Cache: Sendable {
        private struct Entry: Sendable {
            let modified: Date?
            let names: [String]
        }

        private let previous: [String: Entry]
        private var current: [String: Entry] = [:]

        init() { previous = [:] }

        /// Only bundles this pass asks about carry forward, so uninstalled apps fall out instead of accumulating.
        init(reusing cache: Cache) { previous = cache.current }

        mutating func alternateNames(for url: URL, displayName: String) -> [String] {
            let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            if let cached = previous[url.path], cached.modified == modified {
                current[url.path] = cached
                return cached.names
            }
            let names = SpotlightNames.alternateNames(for: url, displayName: displayName)
            current[url.path] = Entry(modified: modified, names: names)
            return names
        }
    }
}
