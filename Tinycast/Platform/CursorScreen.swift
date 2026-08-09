import AppKit

extension NSScreen {
    /// The display in use; `NSScreen.main` is the key window's, which we rarely have.
    static var underCursor: NSScreen? {
        let mouse = NSEvent.mouseLocation
        // NSMouseInRect, not `contains`: the topmost row otherwise reads as the display above.
        return screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? main
    }
}
