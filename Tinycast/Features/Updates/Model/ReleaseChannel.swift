import Foundation

/// Which stream of releases a build follows. The channels are side-by-side apps with their own
/// bundle ids, so a build only ever updates within its own — crossing would mean a different app.
enum ReleaseChannel: Sendable {
    case stable
    case beta
    /// A local build. It has no release stream, and never updates itself.
    case development

    init(bundleID: String?) {
        switch bundleID {
        case "com.tinycast.app": self = .stable
        case "com.tinycast.app.beta": self = .beta
        default: self = .development
        }
    }

    var updatesItself: Bool { self != .development }

    /// Beta ships as a GitHub prerelease and stable does not; neither ever sees the other's.
    func accepts(prerelease: Bool) -> Bool {
        switch self {
        case .stable: return !prerelease
        case .beta: return prerelease
        case .development: return false
        }
    }
}
