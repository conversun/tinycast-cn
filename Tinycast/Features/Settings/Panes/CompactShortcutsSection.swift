import SwiftUI

struct CompactShortcutsSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppIndex.self) private var appIndex

    var body: some View {
        Section {
            ForEach(settings.compactBarCommands, id: \.self) { command in
                shortcut(command)
            }
            Menu {
                options(availableCommands) { command in
                    guard settings.compactBarCommands.count < CommandID.compactBarLimit,
                        !settings.compactBarCommands.contains(command)
                    else { return }
                    settings.compactBarCommands.append(command)
                }
            } label: {
                Label("Add Shortcut", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(settings.compactBarCommands.count >= CommandID.compactBarLimit)
        } header: {
            SettingsSectionHeader(.generalCompactShortcuts)
        }
    }

    private var availableCommands: [CommandID] {
        CommandID.compactBarOptions.filter { !settings.compactBarCommands.contains($0) }
    }

    private func replacements(for command: CommandID) -> [CommandID] {
        CommandID.compactBarOptions.filter { $0 == command || !settings.compactBarCommands.contains($0) }
    }

    private func shortcut(_ command: CommandID) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            Menu {
                options(replacements(for: command)) { replace(command, with: $0) }
            } label: {
                commandLabel(command)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            if !appIndex.isCommandEnabled(command) {
                Text("Off").foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.lg)
            rowButton("Move Up", systemImage: "chevron.up") { move(command, by: -1) }
                .disabled(settings.compactBarCommands.first == command)
            rowButton("Move Down", systemImage: "chevron.down") { move(command, by: 1) }
                .disabled(settings.compactBarCommands.last == command)
            rowButton("Remove", systemImage: "minus.circle.fill") {
                settings.compactBarCommands.removeAll { $0 == command }
            }
            .foregroundStyle(Theme.Colors.destructive)
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
    }

    /// A borderless button hits only its glyph's bounds, and a chevron's is a few points tall.
    private func rowButton(
        _ title: LocalizedStringResource, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
            .frame(width: Theme.Size.settingsRowButton, height: Theme.Size.settingsRowButton)
            .contentShape(Rectangle())
        }
        .help(Text(title))
    }

    /// An off feature stays selectable, so its slot is ready the moment the feature turns on.
    @ViewBuilder
    private func options(
        _ commands: [CommandID], select: @escaping (CommandID) -> Void
    ) -> some View {
        let off = commands.filter { !appIndex.isCommandEnabled($0) }
        ForEach(commands.filter(appIndex.isCommandEnabled), id: \.self) { command in
            Button {
                select(command)
            } label: {
                commandLabel(command)
            }
        }
        if !off.isEmpty {
            Section("Off") {
                ForEach(off, id: \.self) { command in
                    Button {
                        select(command)
                    } label: {
                        commandLabel(command)
                    }
                }
            }
        }
    }

    private func commandLabel(_ command: CommandID) -> some View {
        Label {
            Text(command.name)
        } icon: {
            SymbolImage(name: command.sfSymbol, size: Theme.Size.settingsRowIcon)
                .environment(\.symbolVariants, .none)
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
    }

    private func replace(_ command: CommandID, with replacement: CommandID) {
        guard let index = settings.compactBarCommands.firstIndex(of: command),
            !settings.compactBarCommands.contains(replacement)
        else { return }
        settings.compactBarCommands[index] = replacement
    }

    private func move(_ command: CommandID, by step: Int) {
        guard let index = settings.compactBarCommands.firstIndex(of: command) else { return }
        let destination = index + step
        guard settings.compactBarCommands.indices.contains(destination) else { return }
        settings.compactBarCommands.swapAt(index, destination)
    }
}
