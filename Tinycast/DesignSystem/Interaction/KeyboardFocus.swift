import AppKit

/// A view whose subtree never takes the keyboard: a preview's transport, where the field owns it.
protocol KeyboardFocusRefusing: NSView {}

extension NSView {
    /// Asked of a would-be first responder: the mark sits on an ancestor, not on the control hit.
    var refusesKeyboardFocus: Bool {
        sequence(first: self, next: { $0.superview }).contains { $0 is KeyboardFocusRefusing }
    }
}
