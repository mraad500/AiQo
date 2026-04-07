import Foundation

enum KitchenLanguageRoute {
    case arabicGPT
    case englishAppleIntelligence
}

struct KitchenLanguageRouter {
    // swiftlint:disable:next force_try
    private static let arabicRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: "[\\p{Arabic}]", options: [])
    }()

    static func route(for text: String) -> KitchenLanguageRoute {
        containsArabic(text) ? .arabicGPT : .englishAppleIntelligence
    }

    static func containsArabic(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return arabicRegex.firstMatch(in: text, options: [], range: range) != nil
    }
}
