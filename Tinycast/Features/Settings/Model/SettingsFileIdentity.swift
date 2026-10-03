import CryptoKit
import Foundation

/// Identities the file leaves out, derived so that every read of the same text agrees on them.
enum SettingsFileIdentity {
    /// A version 8 UUID from SHA-256, so a record written by hand keeps one id across reloads.
    static func uuid(for text: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(text.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
}
