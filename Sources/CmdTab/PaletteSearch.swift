import Foundation

enum PaletteSearch {
    private static let minSimilarity = 0.4
    private static let rememberedPromotionTolerance = 0.05

    static func rankedItems(
        _ items: [SwitcherItem],
        query: String,
        rememberedStableKey: String? = nil
    ) -> [SwitcherItem] {
        let normalized = normalizedQuery(query)
        guard !normalized.isEmpty else { return items }

        var ranked = items
            .enumerated()
            .compactMap { index, item -> (item: SwitcherItem, similarity: Double, index: Int)? in
                let similarity = relevance(for: item, normalizedQuery: normalized)
                guard similarity >= minSimilarity else { return nil }
                return (item, similarity, index)
            }
            .sorted {
                if $0.similarity != $1.similarity {
                    return $0.similarity > $1.similarity
                }
                return $0.index < $1.index
            }

        if let rememberedStableKey,
           let strongestSimilarity = ranked.first?.similarity,
           let rememberedIndex = ranked.firstIndex(where: { $0.item.historyIdentity.stableKey == rememberedStableKey }),
           strongestSimilarity - ranked[rememberedIndex].similarity <= rememberedPromotionTolerance {
            let rememberedItem = ranked.remove(at: rememberedIndex)
            ranked.insert(rememberedItem, at: 0)
        }

        return ranked.map(\.item)
    }

    static func normalizedQuery(_ query: String) -> String {
        normalizeForSpaceInsensitiveSearch(query).text
    }

    private static func relevance(for item: SwitcherItem, normalizedQuery: String) -> Double {
        let appName = item.subtitle
        let title = item.title

        let appResults = smithWatermanHighlightsIgnoringSpaces(query: normalizedQuery, text: appName, topK: 3, allowOverlaps: false)
        let titleResults = smithWatermanHighlightsIgnoringSpaces(query: normalizedQuery, text: title, topK: 3, allowOverlaps: false)

        let appSimilarity = appResults.first?.similarity ?? 0.0
        let titleSimilarity = titleResults.first?.similarity ?? 0.0

        var similarity = max(appSimilarity * 1.02, titleSimilarity)
        similarity += max(acronymBonus(query: normalizedQuery, text: appName), acronymBonus(query: normalizedQuery, text: title))

        return similarity
    }

    private static func normalizeForSpaceInsensitiveSearch(_ text: String) -> (text: String, normalizedToOriginal: [Int]) {
        let chars = Array(text)
        var normalizedChars = [Character]()
        var normalizedToOriginal = [Int]()

        normalizedChars.reserveCapacity(chars.count)
        normalizedToOriginal.reserveCapacity(chars.count)

        for (idx, char) in chars.enumerated() {
            if char.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) {
                continue
            }
            normalizedChars.append(Character(String(char).lowercased()))
            normalizedToOriginal.append(idx)
        }

