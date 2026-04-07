import Foundation

enum KitchenLanguageRoute {
    case arabicGPT
    case englishAppleIntelligence
}

struct KitchenLanguageRouter {
    private static let arabicRegexPattern = "[\\p{Arabic}]"

    static func route(for text: String) -> KitchenLanguageRoute {
        containsArabic(text) ? .arabicGPT : .englishAppleIntelligence
    }

    static func containsArabic(_ text: String) -> Bool {
        guard !text.isEmpty,
              let regex = try? NSRegularExpression(pattern: arabicRegexPattern, options: []) else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
