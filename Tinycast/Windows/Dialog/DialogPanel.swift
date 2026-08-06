import AppKit
import Carbon.HIToolbox

/// Borderless panel hosting one Tinycast dialog. Keys are intercepted in `sendEvent` rather than
/// SwiftUI's `onKeyPress` so Esc/↵ work without depending on anything inside the dialog holding focus.
final class DialogPanel: NSPanel {
    /// What the panel saw, not what it means: how far a step moves is the caller's business.
    enum Key {
        case cancel
        case confirm
        case increment
        case decrement
    }

    var onKey: ((Key) -> Void)?

    init(content: NSView) {
        super.init(
            contentRect: NSRect(origin: .zero, size: content.frame.size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // Above the palette's `.floating`, so a confirmation is never buried under the window that triggered it.
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Suppresses AppKit's own window animation; `fadeIn`/`fadeOut` replace it.
        animationBehavior = .none
        isReleasedWhenClosed = false
        contentView = content
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, let onKey else {
            super.sendEvent(event)
            return
        }
        switch Int(event.keyCode) {
        case kVK_Escape:
            onKey(.cancel)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onKey(.confirm)
        case kVK_LeftArrow, kVK_DownArrow:
            onKey(.decrement)
        case kVK_RightArrow, kVK_UpArrow:
            onKey(.increment)
        default:
            super.sendEvent(event)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
