import Carbon.HIToolbox
import CommonCrypto
import CryptoKit
import Foundation

/// A decrypted Raycast 1.x export in Raycast's own names and encodings; validating those against Tinycast's domain types is `RaycastImportV1`'s job, which is what keeps this layer AppKit-free for `Tools/raycast-test.swift`.
struct RaycastV1Payload: Sendable, Equatable {
    struct Hotkey: Sendable, Equatable {
        let carbonKeyCode: Int
        let carbonModifiers: Int
    }

    struct HyperKeyState: Sendable, Equatable {
        let enabled: Bool
        /// A Carbon virtual key code (57 is caps lock), unlike v2's `"caps_lock"` string.
        let keyCode: Int
        let includesShift: Bool?
    }

    struct SnippetRecord: Sendable, Equatable {
        let name: String
        let text: String
        let keyword: String?
    }

    var popToRootTimeout: Int?
    var emojiSkinTone: String?
    var hyperKey: HyperKeyState?
    var useHyperKeyIcon: Bool?
    var windowMode: String?
    var showFavoritesInCompactMode: Bool?
    var statusBarIsVisible: Bool?
    var clipboardDisabledApps: [String]?
    var toggleClipboard: Hotkey?
    var toggleEmoji: Hotkey?
    var appHotkeys: [String: Hotkey] = [:]
    var favorites: [String] = []
    var snippets: [SnippetRecord] = []
    var clipboard: [ClipboardItem] = []
    /// Image clips whose file no longer exists on disk (Raycast's cache is pruned independently).
    var missingImages = 0
}

/// Decrypts a Raycast 1.x `.rayconfig` — a bare `IV(16) ‖ AES-256-CBC(gzip(JSON), PKCS#7)` blob, no header or envelope — and reads it into `RaycastV1Payload`. Full format notes in [raycast-import.md](../../../docs/raycast-import.md).
enum RaycastV1Decoder {
    static func decrypt(_ raw: Data, passphrase: String) throws -> Data {
        guard raw.count >= 32, raw.count % 16 == 0 else { throw RaycastImportError.notRaycastFile }
        let plaintext = try decryptCBC(
            Data(raw.dropFirst(ivLength)),
            key: derivedKey(passphrase: passphrase),
            iv: Data(raw.prefix(ivLength)))

        // A wrong key usually fails PKCS#7 but unpads cleanly roughly 1 in 256 times, so the gzip header is the real check — at offset 0, because the IV is not part of the payload.
        let magic = [UInt8](plaintext.prefix(3))
        guard magic.count == 3, magic[0] == 0x1f, magic[1] == 0x8b, magic[2] == 0x08,
            let json = try? Gunzip.decompress(plaintext)
        else { throw RaycastImportError.incorrectPassphrase }
        return json
    }

    static func payload(_ decrypted: Data) throws -> RaycastV1Payload {
        guard let json = try? JSONSerialization.jsonObject(with: decrypted) as? [String: Any] else {
            throw RaycastImportError.corrupt
        }
        var payload = RaycastV1Payload()
        readPreferences(json, into: &payload)
        readRootSearch(json, into: &payload)
        readClipboard(json, into: &payload)
        payload.favorites = readFavorites(json)
        payload.snippets = readSnippets(json)
        return payload
    }

    /// Hyphen-joined modifier names with a trailing Carbon key code (`"Command-32"`, `"Shift-Control-Option-Command-32"`); an unrecognised modifier rejects the whole shortcut, since importing a weaker combo could shadow something else.
    static func hotkey(from string: String?) -> RaycastV1Payload.Hotkey? {
        guard let string else { return nil }
        let parts = string.split(separator: "-")
        guard parts.count >= 1, let keyCode = Int(parts[parts.count - 1]) else { return nil }

        var modifiers = 0
        for part in parts.dropLast() {
            switch part.lowercased() {
            case "command", "cmd": modifiers |= cmdKey
            case "shift": modifiers |= shiftKey
            case "option", "alt": modifiers |= optionKey
            case "control", "ctrl": modifiers |= controlKey
            default: return nil
            }
        }
        return .init(carbonKeyCode: keyCode, carbonModifiers: modifiers)
    }

    // MARK: - Crypto

    private static let ivLength = 16

    /// For a 32-byte key `EVP_BytesToKey(SHA-256, salt: none)` is one digest round, and the IV it would derive next is discarded — Raycast writes a random IV into the file instead.
    private static func derivedKey(passphrase: String) -> Data {
        Data(SHA256.hash(data: Data(passphrase.utf8)))
    }

