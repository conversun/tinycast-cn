import SwiftUI

/// Blurred once it has content, so opening Settings on a stream cannot spill it; empty opens plain.
struct SystemPromptEditor: View {
    @Binding var text: String

    @Environment(\.isEnabled) private var isEnabled
    @State private var isRevealed: Bool

    init(text: Binding<String>) {
        _text = text
        _isRevealed = State(initialValue: text.wrappedValue.isBlank)
    }

    /// A `TextEditor` keeps caret, keyboard and selection through `.disabled`, so it goes
    private var isEditable: Bool { isEnabled && isRevealed }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                // A ternary types as String, so each arm looks itself up rather than the key.
                Text(text.isBlank
                    ? String(localized: "Nothing added")
                    : String(localized: "Added to every message"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.lg)
                Button {
                    withAnimation(.easeOut(duration: Theme.Duration.enter)) { isRevealed.toggle() }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .help(isRevealed
                    ? String(localized: "Hide the prompt")
                    : String(localized: "Show the prompt"))
                .disabled(text.isBlank)
                .accessibilityLabel(isRevealed
                    ? String(localized: "Hide the system prompt")
                    : String(localized: "Show the system prompt"))
            }
            prompt
                .padding(Theme.Spacing.sm)
                .frame(height: Theme.Size.editorTextHeight)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                        .fill(Theme.Colors.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                        .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var prompt: some View {
        if isEditable {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
        } else {
            ScrollView {
                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Self.textInset)
            }
            .scrollBounceBehavior(.basedOnSize)
            .blur(radius: isRevealed ? 0 : Theme.Blur.redaction)
        }
    }

    /// The text container's line-fragment padding, which is where `TextEditor` starts its own text.
    private static let textInset: CGFloat = 5
}

extension String {
    fileprivate var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
