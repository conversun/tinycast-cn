import Foundation

/// What a resolved quicklink link points at. Detection is by shape alone — no filesystem or
/// Launch Services read — so the whole rule set is covered by `Tools/quicklink-test.swift`.
enum QuicklinkDestination: Hashable, Sendable {
    case web(URL)
    /// A mountable share: `smb://`, `afp://`, `nfs://`, `ftp://`, `sftp://`, `ftps://`.
    case network(URL)
    /// Any other registered scheme — `spotify://`, `slack://`, `shortcuts://`, `mailto:`.
    case deeplink(URL)
    /// An absolute local path, tilde already expanded.
    case path(String)

    var defaultSymbol: String {
        switch self {
        case .web: return "globe"
        case .network: return "externaldrive.connected.to.line.below"
        case .deeplink: return "arrow.up.forward.app"
        case .path: return "folder"
        }
    }

    /// What the row and the editor preview show under the name.
    var displayText: String {
        switch self {
        case .web(let url), .network(let url), .deeplink(let url): return url.absoluteString
        case .path(let path): return path
        }
    }

    private static let networkSchemes: Set<String> = ["smb", "afp", "nfs", "ftp", "sftp", "ftps"]

    /// `homeDirectory` is injected rather than read, so a harness run can't depend on the machine.
    static func detect(_ link: String, homeDirectory: String = NSHomeDirectory()) -> Self? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let path = absolutePath(trimmed, homeDirectory: homeDirectory) {
            return .path(path)
        }
        if let scheme = scheme(of: trimmed) {
            guard let url = url(from: trimmed) else { return nil }
            // A file: URL names a local path, so it resolves to one rather than to a deeplink.
            if scheme == "file" { return url.isFileURL ? .path(url.path) : nil }
            if scheme == "http" || scheme == "https" { return .web(url) }
            return networkSchemes.contains(scheme) ? .network(url) : .deeplink(url)
        }
        // A bare host is the way people actually write a website down, so `github.com/a?b=c` is
        // treated as https rather than rejected.
        guard looksLikeBareHost(trimmed), let url = url(from: "https://" + trimmed) else {
            return nil
        }
        return .web(url)
    }

    /// Whether values substituted into this link need percent-encoding. Answered from the link's
    /// prefix rather than from a parsed destination, because the encoding has to be chosen *before*
    /// placeholders are resolved. A local path is the one kind that must not be encoded — `%20` in
    /// a path is a literal, not a space.
    static func usesURLEncoding(_ link: String, homeDirectory: String = NSHomeDirectory()) -> Bool {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        return absolutePath(trimmed, homeDirectory: homeDirectory) == nil
    }

    /// True when the link still carries a placeholder. Such a link can only be checked after
    /// expansion, so validation accepts it and the open path reports a bad *resolved* value instead.
    static func containsPlaceholder(_ link: String) -> Bool {
        guard let opening = link.firstIndex(of: "{") else { return false }
        return link[link.index(after: opening)...].contains("}")
    }

    private static func absolutePath(_ value: String, homeDirectory: String) -> String? {
        if value.hasPrefix("/") { return value }
        guard value.hasPrefix("~") else { return nil }
        let home = homeDirectory.hasSuffix("/") ? String(homeDirectory.dropLast()) : homeDirectory
        if value == "~" { return home }
        guard value.hasPrefix("~/") else { return nil }
        return home + String(value.dropFirst(1))
    }

    /// The lowercased scheme when the value starts with an RFC 3986 `scheme:`.
    private static func scheme(of value: String) -> String? {
        guard let colon = value.firstIndex(of: ":") else { return nil }
        let candidate = value[value.startIndex..<colon]
        guard let first = candidate.first, first.isLetter else { return nil }
        guard candidate.dropFirst().allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" })
        else { return nil }
        // Two false positives worth excluding, since both are far more common than the schemes they
        // would shadow: a Windows drive letter ("C:/…"), and a host:port ("example.com:8080") whose
        // dot already fails the loop above but whose port would otherwise read as a path.
        guard candidate.count > 1 else { return nil }
        let remainder = value[value.index(after: colon)...]
        guard !remainder.isEmpty, !remainder.allSatisfy(\.isNumber) else { return nil }
        return candidate.lowercased()
    }

    /// A space is the one authoring mistake worth rescuing — anything else illegal is a real error,
    /// and blanket re-encoding would corrupt the `%xx` the template engine already produced.
    private static func url(from value: String) -> URL? {
        URL(string: value) ?? URL(string: value.replacingOccurrences(of: " ", with: "%20"))
    }

    private static func looksLikeBareHost(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace) else { return false }
        var host = value.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        if let colon = host.firstIndex(of: ":") {
            let port = host[host.index(after: colon)...]
            guard !port.isEmpty, port.allSatisfy(\.isNumber) else { return false }
            host = host[host.startIndex..<colon]
        }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return false }
        // Requiring a letter-led final label keeps version numbers and decimals out.
        guard let tld = labels.last, tld.count >= 2, tld.first?.isLetter == true else { return false }
        return tld.allSatisfy(\.isLetter)
    }
}
