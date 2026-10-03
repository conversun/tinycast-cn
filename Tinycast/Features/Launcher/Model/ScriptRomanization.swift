import Foundation

/// What a name in another script gets typed as, routed per script because ICU serves none of them.
enum ScriptRomanization {
    /// The scripts worth their own rule; everything else ICU's generic transform handles well.
    enum Script: Sendable {
        case han
        case japanese
        case hangul
        case cyrillic
        case other
    }

    /// Words one space apart, folded; nil when the name is Latin already.
    static func latin(_ name: String) -> String? {
        guard let script = script(of: name) else { return nil }
        let reading: String? =
            switch script {
            case .han: hanReading(of: name)
            // Only the kana romanize: ICU would read the kanji as Mandarin, which is a wrong word.
            case .japanese: transform(dropping(name, in: hanRanges), .toLatin)
            case .hangul, .other: transform(name, .toLatin)
            case .cyrillic: cyrillicReading(of: name)
            }
        guard let reading else { return nil }
        let spaced = reading.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let folded = FuzzyMatch.normalized(spaced)
        return folded.isEmpty || folded == FuzzyMatch.normalized(name) ? nil : folded
    }

    /// The first script with a rule of its own, kana before Han so a Japanese title routes right.
    static func script(of name: String) -> Script? {
        var hasHan = false
        var hasHangul = false
        var hasCyrillic = false
        var hasOther = false
        for scalar in name.unicodeScalars {
            if contains(kanaRanges, scalar) { return .japanese }
            if contains(hanRanges, scalar) {
                hasHan = true
            } else if contains(
                hangulRanges, scalar)
            {
                hasHangul = true
            } else if contains(cyrillicRanges, scalar) {
                hasCyrillic = true
            } else if scalar.value > 0x24F, scalar.properties.isAlphabetic {
                hasOther = true
            }
        }
        if hasHan { return .han }
        if hasHangul { return .hangul }
        if hasCyrillic { return .cyrillic }
        return hasOther ? .other : nil
    }

    /// ICU's Cyrillic is scientific — `Яндекс` becomes `Ândeks`, never the `yandex` users type.
    private static func cyrillicReading(of name: String) -> String {
        var result = ""
        for character in name.lowercased() {
            if let latin = cyrillicLatin[character] {
                result += latin
            } else if character.isLetter || character.isNumber {
                result.append(character)
            } else {
                result.append(" ")
            }
        }
        return result
    }

    private static func hanReading(of name: String) -> String? {
        let text = FuzzyMatch.normalized(name) as NSString
        guard let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault, text as CFString, CFRangeMake(0, text.length),
            kCFStringTokenizerUnitWord, Locale(identifier: "zh_Hans") as CFLocale)
        else { return nil }
        var words: [String] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let word = text.substring(with: NSRange(location: range.location, length: range.length))
            guard word.unicodeScalars.allSatisfy({ contains(hanRanges, $0) }) else {
                words.append(word)
                continue
            }
            guard let transcription = CFStringTokenizerCopyCurrentTokenAttribute(
                tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            else { continue }
            let reading = FuzzyMatch.normalized(transcription).filter(\.isLetter)
            guard !reading.isEmpty else { continue }
            words += Pinyin.syllables(of: reading, count: word.count) ?? [reading]
        }
        return words.joined(separator: " ")
    }

    private static let cyrillicLatin: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "ґ": "g", "д": "d", "е": "e", "ё": "yo", "є": "ye",
        "ж": "zh", "з": "z", "и": "i", "і": "i", "ї": "yi", "й": "y", "к": "k", "л": "l", "м": "m",
        "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ў": "u", "ф": "f",
        "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "",
        "э": "e", "ю": "yu", "я": "ya"
    ]

    private static func transform(_ value: String, _ transform: StringTransform) -> String? {
        value.applyingTransform(transform, reverse: false)?
            .folding(options: FuzzyMatch.folding, locale: nil)
    }

    private static func dropping(_ value: String, in ranges: [ClosedRange<UInt32>]) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { !contains(ranges, $0) }))
    }

    private static func contains(_ ranges: [ClosedRange<UInt32>], _ scalar: Unicode.Scalar) -> Bool {
        ranges.contains { $0.contains(scalar.value) }
    }

    private static let hanRanges: [ClosedRange<UInt32>] = [
        0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF
    ]
    private static let kanaRanges: [ClosedRange<UInt32>] = [
        0x3040...0x309F, 0x30A0...0x30FF, 0x31F0...0x31FF
    ]
    private static let hangulRanges: [ClosedRange<UInt32>] = [
        0x1100...0x11FF, 0x3130...0x318F, 0xA960...0xA97F, 0xAC00...0xD7AF
    ]
    private static let cyrillicRanges: [ClosedRange<UInt32>] = [0x0400...0x052F]
}
