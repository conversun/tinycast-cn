import Foundation

/// settings.json's text: a printer that keeps the file's order, and a parser that reports.
enum SettingsFileFormat {
    struct Parsed: Equatable {
        var values: [SettingsFileKey: SettingsFileJSON]
        var issues: [SettingsFileIssue]
    }

    /// Every value under its section, in `SettingsFileKey` order; a key without one is left out.
    static func render(_ values: [SettingsFileKey: SettingsFileJSON]) -> Data {
        var sections: [SettingsFileJSON.Member] = []
        var members: [SettingsFileJSON.Member] = []
        var section: String?
        for key in SettingsFileKey.allCases {
            guard let value = values[key] else { continue }
            if let section, section != key.section {
                sections.append(.init(key: section, value: .object(members)))
                members.removeAll(keepingCapacity: true)
            }
            section = key.section
            members.append(.init(key: key.name, value: value))
        }
        if let section { sections.append(.init(key: section, value: .object(members))) }
        return Data((text(.object(sections), indent: 0) + "\n").utf8)
    }

    /// Throws only when nothing in the file can be trusted; a single bad key is an issue instead.
    static func parse(_ data: Data) throws(SettingsFileIssue) -> Parsed {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw .invalidJSON(detail(of: error as NSError))
        }
        guard let sections = SettingsFileJSON(jsonObject: object).members else {
            throw .notAnObject(nil)
        }

        var parsed = Parsed(values: [:], issues: [])
        for section in sections {
            guard SettingsFileKey.sections.contains(section.key) else {
                parsed.issues.append(.unknownSetting(section.key))
                continue
            }
            guard let members = section.value.members else {
                parsed.issues.append(.notAnObject(section.key))
                continue
            }
            for member in members {
                let path = section.key + "." + member.key
                guard let key = SettingsFileKey(rawValue: path) else {
                    parsed.issues.append(.unknownSetting(path))
                    continue
                }
                parsed.values[key] = member.value
            }
        }
        return parsed
    }

    // MARK: - Printing

    private static let indentUnit = "  "

    private static func text(_ value: SettingsFileJSON, indent: Int) -> String {
        switch value {
        case .null:
            return "null"
        case .bool(let bool):
            return bool ? "true" : "false"
        case .number(let number):
            return spelled(number)
        case .string(let string):
            return quoted(string)
        case .array(let items):
            let lines = items.map { text($0, indent: indent + 1) }
            return block(lines, open: "[", close: "]", indent: indent)
        case .object(let members):
            let lines = members.map { quoted($0.key) + ": " + text($0.value, indent: indent + 1) }
            return block(lines, open: "{", close: "}", indent: indent)
        }
    }

    /// Empty stays on one line; anything else puts one element per line.
    private static func block(
        _ lines: [String], open: String, close: String, indent: Int
    ) -> String {
        guard !lines.isEmpty else { return open + close }
        let inner = String(repeating: indentUnit, count: indent + 1)
        let outer = String(repeating: indentUnit, count: indent)
        let body = lines.map { inner + $0 }.joined(separator: ",\n")
        return open + "\n" + body + "\n" + outer + close
    }

    /// Whole numbers without a trailing `.0`; JSON has no spelling for a non-finite one.
    private static func spelled(_ number: Double) -> String {
        guard number.isFinite else { return "null" }
        if let whole = Int(exactly: number) { return String(whole) }
        return String(number)
    }

    /// Only what JSON requires is escaped, so paths and accented text stay as typed.
    private static func quoted(_ string: String) -> String {
        var result = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    /// "Invalid value around line 3, column 7." reads better mid-sentence without its capital.
    private static func detail(of error: NSError) -> String {
        let text = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
        let trimmed = text.hasSuffix(".") ? String(text.dropLast()) : text
        return trimmed.prefix(1).lowercased() + trimmed.dropFirst()
    }
}
