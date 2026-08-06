import AppKit

/// The volume readout, since macOS only draws its own HUD for real media keys and a CoreAudio change
/// would otherwise be silent. A box, not the pill, because a level needs a bar and a number.
@MainActor
final class VolumeHUDController {
    private let presenter = HUDPresenter(
        anchor: .heightFraction(bottomFraction), dwell: Theme.Duration.volumeHUD,
        screen: { .underCursor })
    private let state = VolumeState(level: 0)

    func show(level: Float32, muted: Bool) {
        // The view observes `state`, so a repeat animates the bar in place instead of replaying the entrance.
        let showing = presenter.isShowing
        state.level = VolumeLevel.clamped(Double(level))
        state.muted = muted
        if showing {
            presenter.extend()
        } else {
            presenter.show(
                VolumeHUDView(state: state),
                size: CGSize(width: Theme.Size.hudWidth, height: Theme.Size.hudHeight))
        }
    }

    /// Higher than the pill, since the box is taller — this keeps their optical edge distance equal.
    private static let bottomFraction: CGFloat = 0.12
}
