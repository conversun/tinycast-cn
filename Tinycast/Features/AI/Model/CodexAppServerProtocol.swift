import Foundation

enum CodexValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([CodexValue])
    case object([String: CodexValue])

    init(_ value: Any) {
        switch value {
        case is NSNull: self = .null
        // `0`/`1` bridge to Bool too, so only a CFBoolean box counts as one.
        case let value as NSNumber:
            self =
                CFGetTypeID(value) == CFBooleanGetTypeID()
                ? .bool(value.boolValue) : .number(value.doubleValue)
        case let value as String: self = .string(value)
        case let value as [Any]: self = .array(value.map(CodexValue.init))
        case let value as [String: Any]: self = .object(value.mapValues(CodexValue.init))
        default: self = .null
        }
    }

    var objectValue: [String: CodexValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [CodexValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    var intValue: Int? {
        guard case .number(let value) = self else { return nil }
        return Int(value)
    }
}

enum CodexAppServerProtocol {
    enum RequestID: Equatable, Sendable {
        case integer(Int)
        case string(String)

        var jsonValue: Any {
            switch self {
            case .integer(let value): return value
            case .string(let value): return value
            }
        }
    }

    enum Message {
        case response(id: Int, result: [String: CodexValue])
        case failure(id: Int, message: String)
        case notification(method: String, params: [String: CodexValue])
        case request(id: RequestID, method: String, params: [String: CodexValue])
        case invalid
    }

    static func request(id: Int, method: String, params: [String: Any]) throws -> Data {
        try line(["id": id, "method": method, "params": params])
    }

    static func notification(method: String, params: [String: Any] = [:]) throws -> Data {
        try line(["method": method, "params": params])
    }

    static func response(id: RequestID, result: [String: Any]) throws -> Data {
        try line(["id": id.jsonValue, "result": result])
    }

    static func errorResponse(id: RequestID, message: String) throws -> Data {
        try line(["id": id.jsonValue, "error": ["code": -32_601, "message": message]])
    }

    static func parse(_ data: Data) -> Message {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .invalid
        }
        let numericID = (object["id"] as? NSNumber)?.intValue
        let requestID: RequestID?
        if let numericID {
            requestID = .integer(numericID)
        } else if let stringID = object["id"] as? String {
            requestID = .string(stringID)
        } else {
            requestID = nil
        }
        if let method = object["method"] as? String {
            let params = (object["params"] as? [String: Any] ?? [:]).mapValues(CodexValue.init)
            if let requestID { return .request(id: requestID, method: method, params: params) }
            return .notification(method: method, params: params)
        }
        guard let id = numericID else { return .invalid }
        if let result = object["result"] as? [String: Any] {
            return .response(id: id, result: result.mapValues(CodexValue.init))
        }
        if let error = object["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return .failure(id: id, message: message)
        }
        return .invalid
    }

    private static func line(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        return data
    }
}
