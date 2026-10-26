import Foundation

@main
@MainActor
struct CompactFavoritesMigrationTest {
    static var failures = 0

    static func main() throws {
        let retired = file(appearance: #""showFavoritesInCompactMode": true, "compactMode": true"#)
        let rewrite = CompactFavoritesMigration.migrated(retired)
        check("a file with the retired key is rewritten", rewrite != nil)
        if let rewrite {
            let parsed = try SettingsFileFormat.parse(rewrite)
            let original = try SettingsFileFormat.parse(retired)
            check("the rewrite reports nothing", parsed.issues.isEmpty)
            check("the rewrite keeps every other value", parsed.values == original.values)
        }

        let typo = file(appearance: #""showFavoritesInCompactMode": true, "compactMod": true"#)
        check("another unknown key leaves the file to the import", migrated(typo) == nil)
        check("a clean file is left alone", migrated(file(appearance: #""compactMode": true"#)) == nil)
        check("invalid JSON is left alone", migrated(Data("{".utf8)) == nil)

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }

    private static func migrated(_ data: Data) -> Data? {
        CompactFavoritesMigration.migrated(data)
    }

    private static func file(appearance: String) -> Data {
        Data(#"{ "general": { "language": "en" }, "appearance": { \#(appearance) } }"#.utf8)
    }

    private static func check(_ description: String, _ condition: @autoclosure () -> Bool) {
        if condition() {
            print("PASS  \(description)")
        } else {
            print("FAIL  \(description)")
            failures += 1
        }
    }
}
