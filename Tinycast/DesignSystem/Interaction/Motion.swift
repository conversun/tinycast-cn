import SwiftUI

/// `AppCore` projects `AppSettings.animationsEnabled` here; global, so no surface can miss it.
@MainActor
enum Motion {
    static var isEnabled = true

    /// Zero while animations are off, so an AppKit animation group lands at once.
    static func duration(_ duration: TimeInterval) -> TimeInterval {
        isEnabled ? duration : 0
    }
}

extension View {
    /// Every hosting root applies this; the flag is read per transaction, so a toggle lands live.
    func motionScope() -> some View {
        transaction { transaction in
            guard !Motion.isEnabled else { return }
            transaction.animation = nil
            // Without it, a descendant's `.animation(_:value:)` would insert its own again.
            transaction.disablesAnimations = true
        }
    }
}
