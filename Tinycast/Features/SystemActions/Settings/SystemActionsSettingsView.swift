import SwiftUI

struct SystemActionsSettingsView: View {
    var body: some View {
        SettingsPane(
            title: "System Actions",
            subtitle: "Lock, sleep, volume, Trash and the rest — from the launcher or a global shortcut."
        ) {
            LauncherItemsCard(
                kind: .systemAction,
                header: "System Actions",
                searchPrompt: "Search system actions…")
        }
    }
}
