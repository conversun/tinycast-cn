import Foundation

@MainActor
struct FavoriteActions {
    let isFavorite: Bool
    var canMoveUp = false
    var canMoveDown = false
    let toggle: () -> Void
    var move: (Int) -> Void = { _ in }

    var items: [PopoverMenuItem] {
        var items = [
            PopoverMenuItem(
                title: isFavorite
                    ? String(localized: "Remove from Favorites")
                    : String(localized: "Add to Favorites"),
                systemImage: isFavorite ? "star.slash" : "star", startsSection: true,
                shortcut: "⇧⌘F", action: toggle)
        ]
        if canMoveUp {
            items.append(
                PopoverMenuItem(
                    title: String(localized: "Move Favorite Up"), systemImage: "arrow.up",
                    shortcut: "⌥⌘↑"
                ) { move(-1) })
        }
        if canMoveDown {
            items.append(
                PopoverMenuItem(
                    title: String(localized: "Move Favorite Down"), systemImage: "arrow.down",
                    shortcut: "⌥⌘↓"
                ) { move(1) })
        }
        return items
    }
}
