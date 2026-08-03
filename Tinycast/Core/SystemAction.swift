import Foundation

struct SystemAction: Identifiable, Hashable, Sendable {
    enum ID: String, CaseIterable, Sendable {
        case lockScreen = "lock-screen"
        case sleep
        case sleepDisplays = "sleep-displays"
        case restart
        case shutDown = "shut-down"
        case logOut = "log-out"
        case showScreenSaver = "show-screen-saver"
        case playPause = "play-pause"
        case nextTrack = "next-track"
        case previousTrack = "previous-track"
        case toggleMute = "toggle-mute"
        case volumeUp = "volume-up"
        case volumeDown = "volume-down"
        case setVolume = "set-volume"
        case volume0 = "volume-0"
        case volume25 = "volume-25"
        case volume50 = "volume-50"
        case volume75 = "volume-75"
        case volume100 = "volume-100"
        case showDesktop = "show-desktop"
        case toggleAppearance = "toggle-system-appearance"
        case toggleStageManager = "toggle-stage-manager"
        case openTrash = "open-trash"
        case emptyTrash = "empty-trash"
        case ejectAllDisks = "eject-all-disks"
        case toggleHiddenFiles = "toggle-hidden-files"
        case hideOtherApps = "hide-all-apps-except-frontmost"
        case unhideAllApps = "unhide-all-hidden-apps"
        case quitAllApps = "quit-all-apps"
        case dismissNotifications = "dismiss-notifications"
        case toggleBluetooth = "toggle-bluetooth"
    }

    /// Whether running the action needs a confirmation first, and the copy for it. Every action
    /// that needs one is destructive, so `AppCore` renders them all the same way and the catalog
    /// only has to supply the words.
    enum Confirmation: Hashable, Sendable {
        case none
        case required(title: String, message: String)
        /// Quit All alone counts its targets before asking, so its copy is built at call time.
        case computed
    }

    let id: ID
    let name: String
    let sfSymbol: String
    let confirmation: Confirmation

    /// Stable identity for the launcher entry, and with it the persisted favorite, visibility and ranking keys.
    var entryID: String { "system-action:" + id.rawValue }
}

enum SystemActionCatalog {
    static let all: [SystemAction] = SystemAction.ID.allCases.map { id in
        SystemAction(
            id: id, name: name(for: id), sfSymbol: symbol(for: id),
            confirmation: confirmation(for: id))
    }

    private static let byEntryID = Dictionary(uniqueKeysWithValues: all.map { ($0.entryID, $0) })
    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func action(forEntryID entryID: String) -> SystemAction? {
        byEntryID[entryID]
    }

    static func action(id: SystemAction.ID) -> SystemAction {
        // Every ID is in `all` by construction, so a miss is a programmer error rather than a runtime case.
        byID[id]!
    }

    private static func name(for id: SystemAction.ID) -> String {
        switch id {
        case .lockScreen: return String(localized: "Lock Screen")
        case .sleep: return String(localized: "Sleep")
        case .sleepDisplays: return String(localized: "Sleep Displays")
        case .restart: return String(localized: "Restart")
        case .shutDown: return String(localized: "Shut Down")
        case .logOut: return String(localized: "Log Out")
        case .showScreenSaver: return String(localized: "Show Screen Saver")
        case .playPause: return String(localized: "Play / Pause")
        case .nextTrack: return String(localized: "Next Track")
        case .previousTrack: return String(localized: "Previous Track")
        case .toggleMute: return String(localized: "Toggle Mute")
        case .volumeUp: return String(localized: "Turn Volume Up")
        case .volumeDown: return String(localized: "Turn Volume Down")
        case .setVolume: return String(localized: "Set Volume…")
        case .volume0: return String(localized: "Set Volume to 0%")
        case .volume25: return String(localized: "Set Volume to 25%")
        case .volume50: return String(localized: "Set Volume to 50%")
        case .volume75: return String(localized: "Set Volume to 75%")
        case .volume100: return String(localized: "Set Volume to 100%")
        case .showDesktop: return String(localized: "Show Desktop")
        case .toggleAppearance: return String(localized: "Toggle System Appearance")
        case .toggleStageManager: return String(localized: "Toggle Stage Manager")
        case .openTrash: return String(localized: "Open Trash")
        case .emptyTrash: return String(localized: "Empty Trash")
        case .ejectAllDisks: return String(localized: "Eject All Disks")
        case .toggleHiddenFiles: return String(localized: "Toggle Hidden Files")
        case .hideOtherApps: return String(localized: "Hide All Apps Except Frontmost")
        case .unhideAllApps: return String(localized: "Unhide All Hidden Apps")
        case .quitAllApps: return String(localized: "Quit All Applications")
        case .dismissNotifications: return String(localized: "Dismiss Notifications")
        case .toggleBluetooth: return String(localized: "Toggle Bluetooth")
        }
    }

    private static func symbol(for id: SystemAction.ID) -> String {
        switch id {
        case .lockScreen: return "lock"
        case .sleep: return "moon.zzz"
        case .sleepDisplays: return "display"
        case .restart: return "arrow.clockwise"
        case .shutDown: return "power"
        case .logOut: return "rectangle.portrait.and.arrow.right"
        case .showScreenSaver: return "rectangle.inset.filled"
        case .playPause: return "playpause"
        case .nextTrack: return "forward.end"
        case .previousTrack: return "backward.end"
        case .toggleMute: return "speaker.slash"
        case .volumeUp: return "speaker.plus"
        case .volumeDown: return "speaker.minus"
        case .setVolume, .volume0, .volume25, .volume50, .volume75, .volume100:
            return "speaker.wave.2"
        case .showDesktop: return "macwindow.on.rectangle"
        case .toggleAppearance: return "circle.lefthalf.filled"
        case .toggleStageManager: return "squares.leading.rectangle"
        case .openTrash: return "trash"
        case .emptyTrash: return "trash.slash"
        case .ejectAllDisks: return "eject"
        case .toggleHiddenFiles: return "eye.slash"
        case .hideOtherApps: return "eye.slash.circle"
        case .unhideAllApps: return "eye.circle"
        case .quitAllApps: return "xmark.circle"
        case .dismissNotifications: return "bell.slash"
        // Not an SF Symbol — the logo is a Bluetooth SIG trademark, so this resolves to a bundled asset instead.
        case .toggleBluetooth: return "bluetooth"
        }
    }

    private static let sessionEndingMessage = String(
        localized: "Applications with unsaved changes may ask you to save.")

    private static func confirmation(for id: SystemAction.ID) -> SystemAction.Confirmation {
        switch id {
        case .restart:
            return .required(
                title: String(localized: "Restart your Mac?"), message: sessionEndingMessage)
        case .shutDown:
            return .required(
                title: String(localized: "Shut down your Mac?"), message: sessionEndingMessage)
        case .logOut:
            return .required(
                title: String(localized: "Log out now?"), message: sessionEndingMessage)
        case .emptyTrash:
            return .required(
                title: String(localized: "Empty Trash?"),
                message: String(localized: "The items in the Trash will be permanently deleted."))
        case .quitAllApps:
            return .computed
        default:
            return .none
        }
    }
}
