import Foundation

/// All the classifier may know about one path. Injected, which is what keeps it pure and harness-drivable.
struct PathFacts: Hashable, Sendable {
    let path: String
    var exists = true
    /// Never followed: sizing through one could walk the whole disk.
    var isSymbolicLink = false
    var volumeIsReadOnly = false
    /// `SF_RESTRICTED` / `SF_IMMUTABLE` — SIP.
    var isSystemRestricted = false
    /// `UF_IMMUTABLE` — Finder's "Locked" checkbox, which the user can clear themselves.
    var isUserImmutable = false
    /// Only decides anything under a sticky parent — see `classify`.
    var isOwnedByCurrentUser = true
    var parentIsWritable = true
    /// `S_ISVTX` on the enclosing directory: the `/tmp` rule, where only an item's owner may unlink it.
    var parentIsSticky = false
}

/// Process-wide facts, probed once per scan rather than once per candidate.
struct UninstallEnvironment: Hashable, Sendable {
    let home: String
    let hasFullDiskAccess: Bool
}

/// Why a candidate can or can't be trashed. Advisory, not a boundary: TCC is evaluated at the syscall, so this can be wrong either way.
/// It grays a row with a reason and skips doomed attempts; `UninstallRunner` still reports per-item failure.
enum UninstallProtection: String, Hashable, Sendable, CaseIterable {
    case removable
    case systemProtected
    case userLocked
    case notOwned
    case needsFullDiskAccess
    case parentNotWritable
    case missing

    var isRemovable: Bool { self == .removable }

    /// Nil for exactly `.removable`; the row's lock icon keys off it.
    var lockReason: String? {
        switch self {
        case .removable:
            return nil
        case .systemProtected:
            return String(localized: "Part of macOS and protected by the system.")
        case .userLocked:
            return String(localized: "Locked in Finder. Unlock it in Get Info, then try again.")
        case .notOwned:
            return String(localized: "Owned by another user, in a folder that only lets owners remove things.")
        case .needsFullDiskAccess:
            return String(localized: "Needs Full Disk Access, which Tinycast doesn’t request. Grant it in System Settings › Privacy & Security to include this item.")
        case .parentNotWritable:
            return String(localized: "Its enclosing folder isn’t writable by you, and Tinycast never asks for an administrator password.")
        case .missing:
            return String(localized: "No longer on disk.")
        }
    }
}

enum UninstallProtectionRules {
    /// Precedence is asserted: a SIP file is also root-owned and often TCC-gated, and "part of macOS" is the most useful reason.
    static func classify(_ facts: PathFacts, environment: UninstallEnvironment) -> UninstallProtection
    {
        guard facts.exists else { return .missing }
        if facts.isSystemRestricted || facts.volumeIsReadOnly { return .systemProtected }
        if facts.isUserImmutable { return .userLocked }
        if !environment.hasFullDiskAccess,
            isTCCProtected(path: facts.path, home: environment.home)
        {
            return .needsFullDiskAccess
        }
        // Trashing is a rename out of the parent, so its write bit decides — not who owns the item.
        if !facts.parentIsWritable { return .parentNotWritable }
        // The one case where ownership does decide: a sticky parent lets only an owner unlink.
        if facts.parentIsSticky, !facts.isOwnedByCurrentUser { return .notOwned }
        return .removable
    }

    /// Wider than the current roots on purpose, so adding one later can't silently start attempting denied reads.
    static func isTCCProtected(path: String, home: String) -> Bool {
        let relative = tccRelativePrefixes.contains { path.hasPrefix(home + "/" + $0) }
        return relative || path.hasPrefix("/Library/Application Support/com.apple.TCC")
    }

    /// Measured, not assumed — probe by creating and trashing a throwaway directory. Listing is *not* the test:
    /// both container roots list fine and still refuse the trash. Re-measure before adding an entry.
    static let tccRelativePrefixes: [String] = [
        "Library/Containers/",
        "Library/Group Containers/",
        "Library/Cookies/",
        "Library/Safari",
        "Library/Mail",
        "Library/Messages",
        "Library/Calendars",
        "Library/Suggestions",
        "Library/HomeKit",
        "Library/IdentityServices",
        "Library/Sharing",
        "Library/Biome",
        "Library/Trial",
        "Library/Metadata/CoreSpotlight",
        "Library/Application Support/AddressBook",
        "Library/Application Support/CallHistoryDB",
        "Library/Application Support/com.apple.TCC",
        "Library/Application Support/MobileSync"
    ]
}
