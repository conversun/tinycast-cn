import Foundation

/// A bundle's names in the languages this Mac reads; `CFBundle` alone misses every loctable app.
enum BundleLocalization {
    /// Preferred languages first, English last: a user who reads Thai still types "Calendar".
    nonisolated static func indexedLanguages(_ preferred: [String]) -> [String] {
        var codes: [String] = []
        var seen = Set<String>()
        for tag in preferred + ["en"] {
            let bare = tag.split(separator: "-").first.map(String.init) ?? tag
            let aliases = resourceAlias(for: bare).map { [$0] } ?? []
            for form in [tag] + scriptForms(tag) + [bare] + aliases {
                // loctable keys and .lproj folders use underscores where a language tag uses "-".
                let underscored = form.replacingOccurrences(of: "-", with: "_")
                for code in [form, underscored]
                where !code.isEmpty && seen.insert(code).inserted {
                    codes.append(code)
                }
            }
        }
        return codes
    }

    private static func resourceAlias(for language: String) -> String? {
        language == "nb" ? "no" : nil
    }

    private static func scriptForms(_ tag: String) -> [String] {
        let subtags = tag.split(separator: "-")
        guard subtags.contains(where: { $0.count == 4 && $0.allSatisfy(\.isLetter) })
        else { return [] }
        let language = Locale.Language(identifier: tag)
        guard let code = language.languageCode?.identifier, let script = language.script
        else { return [] }
        let scriptForm = "\(code)-\(script.identifier)"
        let regionForms = [language.region, maximal(scriptForm).region].compactMap { $0 }
            .map { "\(code)-\($0.identifier)" }
            .filter { maximal($0).script == script }
        return [scriptForm] + regionForms
    }

    private static func maximal(_ identifier: String) -> Locale.Language {
        Locale.Language(identifier: Locale.Language(identifier: identifier).maximalIdentifier)
    }

    /// Every name the bundle carries, most preferred language first. `base` — an app's file name, a
    /// pane's `Info.plist` — ranks with the language it is written in, unless that one renames it.
    nonisolated static func names(
        for bundleURL: URL, base: String, developmentRegion: String?, languages: [String]
    ) -> [String] {
        let resources = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let table = plist(at: resources.appendingPathComponent("InfoPlist.loctable"))
        let development = developmentRegion.flatMap { languageCode(of: $0) }
        let developmentAlias = development.flatMap { resourceAlias(for: $0) }
        let developmentFallback = languages.last { code in
            guard let development else { return false }
            return code.caseInsensitiveCompare(development) == .orderedSame
                || code == developmentAlias
        }
        var result: [String] = []
        var seen = Set<String>()
        var isBaseRenamed = false

        func append(_ name: String) {
            guard seen.insert(FuzzyMatch.normalized(name)).inserted else { return }
            result.append(name)
        }

        for code in languages {
            let strings = plist(
                at: resources.appendingPathComponent("\(code).lproj/InfoPlist.strings"))
            let translated = [table?[code] as? [String: Any], strings]
                .compactMap { $0.flatMap(AppDisplayName.inInfo) }
            translated.forEach(append)
            if let development,
                code.caseInsensitiveCompare(development) == .orderedSame || code == developmentAlias
            {
                if !translated.isEmpty { isBaseRenamed = true }
                if code == developmentFallback && !isBaseRenamed { append(base) }
            }
        }
        // A development region this Mac doesn't read still leaves the name searchable.
        if !isBaseRenamed { append(base) }
        return result
    }

    /// `CFBundleDevelopmentRegion` still ships its pre-BCP-47 spelling: Safari's reads "English".
    private static func languageCode(of region: String) -> String? {
        Locale.Language(identifier: Locale.canonicalLanguageIdentifier(from: region))
            .languageCode?.identifier
    }

    private static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil))
            as? [String: Any]
    }
}
