import Foundation

/// Upstream version precedence first, then the Chinese build's revision.
struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    /// Nil on a stable release, which outranks every prerelease of the same triple.
    let beta: Int?
    let cnRevision: Int?

    init?(_ text: String) {
        var body = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        // Release tags carry a leading `v`; `CFBundleShortVersionString` never does.
        if body.first == "v" { body = body.dropFirst() }

        var suffixes = body.split(separator: "-", omittingEmptySubsequences: false)
        guard let triple = suffixes.first else { return nil }
        suffixes.removeFirst()
        let numbers = triple.split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
            let major = Self.number(numbers[0]),
            let minor = Self.number(numbers[1]),
            let patch = Self.number(numbers[2])
        else { return nil }

        if let revision = suffixes.last, revision.hasPrefix("cn.") {
            guard let count = Self.number(revision.dropFirst(3)) else { return nil }
            cnRevision = count
            suffixes.removeLast()
        } else {
            cnRevision = nil
        }
        guard suffixes.count <= 1 else { return nil }
        if let prerelease = suffixes.first {
            let suffix = prerelease.split(separator: ".", omittingEmptySubsequences: false)
            guard suffix.count == 2, suffix[0] == "beta", let count = Self.number(suffix[1])
            else { return nil }
            beta = count
        } else {
            beta = nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    var isPrerelease: Bool { beta != nil }

    var description: String {
        let triple = "\(major).\(minor).\(patch)"
        let upstream = beta.map { "\(triple)-beta.\($0)" } ?? triple
        return cnRevision.map { "\(upstream)-cn.\($0)" } ?? upstream
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.beta, rhs.beta) {
        case (nil, nil): break
        case (.some, nil): return true
        case (nil, .some): return false
        case (.some(let left), .some(let right)):
            if left != right { return left < right }
        }
        switch (lhs.cnRevision, rhs.cnRevision) {
        case (nil, nil): return false
        case (nil, .some): return true
        case (.some, nil): return false
        case (.some(let left), .some(let right)): return left < right
        }
    }

    /// Rejects a signed or padded field, which `Int` would silently reinterpret.
    private static func number(_ text: Substring) -> Int? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(text)
    }
}

extension AppVersion: Codable {
    init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = AppVersion(text) else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(), debugDescription: "Not a version: \(text)")
        }
        self = parsed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
