import Foundation

enum CaptainMessageIntent: String, Sendable {
    case general
    case workout
    case nutrition
    case sleep
    case challenge
    case vibe
    case emotionalSupport
    case recovery

    static func detect(message: String, screenContext: ScreenContext) -> CaptainMessageIntent {
        let normalized = CaptainCognitiveTextAnalyzer.normalizedText(message)

        if screenContext == .sleepAnalysis || CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: sleepKeywords) {
            return .sleep
        }

        if screenContext == .kitchen || CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: nutritionKeywords) {
            return .nutrition
        }

        if screenContext == .gym || CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: workoutKeywords) {
            return .workout
        }

        if screenContext == .peaks || CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: challengeKeywords) {
            return .challenge
        }

        if screenContext == .myVibe || CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: vibeKeywords) {
            return .vibe
        }

        if CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: emotionalSupportKeywords) {
            return .emotionalSupport
        }

        if CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: recoveryKeywords) {
            return .recovery
        }

        return .general
    }

    var retrievalCategoryWeights: [String: Double] {
        switch self {
        case .general:
            return [
                "goal": 2.0,
                "preference": 1.8,
                "insight": 1.6,
                "mood": 1.4,
                "active_record_project": 1.2
            ]
        case .workout:
            return [
                "injury": 4.8,
                "goal": 4.2,
                "preference": 3.8,
                "body": 2.8,
                "sleep": 2.2,
                "active_record_project": 3.6,
                "workout_history": 2.8
            ]
        case .nutrition:
            return [
                "nutrition": 4.6,
                "goal": 3.3,
                "preference": 2.6,
                "body": 2.4,
                "sleep": 1.2
            ]
        case .sleep:
            return [
                "sleep": 5.2,
                "preference": 2.5,
                "mood": 2.2,
                "goal": 1.0
            ]
        case .challenge:
            return [
                "active_record_project": 5.5,
                "goal": 3.5,
                "preference": 1.7,
                "workout_history": 2.6,
                "mood": 1.2
            ]
        case .vibe:
            return [
                "mood": 4.5,
                "preference": 2.5,
                "insight": 2.5,
                "sleep": 2.0,
                "goal": 1.0
            ]
        case .emotionalSupport:
            return [
                "mood": 4.8,
                "insight": 3.3,
                "sleep": 2.1,
                "goal": 1.5,
                "preference": 1.0
            ]
        case .recovery:
            return [
                "injury": 4.4,
                "sleep": 3.8,
                "mood": 2.2,
                "goal": 1.4,
                "preference": 1.6
            ]
        }
    }

    var coachingDirective: String {
        switch self {
        case .general:
            return "Answer the direct ask first, then personalize with the strongest relevant memory only."
        case .workout:
            return "Coach like a sharp trainer: action first, respect injuries and recovery, and align the plan with the user's goal."
        case .nutrition:
            return "Keep food advice practical, simple, and aligned with the user's body goal and routine."
        case .sleep:
            return "Bias toward calm, recovery, bedtime consistency, and gentle guidance instead of hype."
        case .challenge:
            return "Anchor the reply in momentum, accountability, and measurable wins tied to the user's active challenge."
        case .vibe:
            return "Tune the response to mood and energy first, then guide gently without sounding clinical."
        case .emotionalSupport:
            return "Empathize first, then give one grounded next step. Don't rush into fixing mode."
        case .recovery:
            return "Protect recovery, reduce overload, and keep recommendations low-friction."
        }
    }

    var label: String {
        switch self {
        case .general:
            return "general_coaching"
        case .workout:
            return "workout_coaching"
        case .nutrition:
            return "nutrition_guidance"
        case .sleep:
            return "sleep_guidance"
        case .challenge:
            return "challenge_execution"
        case .vibe:
            return "vibe_regulation"
        case .emotionalSupport:
            return "emotional_support"
        case .recovery:
            return "recovery_support"
        }
    }
}

enum CaptainEmotionalSignal: String, Sendable {
    case neutral
    case motivated
    case tired
    case stressed
    case frustrated

    static func detect(message: String) -> CaptainEmotionalSignal {
        let normalized = CaptainCognitiveTextAnalyzer.normalizedText(message)

        if CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: motivatedKeywords) {
            return .motivated
        }

        if CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: tiredKeywords) {
            return .tired
        }

        if CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: stressedKeywords) {
            return .stressed
        }

        if CaptainCognitiveTextAnalyzer.containsAny(normalized, keywords: frustratedKeywords) {
            return .frustrated
        }

        return .neutral
    }

    var replyDirective: String {
        switch self {
        case .neutral:
            return "Keep the reply human, direct, and not overdramatic."
        case .motivated:
            return "Match the user's momentum, but keep it disciplined and specific."
        case .tired:
            return "Acknowledge low energy and avoid overloading the user with intensity."
        case .stressed:
            return "Lower pressure, simplify the advice, and sound grounding rather than intense."
        case .frustrated:
            return "Validate the friction first, then give a clean path forward without sounding preachy."
        }
    }

    var label: String {
        switch self {
        case .neutral:
            return "neutral"
        case .motivated:
            return "motivated"
        case .tired:
            return "tired"
        case .stressed:
            return "stressed"
        case .frustrated:
            return "frustrated"
        }
    }
}

