import SwiftUI

/// The volume box: speaker glyph, bar, number. Takes the palette's surface recipe rather than glass —
/// it has content to read, not a control to press — so it reads as a sibling of the dialogs.
struct VolumeHUDView: View {
    @ObservedObject var state: VolumeState

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            SymbolImage(
                name: VolumeLevel.symbol(level: state.level, muted: state.muted),
                size: Theme.Size.dialogIcon
            )
            .foregroundStyle(Color.primary)
            HStack(spacing: Theme.Spacing.md) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.Colors.controlSurface)
                        Capsule()
                            .fill(Color.white.opacity(state.muted ? 0.35 : 0.85))
                            .frame(width: geometry.size.width * fill)
                    }
                }
                .frame(height: Theme.Size.volumeTrackHeight)
                // Muted prints the word, not 0%: the bar is already empty, and a number would contradict it or hide the level to come back to.
                Text(state.muted ? "Muted".localizedUI : VolumeLevel.percentage(state.level))
                    .font(Theme.Typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
                    .frame(width: Theme.Size.volumeReadout, alignment: .trailing)
            }
        }
        // Asymmetric: 20pt of side padding costs a fifth of a 200pt box against a twentieth of a 420pt dialog, and the bar is the content here.
        .padding(.vertical, Theme.Spacing.xxl)
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(width: Theme.Size.hudWidth, height: Theme.Size.hudHeight)
        .background(Color.black.opacity(Theme.Colors.panelDimming))
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous))
        .panelEntrance()
        // A repeat command slides the bar to its new value instead of cutting to it.
        .animation(.easeOut(duration: Theme.Duration.exit), value: state.level)
        .animation(.easeOut(duration: Theme.Duration.exit), value: state.muted)
    }

    private var fill: CGFloat {
        state.muted ? 0 : VolumeLevel.clamped(state.level)
    }
}
