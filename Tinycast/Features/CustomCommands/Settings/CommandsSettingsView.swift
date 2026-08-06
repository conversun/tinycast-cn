import SwiftUI

/// Both flavours of command in one pane: Tinycast's own built-ins, then the shell commands the user writes.
struct CommandsSettingsView: View {
    @Environment(CustomCommandStore.self) private var store
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings
    @State private var editor: EditorTarget?
    @State private var pendingDeletion: CustomCommand?

    var body: some View {
        SettingsPane(
            title: "Commands",
            subtitle: "Tinycast's built-in commands, plus your own shell commands."
        ) {
            LauncherItemsCard(
                kind: .command,
                header: "Commands",
                searchPrompt: "Search commands…")

            customCommands
        }
        .sheet(item: $editor) { target in
            CustomCommandEditorSheet(command: target.command)
        }
        .alert(item: $pendingDeletion) { command in
            Alert(
                title: Text("Delete “\(command.name)”?"),
                message: Text("Its global shortcut and launcher references will also be removed."),
                primaryButton: .destructive(Text("Delete")) {
                    core.customCommandCoordinator.deleteCustomCommand(id: command.id)
                },
                secondaryButton: .cancel())
        }
    }

    @ViewBuilder
    private var customCommands: some View {
        @Bindable var settings = settings
        FeatureSwitchCard(
            header: "Custom Commands",
            enableTitle: "Enable custom commands",
            enableSubtitle:
                "Commands run with your user account in /bin/zsh, so use full executable paths.",
            systemImage: CustomCommand.sfSymbol,
            launcherSubtitle: "Find your commands in launcher search.",
            isEnabled: $settings.customCommandsEnabled,
            showsInLauncher: $settings.customCommandsShowInLauncher)

        SettingsCard {
            if store.commands.isEmpty {
                SettingsRow(
                    title: "No custom commands",
                    subtitle: "Add one to make it searchable from the launcher.",
                    systemImage: CustomCommand.sfSymbol,
                    tint: .secondary
                ) {
                    EmptyView()
                }
            } else {
                ForEach(Array(sortedCommands.enumerated()), id: \.element.id) { index, command in
                    if index > 0 { SettingsDivider() }
                    CustomCommandSettingsRow(
                        command: command,
                        onEdit: { editor = EditorTarget(command: command) },
                        onDelete: { pendingDeletion = command })
                }
            }
            SettingsDivider()

            SettingsRow(
                title: "Add Custom Command",
                subtitle: "Name it, then give it a shortcut if you want one.",
                systemImage: "plus.circle",
                tint: .green
            ) {
                Button("Add…") { editor = EditorTarget(command: nil) }
                    .controlSize(.small)
            }
        }
        // Same dim as a hidden launcher category; the switch above stays live.
        .opacity(settings.customCommandsEnabled ? 1 : 0.45)
        .disabled(!settings.customCommandsEnabled)
    }

    private var sortedCommands: [CustomCommand] {
        store.commands.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

private struct EditorTarget: Identifiable {
    let id = UUID()
    let command: CustomCommand?
}

private struct CustomCommandSettingsRow: View {
    let command: CustomCommand
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: CustomCommand.sfSymbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.green)
                .frame(width: Theme.Size.settingsRowIcon)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                Text(command.name)
                    .font(.body)
                    .lineLimit(1)
                Text(command.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(command.command)
            }

            Spacer(minLength: Theme.Spacing.lg)
            ShortcutRecorder(action: .customCommand(id: command.id))

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit Command")
            .accessibilityLabel("Edit \(command.name)")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete Command")
            .accessibilityLabel("Delete \(command.name)")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }
}
