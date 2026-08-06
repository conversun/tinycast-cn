import AppKit
import SwiftUI

/// Hosts auxiliary SwiftUI windows (About, Settings), torn down on close so their SwiftUI trees deallocate instead of lingering, and rebuilt instantly on reopen from live state.
@MainActor
final class AuxWindowController: NSObject, NSWindowDelegate {
    private var windows: [String: NSWindow] = [:]

    /// Returns `true` when a new window was created, `false` when an existing one was re-raised.
    @discardableResult
    func show<Content: View>(
        id: String, title: String, size: CGSize, seamlessTitleBar: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> Bool {
        let window: NSWindow
        let isNew: Bool
        if let existing = windows[id] {
            window = existing
            isNew = false
        } else {
            isNew = true
            var style: NSWindow.StyleMask = [.titled, .closable]
            if seamlessTitleBar { style.insert(.fullSizeContentView) }
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: style,
                backing: .buffered,
                defer: false
            )
            window.title = title
            // Let the content run edge-to-edge under a transparent titlebar so the window reads as one continuous surface — the modern inspector look.
            if seamlessTitleBar {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
            }
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: content())
            // Let the window keep its requested size instead of resizing to the SwiftUI fitting size (an unconstrained fill would otherwise blow the window up); the content fills the fixed frame.
            hosting.sizingOptions = []
            window.contentView = hosting
            window.delegate = self
            window.center()
            windows[id] = window
        }
        // Promote to a regular app so the window gets a Dock icon and normal layering; demoted back to accessory when the last aux window closes.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // A plain `NSWindow` only becomes key while the app is active, but `NSApp.activate` from the menu bar is async, so the synchronous `makeKeyAndOrderFront` above can land first; re-asserting key on the next runloop makes the window truly key up front.
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
        }
        return isNew
    }

    /// Re-focus an open aux window on reopen (Dock-icon click); returns false when none is open. `windows` only holds live windows (`windowWillClose` prunes them).
    @discardableResult
    func focusExisting() -> Bool {
        guard let window = windows.values.first(where: { $0.isVisible }) ?? windows.values.first
        else { return false }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }

    /// Close a window programmatically; `windowWillClose` handles the dict/teardown so the SwiftUI tree deallocates.
    func close(id: String) {
        windows[id]?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
            let id = windows.first(where: { $0.value === window })?.key
        else { return }
        windows.removeValue(forKey: id)
        if windows.isEmpty { NSApp.setActivationPolicy(.accessory) }
    }
}
