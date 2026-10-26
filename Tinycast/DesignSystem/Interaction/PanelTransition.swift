import AppKit
import SwiftUI

// How a borderless surface arrives and leaves.

extension NSWindow {
    /// Fades the whole window, shadow included; `order` runs while still invisible.
    func fadeIn(duration: TimeInterval, order: () -> Void) {
        alphaValue = 0
        order()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.duration(duration)
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        } completionHandler: { [weak self] in
            // AppKit runs the handler on the main thread; the parameter just isn't typed for it.
            MainActor.assumeIsolated {
                // The shadow is cached from the frame it was first drawn at, scaled down.
                self?.invalidateShadow()
            }
        }
    }

    /// Safe to interrupt — the handler checks opacity — and `done` runs once it is off screen.
    func fadeOut(duration: TimeInterval, done: (@MainActor () -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.duration(duration)
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.alphaValue == 0 else { return }
                self.orderOut(nil)
                done?()
            }
        }
    }

    func cancelFade() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            animator().alphaValue = 1
        }
    }

    /// AppKit's close animation keeps drawing the window after `orderOut`; `done` runs once it ends.
    func orderOutAnimated(then done: @escaping @MainActor () -> Void) {
        let animates = animationBehavior != .none && occlusionState.contains(.visible)
        orderOut(nil)
        guard animates else {
            done()
            return
        }
        OrderOutCompletion(done: done).arm(for: self)
    }
}

@MainActor
private final class OrderOutCompletion {
    /// Longer than any close animation AppKit runs, so a missed notification still finishes.
    private static let bound = Duration.seconds(1)

    private var done: (@MainActor () -> Void)?
    private var observer: NotificationToken?
    private var timeout: Task<Void, Never>?

    init(done: @escaping @MainActor () -> Void) {
        self.done = done
    }

    func arm(for window: NSWindow) {
        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [self, weak window] _ in
            MainActor.assumeIsolated {
                guard window?.occlusionState.contains(.visible) != true else { return }
                finish()
            }
        }
        observer = NotificationToken(token, center: .default)
        timeout = Task { [self] in
            try? await Task.sleep(for: Self.bound)
            finish()
        }
    }

    private func finish() {
        guard let done else { return }
        self.done = nil
        observer = nil
        timeout?.cancel()
        timeout = nil
        done()
    }
}

extension View {
    /// Scales up as the window fades in, inside the measured frame, so nothing clips.
    func panelEntrance() -> some View {
        modifier(PanelEntrance())
    }
}

private struct PanelEntrance: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : Self.entryScale)
            .onAppear {
                withAnimation(.easeOut(duration: Theme.Duration.enter)) { appeared = true }
            }
    }

    private static let entryScale: CGFloat = 0.94
}
