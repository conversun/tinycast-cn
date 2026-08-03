import SwiftUI

extension DialogTone {
    /// Tints the leading glyph only; buttons take their color from `DialogAction.Role`.
    var tint: Color {
        switch self {
        case .neutral: return .secondary
        case .success: return Theme.Colors.success
        case .danger: return Theme.Colors.destructive
        }
    }
}

/// A Tinycast dialog: the palette's surface recipe (scrim over vibrancy, clipped last) at dialog size, with glass only on the buttons.
struct DialogView: View {
    let request: DialogRequest
    let onChoose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                SymbolImage(name: request.symbol, size: Theme.Size.dialogIcon)
                    .foregroundStyle(request.tone.tint)
                    .frame(width: Theme.Size.dialogIcon)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(request.title.localizedUI)
                        .font(.headline)
                    if let message = request.message {
                        Text(message.localizedUI)
                            .font(Theme.Typography.rowTrailing)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            if let volume = request.volume {
                VolumeSlider(state: volume)
            }

            HStack(spacing: Theme.Spacing.md) {
                Spacer(minLength: 0)
                ForEach(visualOrder, id: \.self) { index in
                    DialogButton(
                        action: request.actions[index],
                        keyCap: keyCap(for: index),
                        onActivate: { onChoose(index) }
                    )
                }
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: Theme.Size.dialogWidth, alignment: .leading)
        .background(Color.black.opacity(Theme.Colors.panelDimming))
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous))
        .panelEntrance()
    }

    /// Cancel renders leading per macOS convention; `onChoose(index)` still dispatches against the original order, so callers ignore display position.
    private var visualOrder: [Int] {
        request.actions.indices.sorted { rank(of: $0) < rank(of: $1) }
    }

    private func rank(of index: Int) -> Int {
        request.actions[index].role == .cancel ? 0 : 1
    }

    /// Only the two keys the panel actually handles are advertised, so a hover tooltip can't drift from the behavior.
    private func keyCap(for index: Int) -> String? {
        if index == request.defaultIndex { return "↵" }
        if index == request.cancelIndex { return "esc" }
        return nil
    }
}

private struct DialogButton: View {
    let action: DialogAction
    let keyCap: String?
    let onActivate: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onActivate) {
            Text(action.title.localizedUI)
                .font(Theme.Typography.bar)
                .foregroundStyle(labelColor)
                .padding(.horizontal, Theme.Spacing.xl)
                .frame(height: Theme.Size.menuButton)
                .contentShape(Capsule())
                .background(Capsule().fill(hovered ? Theme.Colors.menuHover : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .frosted(in: Capsule())
        .tooltip(keyCap)
    }

    private var labelColor: Color {
        switch action.role {
        case .standard: return .primary
        case .destructive: return Theme.Colors.destructive
        case .cancel: return Theme.Colors.textSecondary
        }
    }
}