    private static func decryptCBC(_ ciphertext: Data, key: Data, iv: Data) throws -> Data {
        var output = Data(count: ciphertext.count + kCCBlockSizeAES128)
        let capacity = output.count
        var moved = 0
        let status = output.withUnsafeMutableBytes { out in
            ciphertext.withUnsafeBytes { input in
                iv.withUnsafeBytes { iv in
                    key.withUnsafeBytes { key in
                        CCCrypt(
                            CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            key.baseAddress, key.count, iv.baseAddress,
                            input.baseAddress, input.count,
                            out.baseAddress, capacity, &moved)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw RaycastImportError.incorrectPassphrase }
        return Data(output.prefix(moved))
    }

    // MARK: - Providers

    private static func readPreferences(_ json: [String: Any], into payload: inout RaycastV1Payload) {
        let preferences = json["builtin_package_raycastPreferences"] as? [String: Any]
        let advanced = preferences?["preferencesAdvanced"] as? [String: Any]
        let appearance = preferences?["preferencesAppearance"] as? [String: Any]

        payload.popToRootTimeout = advanced?["popToRootTimeout"] as? Int
        payload.emojiSkinTone = advanced?["emojiSkinTone"] as? String
        payload.useHyperKeyIcon = advanced?["useHyperKeyIcon"] as? Bool
        if let state = advanced?["raycast_hyperKey_state"] as? [String: Any],
            let keyCode = state["keyCode"] as? Int {
            payload.hyperKey = .init(
                enabled: state["enabled"] as? Bool ?? true,
                keyCode: keyCode,
                includesShift: state["includeShiftKey"] as? Bool)
        }
        payload.windowMode = appearance?["raycastPreferredWindowMode"] as? String
        payload.showFavoritesInCompactMode = appearance?["showFavoritesInCompactMode"] as? Bool
        payload.statusBarIsVisible = appearance?["statusBarIsVisible"] as? Bool
    }

    /// For a `systemApp` entry `key` is already the bundle ID, so — unlike v2, which hides a path inside the command id — nothing here touches the filesystem and a hotkey survives the app being uninstalled.
    private static func readRootSearch(_ json: [String: Any], into payload: inout RaycastV1Payload) {
        let entries =
            (json["builtin_package_rootSearch"] as? [String: Any])?["rootSearch"] as? [[String: Any]]
            ?? []
        for entry in entries {
            guard let hotkey = hotkey(from: entry["hotkey"] as? String),
                let key = entry["key"] as? String, !key.isEmpty
            else { continue }
            switch entry["type"] as? String {
            case "systemApp":
                payload.appHotkeys[key] = hotkey
            case "command":
                if key == "builtin_command_clipboardHistory" {
                    payload.toggleClipboard = hotkey
                } else if key.lowercased().contains("emoji") {
                    payload.toggleEmoji = hotkey
                }
            default:
                break
            }
        }
    }

    /// Only `image` becomes an image clip: a `file` record can be any document and Tinycast has no kind for that, so its label imports as text.
    private static func readClipboard(_ json: [String: Any], into payload: inout RaycastV1Payload) {
        guard let history = json["builtin_package_clipboardHistory"] as? [String: Any] else { return }
        payload.clipboardDisabledApps = history["clipboardHistoryDisabledApplications"] as? [String]

        let records = history["clipboardHistoryRecords"] as? [[String: Any]] ?? []
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for record in records {
            let createdAt = parseDate(record["createdAt"] as? String, using: fractional) ?? Date()
            let source = bundleID(atPath: record["applicationPath"] as? String)

            if record["category"] as? String == "image", let path = record["filePath"] as? String {
                guard FileManager.default.fileExists(atPath: path) else {
                    payload.missingImages += 1
                    continue
                }
                payload.clipboard.append(
                    ClipboardItem(imagePath: path, createdAt: createdAt, sourceBundleID: source))
                continue
            }
            if let text = record["text"] as? String, !text.isEmpty {
                payload.clipboard.append(
                    ClipboardItem(
                        id: UUID(), kind: .text, text: text, imagePath: nil, createdAt: createdAt,
                        sourceBundleID: source))
            }
        }
    }

    /// Unverified against a real export (none had favorites pinned), so every plausible entry shape is accepted and anything that isn't clearly a bundle ID is dropped rather than guessed at.
    private static func readFavorites(_ json: [String: Any]) -> [String] {
        let pinned =
            (json["builtin_package_navigation"] as? [String: Any])?["pinnedMenuItems"] as? [Any] ?? []
        return pinned.compactMap { item in
            if let bundleID = item as? String { return looksLikeBundleID(bundleID) ? bundleID : nil }
            guard let entry = item as? [String: Any] else { return nil }
            if let key = entry["key"] as? String, looksLikeBundleID(key) { return key }
            return bundleID(atPath: entry["path"] as? String)
        }
    }

    /// Unverified against a real export; the field names match what Raycast's snippet provider writes.
    private static func readSnippets(_ json: [String: Any]) -> [RaycastV1Payload.SnippetRecord] {
        let entries =
            (json["builtin_package_snippets"] as? [String: Any])?["snippets"] as? [[String: Any]] ?? []
        return entries.compactMap { entry in
            let name = (entry["name"] as? String)?.trimmed ?? ""
            guard !name.isEmpty, let text = entry["text"] as? String else { return nil }
            let keyword = (entry["keyword"] as? String)?.trimmed
            return .init(name: name, text: text, keyword: keyword?.isEmpty == false ? keyword : nil)
        }
    }

    // MARK: - Helpers

    private static func parseDate(_ string: String?, using parser: ISO8601DateFormatter) -> Date? {
        guard let string else { return nil }
        // Fractional-seconds parser first; v1 stamps whole seconds, so the fallback does the work.
        return parser.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    private static func bundleID(atPath path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier
    }

    private static func looksLikeBundleID(_ value: String) -> Bool {
        value.contains(".") && !value.contains("/") && !value.contains(" ")
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
