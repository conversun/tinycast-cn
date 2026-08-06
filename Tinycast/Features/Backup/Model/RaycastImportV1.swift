import Carbon.HIToolbox
import Foundation

/// Validates the plain Raycast values `RaycastV1Decoder` returns against Tinycast's domain types. Shares no mapper with `RaycastImportV2`: the two formats have almost no shape in common, so a merged mapper would branch at every field.
enum RaycastImportV1 {
    static func read(_ raw: Data, passphrase: String) throws -> RaycastImport.Result {
        let payload = try RaycastV1Decoder.payload(
            RaycastV1Decoder.decrypt(raw, passphrase: passphrase))

        var backup = SettingsBackup()
        backup.settings = settings(from: payload)
        backup.hotkeys = hotkeys(from: payload)
        backup.favoriteApps = payload.favorites.isEmpty ? nil : payload.favorites

        return RaycastImport.Result(
            backup: backup,
            clipboard: payload.clipboard,
            snippets: payload.snippets.map {
                Snippet(name: $0.name, text: $0.text, keyword: $0.keyword)
            },
            missingImages: payload.missingImages)
    }

    /// A Carbon key code here, unlike v2's `"caps_lock"` string; nothing ever maps to `.none`, since an export without a Hyper key must not clear one the user already configured.
    private static let hyperKeys: [Int: HyperKeyPhysicalKey] = [
        kVK_CapsLock: .capsLock,
        kVK_RightControl: .rightControl,
        kVK_RightShift: .rightShift,
        kVK_RightOption: .rightOption,
        kVK_RightCommand: .rightCommand
    ]

    private static func settings(from payload: RaycastV1Payload) -> SettingsBackup.SettingsData? {
        var data = SettingsBackup.SettingsData()
        var mapped = false

        // Exact-match only: a Raycast timeout outside Tinycast's option set is skipped, not clamped.
        if let secs = payload.popToRootTimeout, let timeout = PopToRootTimeout(rawValue: secs) {
            data.popToRootSeconds = timeout.rawValue
            mapped = true
        }
        if let tone = skinTone(payload.emojiSkinTone) {
            data.emojiSkinTone = tone
            mapped = true
        }
        // A disabled Hyper key carries no physical key to import, but its shift preference still applies.
        if let hyperKey = payload.hyperKey {
            if hyperKey.enabled, let key = hyperKeys[hyperKey.keyCode] {
                data.hyperKey = key.rawValue
                mapped = true
            }
            if let includesShift = hyperKey.includesShift {
                data.hyperKeyIncludesShift = includesShift
                mapped = true
            }
        }
        if let useIcon = payload.useHyperKeyIcon {
            data.hyperKeyReplacesGlyph = useIcon
            mapped = true
        }
        // Raycast's window mode is a string ("compact"/"default"/…); Tinycast only has the compact toggle.
        if let mode = payload.windowMode {
            data.compactMode = (mode == "compact")
            mapped = true
        }
        if let showFavorites = payload.showFavoritesInCompactMode {
            data.showFavoritesInCompactMode = showFavorites
            mapped = true
        }
        if let visible = payload.statusBarIsVisible {
            data.showInMenuBar = visible
            mapped = true
        }
        if let disabled = payload.clipboardDisabledApps, !disabled.isEmpty {
            data.clipboardDisabledApps = disabled
            mapped = true
        }
        return mapped ? data : nil
    }

    /// A v1 export carries no global palette hotkey, so `togglePalette` is never set from one.
    private static func hotkeys(from payload: RaycastV1Payload) -> SettingsBackup.HotkeyBackup? {
        var hotkeys = SettingsBackup.HotkeyBackup()
        var mapped = false

        if let clipboard = payload.toggleClipboard {
            hotkeys.toggleClipboard = binding(clipboard)
            mapped = true
        }
        if let emoji = payload.toggleEmoji {
            hotkeys.toggleEmoji = binding(emoji)
            mapped = true
        }
        if !payload.appHotkeys.isEmpty {
            hotkeys.apps = payload.appHotkeys.mapValues(binding)
            mapped = true
        }
        return mapped ? hotkeys : nil
    }

    /// Always a `.combo`: Raycast has no double-tap binding to import.
    private static func binding(_ hotkey: RaycastV1Payload.Hotkey) -> HotKeyBinding {
        .combo(
            KeyShortcut(
                carbonKeyCode: hotkey.carbonKeyCode, carbonModifiers: hotkey.carbonModifiers))
    }

    /// Enum raw values line up (`light`…`dark`); Raycast's `default` maps to none.
    private static func skinTone(_ raw: String?) -> String? {
        guard let raw else { return nil }
        if raw == "default" { return EmojiSkinTone.none.rawValue }
        return EmojiSkinTone(rawValue: raw)?.rawValue
    }
}
