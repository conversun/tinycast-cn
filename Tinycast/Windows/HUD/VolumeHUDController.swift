import AppKit

/// The volume readout; a box, not the pill, because a level needs a bar and a number.
@MainActor
final class VolumeHUDController {
    private let presenter = HUDPresenter(
        anchor: .heightFraction(bottomFraction), dwell: Theme.Duration.volumeHUD,
        screen: { .underCursor })
    private let state = VolumeState(level: 0)

    func show(level: Float32, muted: Bool) {
        // The view observes `state`, so a repeat animates the bar rather than replaying.
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

    /// Higher than the pill, the box being taller, so their edge distance reads equal.
    private static let bottomFraction: CGFloat = 0.12
}
