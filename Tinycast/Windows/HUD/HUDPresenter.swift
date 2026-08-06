import AppKit
import SwiftUI

/// Everything the two HUDs agree on: one panel at a time, replace rather than stack, fade in, dwell,
/// fade away. What they don't share — content, anchor, dwell — is what the initializer takes.
@MainActor
final class HUDPresenter {
    /// Where the panel sits above the bottom of the visible frame.
    enum Anchor {
        case edgeInset(CGFloat)
        case heightFraction(CGFloat)
    }

    private let anchor: Anchor
    private let dwell: TimeInterval
    private let screen: () -> NSScreen?
    private var panel: HUDPanel?
    private var dismissal: Task<Void, Never>?

    init(anchor: Anchor, dwell: TimeInterval, screen: @escaping () -> NSScreen?) {
        self.anchor = anchor
        self.dwell = dwell
        self.screen = screen
    }

    /// Replaces whatever is up. `size` nil lets SwiftUI measure, which is how the pill tracks its message.
    func show(_ view: some View, size: CGSize? = nil) {
        let panel = panel ?? make()
        let host = NSHostingView(rootView: view)
        // Never size from `host.frame` after attaching: AppKit resets it to the window's content rect, zero on a fresh panel, and a zero-width window "centers" with its leading edge on the midline.
        let content = size ?? host.fittingSize
        host.setFrameSize(content)
        panel.setContentSize(content)
        panel.contentView = host
        place(panel)
        // A panel already on screen may be mid-fade; bring it back rather than starting a second one.
        if panel.isVisible {
            panel.cancelFade()
        } else {
            panel.fadeIn(duration: Theme.Duration.enter) { panel.orderFrontRegardless() }
        }
        scheduleDismissal()
    }

    /// Re-arms the dismissal for content that updates through an observable, so a repeat extends rather than replays.
    func extend() {
        guard let panel, panel.isVisible else { return }
        panel.cancelFade()
        scheduleDismissal()
    }

    var isShowing: Bool { panel?.isVisible ?? false }

    private func scheduleDismissal() {
        dismissal?.cancel()
        dismissal = Task { [weak self, dwell] in
            try? await Task.sleep(for: .seconds(dwell))
            guard !Task.isCancelled else { return }
            self?.panel?.fadeOut(duration: Theme.Duration.exit)
        }
    }

    private func make() -> HUDPanel {
        let panel = HUDPanel()
        self.panel = panel
        return panel
    }

    private func place(_ panel: NSPanel) {
        guard let visible = screen()?.visibleFrame else { return }
        let y: CGFloat
        switch anchor {
        case .edgeInset(let inset):
            y = visible.minY + inset
        case .heightFraction(let fraction):
            y = visible.minY + visible.height * fraction
        }
        panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2, y: y))
    }
}
