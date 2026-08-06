import Foundation

enum FuzzyMatch {
    /// Everything but `.subsequence` is a literal hit — the query's own characters, contiguous — which is what lets `SearchRelevance` rank a declared alias above incidental letter soup.
    enum Tier: Sendable {
        case exact
        case prefix
        case wordStart
        case substring
        case subsequence

        var isLiteral: Bool { self != .subsequence }
    }

    struct Match: Sendable {
        let tier: Tier
        let score: Int
    }

    /// A query folded once, so ranking a list doesn't re-fold the same string for every candidate field.
    struct Query: Sendable {
        fileprivate let text: String
        var isEmpty: Bool { text.isEmpty }

        init(_ raw: String) { text = FuzzyMatch.normalized(raw) }
    }

    /// Tiered relevance (higher is better), or nil when the query doesn't match; tiers are spaced so a better kind always wins.
    static func match(query: String, candidate: String) -> Match? {
        match(Query(query), candidate: candidate)
    }

    static func match(_ query: Query, candidate: String) -> Match? {
        let q = query.text
        let c = normalized(candidate)
        guard !q.isEmpty else { return Match(tier: .exact, score: 0) }

        if c == q { return Match(tier: .exact, score: 100_000) }
        if c.hasPrefix(q) { return Match(tier: .prefix, score: 90_000 - c.count) }

        if let range = c.range(of: q) {
            let atWordStart = isWordStart(c, range.lowerBound)
            return Match(
                tier: atWordStart ? .wordStart : .substring,
                score: (atWordStart ? 80_000 : 70_000) - c.count)
        }

        guard let sub = subsequenceScore(Array(q), Array(c)) else { return nil }
        return Match(tier: .subsequence, score: sub)
    }

    /// Score-only form, for callers that rank one field and don't band by match strength.
    static func score(query: String, candidate: String) -> Int? {
        match(query: query, candidate: candidate)?.score
    }

    /// The widest score `match` can return; `SearchRelevance` sizes its bands off this so they never overlap.
    static let maximumScore = 100_000

