import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

#if DEBUG
/// Experimental, DEBUG-only lab for the FREE on-device Captain.
///
/// It compares two on-device strategies for producing an authentic Iraqi reply,
/// so we can READ ~10 real samples on a device and judge quality *before* wiring
/// anything into production:
///
///   • Path A — "Direct":  the model writes Iraqi directly (today's shipping
///                         `CaptainOnDeviceChatEngine`).
///   • Path B — "Bridge":  the model answers in English (where Apple Intelligence
///                         is strongest), then rewrites it into spoken Iraqi, then a
///                         deterministic dialect polish cleans residual MSA. This is
///                         the "generate-then-localize" idea, refined with app assets
///                         instead of a naive translate (which would produce dead MSA).
///
/// Everything here is on-device. No cloud, no network, no IAP. Nothing is reachable
/// in a release build (the whole file is `#if DEBUG`).
actor OnDeviceCaptainLab {

    struct Output: Sendable {
        var direct: String?
        var directError: String?
        var directMs: Int = 0

        var englishCore: String?
        var iraqiBridge: String?
        var bridgeError: String?
        var bridgeMs: Int = 0
    }

    private let directEngine = CaptainOnDeviceChatEngine()

    // MARK: - Availability

    /// Human-readable Apple Intelligence availability (safe to call from anywhere).
    nonisolated func availabilityDescription() -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "✅ Apple Intelligence جاهز على الجهاز"
            case .unavailable(let reason):
                return "⚠️ غير متاح: \(String(describing: reason))"
            @unknown default:
                return "؟ حالة غير معروفة"
            }
        } else {
            return "iOS < 26 — FoundationModels غير متوفر"
        }
        #else
        return "FoundationModels غير مُضمّن بهذا البناء"
        #endif
    }

    // MARK: - Run one prompt through both paths

    func run(prompt: String) async -> Output {
        var out = Output()

        // Path A — direct Iraqi via the real shipping engine (honest baseline).
        let startA = Date()
        do {
            out.direct = try await directEngine.respond(to: prompt)
        } catch {
            out.directError = error.localizedDescription
        }
        out.directMs = Int(Date().timeIntervalSince(startA) * 1000)

        // Path B — English core → Iraqi rewrite → deterministic dialect polish.
        let startB = Date()
        do {
            let english = try await generate(system: Self.englishCoreInstructions, user: prompt)
            out.englishCore = english
            let rewritten = try await generate(system: Self.iraqiRewriteInstructions, user: english)
            out.iraqiBridge = Self.dialectPolish(rewritten)
        } catch {
            out.bridgeError = error.localizedDescription
        }
        out.bridgeMs = Int(Date().timeIntervalSince(startB) * 1000)

        return out
    }

    // MARK: - On-device generation (one shot)

    private func generate(system: String, user: String) async throws -> String {
        let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                throw CaptainOnDeviceChatError.modelUnavailable
            }
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: trimmed)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif

        throw CaptainOnDeviceChatError.foundationModelsUnavailable
    }

    // MARK: - Instructions

    private static let englishCoreInstructions = """
    You are Captain Hammoudi, an elite, warm, direct fitness & wellbeing coach inside
    the AiQo app (a Bio-Digital OS).
    Answer the user's message helpfully IN ENGLISH ONLY.
    - 2 to 4 short lines.
    - Practical and grounded. No medical claims. Never invent the user's numbers.
    - End with ONE short question to keep the conversation going.
    """

    private static let iraqiRewriteInstructions = """
    You are an expert localizer into spoken IRAQI Arabic (Mesopotamian, masculine,
    casual — a Baghdadi coach talking to a buddy).
    Rewrite the user's message into natural spoken Iraqi. Keep the SAME meaning and a
    similar length. Use Iraqi words such as: شلونك، هسه، شكد، اكو، ماكو، عاشت ايدك،
    شد حيلك، يلا، خوش، زين، چان، هواية، بس. Do NOT use formal MSA (فصحى). Do NOT use
    Egyptian/Levantine/Gulf words. Output ONLY the Iraqi text — no quotes, no notes.

    Example —
    Input: You're close to your goal. Don't stop now, the finish matters more than the start.
    Output: قربت عالهدف يا بطل. لا توقف هسه، الختام أهم من البداية.

    Example —
    Input: Get some rest tonight. Your body needs recovery to grow.
    Output: اليله ريّح زين. جسمك يريد راحة حتى يكبر، خوش نوم يعوّضك.
    """

    // MARK: - Deterministic dialect polish (no model, no network)

    /// Cleans residual MSA markers into Iraqi equivalents. Whole-word only, so it never
    /// corrupts a word that merely contains a target as a substring.
    nonisolated static func dialectPolish(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "*", with: "")

        // Multi-word phrases first so they win over their single-word components.
        let pairs: [(String, String)] = [
            ("كيف حالك", "شلونك"), ("كيف الحال", "شلونك"),
            ("ماذا تريد", "شتريد"), ("ما الذي", "شنو"), ("ماذا", "شنو"),
            ("لا يوجد", "ماكو"), ("هناك", "اكو"), ("يوجد", "اكو"),
            ("الآن", "هسه"), ("الان", "هسه"), ("حالاً", "هسه"), ("هلأ", "هسه"),
            ("لماذا", "ليش"), ("كثيراً", "هواية"), ("كثيرا", "هواية"),
            ("جيداً", "زين"), ("جيد", "زين"), ("رائع", "خوش"),
            ("أيضاً", "هم"), ("ايضا", "هم"), ("فقط", "بس"), ("هيا", "يلا"),
            ("يمكنك", "تكدر"), ("تستطيع", "تكدر"),
            ("الذي", "اللي"), ("التي", "اللي"),
            ("إيه", "اي"), ("ايه", "اي"), ("عشان", "حتى"), ("علشان", "حتى"),
            ("كده", "هيج"), ("بدي", "اريد"),
        ]
        for (from, to) in pairs {
            s = replaceWholeWord(from, with: to, in: s)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func replaceWholeWord(
        _ word: String,
        with replacement: String,
        in text: String
    ) -> String {
        let pattern = "(?<!\\p{L})\(NSRegularExpression.escapedPattern(for: word))(?!\\p{L})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
#endif
