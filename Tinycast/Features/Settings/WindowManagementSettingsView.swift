import SwiftUI

struct WindowManagementSettingsView: View {
    @ObservedObject private var settings = AppCore.shared.settings

    var body: some View {
        SettingsPane(
            title: "Window Management",
            subtitle:
                "Snap, resize and move the frontmost window from the launcher or a global shortcut."
        ) {
            FeatureSwitchCard(
                header: "Window Management",
                enableTitle: "Enable window management",
                enableSubtitle:
                    "Moves the window you were last in, using the Accessibility permission Tinycast already uses to paste.",
                systemImage: "macwindow",
                launcherSubtitle: "Find the window commands in launcher search.",
                isEnabled: $settings.windowManagementEnabled,
                showsInLauncher: $settings.windowManagementShowInLauncher)

            Group {
                optionsCard
                commandsCard
            }
            // Same dim as ShortcutsSettingsView's hidden-category card; the switch above stays live.
            .opacity(settings.windowManagementEnabled ? 1 : 0.45)
            .disabled(!settings.windowManagementEnabled)
        }
    }

    private var optionsCard: some View {
        SettingsCard(header: "Options") {
            SettingsRow(
                title: "Cycle sizes on repeat",
                subtitle:
                    "Triggering a half again steps it through a third and two thirds before returning.",
                systemImage: "arrow.triangle.2.circlepath",
                tint: .blue
            ) {
                Toggle("Cycle sizes on repeat", isOn: $settings.windowCycleOnRepeat)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("Cycle sizes on repeat")
            }

            SettingsDivider()

            SettingsRow(
                title: "Gap between windows",
                subtitle: "Points left between tiled windows and around the screen edge.",
                systemImage: "square.split.2x1",
                tint: .blue
            ) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(String(localized: "\(settings.windowGap) pt"))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Stepper(
                        "Gap between windows", value: $settings.windowGap, in: 0...64, step: 2)
                        .labelsHidden()
                }
            }
        }
    }

    private var commandsCard: some View {
        SettingsCard(header: "Commands") {
            ForEach(Array(WindowCommandCatalog.grouped().enumerated()), id: \.element.group) { index, section in
                if index > 0 { SettingsDivider() }
                WindowCommandGroupHeader(title: section.group.title)
                ForEach(section.commands) { command in
                    WindowCommandSettingsRow(command: command)
                }
            }
        }
    }
}

private struct WindowCommandGroupHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.Typography.sectionHeader)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xs)
    }
}

/// One command: its shortcut recorder and the launcher-visibility checkbox, mirroring
/// `ShortcutsSettingsView`'s row so both lists behave identically.
private struct WindowCommandSettingsRow: View {
    let command: WindowCommand
    @EnvironmentObject private var visibility: VisibilityStore
    // Hover lives on the row so a mouse sweep repaints only the rows entering and leaving.
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: command.sfSymbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: Theme.Size.settingsRowIcon)

            Text(command.name)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: Theme.Spacing.lg)

            ShortcutRecorder(action: .windowCommand(id: command.id))

            Toggle("", isOn: visibilityBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("Show in launcher")
                .accessibilityLabel("Show \(command.name) in launcher")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(hovered ? Theme.Colors.rowHover : .clear)
                .padding(.horizontal, Theme.Spacing.sm)
        )
        .onHover { hovered = $0 }
    }

    /// `VisibilityStore` keys on the entry, so this builds the same entry `AppIndex` publishes.
    private var entry: AppEntry {
        AppEntry(
            id: command.entryID, name: command.name,
            url: URL(string: "tinycast://window-command/" + command.id.rawValue)!, bundleID: nil,
            kind: .windowCommand)
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { visibility.isItemVisible(entry) },
            set: { visibility.setItemVisible($0, for: entry) })
    }
}
