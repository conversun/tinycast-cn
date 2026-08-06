import Foundation

/// Built-in launcher actions surfaced alongside user-authored commands, with dispatch in `AppCore.runCommand`.
enum CommandID: String, CaseIterable, Sendable {
    case calculatorHistory = "command:calculator-history"
    case clipboardHistory = "command:clipboard-history"
    case searchEmoji = "command:search-emoji"
    case createQuicklink = "command:create-quicklink"
    case searchQuicklinks = "command:search-quicklinks"
    case importQuicklinks = "command:import-quicklinks"
    case exportQuicklinks = "command:export-quicklinks"
    case exportSettings = "command:export-settings"
    case importSettings = "command:import-settings"
    case importFromRaycast = "command:import-from-raycast"
    case settings = "command:settings"
    case about = "command:about"
    case quit = "command:quit"

    var name: String {
        switch self {
        case .calculatorHistory: return String(localized: "Calculator History")
        case .clipboardHistory: return String(localized: "Clipboard History")
        case .searchEmoji: return String(localized: "Search Emoji & Symbols")
        case .createQuicklink: return String(localized: "Create Quicklink")
        case .searchQuicklinks: return String(localized: "Search Quicklinks")
        case .importQuicklinks: return String(localized: "Import Quicklinks")
        case .exportQuicklinks: return String(localized: "Export Quicklinks")
        case .exportSettings: return String(localized: "Export Settings")
        case .importSettings: return String(localized: "Import Settings")
        case .importFromRaycast: return String(localized: "Import from Raycast")
        case .settings: return String(localized: "Settings")
        case .about: return String(localized: "About Tinycast")
        case .quit: return String(localized: "Quit Tinycast")
        }
    }

    var sfSymbol: String {
        switch self {
        case .calculatorHistory: return "plus.forwardslash.minus"
        case .clipboardHistory: return "doc.on.clipboard"
        case .searchEmoji: return "face.smiling"
        case .createQuicklink: return "link.badge.plus"
        case .searchQuicklinks: return Quicklink.sfSymbol
        case .importQuicklinks: return "square.and.arrow.down"
        case .exportQuicklinks: return "square.and.arrow.up"
        case .exportSettings: return "square.and.arrow.up"
        case .importSettings: return "square.and.arrow.down"
        case .importFromRaycast: return "arrow.down.doc"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        case .quit: return "power"
        }
    }

    /// Only meaningful while Quicklinks is on, so `AppIndex` drops these from the built-in slice
    /// when the feature is off.
    var isQuicklinkCommand: Bool {
        switch self {
        case .createQuicklink, .searchQuicklinks, .importQuicklinks, .exportQuicklinks: return true
        default: return false
        }
    }
}

enum CommandCatalog {
    /// Sorted by name to keep the AppIndex sort invariant; the URL is a placeholder since commands are never launched from disk.
    nonisolated static let all: [AppEntry] =
        CommandID.allCases
        .map { id in
            AppEntry(
                id: id.rawValue, name: id.name,
                url: URL(
                    string: "tinycast://" + id.rawValue.replacingOccurrences(of: ":", with: "/"))!,
                bundleID: nil, kind: .command)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    static func command(for entry: AppEntry) -> CommandID? {
        CommandID(rawValue: entry.id)
    }
}
