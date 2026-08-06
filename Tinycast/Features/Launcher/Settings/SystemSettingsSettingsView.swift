import SwiftUI

/// The launcher category for macOS System Settings panes — hence the doubled name.
struct SystemSettingsSettingsView: View {
    var body: some View {
        SettingsPane(
            title: "System Settings",
            subtitle: "Jump straight to a System Settings pane from the launcher or a global shortcut."
        ) {
            LauncherItemsCard(
                kind: .systemSettings,
                header: "System Settings",
                searchPrompt: "Search System Settings…")
        }
    }
}
