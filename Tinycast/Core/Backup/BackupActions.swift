import AppKit
import UniformTypeIdentifiers

/// User-facing entry points for the backup flows, shared between the Settings pane and the palette commands. The Raycast decrypt runs off the main actor (scrypt is CPU-heavy); everything else is quick.
@MainActor
enum BackupActions {
    struct RaycastOutcome {
        var summary: SettingsBackup.ApplySummary
        var clipboardImported: Int
        var snippetsImported: Int
        /// Set when the snippet files couldn't be written; the rest of the import still applied.
        var snippetsError: String?
        var missingImages: Int
    }

    // MARK: - Tinycast native (own file panels; dialogs come from `AppCore`)

    /// The JSON save panel, shared with the quicklinks archive. Tinycast is an accessory app, so it
    /// has to activate itself before a modal panel or the panel opens behind everything.
    static func chooseSaveLocation(named base: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(base)-\(dateStamp()).json"
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func chooseJSONFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func exportSettings() async {
        guard let url = chooseSaveLocation(named: "Tinycast-Settings") else { return }
        do {
            try SettingsBackup.gather().encoded().write(to: url, options: .atomic)
        } catch {
            await present(
                title: "Export Failed", message: error.localizedDescription,
                symbol: "square.and.arrow.up")
        }
    }

    static func importSettings() async {
        guard let url = chooseJSONFile() else { return }
        do {
            let backup = try SettingsBackup(json: try Data(contentsOf: url))
            let commandCount = backup.customCommands?.count ?? 0
            let shortcutCount = backup.hotkeys?.customCommands?.count ?? 0
            guard await confirmExecutableImport(commands: commandCount, shortcuts: shortcutCount)
            else { return }
            await present(
                title: "Settings Imported", message: summaryText(backup.apply()),
                symbol: importSymbol, tone: .success)
        } catch {
            await present(
                title: "Import Failed", message: error.localizedDescription, symbol: importSymbol)
        }
    }

    // MARK: - Raycast (the pane owns the passphrase field + inline status)

    static func importRaycast(file: URL, passphrase: String, options: RaycastImportOptions = .all)
        async throws -> RaycastOutcome {
        // Detect, decrypt and parse off the main actor, inside an autoreleasepool so the large JSON tree drains at once instead of spiking the main-thread footprint. Only the value-type Result crosses back.
        let result = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                try RaycastImport.read(file: file, passphrase: passphrase).selecting(options)
            }
        }.value
        // A snippet write failure is reported in the outcome rather than thrown: it must not abort the settings and clipboard the user also asked for.
        var snippetsImported = 0
        var snippetsError: String?
        if !result.snippets.isEmpty {
            do {
                // Starting the (lazily started) store first gets the imported snippets into the launcher immediately. With the feature switched off the files are still written and appear once it's re-enabled.
                if AppCore.shared.settings.snippetsEnabled {
                    await AppCore.shared.snippetsStore.start()
                }
                snippetsImported =
                    try await AppCore.shared.snippetsStore.importSnippets(result.snippets).count
            } catch {
                snippetsError = error.localizedDescription
            }
        }
        let summary = result.backup.apply()
        let imported =
            result.clipboard.isEmpty
            ? 0 : AppCore.shared.clipboardStore.importEntries(result.clipboard)
        return RaycastOutcome(
            summary: summary,
            clipboardImported: imported,
            snippetsImported: snippetsImported,
            snippetsError: snippetsError,
            missingImages: result.missingImages)
    }

    /// Every Raycast channel (stable, beta, alpha, internal) shares this bundle-id prefix.
    static let raycastBundleIDPrefix = "com.raycast"

    static func isRaycastBundleID(_ id: String) -> Bool { id.hasPrefix(raycastBundleIDPrefix) }

    /// Quit any running Raycast app so its hotkeys stop clashing; skip `.prohibited` (pure background helpers/XPC).
    static func quitRaycast() {
        for app in NSWorkspace.shared.runningApplications
        where app.bundleIdentifier.map(isRaycastBundleID) == true
            && app.activationPolicy != .prohibited {
            app.terminate()
        }
    }

    /// Shared `.rayconfig` file picker used by the Backup pane and onboarding.
    static func pickRaycastFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Nil when the file isn't a Raycast export at all. Reads only the leading bytes — mapped, not copied — so the pane can label a file before a passphrase is typed.
    static func detectRaycastFormat(of file: URL) -> RaycastFormat? {
        guard let raw = try? Data(contentsOf: file, options: .mappedIfSafe) else { return nil }
        return try? RaycastFormat.detect(raw)
    }

    // MARK: - Helpers

    static func summaryText(_ s: SettingsBackup.ApplySummary) -> String {
        appliedText(s) ?? nothingImportedText
    }

    static let nothingImportedText = String(localized: "Nothing to import from this file.")

    /// `nil` when the backup applied no settings, so callers that also import clipboard or snippets can compose one combined sentence instead of contradicting the empty-import wording.
    static func appliedText(_ s: SettingsBackup.ApplySummary) -> String? {
        var parts: [String] = []
        if s.settingsFields > 0 {
            parts.append(String(localized: "\(s.settingsFields) settings"))
        }
        if s.hotkeys > 0 { parts.append(String(localized: "\(s.hotkeys) shortcuts")) }
        if s.favorites > 0 { parts.append(String(localized: "\(s.favorites) favorites")) }
        if s.hiddenItems > 0 {
            parts.append(String(localized: "\(s.hiddenItems) hidden items"))
        }
        if s.customCommands > 0 {
            parts.append(String(localized: "\(s.customCommands) custom commands"))
        }
        if s.quicklinks > 0 { parts.append(String(localized: "\(s.quicklinks) quicklinks")) }
        guard !parts.isEmpty else { return nil }
        return String(format: "Applied %@.".localizedUI, parts.joined(separator: ", "))
    }

    static func raycastSummaryText(_ outcome: RaycastOutcome) -> String {
        var parts: [String] = []
        if let applied = appliedText(outcome.summary) { parts.append(applied) }
        if outcome.clipboardImported > 0 {
            parts.append(String(localized: "Imported \(outcome.clipboardImported) clipboard entries."))
        }
        if outcome.snippetsImported == 1 {
            parts.append(String(localized: "Imported 1 snippet."))
        } else if outcome.snippetsImported > 1 {
            parts.append(String(localized: "Imported \(outcome.snippetsImported) snippets."))
        }
        if let snippetsError = outcome.snippetsError {
            parts.append(String(localized: "Couldn’t import snippets: \(snippetsError)"))
        }
        var message = parts.isEmpty ? nothingImportedText : parts.joined(separator: " ")
        if outcome.missingImages > 0 {
            message += " "
                + String(localized: "\(outcome.missingImages) images were unavailable and skipped.")
        }
        return message
    }

    private static func confirmExecutableImport(commands: Int, shortcuts: Int) async -> Bool {
        guard commands > 0 || shortcuts > 0 else { return true }
        let commandText = commands == 1
            ? String(localized: "1 custom command")
            : String(localized: "\(commands) custom commands")
        let shortcutText =
            shortcuts == 1
            ? String(localized: "1 global shortcut")
            : String(localized: "\(shortcuts) global shortcuts")
        // Red glyph because this is a real security warning, but a plain button: importing a file
        // destroys nothing, so the confirm action isn't destructive.
        return await AppCore.shared.confirm(
            title: String(localized: "Import executable commands?"),
            message: String(
                format:
                    "This backup contains %@ and %@. Custom commands can run arbitrary shell code. Only import files you trust."
                    .localizedUI,
                commandText, shortcutText),
            symbol: importSymbol, confirmTitle: String(localized: "Import"),
            confirmRole: .standard)
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Every import dialog — the warning, the failure and the summary — carries the same glyph, so the flow reads as one thing.
    private static let importSymbol = "square.and.arrow.down"

    private static func present(
        title: String, message: String, symbol: String, tone: DialogTone = .danger
    ) async {
        await AppCore.shared.showNotice(
            title: title, message: message, symbol: symbol, tone: tone)
    }
}
