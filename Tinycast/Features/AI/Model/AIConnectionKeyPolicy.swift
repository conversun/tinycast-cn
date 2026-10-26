import Foundation

/// What saving a connection does to its Keychain key: a key never follows a retargeted endpoint.
enum AIConnectionKeyPolicy {
    enum Outcome: Equatable {
        case store(String)
        case removeStored
        case keep
        case reject(String)
    }

    static func resolve(
        enteredKey: String, connection: AIConnection, saved: AIConnection?, hasStoredKey: Bool,
        hasHeaders: Bool
    ) -> Outcome {
        let key = enteredKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { return .store(key) }
        let keyIsOptional = hasHeaders || AIEndpointPolicy.isLoopback(connection.baseURL)
        let retargeted =
            hasStoredKey && saved.map { !AIEndpointPolicy.sameDestination(connection, $0) } == true
        if retargeted {
            return keyIsOptional
                ? .removeStored
                : .reject(
                    String(
                        localized: """
                            Enter an API key for this endpoint — the saved key stays with the old one.
                            """))
        }
        guard keyIsOptional || hasStoredKey else {
            return .reject(String(localized: "Enter an API key for this remote provider."))
        }
        return .keep
    }
}
