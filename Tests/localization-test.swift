import Foundation

@main
struct LocalizationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let url = root.appendingPathComponent("Tinycast/zh-Hans.lproj")
        guard let bundle = Bundle(url: url) else {
            fatalError("Chinese localization bundle is missing")
        }
        let keys = [
            "Navigate back or close window",
            "A .tinycast file exported from Tinycast.",
            "Settings & Shortcuts",
            "Snippets",
            "Launcher Learning",
            "List, detail, form, grid and no-view commands, plus preferences, storage and OAuth.",
            "Menu-bar commands, Raycast's OAuth proxy, and its AI, browser and window services.",
            "Create Window Layout",
            "No external providers ready",
            "Turn on Apple Intelligence, or add a provider above.",
            "Save an arrangement, then restore it with one shortcut.",
            "Clipboard changes from these apps won't be recorded.",
            "Triggering a half again re-applies the same frame.",
            "Hyper Key",
            "Connecting…",
            "Stopped",
            "Tools from every enabled server are offered to the model; type @slug to address "
                + "one directly. The first call of a chat asks before it runs. Credentials "
                + "stay in your login Keychain.",
            "Conversations stay on this Mac. Nothing here is carried in a settings backup — which "
                + "chats a Mac keeps is that Mac's business.",
            "Your text is sent ahead of every message in every chat, after what Tinycast "
                + "already tells the model about itself. Both are billed again on each turn.",
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
        if String(format: format, 3) != "3 个 API 连接" {
            print("FAIL: localized API connection count")
            failures += 1
        }
        print("Localization: \(keys.count + formats.count + 1) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
