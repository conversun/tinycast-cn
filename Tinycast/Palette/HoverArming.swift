import CoreGraphics

/// Decides when pointer movement is the pointer *choosing* a row, rather than drift around where it
/// already stands. Pure: the palette's arming state lives on `PaletteState`.
enum HoverArming {
    /// Below this the pointer has not gone anywhere: a wheel click nudges the mouse a point or two,
    /// and a gesture ends with a mouse-moved event that carries no displacement at all.
    private static let slop: CGFloat = 3

    static func isDeliberate(_ pointer: CGPoint, from anchor: CGPoint) -> Bool {
        hypot(pointer.x - anchor.x, pointer.y - anchor.y) > slop
    }
}
