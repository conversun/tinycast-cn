import Foundation

/// The ⌘-digit slots the Favorites section answers to: ⌘1…⌘9 then ⌘0, which is the tenth the way a
/// tab bar spells ten. Favorites past the tenth are listed and reorderable but carry no chord.
enum FavoriteSlots {
    static let digits: [Character] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    /// The favorite a digit launches, or nil when that key is not a slot.
    static func index(for digit: Character) -> Int? { digits.firstIndex(of: digit) }

    /// The digit shown on the row at `index`, or nil past the last slot.
    static func digit(at index: Int) -> Character? {
        digits.indices.contains(index) ? digits[index] : nil
    }
}
