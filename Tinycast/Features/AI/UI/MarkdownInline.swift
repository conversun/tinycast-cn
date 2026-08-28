import SwiftUI

/// Inline markdown for one block. `Text` renders emphasis on its own but not code or strikethrough.
enum MarkdownInline {
    static func attributed(_ source: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        guard var text = try? AttributedString(markdown: source, options: options) else {
            return AttributedString(source)
        }
        let intents = text.runs.compactMap { run in run.inlinePresentationIntent.map { ($0, run.range) } }
        for (intent, range) in intents {
            if intent.contains(.code) {
                text[range].font = Theme.Typography.inlineCode
                text[range].backgroundColor = Theme.Colors.controlSurface
            }
            if intent.contains(.strikethrough) { text[range].strikethroughStyle = .single }
        }
        return text
    }

    static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: Theme.Typography.markdownHeading1
        case 2: Theme.Typography.markdownHeading2
        default: Theme.Typography.markdownHeading3
        }
    }
}
