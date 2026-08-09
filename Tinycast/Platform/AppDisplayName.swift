import Foundation

extension Bundle {
    /// The channel-aware display name, from the generated Info.plist.
    var appDisplayName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.usableName
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)?.usableName
            ?? "Tinycast"
    }
}

extension String {
    /// The string itself, or nil when it holds nothing displayable. A bundle key that is *present but blank* is the case a plain `??` chain gets wrong: it stops at the empty string instead of falling through to the next name.
    var usableName: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
