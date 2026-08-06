import Foundation

/// A modifier whose double-tap can carry a global binding. Deliberately just these four: Caps Lock belongs to the Hyper Key, and `fn` isn't a real modifier on every keyboard.
enum DoubleTapModifier: String, CaseIterable, Codable, Sendable {
    case control
    case option
    case shift
    case command

    var glyph: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }

    var keycaps: [String] { [glyph, glyph] }
}
