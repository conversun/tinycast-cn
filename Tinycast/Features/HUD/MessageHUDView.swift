import SwiftUI

/// The message pill. Its glyph trails the message and *is* the tone: unlike a dialog, a pill has no
/// subject to name — the message already says what happened — so the icon only has to say how it went.
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
        // Not glass: with nothing to lens on a panel of its own it falls back to an opaque backing, showing as a dark edge outside the capsule.
        .background(Color.black.opacity(Theme.Colors.panelDimming))
        .background(VisualEffectView())
        .clipShape(Capsule())
    }
}

/// Deliberately file-scoped rather than a property on `DialogTone`: a *dialog's* glyph names its
/// subject and never its tone, and nothing should be able to reach for this when building one.
extension DialogTone {
    fileprivate var hudSymbol: String {
        switch self {
        case .neutral: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .danger: return "exclamationmark.circle.fill"
        }
    }
}