enum CaptainCognitiveTextAnalyzer {
    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "for", "from", "how", "i", "im", "in", "is", "it", "me",
        "my", "of", "on", "or", "that", "the", "this", "to", "today", "want", "with", "you", "your",
        "ابي", "ابغى", "اريد", "اليوم", "شنو", "شلون", "على", "عن", "اني", "انا", "هاي", "هذا", "هذي",
        "كلش", "من", "الى", "في", "مو", "لا", "بس", "بعد", "عندي", "عنده", "علي", "ويا", "حتى", "اذا"
    ]

    static func normalizedText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
            .lowercased()
    }

    static func tokens(from text: String) -> Set<String> {
        let normalized = normalizedText(text)
        let cleaned = normalized.replacingOccurrences(
            of: #"[^\p{L}\p{N}]+"#,
            with: " ",
            options: .regularExpression
        )

        return Set(
            cleaned
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 2 && !stopWords.contains($0) }
        )
    }

    static func containsAny(_ normalizedText: String, keywords: [String]) -> Bool {
        keywords.contains { normalizedText.contains($0) }
    }
}

struct CaptainPromptContext: Sendable {
    let profileSummary: String
    let intentSummary: String
    let workingMemorySummary: String
}

@MainActor
final class CaptainCognitivePipeline {
    static let shared = CaptainCognitivePipeline()

    private let memoryStore: MemoryStore
    private let recordProjectManager: RecordProjectManager
    private let profileStore: UserProfileStore
    private let personalizationStore: CaptainPersonalizationStore

    init(
        memoryStore: MemoryStore? = nil,
        recordProjectManager: RecordProjectManager? = nil,
        profileStore: UserProfileStore? = nil,
        personalizationStore: CaptainPersonalizationStore? = nil
    ) {
        self.memoryStore = memoryStore ?? .shared
        self.recordProjectManager = recordProjectManager ?? .shared
        self.profileStore = profileStore ?? .shared
        self.personalizationStore = personalizationStore ?? .shared
    }

    func buildPromptContext(
        userMessage: String,
        screenContext: ScreenContext,
        customization: CaptainCustomization,
        preferredName: String?
    ) -> CaptainPromptContext {
        let intent = CaptainMessageIntent.detect(message: userMessage, screenContext: screenContext)
        let emotionalSignal = CaptainEmotionalSignal.detect(message: userMessage)

        return CaptainPromptContext(
            profileSummary: buildStableProfileSummary(
                customization: customization,
                preferredName: preferredName
            ),
            intentSummary: buildIntentSummary(
                intent: intent,
                emotionalSignal: emotionalSignal,
                screenContext: screenContext
            ),
            workingMemorySummary: buildWorkingMemorySummary(
                userMessage: userMessage,
                screenContext: screenContext,
                intent: intent
            )
        )
    }
}

private extension CaptainCognitivePipeline {
    func buildStableProfileSummary(
        customization: CaptainCustomization,
        preferredName: String?
    ) -> String {
        let profile = profileStore.current

        var lines = [
            "- Preferred name: \(summaryValue(preferredName))",
            "- Profile name: \(summaryValue(profile.name))",
            "- Username: \(summaryValue(profile.username))",
            "- Declared goal text: \(summaryValue(profile.goalText))",
            "- Age: \(summaryValue(customization.age))",
            "- Height cm: \(summaryValue(customization.height))",
            "- Weight kg: \(summaryValue(customization.weight))",
            "- Preferred tone: \(customization.tone.rawValue)"
        ]

        if let personalization = personalizationStore.currentSnapshot() {
            lines.append(contentsOf: [
                "- Primary goal: \(personalization.primaryGoal.canonicalGoalText)",
                "- Favorite sport: \(personalization.favoriteSport.canonicalValue)",
                "- Preferred workout time: \(personalization.preferredWorkoutTime.canonicalValue)",
                "- Bedtime preference: \(CaptainPersonalizationTimeFormatter.localizedString(personalization.bedtime))",
                "- Wake time preference: \(CaptainPersonalizationTimeFormatter.localizedString(personalization.wakeTime))",
                "- Smart wake recommendation: \(CaptainPersonalizationTimeFormatter.localizedString(personalization.recommendedWakeTime))",
                "- Smart wake alarm saved: \(personalization.isAlarmSaved ? "yes" : "no")"
            ])
        }

        return lines.joined(separator: "\n")
    }

