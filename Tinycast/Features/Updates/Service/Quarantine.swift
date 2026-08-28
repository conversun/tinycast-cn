import Foundation

/// The `com.apple.quarantine` flag, through the syscalls rather than the `xattr` tool.
///
/// An archive Tinycast fetched itself is not quarantined — macOS sets the flag for sandboxed
/// downloaders and for apps that opt in with `LSFileQuarantineEnabled`, and Tinycast is neither —
/// so this is a guard against being wrong about that, not a routine step.
enum Quarantine {
    private static let attribute = "com.apple.quarantine"

    static func isSet(on url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(path, attribute, nil, 0, 0, XATTR_NOFOLLOW) >= 0
        }
    }

    /// Clears the flag from a bundle and everything inside it, since expanding a quarantined
    /// archive marks every file it wrote, not just the bundle root.
    static func clear(from root: URL) {
        remove(from: root)
        guard
            let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: nil)
        else { return }
        for case let url as URL in walker { remove(from: url) }
    }

    private static func remove(from url: URL) {
        _ = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(0) }
            return removexattr(path, attribute, XATTR_NOFOLLOW)
        }
    }
}
