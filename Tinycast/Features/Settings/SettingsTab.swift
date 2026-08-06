import SwiftUI

enum SettingsTab: Int, CaseIterable, Identifiable {
    // Declaration order is sidebar order: general, then one pane per launcher category, then the rest.
    case general, applications, systemSettings, systemActions, commands, quicklinks, snippets,
        windowManagement, clipboard, emoji, permissions, backup, miscellaneous, about
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .applications: return "Applications"
        case .systemSettings: return "System Settings"
        case .systemActions: return "System Actions"
        case .commands: return "Commands"
        case .quicklinks: return "Quicklinks"
        case .snippets: return "Snippets"
        case .windowManagement: return "Window Management"
        case .clipboard: return "Clipboard"
        case .emoji: return "Emoji & Symbols"
        case .permissions: return "Permissions"
        case .backup: return "Backup"
        case .miscellaneous: return "Miscellaneous"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "switch.2"
        case .applications: return "square.grid.2x2"
        case .systemSettings: return "gearshape"
        case .systemActions: return "bolt"
        case .commands: return "terminal"
        case .quicklinks: return "link"
        case .snippets: return "curlybraces"
        case .windowManagement: return "macwindow"
        case .clipboard: return "doc.on.clipboard"
        case .emoji: return "face.smiling"
        case .permissions: return "lock.shield"
        case .backup: return "arrow.up.arrow.down.circle"
        case .miscellaneous: return "ellipsis.circle"
        case .about: return "info.circle"
        }
    }

    /// Colored icon tile, System Settings style — a small cue that makes the sidebar scannable.
    var tint: Color {
        switch self {
        case .general: return .gray
        case .applications: return .blue
        case .systemSettings: return .indigo
        case .systemActions: return .orange
        case .commands: return .green
        case .quicklinks: return .cyan
        case .snippets: return .green
        case .windowManagement: return .blue
        case .clipboard: return .orange
        case .emoji: return .yellow
        case .permissions: return .blue
        case .backup: return .teal
        case .miscellaneous: return .purple
        case .about: return .pink
        }
    }
}
