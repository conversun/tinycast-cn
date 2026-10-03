import Foundation

/// settings.json as a tree whose objects keep their key order, so the file reads top to bottom.
enum SettingsFileJSON: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([SettingsFileJSON])
    case object([Member])

    struct Member: Equatable, Sendable {
        let key: String
        let value: SettingsFileJSON
    }

    /// Members in the order written, which is the order the file lists them.
    static func object(_ members: KeyValuePairs<String, SettingsFileJSON>) -> SettingsFileJSON {
        .object(members.map { Member(key: $0.key, value: $0.value) })
    }

    /// From `JSONSerialization`; a dictionary has no order, so its keys are sorted to stay stable.
    init(jsonObject: Any) {
        switch jsonObject {
        case let number as NSNumber:
            // `0` and `1` bridge to Bool too, so only a CFBoolean box counts as one.
            self =
                CFGetTypeID(number) == CFBooleanGetTypeID()
                ? .bool(number.boolValue) : .number(number.doubleValue)
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.map(SettingsFileJSON.init(jsonObject:)))
        case let dictionary as [String: Any]:
            self = .object(
                dictionary.sorted { $0.key < $1.key }.map {
                    Member(key: $0.key, value: SettingsFileJSON(jsonObject: $0.value))
                })
        default:
            self = .null
        }
    }

    subscript(key: String) -> SettingsFileJSON? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }

    var members: [Member]? {
        guard case .object(let members) = self else { return nil }
        return members
    }

    var items: [SettingsFileJSON]? {
        guard case .array(let items) = self else { return nil }
        return items
    }

    var string: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var bool: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    var number: Double? {
        guard case .number(let value) = self, value.isFinite else { return nil }
        return value
    }

    /// A whole number only: `1.5` is not an `Int` the file meant.
    var int: Int? {
        number.flatMap { Int(exactly: $0) }
    }
}

extension SettingsFileJSON: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByBooleanLiteral
{
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
}
