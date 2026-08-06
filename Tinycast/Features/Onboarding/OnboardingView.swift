import AppKit
import Combine
import SwiftUI

/// First-launch wizard: set the palette shortcut, offer Accessibility + launch-at-login, offer a Raycast import, then drop into the launcher. Re-runnable from Settings. Reuses the app's own controls (`ShortcutRecorder`, `SettingsCard`, `BackupActions`) so it looks and behaves like the rest of Tinycast.
struct OnboardingView: View {
    @State private var step = 0
    @State private var model = OnboardingModel()
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings
    @Environment(HotKeyManager.self) private var hotKeys

    @State private var accessibilityTrusted = Permissions.isAccessibilityTrusted()
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let lastStep = 3
    /// Fixed AppKit-owned size, chosen to fit the tallest onboarding step.
    static let windowSize = CGSize(width: 520, height: 458)

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            hero
            stepContent
                .frame(maxHeight: .infinity, alignment: .top)
            footer
        }
        .padding(.top, Theme.Spacing.xxl)
        .padding([.horizontal, .bottom], Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.clear],
                startPoint: .top, endPoint: .center)
        )
        // Extend under the transparent titlebar (top padding clears the traffic lights) so the window height equals the fixed content height.
        .ignoresSafeArea()
        // Onboarding's shortcut step has a recorder too, and it isn't inside a `SettingsPane`.
        .shortcutRecorderPopoverHost()
        .animation(.easeInOut(duration: 0.2), value: step)
        .onAppear { accessibilityTrusted = Permissions.isAccessibilityTrusted() }
        .onReceive(refreshTimer) { _ in
            let trusted = Permissions.isAccessibilityTrusted()
            if trusted != accessibilityTrusted { accessibilityTrusted = trusted }
        }
    }

    // MARK: - Hero (icon/glyph + title + subtitle)

    private var hero: some View {
        VStack(spacing: Theme.Spacing.md) {
            heroMark
            VStack(spacing: Theme.Spacing.xs) {
                Text(title.localizedUI)
                    .font(.title2.weight(.bold))
                Text(subtitle.localizedUI)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var heroMark: some View {
        if step == 0 {
            Image(nsImage: Self.appIcon)
                .resizable()
                .frame(width: 60, height: 60)
        } else {
            Image(systemName: heroSymbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(heroTint)
                .frame(width: 60, height: 60)
                .background(Circle().fill(heroTint.opacity(0.14)))
        }
    }

    private var title: String {
        switch step {
        case 0: "Welcome to Tinycast"
        case 1: "Enable Pasting"
        case 2: "Import from Raycast"
        default: "You're all set"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: "Set a shortcut to summon the launcher from anywhere."
        case 1: "Let Tinycast paste items back into the app you were using."
        case 2: "Bring your shortcuts, favorites, and clipboard history along."
        default: readyMessage
        }
    }

    private var heroSymbol: String {
        switch step {
        case 1: "accessibility"
        case 2: "wand.and.stars"
        default: "checkmark"
        }
    }

    private var heroTint: Color {
        switch step {
        case 1: .blue
        case 2: .orange
        default: .green
        }
    }

    private var readyMessage: String {
        if let caps = hotKeys.binding(for: .togglePalette)?.keycaps {
            return String(localized: "Press \(caps.joined()) anytime to start using Tinycast.")
        }
        return String(localized: "Tinycast is ready. Set a shortcut in Settings to summon it.")
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: shortcutStep
        case 1: accessibilityStep
        case 2: raycastStep
        default: doneStep
        }
    }

    private var shortcutStep: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SettingsCard {
                SettingsRow(
                    title: "App Launcher",
                    subtitle: "Press this shortcut to open Tinycast.",
                    systemImage: "magnifyingglass", tint: .blue
                ) {
                    ShortcutRecorder(action: .togglePalette)
                }
                SettingsDivider()
                SettingsRow(
                    title: "Launch at login",
                    subtitle: "Start Tinycast automatically when you log in.",
                    systemImage: "power", tint: .green
                ) {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
            caption("You can change these anytime in Settings.")
        }
    }

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SettingsCard {
                SettingsRow(
                    title: "Accessibility",
                    subtitle:
                        "Allows pasting clipboard items and expanded snippets into active apps.",
                    systemImage: "accessibility", tint: .blue
                ) {
                    statusBadge
                }
            }
            caption("Optional — you can enable this later in Settings › Permissions.")
        }
    }

    private var raycastStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SettingsCard {
                SettingsRow(
                    title: "Raycast Export",
                    subtitle: model.fileSubtitle,
                    systemImage: "doc.badge.gearshape", tint: .orange
                ) {
                    Button("Choose…") { model.chooseFile() }.controlSize(.small)
                }
                SettingsDivider()
                SettingsRow(
                    title: "Passphrase",
                    subtitle: "The password you set when exporting from Raycast.",
                    systemImage: "key", tint: .gray
                ) {
                    SecureField("Passphrase", text: $model.passphrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onSubmit { model.run() }
                }
            }
            RaycastImportSelection(selection: $model.selection, format: model.format)
                .padding(.horizontal, Theme.Spacing.xs)
            if let status = model.status {
                importStatus(status)
            } else {
                caption("Optional — you can import later in Settings › Backup.")
            }
        }
    }

    private var doneStep: some View {
        caption("Everything's ready. Hit Get Started to open the launcher.")
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Footer (step dots + navigation)

    private var footer: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0...Self.lastStep, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: 7, height: 7)
                }
            }
            HStack {
                if step > 0 {
                    Button {
                        step -= 1
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if showsSkip {
                    Button("Skip") { advance() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                if step == 2 && model.importing {
                    Button {} label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            ProgressView().controlSize(.small)
                            Text("Importing…")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(true)
                } else {
                    Button(primaryTitle.localizedUI, action: primaryAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(primaryDisabled)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var showsSkip: Bool {
        (step == 1 && !accessibilityTrusted) || (step == 2 && !model.didImport)
    }

    private var primaryTitle: String {
        switch step {
        case 0: "Continue"
        case 1: accessibilityTrusted ? "Continue" : "Grant Access"
        case 2:
            if model.didImport {
                "Continue"
            } else if model.importing {
                "Importing…"
            } else {
                "Import"
            }
        default: "Get Started"
        }
    }

    private var primaryDisabled: Bool {
        step == 2 && !model.didImport && !model.canImport
    }

    private func primaryAction() {
        switch step {
        case 1 where !accessibilityTrusted:
            Permissions.openAccessibilitySettings()
        case 2 where !model.didImport:
            model.run()
        case Self.lastStep:
            core.paletteCoordinator.finishOnboarding()
        default:
            advance()
        }
    }

    private func advance() {
        step = min(step + 1, Self.lastStep)
    }

    // MARK: - Shared bits

    private func caption(_ text: String) -> some View {
        Text(text.localizedUI)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, Theme.Spacing.xs)
    }

    @ViewBuilder
    private func importStatus(_ status: OnboardingModel.ImportStatus) -> some View {
        switch status {
        case .success(let message):
            statusLine(message, systemImage: "checkmark.circle.fill", tint: .green)
        case .failure(let message):
            statusLine(message, systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }
    }

    private func statusLine(_ message: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(message).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.xs)
    }

    private var statusBadge: some View {
        HStack(spacing: Theme.Spacing.xs + 1) {
            Image(
                systemName: accessibilityTrusted
                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text((accessibilityTrusted ? "Granted" : "Not granted").localizedUI)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            Capsule().fill((accessibilityTrusted ? Color.green : Color.orange).opacity(0.14)))
    }

    // Read the bundled .icns directly: `NSApp.applicationIconImage` is the generic placeholder until LaunchServices registers the app (it hasn't when run from `build/`).
    private static let appIcon: NSImage = {
        if let name = Bundle.main.infoDictionary?["CFBundleIconFile"] as? String,
            let url = Bundle.main.url(forResource: name, withExtension: "icns"),
            let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }()
}

/// Owns the Raycast import step's state and the async import call, kept off the view so lifetimes are explicit and the body stays declarative.
@MainActor
@Observable
final class OnboardingModel {
    enum ImportStatus {
        case success(String)
        case failure(String)
    }

    var file: URL?
    var passphrase = ""
    var importing = false
    var status: ImportStatus?
    var selection: RaycastImportOptions = .all
    var format: RaycastFormat?

    var canImport: Bool { format != nil && !passphrase.isEmpty && !selection.isEmpty && !importing }
    var didImport: Bool {
        if case .success = status { return true }
        return false
    }

    var fileSubtitle: String {
        guard let name = file?.lastPathComponent else {
            return "Choose a .rayconfig file exported from Raycast."
        }
        return "\(name) — \(format?.title ?? String(localized: "not a Raycast export"))"
    }

    func chooseFile() {
        guard let url = BackupActions.pickRaycastFile() else { return }
        file = url
        format = BackupActions.detectRaycastFormat(of: url)
        status = nil
    }

    func run() {
        guard canImport, let file else { return }
        importing = true
        status = nil
        Task {
            defer { importing = false }
            do {
                let outcome = try await BackupActions.importRaycast(
                    file: file, passphrase: passphrase, options: selection)
                status = .success(BackupActions.raycastSummaryText(outcome))
                passphrase = ""
            } catch {
                status = .failure(error.localizedDescription)
            }
        }
    }
}
