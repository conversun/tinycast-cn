import Foundation

/// Recognizes "tap a lone modifier twice" out of a stream of modifier snapshots. Pure and clock-injected (`now` is a caller-supplied monotonic timestamp) so `Tools/hotkey-test.swift` can drive it without an event tap.
struct DoubleTapDetector {
    /// Longest a press may last and still count as a tap — matches `HyperKeyTap.quickPressWindow`, so a "tap" means the same thing in both features.
    static let maxHold: TimeInterval = 0.25
    /// Longest gap between the first tap's release and the second tap's press.
    static let maxGap: TimeInterval = 0.30

    enum Input: Sendable {
        /// A modifier transition: which of the four eligible modifiers are now held, and whether `fn` is down alongside.
        case modifiers(Set<DoubleTapModifier>, hasOtherModifiers: Bool)
        /// A key press or mouse click, which turns the press in flight into a chord.
        case otherInput
    }

    private var held: Set<DoubleTapModifier> = []
    private var press: (modifier: DoubleTapModifier, startedAt: TimeInterval)?
    private var pendingTap: (modifier: DoubleTapModifier, releasedAt: TimeInterval)?

    /// Returns the modifier whose double-tap just completed. Firing happens on the *second release*, so the modifier is already up when the caller runs the action — the palette never opens with a phantom ⌘ held, and "double-tap and hold" is a deliberate non-event.
    mutating func handle(_ input: Input, at now: TimeInterval) -> DoubleTapModifier? {
        switch input {
        case .otherInput:
            invalidate()
            return nil
        case .modifiers(let modifiers, let hasOtherModifiers):
            return handle(modifiers, hasOtherModifiers: hasOtherModifiers, at: now)
        }
    }

    mutating func reset() {
        held = []
        invalidate()
    }

    private mutating func handle(
        _ modifiers: Set<DoubleTapModifier>, hasOtherModifiers: Bool, at now: TimeInterval
    ) -> DoubleTapModifier? {
        let previous = held
        held = modifiers

        guard !hasOtherModifiers else {
            invalidate()
            return nil
        }
        if modifiers.isEmpty { return completeTap(at: now) }

        // A tap can only begin from nothing held: a second modifier joining, or a chord unwinding back to one, must not read as a fresh press.
        guard previous.isEmpty, modifiers.count == 1, let modifier = modifiers.first else {
            invalidate()
            return nil
        }
        press = (modifier, now)
        return nil
    }

    private mutating func completeTap(at now: TimeInterval) -> DoubleTapModifier? {
        guard let press, now - press.startedAt <= Self.maxHold else {
            invalidate()
            return nil
        }
        self.press = nil

        guard let pending = pendingTap, pending.modifier == press.modifier,
            press.startedAt - pending.releasedAt <= Self.maxGap
        else {
            pendingTap = (press.modifier, now)
            return nil
        }
        pendingTap = nil
        return press.modifier
    }

    private mutating func invalidate() {
        press = nil
        pendingTap = nil
    }
}
