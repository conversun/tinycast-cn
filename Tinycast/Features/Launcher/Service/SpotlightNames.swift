import CoreServices
import Foundation

/// The aliases macOS knows an app by, which no Info.plist key exposes.
enum SpotlightNames {
    /// `MDItem.h` exports no constant for this key, so it is named directly.
    private static let attribute = "kMDItemAlternateNames"

    /// Empty when the path isn't indexed; Spotlight off is a thinner index, not a failure.
    nonisolated static func alternateNames(for url: URL, displayName: String) -> [String] {
        guard let item = MDItemCreateWithURL(nil, url as CFURL),
            let raw = MDItemCopyAttribute(item, attribute as CFString) as? [String]
        else { return [] }
        return SearchFields.usableAlternateNames(
            raw, displayName: displayName, fileName: url.lastPathComponent)
    }

    /// ~0.8 ms per bundle, so a pass re-reads only bundles whose modification date moved.
    struct Cache: Sendable {
        private struct Entry: Sendable {
            let modified: Date?
            let names: [String]
        }

        private let previous: [String: Entry]
        private var current: [String: Entry] = [:]

        init() { previous = [:] }

        /// Only bundles this pass asks about carry forward, so uninstalled apps fall out.
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
