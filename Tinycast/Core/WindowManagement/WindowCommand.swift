import Foundation

struct WindowCommand: Identifiable, Hashable, Sendable {
    enum ID: String, CaseIterable, Sendable {
        case leftHalf = "left-half"
        case rightHalf = "right-half"
        case topHalf = "top-half"
        case bottomHalf = "bottom-half"
        case topLeftQuarter = "top-left-quarter"
        case topRightQuarter = "top-right-quarter"
        case bottomLeftQuarter = "bottom-left-quarter"
        case bottomRightQuarter = "bottom-right-quarter"
        case firstThird = "first-third"
        case centerThird = "center-third"
        case lastThird = "last-third"
        case firstTwoThirds = "first-two-thirds"
        case lastTwoThirds = "last-two-thirds"
        case maximize
        case almostMaximize = "almost-maximize"
        case maximizeHeight = "maximize-height"
        case maximizeWidth = "maximize-width"
        case center
        case centerHalf = "center-half"
        case makeLarger = "make-larger"
        case makeSmaller = "make-smaller"
        case restore
        case moveLeft = "move-left"
        case moveRight = "move-right"
        case moveUp = "move-up"
        case moveDown = "move-down"
        case nextDisplay = "next-display"
        case previousDisplay = "previous-display"
        case toggleFullscreen = "toggle-fullscreen"
    }

    /// What the mover has to do, so its dispatch stays exhaustive and the catalog remains the one source of truth.
    enum Kind: String, Sendable {
        /// Resolve a target frame from the screen and write it.
        case geometry
        /// Geometry too, but sourced from the recorded pre-action frame rather than computed.
        case restore
        /// No geometry at all — the native `AXFullScreen` toggle.
        case fullscreen
    }

    /// The launcher section a command belongs to, and the order the Settings panel lists them in.
    enum Group: String, CaseIterable, Sendable {
        case halves
        case quarters
        case thirds
        case sizing
        case moving
        case fullscreen

        var title: String {
            switch self {
            case .halves: return String(localized: "Halves")
            case .quarters: return String(localized: "Quarters")
            case .thirds: return String(localized: "Thirds")
            case .sizing: return String(localized: "Sizing")
            case .moving: return String(localized: "Moving")
            case .fullscreen: return String(localized: "Fullscreen")
            }
        }
    }

    let id: ID
    let name: String
    let sfSymbol: String
    let kind: Kind
    let group: Group
    /// Only the four halves cycle ½ → ⅓ → ⅔; every other command ignores the step it is handed.
    let cyclesOnRepeat: Bool
    /// False for the nudges, so the mover never writes `kAXSizeAttribute` for them.
    let resizes: Bool

    var entryID: String { "window-command:" + id.rawValue }
}

enum WindowCommandCatalog {
    static let all: [WindowCommand] = WindowCommand.ID.allCases.map { id in
        WindowCommand(
            id: id, name: name(for: id), sfSymbol: symbol(for: id), kind: kind(for: id),
            group: group(for: id), cyclesOnRepeat: cyclesOnRepeat.contains(id),
            resizes: !movesOnly.contains(id))
    }

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    private static let byEntryID = Dictionary(uniqueKeysWithValues: all.map { ($0.entryID, $0) })

    static func command(id: WindowCommand.ID) -> WindowCommand? { byID[id] }

    static func command(forEntryID entryID: String) -> WindowCommand? { byEntryID[entryID] }

    /// Catalog order grouped for the Settings list; `ID.allCases` is already in group order, so this only partitions it.
    static func grouped() -> [(group: WindowCommand.Group, commands: [WindowCommand])] {
        WindowCommand.Group.allCases.compactMap { group in
            let commands = all.filter { $0.group == group }
            return commands.isEmpty ? nil : (group, commands)
        }
    }

