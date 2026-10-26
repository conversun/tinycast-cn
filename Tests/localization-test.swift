import Foundation

@main
struct LocalizationTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tinycast-localization-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["Localizable", "InfoPlist"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = [
                "xcstringstool", "compile", "Tinycast/Resources/\(name).xcstrings",
                "--output-directory", root.path
            ]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                fatalError("\(name) catalog failed to compile")
            }
        }
        let url = root.appendingPathComponent("zh-Hans.lproj")
        guard let bundle = Bundle(url: url) else {
            fatalError("Chinese localization bundle is missing")
        }
        let keys = [
            "Navigate back or close window",
            "A .tinycast file exported from Tinycast.",
            "Settings & Shortcuts",
            "Snippets",
            "Launcher Learning",
            "List, detail, form, grid, no-view and menu-bar commands, preferences, storage and OAuth.",
            "Raycast's AI, browser and window services.",
            "Create Window Layout",
            "No external providers ready",
            "Turn on Apple Intelligence, or add a provider above.",
            "Save an arrangement, then restore it with one shortcut.",
            "Copies from these apps aren't recorded.",
            "Repeating a half keeps the same frame.",
            "Hyper Key",
            "Connecting…",
            "Stopped",
            "Type @slug to address one server. A chat asks before its first tool call.",
            "Conversations stay on this Mac, outside settings backups.",
            "Sent before every message, after Tinycast's own. Both are billed each turn.",
            "Battery",
            "Headphones",
            "No extension command is running.",
        ]
        var failures = 0
        for key in keys {
            let translated = bundle.localizedString(forKey: key, value: key, table: nil)
            if translated == key {
                print("FAIL: missing Chinese translation for \(key)")
                failures += 1
            }
        }
        let formats = [
            ("No layout matches “%@”.", "设计", "没有与“设计”匹配的布局。"),
            ("%@ · not connected", "Studio Display", "Studio Display · 未连接"),
        ]
        for (key, argument, expected) in formats {
            let format = bundle.localizedString(forKey: key, value: key, table: nil)
            if String(format: format, argument) != expected {
                print("FAIL: localized interpolation for \(key)")
                failures += 1
            }
        }
        let format = bundle.localizedString(forKey: "%lld API connections", value: nil, table: nil)
        if String.localizedStringWithFormat(format, 3) != "3 个 API 连接" {
            print("FAIL: localized API connection count")
            failures += 1
        }
        for key in [
            "NSAppleEventsUsageDescription", "NSBluetoothAlwaysUsageDescription",
            "NSCalendarsFullAccessUsageDescription", "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription", "NSRemindersFullAccessUsageDescription",
            "Tinycast Backup",
        ] {
            let translated = bundle.localizedString(forKey: key, value: key, table: "InfoPlist")
            if translated == key {
                print("FAIL: missing Chinese privacy translation for \(key)")
                failures += 1
            }
        }
        print("Localization: \(keys.count + formats.count + 8) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
