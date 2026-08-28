import SwiftUI

/// The user's own addition to every request. Hidden behind a blur when it already has content, so
/// opening Settings on a stream or in a screenshot does not spill whatever someone told the model
/// to do; an empty one opens plain, because there is nothing yet to give away and a blurred empty
/// box is only a puzzle. The card keeps its edges — only the text goes soft.
struct SystemPromptEditor: View {
    @Binding var text: String

    @Environment(\.isEnabled) private var isEnabled
    @State private var isRevealed: Bool

    init(text: Binding<String>) {
        _text = text
        _isRevealed = State(initialValue: text.wrappedValue.isBlank)
    }

    /// A macOS `TextEditor` keeps its caret, its keyboard and its selection through `.disabled` —
    /// an ancestor's as much as its own — so the editor itself has to go rather than dim.
    private var isEditable: Bool { isEnabled && isRevealed }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(text.isBlank ? "Nothing added" : "Added to every message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.lg)
                Button {
                    withAnimation(.easeOut(duration: Theme.Duration.enter)) { isRevealed.toggle() }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide the prompt" : "Show the prompt")
                .disabled(text.isBlank)
                .accessibilityLabel(isRevealed ? "Hide the system prompt" : "Show the system prompt")
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