    static let cyclesOnRepeat: Set<WindowCommand.ID> = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf
    ]

    /// Nudges reposition without ever touching the size.
    static let movesOnly: Set<WindowCommand.ID> = [.moveLeft, .moveRight, .moveUp, .moveDown]

    private static func name(for id: WindowCommand.ID) -> String {
        switch id {
        case .leftHalf: return String(localized: "Left Half")
        case .rightHalf: return String(localized: "Right Half")
        case .topHalf: return String(localized: "Top Half")
        case .bottomHalf: return String(localized: "Bottom Half")
        case .topLeftQuarter: return String(localized: "Top Left Quarter")
        case .topRightQuarter: return String(localized: "Top Right Quarter")
        case .bottomLeftQuarter: return String(localized: "Bottom Left Quarter")
        case .bottomRightQuarter: return String(localized: "Bottom Right Quarter")
        case .firstThird: return String(localized: "First Third")
        case .centerThird: return String(localized: "Center Third")
        case .lastThird: return String(localized: "Last Third")
        case .firstTwoThirds: return String(localized: "First Two Thirds")
        case .lastTwoThirds: return String(localized: "Last Two Thirds")
        case .maximize: return String(localized: "Maximize")
        case .almostMaximize: return String(localized: "Almost Maximize")
        case .maximizeHeight: return String(localized: "Maximize Height")
        case .maximizeWidth: return String(localized: "Maximize Width")
        case .center: return String(localized: "Center")
        case .centerHalf: return String(localized: "Center Half")
        case .makeLarger: return String(localized: "Make Larger")
        case .makeSmaller: return String(localized: "Make Smaller")
        case .restore: return String(localized: "Restore Window")
        case .moveLeft: return String(localized: "Move Left")
        case .moveRight: return String(localized: "Move Right")
        case .moveUp: return String(localized: "Move Up")
        case .moveDown: return String(localized: "Move Down")
        case .nextDisplay: return String(localized: "Move to Next Display")
        case .previousDisplay: return String(localized: "Move to Previous Display")
        case .toggleFullscreen: return String(localized: "Toggle Fullscreen")
        }
    }

    private static func symbol(for id: WindowCommand.ID) -> String {
        switch id {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .topLeftQuarter: return "rectangle.inset.topleading.filled"
        case .topRightQuarter: return "rectangle.inset.toptrailing.filled"
        case .bottomLeftQuarter: return "rectangle.inset.bottomleading.filled"
        case .bottomRightQuarter: return "rectangle.inset.bottomtrailing.filled"
        case .firstThird, .firstTwoThirds: return "rectangle.leadingthird.inset.filled"
        case .centerThird: return "rectangle.center.inset.filled"
        case .lastThird, .lastTwoThirds: return "rectangle.trailingthird.inset.filled"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .almostMaximize: return "rectangle.inset.filled"
        case .maximizeHeight: return "arrow.up.and.down"
        case .maximizeWidth: return "arrow.left.and.right"
        case .center: return "rectangle.center.inset.filled"
        case .centerHalf: return "rectangle.split.3x1"
        case .makeLarger: return "plus.magnifyingglass"
        case .makeSmaller: return "minus.magnifyingglass"
        case .restore: return "arrow.uturn.backward"
        case .moveLeft: return "arrow.left"
        case .moveRight: return "arrow.right"
        case .moveUp: return "arrow.up"
        case .moveDown: return "arrow.down"
        case .nextDisplay: return "rectangle.on.rectangle.angled"
        case .previousDisplay: return "rectangle.on.rectangle.angled"
        case .toggleFullscreen: return "arrow.up.left.and.arrow.down.right.square"
        }
    }

    private static func kind(for id: WindowCommand.ID) -> WindowCommand.Kind {
        switch id {
        case .restore: return .restore
        case .toggleFullscreen: return .fullscreen
        default: return .geometry
        }
    }

    private static func group(for id: WindowCommand.ID) -> WindowCommand.Group {
        switch id {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf:
            return .halves
        case .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            return .quarters
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds:
            return .thirds
        case .maximize, .almostMaximize, .maximizeHeight, .maximizeWidth, .center, .centerHalf,
            .makeLarger, .makeSmaller, .restore:
            return .sizing
        case .moveLeft, .moveRight, .moveUp, .moveDown, .nextDisplay, .previousDisplay:
            return .moving
        case .toggleFullscreen:
            return .fullscreen
        }
    }
}
