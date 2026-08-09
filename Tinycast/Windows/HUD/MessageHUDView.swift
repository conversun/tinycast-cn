import SwiftUI

/// The message pill, whose trailing glyph is its tone. See docs/ui.md#dialogs--hud.
struct MessageHUDView: View {
    let message: String
    let tone: DialogTone

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(message.localizedUI)
                .font(Theme.Typography.bar)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Image(systemName: tone.hudSymbol)
                .font(Theme.Typography.menuIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tone.tint)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: Theme.Size.hudMaxWidth, alignment: .leading)
        .fixedSize()
        // Not glass: with nothing to lens it falls back to an opaque backing and shows.
        .background(Color.black.opacity(Theme.Colors.panelDimming))
        .background(VisualEffectView())
        .clipShape(Capsule())
    }
}

/// File-scoped on purpose, so nothing can reach for it when building a dialog.
extension DialogTone {
    fileprivate var hudSymbol: String {
        switch self {
        case .neutral: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .danger: return "exclamationmark.circle.fill"
        }
    }
}
