import AppKit

enum PaletteMode: String, CaseIterable, Identifiable {
    case launcher
    case clipboard
    case calculatorHistory
    case emoji
    case uninstall
    case quicklinks
    /// Collects a quicklink's `{argument}` values; the request lives on the session.
    case quicklinkArguments

    var id: String { rawValue }
    var title: String {
        switch self {
        case .launcher: return String(localized: "Apps")
        case .clipboard: return String(localized: "Clipboard")
        case .calculatorHistory: return String(localized: "Calculator History")
        case .emoji: return String(localized: "Emoji & Symbols")
        case .uninstall: return String(localized: "Uninstall Application")
        case .quicklinks: return String(localized: "Quicklinks")
        case .quicklinkArguments: return String(localized: "Open Quicklink")
        }
    }
    var systemImage: String {
        switch self {
        case .launcher: return "magnifyingglass"
        case .clipboard: return "doc.on.doc"
        case .calculatorHistory: return "plus.forwardslash.minus"
        case .emoji: return "face.smiling"
        case .uninstall: return "trash"
        case .quicklinks, .quicklinkArguments: return Quicklink.sfSymbol
        }
    }
    var placeholder: String {
        switch self {
        case .launcher: return String(localized: "Search for apps and commands…")
        case .clipboard: return String(localized: "Type to filter entries…")
        case .calculatorHistory:
            return String(localized: "Do math, convert units, or search your past calculations…")
        case .emoji: return String(localized: "Search emoji and symbols…")
        case .uninstall: return String(localized: "Filter files and folders by name…")
        case .quicklinks: return String(localized: "Search quicklinks…")
        // Replaced by the pending argument's name; only reached if the session vanished mid-render.
        case .quicklinkArguments: return String(localized: "Enter a value…")
        }
    }
}

/// The app a paste lands in, resolved once per show so nothing re-reads it per render.
struct PasteTarget: Equatable {
    let name: String
    /// Bundle path for `IconCache` — nil for a target with no on-disk bundle.
    let iconPath: String?

    init?(app: NSRunningApplication?) {
        guard let app, let name = app.localizedName else { return nil }
        self.name = name
        iconPath = app.bundleURL?.path
    }

    var pasteTitle: String { String(localized: "Paste to \(name)") }
}
