import Foundation

/// A connection's own headers, sent after the route's defaults so one can replace a default.
enum AIRequestHeaders {
    enum ValidationError: LocalizedError, Equatable {
        case invalidName(String)
        case duplicateName(String)
        case invalidValue(String)

        var errorDescription: String? {
            switch self {
            case .invalidName(let name):
                return String(localized: "“\(name)” is not a valid header name.")
            case .duplicateName(let name):
                return String(localized: "The header “\(name)” is listed more than once.")
            case .invalidValue(let name):
                return String(
                    localized: "The value of “\(name)” contains a line break or control character.")
            }
        }
    }

    /// Blank rows are dropped; HTTP names are case-insensitive, so a repeat in any case is refused.
    static func validated(_ rows: [(name: String, value: String)]) throws -> [String: String] {
        var headers: [String: String] = [:]
        var seen: Set<String> = []
        for row in rows {
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = row.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty, value.isEmpty { continue }
            guard !name.isEmpty, name.rangeOfCharacter(from: tokenCharacters.inverted) == nil else {
                throw ValidationError.invalidName(name)
            }
            guard seen.insert(name.lowercased()).inserted else {
                throw ValidationError.duplicateName(name)
            }
            guard value.rangeOfCharacter(from: forbiddenInValue) == nil else {
                throw ValidationError.invalidValue(name)
            }
            headers[name] = value
        }
        return headers
    }

    /// RFC 9110's `tchar`.
    private static let tokenCharacters = CharacterSet(charactersIn: "a"..."z")
        .union(CharacterSet(charactersIn: "A"..."Z"))
        .union(CharacterSet(charactersIn: "0"..."9"))
        .union(CharacterSet(charactersIn: "!#$%&'*+-.^_`|~"))
    private static let forbiddenInValue = CharacterSet.controlCharacters
        .subtracting(CharacterSet(charactersIn: "\t"))
}
