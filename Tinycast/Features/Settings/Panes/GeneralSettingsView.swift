import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings
    private var hyperTap: HyperKeyTap { core.hyperKeyTap }
    private var launcherRanking: LauncherRankingStore { core.launcherRanking }
    // Same UserDefaults key the `App` binds its `MenuBarExtra(isInserted:)` to — toggling here updates the menu-bar icon live, with no shared observable between them.
    @AppStorage(SettingsKey.showInMenuBar) private var showInMenuBar = true
    @State private var confirmingRankingReset = false

    /// The Hyper modifier chord as prose glyphs, tracking the Include Shift toggle.
    private var hyperGlyphs: String { settings.hyperKeyIncludesShift ? "⌃⌥⇧⌘" : "⌃⌥⌘" }

    private var hyperStatusDot: Color? {
        switch hyperTap.status {
        case .off: return nil
        case .active: return .green
        case .needsAccessibility: return .orange
        }
    }

    private var hyperSubtitle: String {
        guard settings.hyperKey != .none else {
            return String(
                format:
                    "Select a physical key to remap to the %@ modifier keys simultaneously."
                    .localizedUI,
                hyperGlyphs)
        }
        var text = String(
            format: "Pressing %@ will trigger the left %@ modifier keys.".localizedUI,
            settings.hyperKey.title.localizedUI, hyperGlyphs)
        if settings.hyperKeyReplacesGlyph {
            text += " " + "Hyper Key shortcuts will be shown in Tinycast with ✦.".localizedUI
        }
        if hyperTap.status == .needsAccessibility {
            text += " " + "Tinycast needs Accessibility access to remap keys.".localizedUI
        }
        return text
    }

    var body: some View {
        @Bindable var settings = settings
        return SettingsPane(
            title: "General",
            subtitle: "Global shortcuts and startup behaviour."
        ) {
            SettingsCard(header: "Global Shortcuts") {
                SettingsRow(
                    title: "App Launcher",
                    subtitle: "Summon the fuzzy app launcher.",
                    systemImage: "magnifyingglass",
                    tint: .blue
                ) {
                    ShortcutRecorder(action: .togglePalette)
                }
            }

            SettingsCard(header: "Search") {
                SettingsRow(
                    title: "Learned ranking",
                    subtitle:
                        "Tinycast privately learns which results you choose for each query. Reset all learned choices to restore the default order.",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: .blue
                ) {
                    Button("Reset…", role: .destructive) {
                        confirmingRankingReset = true
                    }
                    .controlSize(.small)
                    .disabled(launcherRanking.isEmpty)
                }
            }

            SettingsCard(header: "Hyper Key") {
                SettingsRow(
                    title: "Hyper Key",
                    subtitle: hyperSubtitle,
                    systemImage: "sparkle",
                    tint: .purple,
                    statusDot: hyperStatusDot
                ) {
                    if hyperTap.status == .needsAccessibility {
                        Button("Grant Access…") { Permissions.openAccessibilitySettings() }
                            .controlSize(.small)
                    }
                    Picker("", selection: $settings.hyperKey) {
                        ForEach(HyperKeyPhysicalKey.allCases) { key in
                            Text(key.title.localizedUI).tag(key)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: settings.hyperKey) { _, newKey in
                        // A Quick Press choice is meaningless for a different key.
                        settings.hyperKeyQuickPress = .none
                        if newKey != .none { Permissions.ensureAccessibility() }
                    }
                }
                if settings.hyperKey.hasOriginalFunction {
                    SettingsDivider()
                    SettingsRow(
                        title: "Quick Press",
                        subtitle: String(
                            format:
                                "Select an action to perform when %@ is pressed without any other keys."
                                .localizedUI,
                            settings.hyperKey.title.localizedUI),
                        systemImage: "hand.tap",
                        tint: .teal
                    ) {
                        Picker("", selection: $settings.hyperKeyQuickPress) {
                            Text("Does Nothing").tag(HyperKeyQuickPress.none)
                            if let original = settings.hyperKey.quickPressOriginalTitle {
                                Text(original.localizedUI).tag(HyperKeyQuickPress.originalKey)
                            }
                            Text("Trigger Escape").tag(HyperKeyQuickPress.escape)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                SettingsDivider()
                SettingsRow(
                    title: "Include Shift (⇧)",
                    subtitle: String(
                        format: "Hyper Key will remap to the %@ modifier keys.".localizedUI,
                        hyperGlyphs),
                    systemImage: "shift",
                    tint: .indigo
                ) {
                    Toggle("", isOn: $settings.hyperKeyIncludesShift)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(
                    title: String(
                        format: "Replace occurrences of %@ with ✦".localizedUI, hyperGlyphs),
                    subtitle: "Shortcuts containing the Hyper Key modifiers are shown with ✦.",
                    systemImage: "keyboard",
                    tint: .gray
                ) {
                    Toggle("", isOn: $settings.hyperKeyReplacesGlyph)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            SettingsCard(header: "Appearance") {
                SettingsRow(
                    title: "Compact mode",
                    subtitle:
                        "Open the launcher as a slim search bar that expands into the full list as you type.",
                    systemImage: "macwindow",
                    tint: .blue
                ) {
                    Toggle("", isOn: $settings.compactMode)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(
                    title: "Show favorites in compact mode",
                    subtitle:
                        "Pin favorite app icons to the right of the compact bar (⌘1–⌘5 to launch).",
                    systemImage: "star",
                    tint: .yellow
                ) {
                    Toggle("", isOn: $settings.showFavoritesInCompactMode)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(!settings.compactMode)
                }
                .opacity(settings.compactMode ? 1 : 0.5)
                SettingsDivider()
                SettingsRow(
                    title: "Follow the cursor across displays",
                    subtitle:
                        "Open the launcher on whichever display the pointer is on, rather than the one with the menu bar.",
                    systemImage: "display.2",
                    tint: .teal
                ) {
                    Toggle("", isOn: $settings.openOnCursorScreen)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            SettingsCard(header: "General") {
                SettingsRow(
                    title: "Launch at login",
                    subtitle: "Start Tinycast automatically when you log in.",
                    systemImage: "power",
                    tint: .green
                ) {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(
                    title: "Show in menu bar",
                    subtitle:
                        "Keep the Tinycast icon in the menu bar. Shortcuts still work when hidden.",
                    systemImage: "menubar.arrow.up.rectangle",
                    tint: .gray
                ) {
                    Toggle("", isOn: $showInMenuBar)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(
                    title: "Pop to Root Search",
                    subtitle: "Reset to the launcher this long after the window closes.",
                    systemImage: "arrow.uturn.backward",
                    tint: .indigo
                ) {
                    Picker("", selection: $settings.popToRootTimeout) {
                        ForEach(PopToRootTimeout.allCases) { timeout in
                            Text(timeout.title.localizedUI).tag(timeout)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsDivider()
                SettingsRow(
                    title: "Welcome Guide",
                    subtitle:
                        "Re-run the first-launch setup: shortcut, permissions, and Raycast import.",
                    systemImage: "sparkles",
                    tint: .yellow
                ) {
                    Button("Show…") { core.paletteCoordinator.showOnboarding() }
                        .controlSize(.small)
                }
            }
        }
        .confirmationDialog(
            "Reset learned launcher ranking?",
            isPresented: $confirmingRankingReset,
            titleVisibility: .visible
        ) {
            Button("Reset Ranking", role: .destructive) {
                launcherRanking.resetAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tinycast will relearn your preferred results as you use the launcher.")
        }
    }
}
