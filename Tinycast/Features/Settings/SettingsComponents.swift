import SwiftUI

// Reusable building blocks for the Settings window; all metrics come from `Theme` so Settings shares one vocabulary with the palette.

// MARK: - Pane scaffold

/// Standard layout for a settings pane (title + subtitle header, then scrollable content) so headers, insets and scroll behaviour stay identical across the app.
struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                SettingsHeader(title: title, subtitle: subtitle)
                content
            }
            // Ignore the transparent-titlebar safe area and use one fixed `xxl` inset every side instead (the titlebar band is taller than the rhythm we want; traffic lights sit over the sidebar, so nothing collides).
            .padding(Theme.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Settings use the native thin overlay scroller (not the palette's SwiftUI `thinScrollbar`), matching the other windowed setting lists.
            .overlayScroller()
        }
        .ignoresSafeArea(edges: .top)
        // Outside the ScrollView, so an open recorder's callout draws over the pane instead of being clipped by it.
        .shortcutRecorderPopoverHost()
    }
}

/// The title + subtitle block at the top of every pane.
struct SettingsHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title.localizedUI)
                .font(.title2.weight(.bold))
            Text(subtitle.localizedUI)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Grouped card

/// A rounded, hairline-bordered container grouping related rows — the macOS System Settings "card" (rows split by inset dividers via `SettingsRow`/`SettingsDivider`).
struct SettingsCard<Content: View>: View {
    var header: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let header {
                Text(header.localizedUI)
                    .font(Theme.Typography.sectionHeader)
                    .foregroundStyle(.secondary)
                    .padding(.leading, Theme.Spacing.xs)
            }
            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Theme.Colors.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
                )
        }
    }
}

/// The identical top card of a feature pane (Custom Commands, Snippets): the master switch, then its launcher-visibility companion, which locks while the feature is off.
struct FeatureSwitchCard: View {
    let header: String
    let enableTitle: String
    let enableSubtitle: String
    let systemImage: String
    let launcherSubtitle: String
    @Binding var isEnabled: Bool
    @Binding var showsInLauncher: Bool

    var body: some View {
        SettingsCard(header: header) {
            SettingsRow(
                title: enableTitle,
                subtitle: enableSubtitle,
                systemImage: systemImage,
                tint: .green
            ) {
                Toggle(enableTitle.localizedUI, isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel(enableTitle.localizedUI)
            }
            SettingsDivider()
            SettingsRow(
                title: "Show in launcher",
                subtitle: launcherSubtitle,
                systemImage: "magnifyingglass",
                tint: .green
            ) {
                Toggle("Show in launcher", isOn: $showsInLauncher)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("Show in launcher")
            }
            // Same dim as ShortcutsSettingsView's hidden-category card.
            .opacity(isEnabled ? 1 : 0.45)
            .disabled(!isEnabled)
        }
    }
}

/// The filter field above a long settings list, styled like a card so it reads as part of the group below it.
struct SettingsSearchField: View {
    let prompt: String
    @Binding var query: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt.localizedUI, text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.body)
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(Theme.Colors.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
        )
    }
}

/// Inset divider between rows inside a `SettingsCard`, aligned under the row's title (past the icon).
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.cardStroke)
            .frame(height: 1)
            .padding(.leading, Theme.Spacing.xl + Theme.Size.settingsRowIcon + Theme.Spacing.lg)
    }
}

// MARK: - Row

/// A single settings line (optional SF Symbol, title with optional subtitle, trailing control); fixed vertical rhythm keeps every card aligned regardless of the control.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = .secondary
    /// Optional state indicator rendered after the title (green = active, orange = attention).
    var statusDot: Color?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: Theme.Size.settingsRowIcon)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(title.localizedUI)
                        .font(.body)
                    if let statusDot {
                        Circle()
                            .fill(statusDot)
                            .frame(width: Theme.Size.statusDot, height: Theme.Size.statusDot)
                    }
                }
                if let subtitle {
                    Text(subtitle.localizedUI)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.xl)
            trailing
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }
}

// MARK: - Callout

/// A tinted inset box for a notice or warning inside a `SettingsCard` — SF Symbol + title + optional message, with an optional trailing control (e.g. a fix-it button).
struct SettingsCallout<Trailing: View>: View {
    let title: String
    var message: String?
    var systemImage: String = "info.circle"
    var tint: Color = .secondary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: Theme.Size.settingsRowIcon)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                Text(title.localizedUI).font(.body)
                if let message {
                    Text(message.localizedUI)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.xl)
            trailing
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

extension SettingsCallout where Trailing == EmptyView {
    init(title: String, message: String? = nil, systemImage: String = "info.circle", tint: Color = .secondary) {
        self.init(title: title, message: message, systemImage: systemImage, tint: tint) { EmptyView() }
    }
}
