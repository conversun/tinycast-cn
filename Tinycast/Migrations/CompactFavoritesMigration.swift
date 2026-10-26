import Foundation

/// Retires Show favorites in compact mode, whose settings.json key reports on every launch.
enum CompactFavoritesMigration {
    static func run(settingsFileEnabled: Bool) {
        UserDefaults.standard.removeObject(forKey: "showFavoritesInCompactMode")
        guard settingsFileEnabled else { return }
        let url = AppPaths.settingsFile()
        guard let data = try? Data(contentsOf: url), let migrated = migrated(data) else { return }
        try? migrated.write(to: url.resolvingSymlinksInPath(), options: .atomic)
    }

    /// Nil when the key is absent or the file has other problems, which the import must report.
    static func migrated(_ data: Data) -> Data? {
        guard let parsed = try? SettingsFileFormat.parse(data),
            parsed.issues == [.unknownSetting("appearance.showFavoritesInCompactMode")]
        else { return nil }
        return SettingsFileFormat.render(parsed.values)
    }
}
