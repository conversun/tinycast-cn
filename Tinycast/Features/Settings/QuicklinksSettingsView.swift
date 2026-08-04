import SwiftUI

/// The quicklink library plus the behaviour that applies to all of them.
struct QuicklinksSettingsView: View {
    @EnvironmentObject private var store: QuicklinkStore
    @ObservedObject private var core = AppCore.shared
    @ObservedObject private var settings = AppCore.shared.settings
    @State private var query = ""
    @State private var pendingDeletion: Quicklink?

    var body: some View {
        SettingsPane(
            title: "Quicklinks",
            subtitle: "Turn a URL, search, file, folder or deeplink into its own command."
        ) {
            FeatureSwitchCard(
                header: "Quicklinks",
                enableTitle: "Enable quicklinks",
                enableSubtitle:
                    "Open saved destinations from the launcher, a shortcut, or Search Quicklinks.",
                systemImage: Quicklink.sfSymbol,
                launcherSubtitle: "Find your quicklinks in launcher search.",
                isEnabled: $settings.quicklinksEnabled,
                showsInLauncher: $settings.quicklinksShowInLauncher)

            Group {
                if !store.isAvailable { storageCallout }
                library
                behaviour
                transfer
            }
            // Same dim as a hidden launcher category; the switch above stays live.
            .opacity(settings.quicklinksEnabled ? 1 : 0.45)
            .disabled(!settings.quicklinksEnabled)
        }
        // Presented from the pane rather than the row, so "Create Quicklink" can open it from the
        // palette by handing `AppCore` a request.
        .sheet(item: $core.pendingQuicklinkEdit) { request in
            QuicklinkEditorSheet(quicklink: request.quicklink)
        }
        .alert(item: $pendingDeletion) { quicklink in
            Alert(
                title: Text("Delete “\(quicklink.name)”?"),
                message: Text("Its global shortcut and launcher references will also be removed."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await AppCore.shared.deleteQuicklink(id: quicklink.id, confirming: false) }
                },
                secondaryButton: .cancel())
        }
    }

    // MARK: - Cards

    private var storageCallout: some View {
        SettingsCallout(
            title: "Quicklinks can't be saved",
            message:
                "The quicklinks database couldn't be opened, so nothing you change here will stick. The existing file was left untouched.",
            systemImage: "exclamationmark.triangle.fill",
            tint: .orange)
    }

    @ViewBuilder
    private var library: some View {
        if !store.quicklinks.isEmpty {
            SettingsSearchField(prompt: "Search quicklinks…", query: $query)
        }
        SettingsCard {
            if results.isEmpty {
                SettingsRow(
                    title: store.quicklinks.isEmpty ? "No quicklinks" : "No matches",
                    subtitle: store.quicklinks.isEmpty
                        ? "Add one to make it searchable from the launcher."
                        : "No quicklink matches “\(query)”.",
                    systemImage: Quicklink.sfSymbol,
                    tint: .secondary
                ) {
                    EmptyView()
                }
            } else {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, quicklink in
                    if index > 0 { SettingsDivider() }
                    QuicklinkSettingsRow(
                        quicklink: quicklink,
                        onEdit: { core.editQuicklink(quicklink) },
                        onDelete: { pendingDeletion = quicklink })
                }
            }
            SettingsDivider()

            SettingsRow(
                title: "Add Quicklink",
                subtitle: "Name it, paste a link, then give it a shortcut if you want one.",
                systemImage: "plus.circle",
                tint: .green
            ) {
                Button("Add…") { core.editQuicklink(nil) }
                    .controlSize(.small)
            }
        }
    }

    private var behaviour: some View {
        SettingsCard(header: "Behaviour") {
            SettingsRow(
                title: "Open in a new window",
                subtitle:
                    "Ask the handler for a new window instead of reusing its frontmost tab. Only apps that accept a new-window argument can honour this.",
                systemImage: "macwindow.badge.plus",
                tint: .blue
            ) {
                Toggle("", isOn: $settings.quicklinkOpensNewWindow).labelsHidden()
            }
            SettingsDivider()
            SettingsRow(
                title: "When there's no selected text",
                subtitle: "What {selection} does when the app in front exposes nothing to read.",
                systemImage: "text.cursor",
                tint: .indigo
            ) {
                Picker("", selection: $settings.quicklinkSelectionFallback) {
                    ForEach(QuicklinkSelectionFallback.allCases) { option in
                        Text(option.title.localizedUI).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow(
                title: "Confirm before deleting",
                subtitle: "Ask first when deleting a quicklink from the launcher's Actions menu.",
                systemImage: "trash",
                tint: .red
            ) {
                Toggle("", isOn: $settings.quicklinkConfirmsBeforeDelete).labelsHidden()
            }
        }
    }

    private var transfer: some View {
        SettingsCard(header: "Import & Export") {
            SettingsRow(
                title: "Import quicklinks",
                subtitle: "Add quicklinks from a JSON file, skipping any you already have.",
                systemImage: "square.and.arrow.down",
                tint: .teal
            ) {
                Button("Import…") { Task { await core.importQuicklinks() } }
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsRow(
                title: "Export quicklinks",
                subtitle: "Write your whole library to a JSON file.",
                systemImage: "square.and.arrow.up",
                tint: .teal
            ) {
                Button("Export…") { Task { await core.exportQuicklinks() } }
                    .controlSize(.small)
                    .disabled(store.quicklinks.isEmpty)
            }
        }
    }

    /// The store already publishes display order, so filtering keeps pins at the top.
    private var results: [Quicklink] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return store.quicklinks }
        return store.quicklinks.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.link.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

private struct QuicklinkSettingsRow: View {
    let quicklink: Quicklink
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            SymbolImage(name: symbol, size: 13)
                .foregroundStyle(.cyan)
                .frame(width: Theme.Size.settingsRowIcon)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(quicklink.name)
                        .font(.body)
                        .lineLimit(1)
                    if quicklink.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("Pinned to the top")
                    }
                    if !quicklink.showsInRootSearch {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("Hidden from root search")
                    }
                }
                Text(quicklink.link)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(quicklink.link)
            }

            Spacer(minLength: Theme.Spacing.lg)
            ShortcutRecorder(action: .quicklink(id: quicklink.id))

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit Quicklink")
            .accessibilityLabel("Edit \(quicklink.name)")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete Quicklink")
            .accessibilityLabel("Delete \(quicklink.name)")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private var symbol: String {
        quicklink.iconSymbol ?? QuicklinkDestination.detect(quicklink.link)?.defaultSymbol
            ?? Quicklink.sfSymbol
    }
}