    /// App metadata can contain invisible bidirectional/zero-width format scalars (WhatsApp's display name starts with U+200E); they must not demote an otherwise-visible prefix match.
    private static func normalized(_ value: String) -> String {
        let scalars = value.unicodeScalars.filter {
            $0.properties.generalCategory != .format
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    private static func isWordStart(_ s: String, _ index: String.Index) -> Bool {
        if index == s.startIndex { return true }
        let before = s[s.index(before: index)]
        return !before.isLetter && !before.isNumber
    }

    /// Subsequence match with bonuses for consecutive hits and word boundaries, or nil when `q` isn't a subsequence of `c`.
    private static func subsequenceScore(_ q: [Character], _ c: [Character]) -> Int? {
        var qi = 0
        var score = 0
        var run = 0
        var prev = -2
        for (ci, ch) in c.enumerated() where qi < q.count && ch == q[qi] {
            var bonus = 1
            if ci == prev + 1 {
                run += 1
                bonus += run * 3
            } else {
                run = 0
            }
            if ci == 0 {
                bonus += 12
            } else {
                let before = c[ci - 1]
                if !before.isLetter && !before.isNumber { bonus += 8 }
            }
            score += bonus
            prev = ci
            qi += 1
        }
        guard qi == q.count else { return nil }
        return score
    }
}

/// Never flatten these into one string — which field matched is what picks the band.
struct SearchFields: Sendable {
    /// The display name, plus anything identifying the entry just as strongly — a snippet's expansion keyword.
    var names: [String]
    /// Spotlight's `kMDItemAlternateNames`: `iBooks`, `Codex`, `浏览器`.
    var alternateNames: [String] = []
    /// Latin readings of a Han-script name (`weixin`, `wx` for 微信) — derived, so they rank under the aliases macOS itself declares.
    var romanizedNames: [String] = []
    var bundleID: String?
    var executableName: String?
}

enum SearchRelevance {
    /// One band per (field, match strength): a literal hit on a weaker field outranks a subsequence hit on a stronger one, so a declared alias beats letter soup, while at equal strength the display name wins.
    private enum Band: Int {
        case executableName = 0
        case bundleID = 1
        case alternateNameSubsequence = 2
        case nameSubsequence = 3
        case alternateNameLiteral = 4
        case nameLiteral = 5

        var offset: Int { rawValue * SearchRelevance.bandStride }
    }

    /// An order of magnitude above `FuzzyMatch`'s range and two above `LauncherRankingStore`'s boost cap, so a learned boost reorders inside a band but never lifts a result out of one.
    static let bandStride = 10 * FuzzyMatch.maximumScore

    /// Docked from a transliterated match so it ranks under the literal match of the same kind. Stays above `LauncherRankingStore`'s boost cap, or learned ranking could lift a reading back over the name it sits under.
    static let romanizedPenalty = 5_000

    /// Base relevance from the strongest matching field, or nil when no field matches.
    static func score(query: String, fields: SearchFields) -> Int? {
        let query = FuzzyMatch.Query(query)
        // Every entry is equally relevant to an empty query, so no field claims a band.
        guard !query.isEmpty else { return 0 }
        var best: Int?

        func consider(_ candidate: String, literal: Band, subsequence: Band?) {
            guard let match = FuzzyMatch.match(query, candidate: candidate) else { return }
            // Identifier fields pass no subsequence band: "cop" ⊂ "com.apple.Photos" would change *which* apps appear, not just their order.
            guard let band = match.tier.isLiteral ? literal : subsequence else { return }
            best = max(best ?? Int.min, band.offset + match.score)
        }

        for name in fields.names {
            consider(name, literal: .nameLiteral, subsequence: .nameSubsequence)
        }
        for alternate in fields.alternateNames {
            consider(alternate, literal: .alternateNameLiteral, subsequence: .alternateNameSubsequence)
        }
        // A reading is a weaker claim on the query than the name itself, so it stays in the name's own band and is docked instead: it lands under the literal match of the same kind without falling past the kind below it.
        for romanized in fields.romanizedNames {
            guard let match = FuzzyMatch.match(query, candidate: romanized) else { continue }
            let band: Band = match.tier.isLiteral ? .nameLiteral : .nameSubsequence
            // Floored, not allowed to go negative: a weak subsequence scores under the dock, and borrowing from the band offset would drop the reading into the band below.
            best = max(best ?? Int.min, band.offset + max(match.score - romanizedPenalty, 0))
        }
        if let bundleID = fields.bundleID {
            consider(identifyingPart(of: bundleID), literal: .bundleID, subsequence: nil)
            // A pasted identifier should still resolve, which the trimmed form alone can't do.
            if let match = FuzzyMatch.match(query, candidate: bundleID), match.tier == .exact {
                best = max(best ?? Int.min, Band.bundleID.offset + match.score)
            }
        }
        if let executableName = fields.executableName {
            consider(executableName, literal: .executableName, subsequence: nil)
        }
        return best
    }

    /// `apple.Photos` for `com.apple.Photos` — the leading reverse-DNS component carries no identity, and `com` alone prefixes nearly every installed app.
    private static func identifyingPart(of bundleID: String) -> String {
        guard let dot = bundleID.firstIndex(of: ".") else { return bundleID }
        return String(bundleID[bundleID.index(after: dot)...])
    }
}

extension SearchFields {
    /// Spotlight mixes junk in with the real aliases — every bundle lists its own `<Name>.app`, some repeat the display name — and indexing that makes `app` match everything.
    static func usableAlternateNames(
        _ raw: [String], displayName: String, fileName: String
    ) -> [String] {
        let rejected = Set([displayName, fileName].map(strippingAppExtension).map { $0.lowercased() })
        var seen = Set<String>()
        return raw.compactMap { candidate in
            let name = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !isPlaceholder(name) else { return nil }
            let key = strippingAppExtension(name).lowercased()
            guard !key.isEmpty, !rejected.contains(key), seen.insert(key).inserted else { return nil }
            return name
        }
    }

    private static func strippingAppExtension(_ name: String) -> String {
        name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// A lone SCREAMING_SNAKE token is an untranslated localization placeholder; `ALTERNATE_NAME_1` really ships on Home, Journal, Maps, Passwords and Weather.
    private static func isPlaceholder(_ name: String) -> Bool {
        name.contains("_") && !name.contains(where: { $0.isLowercase || $0.isWhitespace })
    }
}
