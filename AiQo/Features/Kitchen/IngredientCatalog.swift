import Foundation

enum IngredientCatalog {
    static func normalize(_ s: String) -> String {
        var value = s
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
            .lowercased()

        let arabicReplacements: [String: String] = [
            "أ": "ا",
            "إ": "ا",
            "آ": "ا",
            "ى": "ي",
            "ة": "ه",
            "ؤ": "و",
            "ئ": "ي",
            "ـ": ""
        ]

        for (source, replacement) in arabicReplacements {
            value = value.replacingOccurrences(of: source, with: replacement)
        }

        let allowed = CharacterSet.letters
            .union(.decimalDigits)
            .union(.whitespacesAndNewlines)

        let cleaned = String(
            String.UnicodeScalarView(
                value.unicodeScalars.map { scalar in
                    allowed.contains(scalar) ? scalar : " "
                }
            )
        )

        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func match(from text: String) -> IngredientKey? {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return nil }

        let prioritizedAliasEntries = IngredientKey.allCases
            .flatMap { key in
                key.aliases.map { (key: key, alias: normalize($0)) }
            }
            .sorted { lhs, rhs in
                if lhs.alias.count != rhs.alias.count {
                    return lhs.alias.count > rhs.alias.count
                }
                return lhs.key.rawValue < rhs.key.rawValue
            }

        for entry in prioritizedAliasEntries where normalized.contains(entry.alias) {
            return entry.key
        }

        return nil
    }

    static func extractAll(from text: String) -> [IngredientKey] {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return [] }

        let normalizedAliasesByKey = IngredientKey.allCases.map { key in
            (key: key, aliases: key.aliases.map { alias in normalize(alias) })
        }

        let matches: [(IngredientKey, Int, Int)] = normalizedAliasesByKey.compactMap { item in
            guard let position = firstMatchPosition(in: normalized, aliases: item.aliases) else {
                return nil
            }
            return (item.key, item.key.category.priority, position)
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }
                if lhs.2 != rhs.2 {
                    return lhs.2 < rhs.2
                }
                return lhs.0.rawValue < rhs.0.rawValue
            }
            .map(\.0)
    }

    static func extractAll(from texts: [String]) -> [IngredientKey] {
        var found: [IngredientKey] = []

        for text in texts {
            for key in extractAll(from: text) where !found.contains(key) {
                found.append(key)
            }
        }

        return found.sorted { lhs, rhs in
            if lhs.category.priority != rhs.category.priority {
                return lhs.category.priority < rhs.category.priority
            }
            guard let lhsIndex = found.firstIndex(of: lhs), let rhsIndex = found.firstIndex(of: rhs) else {
                return lhs.rawValue < rhs.rawValue
            }
            return lhsIndex < rhsIndex
        }
    }

    private static func firstMatchPosition(in text: String, aliases: [String]) -> Int? {
        var bestPosition: Int?

        for alias in aliases where !alias.isEmpty {
            guard let range = text.range(of: alias) else { continue }
            let position = text.distance(from: text.startIndex, to: range.lowerBound)
            if let currentBestPosition = bestPosition {
                if position < currentBestPosition {
                    bestPosition = position
                }
            } else {
                bestPosition = position
            }
        }

        return bestPosition
    }
}
