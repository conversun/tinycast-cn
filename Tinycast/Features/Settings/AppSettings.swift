import SwiftUI

/// UserDefaults keys shared between `@AppStorage` call sites so the App and the Settings UI bind to the same key.
enum SettingsKey {
    /// Menu-bar icon visibility — read by `MenuBarExtra(isInserted:)` and the Settings toggle.
    static let showInMenuBar = "showInMenuBar"
}

/// Delay before a closed palette resets to the root launcher; raw value is seconds in UserDefaults, so an unset key (0) reads as `.immediately`, the default.
enum PopToRootTimeout: Int, CaseIterable, Identifiable, Sendable {
    case immediately = 0
    case afterFive = 5
    case afterFifteen = 15
    case afterThirty = 30
    case afterSixty = 60
    case afterNinety = 90

    var id: Int { rawValue }

    var title: String {
        self == .immediately ? "Immediately" : "After \(rawValue) seconds"
    }

    var interval: TimeInterval { TimeInterval(rawValue) }
}

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults = UserDefaults.standard
    private enum Key {
        static let clipboardRetention = "clipboardRetentionDays"
        static let clipboardDisabledApps = "clipboardDisabledApps"
        static let hyperKey = "hyperKeyPhysicalKey"
        static let hyperKeyIncludesShift = "hyperKeyIncludesShift"
        static let hyperKeyQuickPress = "hyperKeyQuickPress"
        static let hyperKeyReplacesGlyph = "hyperKeyReplacesGlyph"
        static let emojiSkinTone = "emojiSkinTone"
        static let popToRootTimeout = "popToRootTimeout"
        static let compactMode = "compactMode"
        static let showFavoritesInCompactMode = "showFavoritesInCompactMode"
        static let searchScopes = "launcherSearchScopes"
        static let openOnCursorScreen = "openOnCursorScreen"
        static let customCommandsEnabled = "customCommandsEnabled"
        static let customCommandsShowInLauncher = "customCommandsShowInLauncher"
        static let snippetsEnabled = "snippetsEnabled"
        static let snippetsShowInLauncher = "snippetsShowInLauncher"
        static let windowManagementEnabled = "windowManagementEnabled"
        static let windowManagementShowInLauncher = "windowManagementShowInLauncher"
        static let windowGap = "windowManagementGap"
        static let windowCycleOnRepeat = "windowManagementCycleOnRepeat"
        static let quicklinksEnabled = "quicklinksEnabled"
        static let quicklinksShowInLauncher = "quicklinksShowInLauncher"
        static let quicklinkOpensNewWindow = "quicklinkOpensNewWindow"
        static let quicklinkSelectionFallback = "quicklinkSelectionFallback"
        static let quicklinkConfirmsBeforeDelete = "quicklinkConfirmsBeforeDelete"
    }

    /// Folders (and individual `.app` bundles) `AppIndex` scans, in scan order. Editing this re-indexes — `AppIndex.start(settings:)` observes it.
    var searchScopes: [String] {
        didSet { defaults.set(searchScopes, forKey: Key.searchScopes) }
    }

    var clipboardRetention: ClipboardRetention {
        didSet { defaults.set(clipboardRetention.rawValue, forKey: Key.clipboardRetention) }
    }

    /// Bundle IDs whose clipboard changes are never recorded. Ordered so the Settings list is stable.
    var clipboardDisabledApps: [String] {
        didSet { defaults.set(clipboardDisabledApps, forKey: Key.clipboardDisabledApps) }
    }

    var launchAtLogin: Bool {
        didSet { LaunchAtLogin.set(launchAtLogin) }
    }

    /// The physical key remapped to the Hyper chord; `HyperKeyTap` reacts via its observer.
    var hyperKey: HyperKeyPhysicalKey {
        didSet { defaults.set(hyperKey.rawValue, forKey: Key.hyperKey) }
    }

    /// Whether Hyper is ⌃⌥⇧⌘ (on) or ⌃⌥⌘ (off).
    var hyperKeyIncludesShift: Bool {
        didSet { defaults.set(hyperKeyIncludesShift, forKey: Key.hyperKeyIncludesShift) }
    }

    var hyperKeyQuickPress: HyperKeyQuickPress {
        didSet { defaults.set(hyperKeyQuickPress.rawValue, forKey: Key.hyperKeyQuickPress) }
    }

    /// Collapse the Hyper modifier set to "✦" wherever shortcut keycaps render.
    var hyperKeyReplacesGlyph: Bool {
        didSet { defaults.set(hyperKeyReplacesGlyph, forKey: Key.hyperKeyReplacesGlyph) }
    }

    /// Preferred skin tone applied to modifier-capable emoji at render and copy time.
    var emojiSkinTone: EmojiSkinTone {
        didSet { defaults.set(emojiSkinTone.rawValue, forKey: Key.emojiSkinTone) }
    }

    /// How long a closed palette keeps its state before popping back to the root launcher.
    var popToRootTimeout: PopToRootTimeout {
        didSet { defaults.set(popToRootTimeout.rawValue, forKey: Key.popToRootTimeout) }
    }

    /// Summon the launcher as a slim search bar that expands into the full list on typing.
    var compactMode: Bool {
        didSet { defaults.set(compactMode, forKey: Key.compactMode) }
    }

    /// Pin favorite app icons to the right of the compact search bar (⌘1–⌘5 to launch).
    var showFavoritesInCompactMode: Bool {
        didSet { defaults.set(showFavoritesInCompactMode, forKey: Key.showFavoritesInCompactMode) }
    }

    /// Summon the palette on the display under the pointer instead of the one holding the menu bar.
    var openOnCursorScreen: Bool {
        didSet { defaults.set(openOnCursorScreen, forKey: Key.openOnCursorScreen) }
    }

    // Feature switches, off out of the box: off means fully off — no launcher entries, no shortcuts, no keyword expansion, no store. `AppCore` observes all four and re-projects.
    var customCommandsEnabled: Bool {
        didSet { defaults.set(customCommandsEnabled, forKey: Key.customCommandsEnabled) }
    }

    /// With the feature on, controls only whether its launcher section appears.
    var customCommandsShowInLauncher: Bool {
        didSet {
            defaults.set(customCommandsShowInLauncher, forKey: Key.customCommandsShowInLauncher)
        }
    }

    /// Doubles as keyword-expansion consent, so it only flips on through `AppCore.setSnippetsEnabled`'s confirmation and never rides in a settings backup.
    var snippetsEnabled: Bool {
        didSet { defaults.set(snippetsEnabled, forKey: Key.snippetsEnabled) }
    }

    var snippetsShowInLauncher: Bool {
        didSet { defaults.set(snippetsShowInLauncher, forKey: Key.snippetsShowInLauncher) }
    }

    /// Off means fully off: no launcher entries, and a still-registered shortcut moves nothing.
    var windowManagementEnabled: Bool {
        didSet { defaults.set(windowManagementEnabled, forKey: Key.windowManagementEnabled) }
    }

    var windowManagementShowInLauncher: Bool {
        didSet {
            defaults.set(windowManagementShowInLauncher, forKey: Key.windowManagementShowInLauncher)
        }
    }

    /// Points left between tiled windows and around the screen edge. `WindowLayout` caps anything absurd.
    var windowGap: Int {
        didSet { defaults.set(windowGap, forKey: Key.windowGap) }
    }

    /// Re-triggering a half steps it through ⅓ and ⅔ instead of re-applying the same frame.
    var windowCycleOnRepeat: Bool {
        didSet { defaults.set(windowCycleOnRepeat, forKey: Key.windowCycleOnRepeat) }
    }

    /// Off means fully off: no launcher entries, no Quicklinks commands, and a still-registered
    /// shortcut opens nothing.
    var quicklinksEnabled: Bool {
        didSet { defaults.set(quicklinksEnabled, forKey: Key.quicklinksEnabled) }
    }

    var quicklinksShowInLauncher: Bool {
        didSet { defaults.set(quicklinksShowInLauncher, forKey: Key.quicklinksShowInLauncher) }
    }

    /// Ask the handler for a new window rather than reusing its frontmost tab. Off is the macOS
    /// default, which is what "prefer existing tabs" means.
    var quicklinkOpensNewWindow: Bool {
        didSet { defaults.set(quicklinkOpensNewWindow, forKey: Key.quicklinkOpensNewWindow) }
    }

    /// What `{selection}` does when there is no readable selection to pass.
    var quicklinkSelectionFallback: QuicklinkSelectionFallback {
        didSet {
            defaults.set(quicklinkSelectionFallback.rawValue, forKey: Key.quicklinkSelectionFallback)
        }
    }

    var quicklinkConfirmsBeforeDelete: Bool {
        didSet {
            defaults.set(quicklinkConfirmsBeforeDelete, forKey: Key.quicklinkConfirmsBeforeDelete)
        }
    }

    init() {
        // integer(forKey:) returns 0 when unset, which no case matches — falls through to 3 Months.
        clipboardRetention =
            ClipboardRetention(rawValue: defaults.integer(forKey: Key.clipboardRetention))
            ?? .threeMonths
        // Password managers are excluded out of the box; the defaults apply only until the user first edits the list.
        clipboardDisabledApps =
            defaults.stringArray(forKey: Key.clipboardDisabledApps)
            ?? ["com.apple.keychainaccess", "com.apple.Passwords"]
        launchAtLogin = LaunchAtLogin.isEnabled
        hyperKey =
            defaults.string(forKey: Key.hyperKey).flatMap(HyperKeyPhysicalKey.init) ?? .none
        // The two Bools default to true, so absence must be distinguished from stored `false`.
        hyperKeyIncludesShift =
            defaults.object(forKey: Key.hyperKeyIncludesShift) == nil
            || defaults.bool(forKey: Key.hyperKeyIncludesShift)
        hyperKeyQuickPress =
            defaults.string(forKey: Key.hyperKeyQuickPress).flatMap(HyperKeyQuickPress.init)
            ?? .none
        hyperKeyReplacesGlyph =
            defaults.object(forKey: Key.hyperKeyReplacesGlyph) == nil
            || defaults.bool(forKey: Key.hyperKeyReplacesGlyph)
        emojiSkinTone =
            defaults.string(forKey: Key.emojiSkinTone).flatMap(EmojiSkinTone.init) ?? .none
        popToRootTimeout =
            PopToRootTimeout(rawValue: defaults.integer(forKey: Key.popToRootTimeout))
            ?? .immediately
        compactMode = defaults.bool(forKey: Key.compactMode)
        // Defaults to true, so absence must be distinguished from a stored `false`.
        showFavoritesInCompactMode =
            defaults.object(forKey: Key.showFavoritesInCompactMode) == nil
            || defaults.bool(forKey: Key.showFavoritesInCompactMode)
        // An unset key means "never configured" and seeds the defaults; a stored empty array is a user who deliberately cleared the list.
        searchScopes = defaults.stringArray(forKey: Key.searchScopes) ?? SearchScopes.defaults
        openOnCursorScreen =
            defaults.object(forKey: Key.openOnCursorScreen) == nil
            || defaults.bool(forKey: Key.openOnCursorScreen)
        // The enable switches ship off; the launcher toggles default to true, so absence must be distinguished from a stored `false`.
        customCommandsEnabled = defaults.bool(forKey: Key.customCommandsEnabled)
        customCommandsShowInLauncher =
            defaults.object(forKey: Key.customCommandsShowInLauncher) == nil
            || defaults.bool(forKey: Key.customCommandsShowInLauncher)
        snippetsEnabled = defaults.bool(forKey: Key.snippetsEnabled)
        snippetsShowInLauncher =
            defaults.object(forKey: Key.snippetsShowInLauncher) == nil
            || defaults.bool(forKey: Key.snippetsShowInLauncher)
        windowManagementEnabled = defaults.bool(forKey: Key.windowManagementEnabled)
        windowManagementShowInLauncher =
            defaults.object(forKey: Key.windowManagementShowInLauncher) == nil
            || defaults.bool(forKey: Key.windowManagementShowInLauncher)
        // Unset reads as 0, which is the intended default anyway — no gap.
        windowGap = defaults.integer(forKey: Key.windowGap)
        windowCycleOnRepeat = defaults.bool(forKey: Key.windowCycleOnRepeat)
        quicklinksEnabled = defaults.bool(forKey: Key.quicklinksEnabled)
        quicklinksShowInLauncher =
            defaults.object(forKey: Key.quicklinksShowInLauncher) == nil
            || defaults.bool(forKey: Key.quicklinksShowInLauncher)
        quicklinkOpensNewWindow = defaults.bool(forKey: Key.quicklinkOpensNewWindow)
        quicklinkSelectionFallback =
            defaults.string(forKey: Key.quicklinkSelectionFallback)
            .flatMap(QuicklinkSelectionFallback.init) ?? .ask
        quicklinkConfirmsBeforeDelete =
            defaults.object(forKey: Key.quicklinkConfirmsBeforeDelete) == nil
            || defaults.bool(forKey: Key.quicklinkConfirmsBeforeDelete)
    }
}
