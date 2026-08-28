import Foundation

/// What the app is in the middle of. Every flag is injected, so the decision stays pure.
struct UpdateActivity: Sendable {
    var isExpandingSnippet = false
    var isRunningExtension = false
    var isUninstalling = false
    var isRecordingHotKey = false
    var isPromptingForArguments = false
    var isShowingDialog = false
    var isPaletteVisible = false
}

/// Whether it is safe to interrupt the user and swap the app out from under them.
enum UpdateReadiness {
    enum Blocker: Equatable, Sendable {
        case expandingSnippet
        case runningExtension
        case uninstalling
        case recordingHotKey
        case promptingForArguments
        case dialogOpen
        case paletteOpen

        var message: String {
            switch self {
            case .expandingSnippet: return String(localized: "Waiting for a snippet to finish expanding.")
            case .runningExtension: return String(localized: "Waiting for a running extension command to finish.")
            case .uninstalling: return String(localized: "Waiting for the uninstaller to finish.")
            case .recordingHotKey: return String(localized: "Finish recording the shortcut first.")
            case .promptingForArguments: return String(localized: "Finish the open command prompt first.")
            case .dialogOpen: return String(localized: "Close the open dialog first.")
            case .paletteOpen: return String(localized: "Close Tinycast's window first.")
            }
        }
    }

    /// Ordered by consequence: an interrupted expansion or install loses work, an open panel does not.
    static func evaluate(_ activity: UpdateActivity) -> Blocker? {
        if activity.isExpandingSnippet { return .expandingSnippet }
        if activity.isRunningExtension { return .runningExtension }
        if activity.isUninstalling { return .uninstalling }
        if activity.isRecordingHotKey { return .recordingHotKey }
        if activity.isPromptingForArguments { return .promptingForArguments }
        if activity.isShowingDialog { return .dialogOpen }
        if activity.isPaletteVisible { return .paletteOpen }
        return nil
    }
}
