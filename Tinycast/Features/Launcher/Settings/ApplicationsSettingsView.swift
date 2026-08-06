import SwiftUI

struct ApplicationsSettingsView: View {
    var body: some View {
        SettingsPane(
            title: "Applications",
            subtitle: "Choose where Tinycast looks for apps, which ones appear in the launcher, and how to reach them."
        ) {
            // Scopes first: they decide what gets indexed, so they read before the list of what was.
            SearchScopesCard()

            LauncherItemsCard(
                kind: .application,
                header: "Applications",
                searchPrompt: "Search applications…")
        }
    }
}
