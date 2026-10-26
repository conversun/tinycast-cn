import Foundation

enum DictationTextFormatter {
    struct Context: Sendable {
        let trailing: Character?
        let lastNonWhitespace: Character?
        let newParagraph: Bool
        let following: Character?

        init(before: Substring, after: Substring) {
            trailing = before.last
            following = after.first
            var last: Character?
            var paragraph = false
            for character in before.reversed() {
                if !character.isWhitespace {
                    last = character
                    break
                }
                if character.isNewline { paragraph = true }
            }
            lastNonWhitespace = last
            newParagraph = paragraph
        }
    }

    static func stripEcho(_ text: String, after previous: String) -> String {
        guard !text.isEmpty, !previous.isEmpty else { return text }
        let tail = Array(previous.split(separator: " ").suffix(8))
        let head = Array(text.split(separator: " "))
        let plain = { (word: Substring) in
            word.lowercased().trimmingCharacters(in: .alphanumerics.inverted)
        }
        var drop = 0
        for skip in 0..<min(3, head.count) {
            let minimum = skip == 0 ? 1 : skip + 1
            var run = min(tail.count, head.count - skip)
            while run >= minimum {
                guard
                    (0..<run).allSatisfy({ plain(head[skip + $0]) == plain(tail[tail.count - run + $0]) })
                else {
                    run -= 1
                    continue
                }
                drop = max(drop, skip + run)
                break
            }
        }
        guard drop > 0 else { return text }
        var index = text.startIndex
        for _ in 0..<drop {
            while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }
        }
        let rest = String(text[index...])
        return rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : rest
    }

    static func format(_ transcription: String, context: Context?, adaptCapitalization: Bool = true) -> String
    {
        var text = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let context else { return text }
        if adaptCapitalization, let first = text.first, first.isLetter {
            let replacement: String
            if context.lastNonWhitespace == nil || context.newParagraph
                || context.lastNonWhitespace.map({ ".!?".contains($0) }) == true
            {
                replacement = String(first).uppercased()
            } else {
                replacement = String(first).lowercased()
            }
            text.replaceSubrange(text.startIndex...text.startIndex, with: replacement)
        }
        if let trailing = context.trailing, !trailing.isWhitespace,
            !"([{/\"'‘’“—-".contains(trailing),
            let leading = text.first, !".,!?;:)]}/\"'”".contains(leading)
        {
            text = " " + text
        }
        if let leading = context.following, !leading.isWhitespace,
            let trailing = text.last, !trailing.isWhitespace,
            !".,!?;:)]}/\"'”".contains(leading)
        {
            text += " "
        }
        return text
    }
}