        return (String(normalizedChars), normalizedToOriginal)
    }

    private static func smithWatermanHighlightsIgnoringSpaces(
        query: String,
        text: String,
        topK: Int = 1,
        allowOverlaps: Bool = false
    ) -> [SWResult] {
        let normalized = normalizedQuery(query)
        if normalized.isEmpty { return [] }

        let normalizedText = normalizeForSpaceInsensitiveSearch(text)
        if normalizedText.text.isEmpty { return [] }

        let normalizedResults = smithWatermanHighlights(
            query: normalized,
            text: normalizedText.text,
            topK: topK,
            allowOverlaps: allowOverlaps
        )

        return normalizedResults.compactMap { mapNormalizedResultToOriginal($0, normalizedText.normalizedToOriginal) }
    }

    private static func mapNormalizedResultToOriginal(_ result: SWResult, _ normalizedToOriginal: [Int]) -> SWResult? {
        guard let span = mapNormalizedRangeToOriginal(result.span, normalizedToOriginal) else { return nil }
        let subspans = result.subspans.compactMap { mapNormalizedRangeToOriginal($0, normalizedToOriginal) }
        let ops = result.ops.compactMap { mapNormalizedOpToOriginal($0, normalizedToOriginal) }
        return SWResult(score: result.score, similarity: result.similarity, span: span, subspans: subspans, ops: ops)
    }

    private static func mapNormalizedRangeToOriginal(_ range: Range<Int>, _ normalizedToOriginal: [Int]) -> Range<Int>? {
        if range.isEmpty { return nil }
        guard range.lowerBound >= 0, range.upperBound <= normalizedToOriginal.count else { return nil }
        let start = normalizedToOriginal[range.lowerBound]
        let end = normalizedToOriginal[range.upperBound - 1] + 1
        return start..<end
    }

    private static func mapNormalizedOpToOriginal(_ op: SWOp, _ normalizedToOriginal: [Int]) -> SWOp? {
        if op.op == "D" {
            if normalizedToOriginal.isEmpty { return SWOp(op: op.op, qi: op.qi, tj: 0) }
            if op.tj <= 0 { return SWOp(op: op.op, qi: op.qi, tj: normalizedToOriginal[0]) }
            if op.tj >= normalizedToOriginal.count {
                return SWOp(op: op.op, qi: op.qi, tj: normalizedToOriginal[normalizedToOriginal.count - 1] + 1)
            }
            return SWOp(op: op.op, qi: op.qi, tj: normalizedToOriginal[op.tj])
        }

        guard op.tj >= 0, op.tj < normalizedToOriginal.count else { return nil }
        return SWOp(op: op.op, qi: op.qi, tj: normalizedToOriginal[op.tj])
    }

    private static func smithWatermanHighlights(
        query: String,
        text: String,
        match: Int = 2,
        mismatch: Int = -1,
        gap: Int = -2,
        topK: Int = 1,
        minScore: Int = 1,
        allowOverlaps: Bool = false
    ) -> [SWResult] {
        let queryChars = Array(query.lowercased())
        let textChars = Array(text.lowercased())
        let queryCount = queryChars.count
        let textCount = textChars.count

        if queryCount == 0 || textCount == 0 { return [] }

        var scores = Array(repeating: Array(repeating: 0, count: textCount + 1), count: queryCount + 1)
        var backtrack = Array(repeating: Array(repeating: Character("\0"), count: textCount + 1), count: queryCount + 1)

        for i in 1...queryCount {
            for j in 1...textCount {
                let diagonal = scores[i - 1][j - 1] + (queryChars[i - 1] == textChars[j - 1] ? match : mismatch)
                let up = scores[i - 1][j] + gap
                let left = scores[i][j - 1] + gap

                var value = diagonal
                var pointer: Character = "D"
                if up > value { value = up; pointer = "U" }
                if left > value { value = left; pointer = "L" }
                if value < 0 { value = 0; pointer = "\0" }

                scores[i][j] = value
                backtrack[i][j] = pointer
            }
        }

        var candidates: [(score: Int, i: Int, j: Int)] = []
        for i in 1...queryCount {
            for j in 1...textCount {
                let score = scores[i][j]
                if score > 0 { candidates.append((score, i, j)) }
            }
        }

        if candidates.isEmpty { return [] }
        candidates.sort { $0.score > $1.score }

        var results: [SWResult] = []
        var usedSpans: [Range<Int>] = []

        func rangesOverlap(_ lhs: Range<Int>, _ rhs: Range<Int>) -> Bool {
            lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
        }

        func backtrackResult(_ iStart: Int, _ jStart: Int) -> (ops: [SWOp], span: Range<Int>, subspans: [Range<Int>], score: Int) {
            var reversedOps: [SWOp] = []
            var consumedTextIndexes: [Int] = []
            var i = iStart
            var j = jStart

            while i > 0 && j > 0 && scores[i][j] > 0 {
                let pointer = backtrack[i][j]
                if pointer == "D" {
                    reversedOps.append(SWOp(op: queryChars[i - 1] == textChars[j - 1] ? "M" : "S", qi: i - 1, tj: j - 1))
                    consumedTextIndexes.append(j - 1)
                    i -= 1
                    j -= 1
                } else if pointer == "U" {
                    reversedOps.append(SWOp(op: "D", qi: i - 1, tj: j))
                    i -= 1
                } else if pointer == "L" {
                    reversedOps.append(SWOp(op: "I", qi: i, tj: j - 1))
                    consumedTextIndexes.append(j - 1)
                    j -= 1
                } else {
                    break
                }
            }

            let ops = Array(reversedOps.reversed())
            let spanStart = consumedTextIndexes.min() ?? jStart
            let spanEnd = (consumedTextIndexes.max() ?? (jStart - 1)) + 1
            let span = spanStart..<spanEnd

            var subspans: [Range<Int>] = []
            var runStart: Int?
            var cursor = spanStart

            for op in ops {
                switch op.op {
                case "M":
                    if runStart == nil { runStart = cursor }
                    cursor += 1
                case "S", "I":
                    if let runStart { subspans.append(runStart..<cursor) }
                    runStart = nil
                    cursor += 1
                case "D":
                    if let runStart { subspans.append(runStart..<cursor) }
                    runStart = nil
                default:
                    break
                }
            }

            if let runStart { subspans.append(runStart..<cursor) }
            return (ops, span, subspans, scores[iStart][jStart])
        }

        for (score, i, j) in candidates {
            if results.count >= topK || score < minScore { break }
            let result = backtrackResult(i, j)
            if !allowOverlaps && usedSpans.contains(where: { rangesOverlap($0, result.span) }) {
                continue
            }

            let similarity = Double(result.score) / Double(max(1, match * queryCount))
            results.append(
                SWResult(
                    score: result.score,
                    similarity: similarity,
                    span: result.span,
                    subspans: result.subspans,
                    ops: result.ops
                )
            )
            usedSpans.append(result.span)
        }

        return results
    }

    static func acronymBonus(query: String, text: String) -> Double {
        let normalized = normalizedQuery(query)
        if normalized.isEmpty { return 0 }

        let lowercasedText = text.lowercased()
        if lowercasedText.hasPrefix(normalized) {
            return 6.0 + min(2.0, Double(normalized.count) * 0.25)
        }

        let starts = wordStarts(in: text)
        if starts.isEmpty { return 0 }

        let queryChars = Array(normalized)
        var queryIndex = 0
        var firstMatch: Int?

        for (index, char) in starts.enumerated() {
            if queryIndex >= queryChars.count { break }
            if char == queryChars[queryIndex] {
                if firstMatch == nil { firstMatch = index }
                queryIndex += 1
            }
        }

        guard queryIndex == queryChars.count else { return 0 }
        let position = firstMatch ?? 0
        return 4.0 + min(2.0, Double(normalized.count) * 0.2) + (position == 0 ? 1.0 : max(0.0, 0.6 - Double(position) * 0.15))
    }

    private static func wordStarts(in text: String) -> [Character] {
        let chars = Array(text)
        if chars.isEmpty { return [] }

        var starts: [Character] = []
        starts.reserveCapacity(min(16, chars.count))

        for index in 0..<chars.count {
            let char = chars[index]
            if !isAlphaNumeric(char) { continue }
            if index == 0 || !isAlphaNumeric(chars[index - 1]) || (isLowercase(chars[index - 1]) && isUppercase(char)) {
                starts.append(Character(String(char).lowercased()))
            }
        }

        return starts
    }

    private static func isAlphaNumeric(_ char: Character) -> Bool {
        char.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    private static func isLowercase(_ char: Character) -> Bool {
        char.unicodeScalars.allSatisfy { CharacterSet.lowercaseLetters.contains($0) }
    }

    private static func isUppercase(_ char: Character) -> Bool {
        char.unicodeScalars.allSatisfy { CharacterSet.uppercaseLetters.contains($0) }
    }
}

private struct SWOp {
    let op: Character
    let qi: Int
    let tj: Int
}

private struct SWResult {
    let score: Int
    let similarity: Double
    let span: Range<Int>
    let subspans: [Range<Int>]
    let ops: [SWOp]
}
