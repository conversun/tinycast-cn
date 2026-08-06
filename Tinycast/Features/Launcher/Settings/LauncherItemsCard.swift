import SwiftUI

/// One launcher category's Settings card: a search field, the category's "show in launcher" switch, then
/// a row per entry. Never applies the visibility filter itself, so hidden rows stay re-checkable here.
struct LauncherItemsCard: View {
    let kind: AppEntry.Kind
    let header: String
    let searchPrompt: String

    @Environment(AppIndex.self) private var appIndex
    @Environment(VisibilityStore.self) private var visibility
    @State private var query = ""

    private var entries: [AppEntry] {
        // Run the matcher once per render, then scope the results to this category.
        let matched = query.isEmpty ? appIndex.apps : appIndex.matches(query)
        return matched.filter { $0.kind == kind }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SettingsSearchField(prompt: searchPrompt, query: $query)

            SettingsCard(header: header) {
                SettingsRow(
                    title: "Show in launcher",
                    subtitle: "Uncheck an item below to hide just that one.",
                    systemImage: "magnifyingglass",
                    tint: .green
                ) {
                    Toggle("Show in launcher", isOn: kindBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("Show in launcher")
                }
                SettingsDivider()

                // Rows dim while the category is off but stay interactive, so an item can be re-checked first.
                LazyVStack(spacing: 1) {
                    if entries.isEmpty {
                        Text(query.isEmpty ? "Nothing here yet." : String(localized: "No matches for “\(query)”."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Theme.Spacing.xxl)
                    } else {
                        ForEach(entries) { entry in
                            LauncherItemRow(entry: entry)
                        }
                    }
                }
                .padding(Theme.Spacing.sm)
                .opacity(visibility.isKindVisible(kind) ? 1 : 0.45)
            }
        }
    }

    private var kindBinding: Binding<Bool> {
        Binding(
            get: { visibility.isKindVisible(kind) },
            set: { visibility.setKindVisible($0, for: kind) }
        )
    }
}

private struct LauncherItemRow: View {
    let entry: AppEntry
    @Environment(VisibilityStore.self) private var visibility
    // Hover lives on the row itself so a mouse sweep repaints only the rows entering/leaving.
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            AppIconView(app: entry)
                .frame(width: 22, height: 22)
            Text(entry.name).lineLimit(1)
            Spacer(minLength: Theme.Spacing.xl)
            if let action = entry.hotKeyAction {
                ShortcutRecorder(action: action)
            }
            Toggle("", isOn: itemBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .accessibilityLabel("Show \(entry.name) in launcher")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(hovered ? Theme.Colors.rowHover : .clear)
        )
        .onHover { hovered = $0 }
    }

    private var itemBinding: Binding<Bool> {
        Binding(
            get: { visibility.isItemVisible(entry) },
            set: { visibility.setItemVisible($0, for: entry) }
        )
    }
}
