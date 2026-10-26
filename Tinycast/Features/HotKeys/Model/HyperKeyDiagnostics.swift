import Foundation

struct HyperKeyDiagnostics: Equatable, Sendable {
    struct ConflictingApp: Equatable, Sendable {
        let name: String
        let severity: HyperKeyConflictPolicy.Severity
    }

    struct Takeover: Equatable, Sendable {
        let keyboards: [String]
        let likelyApps: [String]
    }

    struct KeyboardTap: Equatable, Sendable {
        let appName: String
        let isSlow: Bool
    }

    struct SecureInput: Equatable, Sendable {
        let reportedOwner: String?
        let ownerIsLoginWindow: Bool
        let likelyOwners: [String]
    }

    let isActive: Bool
    let activeKeyTitle: String?
    /// Nil while there is no tap to ask.
    let eventTapEnabled: Bool?
    let runLoopSourceValid: Bool?
    let remappedKeyboards: [String]
    let conflictingApps: [ConflictingApp]
    let karabinerVirtualKeyboards: [String]
    let karabinerConflict: Bool
    let capsLockMappingConflicts: [String]
    let takeover: Takeover?
    let keyboardTaps: [KeyboardTap]
    let secureInputCompatibilityActive: Bool
    /// Nil while Secure Input is off.
    let secureInput: SecureInput?
}
