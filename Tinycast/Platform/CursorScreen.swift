import AppKit

extension NSScreen {
    /// The display the user is working on. `NSScreen.main` is the key window's screen, which an
    /// accessory app driving non-activating panels never reliably has.
    static var underCursor: NSScreen? {
        let mouse = NSEvent.mouseLocation
        // NSMouseInRect, not `contains`: a pointer on a display's topmost row otherwise resolves to the display stacked above it.
        return screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? main
    }
}
