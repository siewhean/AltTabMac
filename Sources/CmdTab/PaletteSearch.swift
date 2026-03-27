import Foundation

enum PaletteSearch {
    private struct SearchFields {
        let normalizedTitle: String
        let normalizedSubtitle: String
        let normalizedSourceIdentifier: String
        let sourceIdentifierTail: String
        let combinedNormalized: String
        let combinedTokens: [String]
        let acronyms: [String]
    }

    static func rankedItems(
        _ items: [SwitcherItem],
        query: String,
        rememberedStableKey: String? = nil
    ) -> [SwitcherItem] {
        let normalizedQuery = normalizedQuery(query)
        guard !normalizedQuery.isEmpty else { return items }

        let queryTokens = tokenize(normalizedQuery)
        return items
            .enumerated()
            .compactMap { index, item -> (item: SwitcherItem, score: Int, index: Int)? in
                guard let score = score(
                    for: item,
                    normalizedQuery: normalizedQuery,
                    queryTokens: queryTokens,
                    rememberedStableKey: rememberedStableKey
                ) else {
                    return nil
                }
                return (item, score, index)
            }
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.index < $1.index
            }
            .map(\.item)
    }

    static func normalizedQuery(_ text: String) -> String {
        let lowered = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func score(
        for item: SwitcherItem,
        normalizedQuery: String,
        queryTokens: [String],
        rememberedStableKey: String?
    ) -> Int? {
        let fields = searchFields(for: item)
        var score = 0
        var matched = false

        if rememberedStableKey == item.historyIdentity.stableKey {
            score += 4_500
            matched = true
        }

        if fields.normalizedTitle == normalizedQuery {
            score += 3_400
            matched = true
        }

        if fields.normalizedSubtitle == normalizedQuery || fields.sourceIdentifierTail == normalizedQuery {
            score += 3_000
            matched = true
        }

        if fields.normalizedTitle.hasPrefix(normalizedQuery) {
            score += 2_500
            matched = true
        }

        if fields.normalizedSubtitle.hasPrefix(normalizedQuery) || fields.sourceIdentifierTail.hasPrefix(normalizedQuery) {
            score += 2_200
            matched = true
        }

        if fields.acronyms.contains(normalizedQuery) {
            score += 2_600
            matched = true
        } else if fields.acronyms.contains(where: { $0.hasPrefix(normalizedQuery) }) {
            score += 2_100
            matched = true
        }

        if fields.combinedNormalized.contains(normalizedQuery) {
            score += 1_300
            matched = true
        }

        if allQueryTokensMatch(queryTokens, combinedTokens: fields.combinedTokens) {
            score += 1_700
            matched = true
        } else if allQueryTokensContained(queryTokens, haystack: fields.combinedNormalized) {
            score += 1_100
            matched = true
        }

        if !matched {
            return nil
        }

        score += max(0, 60 - min(item.title.count, 60))
        return score
    }

    private static func allQueryTokensMatch(_ queryTokens: [String], combinedTokens: [String]) -> Bool {
        guard !queryTokens.isEmpty else { return false }
        return queryTokens.allSatisfy { queryToken in
            combinedTokens.contains(where: { token in
                token == queryToken || token.hasPrefix(queryToken)
            })
        }
    }

    private static func allQueryTokensContained(_ queryTokens: [String], haystack: String) -> Bool {
        guard !queryTokens.isEmpty else { return false }
        return queryTokens.allSatisfy { haystack.contains($0) }
    }

    private static func searchFields(for item: SwitcherItem) -> SearchFields {
        let normalizedTitle = normalizedQuery(item.title)
        let normalizedSubtitle = normalizedQuery(item.subtitle)
        let normalizedSourceIdentifier = normalizedQuery(item.sourceAppIdentifier ?? "")
        let sourceIdentifierTail = item.sourceAppIdentifier?
            .split(separator: ".")
            .last
            .map(String.init)
            .map(normalizedQuery) ?? ""

        let combinedPieces = [
            normalizedTitle,
            normalizedSubtitle,
            normalizedSourceIdentifier,
            sourceIdentifierTail
        ].filter { !$0.isEmpty }

        let combinedNormalized = combinedPieces.joined(separator: " ")
        let combinedTokens = tokenize(combinedNormalized)
        let acronyms = [
            acronym(from: item.title),
            acronym(from: item.subtitle),
            acronym(from: item.sourceAppIdentifier ?? "")
        ].filter { !$0.isEmpty }

        return SearchFields(
            normalizedTitle: normalizedTitle,
            normalizedSubtitle: normalizedSubtitle,
            normalizedSourceIdentifier: normalizedSourceIdentifier,
            sourceIdentifierTail: sourceIdentifierTail,
            combinedNormalized: combinedNormalized,
            combinedTokens: combinedTokens,
            acronyms: acronyms
        )
    }

    private static func acronym(from text: String) -> String {
        let separators = CharacterSet.alphanumerics.inverted
        let words = text
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        let initials = words.compactMap { $0.first?.lowercased() }.joined()
        if !initials.isEmpty {
            return initials
        }

        return normalizedQuery(text)
    }
}