    func buildIntentSummary(
        intent: CaptainMessageIntent,
        emotionalSignal: CaptainEmotionalSignal,
        screenContext: ScreenContext
    ) -> String {
        [
            "- primary_intent: \(intent.label)",
            "- emotional_signal: \(emotionalSignal.label)",
            "- screen_priority: \(screenContext.focusSummary)",
            "- reply_strategy: \(intent.coachingDirective)",
            "- tone_strategy: \(emotionalSignal.replyDirective)"
        ]
        .joined(separator: "\n")
    }

    func buildWorkingMemorySummary(
        userMessage: String,
        screenContext: ScreenContext,
        intent: CaptainMessageIntent
    ) -> String {
        let relevantMemories = memoryStore.retrieveRelevantMemories(
            for: userMessage,
            screenContext: screenContext,
            limit: 8
        )

        let constraintCategories: Set<String> = ["injury", "sleep", "medical_condition", "body"]
        let constraints = relevantMemories.filter { constraintCategories.contains($0.category) }
        let strategyAnchors = relevantMemories.filter { !constraintCategories.contains($0.category) }

        var sections: [String] = []

        if !strategyAnchors.isEmpty {
            sections.append(
                [
                    "[strategic_memories]",
                    strategyAnchors.map(memoryLine).joined(separator: "\n")
                ]
                .joined(separator: "\n")
            )
        }

        if !constraints.isEmpty {
            sections.append(
                [
                    "[constraints_and_recovery]",
                    constraints.map(memoryLine).joined(separator: "\n")
                ]
                .joined(separator: "\n")
            )
        }

        if shouldIncludeActiveProject(for: intent, screenContext: screenContext),
           let activeProject = recordProjectManager.activeProject() {
            sections.append(
                """
                [active_record_project]
                - title: \(activeProject.recordTitle)
                - target: \(activeProject.targetValue) \(activeProject.unit)
                - current_best: \(activeProject.bestPerformance) \(activeProject.unit)
                - current_week: \(activeProject.currentWeek)/\(activeProject.totalWeeks)
                """
            )
        }

        if sections.isEmpty {
            return "- No high-signal long-term memories were activated for this reply."
        }

        return sections.joined(separator: "\n\n")
    }

    func shouldIncludeActiveProject(
        for intent: CaptainMessageIntent,
        screenContext: ScreenContext
    ) -> Bool {
        screenContext == .peaks || intent == .challenge
    }

    func memoryLine(for memory: CaptainMemorySnapshot) -> String {
        "- \(memory.key): \(memory.value)"
    }

    func summaryValue(_ value: String?) -> String {
        guard let value else { return "not provided" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "not provided" : trimmed
    }
}

private extension CaptainMessageIntent {
    static let workoutKeywords = [
        "تمرين", "تمريني", "جيم", "حديد", "مقاوم", "مقاومة", "ركض", "جري", "كارديو", "workout", "gym", "train", "training", "exercise", "lift", "cardio", "run"
    ]

    static let nutritionKeywords = [
        "اكل", "وجبة", "وجبات", "سعرات", "ثلاجة", "بروتين", "دايت", "طبخ", "meal", "food", "nutrition", "calories", "protein", "diet", "fridge", "kitchen"
    ]

    static let sleepKeywords = [
        "نوم", "نمت", "نعسان", "ارق", "سهر", "استيقاظ", "wake", "sleep", "slept", "bed", "bedtime", "insomnia", "wake up"
    ]

    static let challengeKeywords = [
        "تحدي", "تحديات", "التزام", "انجاز", "رقم", "رقمي", "record", "challenge", "discipline", "progress", "streak", "momentum"
    ]

    static let vibeKeywords = [
        "مود", "فايب", "مزاج", "تركيز", "هدي", "هديء", "music", "mood", "vibe", "focus", "playlist"
    ]

    static let emotionalSupportKeywords = [
        "تعبان", "محبط", "زعلان", "مضغوط", "قلقان", "stress", "stressed", "sad", "anxious", "overwhelmed", "frustrated"
    ]

    static let recoveryKeywords = [
        "استشفاء", "تعب", "ارهاق", "وجع", "الم", "recover", "recovery", "sore", "fatigue", "exhausted"
    ]
}

private extension CaptainEmotionalSignal {
    static let motivatedKeywords = [
        "متحمس", "جاهز", "يلا", "منطلق", "motivated", "ready", "let's go", "locked in"
    ]

    static let tiredKeywords = [
        "تعبان", "نعسان", "مرهق", "ارهاق", "مالي خلق", "tired", "sleepy", "exhausted", "drained"
    ]

    static let stressedKeywords = [
        "مضغوط", "قلقان", "توتر", "مرتبك", "stress", "stressed", "anxious", "overwhelmed"
    ]

    static let frustratedKeywords = [
        "محبط", "معصب", "زهقان", "طفشان", "frustrated", "annoyed", "stuck"
    ]
}
