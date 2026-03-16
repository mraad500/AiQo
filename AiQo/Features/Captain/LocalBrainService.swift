import Foundation

private enum LocalBackgroundNotificationKind: String {
    case sleepNotification = "background.sleep_notification"
    case inactivityNotification = "background.inactivity_notification"
}

enum LocalConversationRole: String, Sendable {
    case system
    case user
    case assistant
}

struct LocalConversationMessage: Sendable {
    let role: LocalConversationRole
    let content: String

    init(role: LocalConversationRole, content: String) {
        self.role = role
        self.content = content
    }
}

struct LocalBrainRequest: Sendable {
    let conversation: [LocalConversationMessage]
    let screenContext: ScreenContext
    let language: AppLanguage
    let systemPrompt: String
    let contextData: CaptainContextData
    let userProfileSummary: String
    let hasAttachedImage: Bool
}

struct LocalBrainServiceReply: Sendable {
    let message: String
    let workoutPlan: WorkoutPlan?
    let mealPlan: MealPlan?
    let rawText: String
}

enum LocalBrainServiceError: LocalizedError {
    case emptyConversation
    case missingUserMessage
    case invalidStructuredResponse

    var errorDescription: String? {
        switch self {
        case .emptyConversation:
            return "Captain local generation cannot run with an empty conversation."
        case .missingUserMessage:
            return "Captain local generation requires a user message."
        case .invalidStructuredResponse:
            return "Captain local generation produced invalid structured JSON."
        }
    }
}

struct LocalBrainService: Sendable {
    private let healthManager: HealthKitManager
    private let sleepAgent: AppleIntelligenceSleepAgent
    private let onDeviceNotificationEngine: CaptainOnDeviceChatEngine

    init(
        healthManager: HealthKitManager = .shared,
        sleepAgent: AppleIntelligenceSleepAgent = AppleIntelligenceSleepAgent(),
        onDeviceNotificationEngine: CaptainOnDeviceChatEngine = CaptainOnDeviceChatEngine()
    ) {
        self.healthManager = healthManager
        self.sleepAgent = sleepAgent
        self.onDeviceNotificationEngine = onDeviceNotificationEngine
    }

    func generateReply(request: LocalBrainRequest) async throws -> LocalBrainServiceReply {
        let normalizedConversation = request.conversation.compactMap { message -> LocalConversationMessage? in
            let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else { return nil }
            return LocalConversationMessage(role: message.role, content: trimmedContent)
        }

        guard !normalizedConversation.isEmpty else {
            throw LocalBrainServiceError.emptyConversation
        }

        let payload = LocalAppIntentPayload(
            systemPrompt: request.systemPrompt,
            transcript: normalizedConversation,
            screenContext: request.screenContext,
            language: request.language,
            contextData: request.contextData,
            userProfileSummary: request.userProfileSummary,
            hasAttachedImage: request.hasAttachedImage
        )

        guard let latestUserMessage = payload.latestUserMessage else {
            throw LocalBrainServiceError.missingUserMessage
        }

        if let backgroundKind = LocalBackgroundNotificationKind(rawValue: payload.systemPrompt) {
            return try await makeBackgroundNotificationReply(
                payload: payload,
                latestUserMessage: latestUserMessage,
                kind: backgroundKind
            )
        }

        if payload.screenContext == .sleepAnalysis {
            return try await makeSleepAnalysisReply(payload: payload)
        }

        let intent = classifyIntent(for: latestUserMessage, in: payload)
        let structuredResponse = CaptainStructuredResponse(
            message: try await buildMessage(for: payload, intent: intent),
            workoutPlan: intent.wantsWorkoutPlan ? buildWorkoutPlan(for: payload, intent: intent) : nil,
            mealPlan: intent.wantsMealPlan ? buildMealPlan(for: payload) : nil
        )

        let rawText = try encodeStructuredResponse(structuredResponse)
        let validatedResponse = try decodeStructuredResponse(from: rawText)

        return LocalBrainServiceReply(
            message: validatedResponse.message,
            workoutPlan: validatedResponse.workoutPlan?.isMeaningful == true ? validatedResponse.workoutPlan : nil,
            mealPlan: validatedResponse.mealPlan?.isMeaningful == true ? validatedResponse.mealPlan : nil,
            rawText: rawText
        )
    }
}

private struct LocalAppIntentPayload: Sendable {
    let systemPrompt: String
    let transcript: [LocalConversationMessage]
    let screenContext: ScreenContext
    let language: AppLanguage
    let contextData: CaptainContextData
    let userProfileSummary: String
    let hasAttachedImage: Bool

    var latestUserMessage: String? {
        transcript.last(where: { $0.role == .user })?.content
    }
}

private struct LocalIntentClassification: Sendable {
    let wantsWorkoutPlan: Bool
    let wantsMealPlan: Bool
    let wantsSleepGuidance: Bool
    let wantsVibeGuidance: Bool
    let wantsChallengeGuidance: Bool
}

private struct LocalSleepSnapshot: Sendable {
    let totalHours: Double
    let deepHours: Double
    let remHours: Double
    let coreHours: Double
    let awakeMinutes: Int
}

private enum LocalWorkoutMode {
    case recovery
    case activation
    case balanced
    case performance
    case challenge
}

private enum LocalMealStyle {
    case balanced
    case quick
    case highProtein
}

private extension LocalBrainService {
    func makeBackgroundNotificationReply(
        payload: LocalAppIntentPayload,
        latestUserMessage: String,
        kind: LocalBackgroundNotificationKind
    ) async throws -> LocalBrainServiceReply {
        let fallback: String
        let message: String

        switch kind {
        case .sleepNotification:
            fallback = payload.language == .english
                ? "Your sleep session is logged. Open Captain Hamoudi for today's recovery analysis."
                : "نومك انحفظ. افتح Captain Hamoudi حتى تشوف تحليل تعافيك اليوم."
            message = try await makeSleepNotificationMessage()

        case .inactivityNotification:
            fallback = inactivityFallback(
                currentSteps: payload.contextData.steps,
                language: payload.language
            )
            do {
                message = try await onDeviceNotificationEngine.respond(to: latestUserMessage)
            } catch {
                message = fallback
            }
        }

        let normalized = normalizedNotificationMessage(
            message,
            fallback: fallback
        )
        let structuredResponse = CaptainStructuredResponse(message: normalized)
        let rawText = try encodeStructuredResponse(structuredResponse)
        let validatedResponse = try decodeStructuredResponse(from: rawText)

        return LocalBrainServiceReply(
            message: validatedResponse.message,
            workoutPlan: nil,
            mealPlan: nil,
            rawText: rawText
        )
    }

    func classifyIntent(
        for userMessage: String,
        in payload: LocalAppIntentPayload
    ) -> LocalIntentClassification {
        let wantsMealFromKeywords = containsAny(userMessage, keywords: Self.mealKeywords)
        let wantsWorkoutFromKeywords = containsAny(userMessage, keywords: Self.workoutKeywords)
        let wantsSleepGuidance = payload.screenContext == .sleepAnalysis || containsAny(userMessage, keywords: Self.sleepKeywords)
        let wantsVibeGuidance = payload.screenContext == .myVibe || containsAny(userMessage, keywords: Self.vibeKeywords)
        let wantsChallengeGuidance = payload.screenContext == .peaks || containsAny(userMessage, keywords: Self.challengeKeywords)

        let wantsMealPlan: Bool
        switch payload.screenContext {
        case .kitchen:
            wantsMealPlan = true
        case .gym, .sleepAnalysis, .peaks, .mainChat, .myVibe:
            wantsMealPlan = payload.hasAttachedImage || wantsMealFromKeywords
        }

        let wantsWorkoutPlan: Bool
        switch payload.screenContext {
        case .gym:
            wantsWorkoutPlan = wantsWorkoutFromKeywords || (!wantsMealFromKeywords && !wantsSleepGuidance && !wantsVibeGuidance)
        case .sleepAnalysis, .peaks, .mainChat, .myVibe, .kitchen:
            wantsWorkoutPlan = wantsWorkoutFromKeywords
        }

        return LocalIntentClassification(
            wantsWorkoutPlan: wantsWorkoutPlan,
            wantsMealPlan: wantsMealPlan,
            wantsSleepGuidance: wantsSleepGuidance,
            wantsVibeGuidance: wantsVibeGuidance,
            wantsChallengeGuidance: wantsChallengeGuidance
        )
    }

    func makeSleepAnalysisReply(payload: LocalAppIntentPayload) async throws -> LocalBrainServiceReply {
        let sleepSession = try await buildLatestSleepSession()
        let message = try await sleepAgent.analyze(session: sleepSession)
        let structuredResponse = CaptainStructuredResponse(
            message: message,
            workoutPlan: nil,
            mealPlan: nil
        )
        let rawText = try encodeStructuredResponse(structuredResponse)
        let validatedResponse = try decodeStructuredResponse(from: rawText)

        return LocalBrainServiceReply(
            message: validatedResponse.message,
            workoutPlan: validatedResponse.workoutPlan,
            mealPlan: validatedResponse.mealPlan,
            rawText: rawText
        )
    }

    func makeSleepNotificationMessage() async throws -> String {
        let sleepSession = try await buildLatestSleepSession()
        return try await sleepAgent.analyze(session: sleepSession)
    }

    func buildMessage(
        for payload: LocalAppIntentPayload,
        intent: LocalIntentClassification
    ) async throws -> String {
        let userMessage = payload.latestUserMessage ?? ""
        let sleepSnapshot = sleepSnapshot(from: userMessage)
        let steps = payload.contextData.steps
        let calories = payload.contextData.calories
        let vibe = payload.contextData.vibe
        let level = payload.contextData.level

        switch payload.language {
        case .arabic:
            if intent.wantsMealPlan && intent.wantsWorkoutPlan {
                return "مستواك \(level) وخطواتك \(steps)، فرتبتلك تمرين عملي مع 3 وجبات تمشي ويا مود \(vibe) وسعراتك الحالية \(calories)."
            }

            if intent.wantsMealPlan {
                if payload.hasAttachedImage {
                    return "بنيتلك 3 وجبات سريعة منطقية على أساس لقطة الثلاجة الحالية، وبشكل يناسب مود \(vibe) وحركتك اليوم \(steps) خطوة."
                }

                return "رتبتلك 3 وجبات واضحة تناسب مود \(vibe) وسعراتك الحالية \(calories)، حتى تبقى ثابت بدون تعقيد."
            }

            if intent.wantsWorkoutPlan {
                return "خطواتك اليوم \(steps) ومستواك \(level)، فالأفضل نشتغل على جلسة قصيرة ومركزة ترفع الأداء بدون تخبيص."
            }

            if intent.wantsSleepGuidance {
                if let sleepSnapshot {
                    return try await sleepAgent.analyze(session: sleepSession(from: sleepSnapshot))
                }

                return "جسمك يحتاج هدوء منظم الليلة. خفف التحفيز، ثبّت النفس، وخلي آخر ساعة قبل النوم أخف حتى يهدأ مود \(vibe)."
            }

            if intent.wantsVibeGuidance {
                return "مود \(vibe) يحتاج إيقاع ثابت بالبداية، وبعدها تصعد الطاقة شوي شوي حتى يبقى تركيزك حاضر بدون استنزاف."
            }

            if intent.wantsChallengeGuidance {
                return "أنت هسه على لفل \(level)، فاختار هدف واحد measurable اليوم وكمّله للنهاية قبل ما تفتح جبهة ثانية."
            }

            return "أنت اليوم على \(steps) خطوة و\(calories) سعرة فعالة، فخل نثبت اليوم بخطوة عملية وحدة تناسب مود \(vibe)."

        case .english:
            if intent.wantsMealPlan && intent.wantsWorkoutPlan {
                return "You are at level \(level) with \(steps) steps today, so I lined up a focused workout and three meals that match your \(vibe) vibe and current calorie burn."
            }

            if intent.wantsMealPlan {
                if payload.hasAttachedImage {
                    return "I built three practical meals around the current fridge capture, tuned to your \(vibe) vibe and today's \(steps) steps."
                }

                return "I mapped out three practical meals that fit your \(vibe) vibe and current active calories of \(calories)."
            }

            if intent.wantsWorkoutPlan {
                return "You are on level \(level) with \(steps) steps today, so the best move is a short, focused session that sharpens output without overloading recovery."
            }

            if intent.wantsSleepGuidance {
                if let sleepSnapshot {
                    return try await sleepAgent.analyze(session: sleepSession(from: sleepSnapshot))
                }

                return "Tonight should be about downshifting the system. Lower stimulation, slow the breathing, and give your \(vibe) state a softer landing."
            }

            if intent.wantsVibeGuidance {
                return "Your \(vibe) vibe will respond best to a steady groove first, then a sharper ramp once your focus is fully online."
            }

            if intent.wantsChallengeGuidance {
                return "You are level \(level), so lock one measurable win today and finish it before you open a second front."
            }

            return "You are at \(steps) steps and \(calories) active calories today, so anchor the day with one practical move that fits your current \(vibe) vibe."
        }
    }

    func normalizedNotificationMessage(
        _ message: String,
        fallback: String
    ) -> String {
        let compact = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolved = compact.isEmpty ? fallback : compact
        guard resolved.count > 160 else { return resolved }

        let index = resolved.index(resolved.startIndex, offsetBy: 160)
        return String(resolved[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    func inactivityFallback(
        currentSteps: Int,
        language: AppLanguage
    ) -> String {
        SmartNotificationManager.shared.inactivityNotificationBody(
            currentSteps: currentSteps,
            language: language
        )
    }

    func buildWorkoutPlan(
        for payload: LocalAppIntentPayload,
        intent: LocalIntentClassification
    ) -> WorkoutPlan {
        let mode = workoutMode(for: payload, intent: intent)

        switch (payload.language, mode) {
        case (.arabic, .recovery):
            return WorkoutPlan(
                title: "خطة استشفاء هادئة",
                exercises: [
                    Exercise(name: "تنفّس 4-6", sets: 3, repsOrDuration: "60 ثانية"),
                    Exercise(name: "مشي خفيف", sets: 2, repsOrDuration: "8 دقائق"),
                    Exercise(name: "فتح الورك والظهر", sets: 3, repsOrDuration: "45 ثانية"),
                    Exercise(name: "تمدد أوتار خلفية", sets: 2, repsOrDuration: "45 ثانية")
                ]
            )
        case (.arabic, .activation):
            return WorkoutPlan(
                title: "خطة تشغيل سريعة",
                exercises: [
                    Exercise(name: "إحماء ديناميكي", sets: 2, repsOrDuration: "60 ثانية"),
                    Exercise(name: "سكوات وزن جسم", sets: 3, repsOrDuration: "12 تكرار"),
                    Exercise(name: "ضغط مائل", sets: 3, repsOrDuration: "10 تكرار"),
                    Exercise(name: "بلانك", sets: 3, repsOrDuration: "30 ثانية")
                ]
            )
        case (.arabic, .balanced):
            return WorkoutPlan(
                title: "خطة توازن اليوم",
                exercises: [
                    Exercise(name: "إحماء مفاصل", sets: 2, repsOrDuration: "75 ثانية"),
                    Exercise(name: "لانجز متبادلة", sets: 3, repsOrDuration: "10 لكل رجل"),
                    Exercise(name: "سحب مطاط أو دامبل رو", sets: 3, repsOrDuration: "12 تكرار"),
                    Exercise(name: "مشي سريع", sets: 2, repsOrDuration: "6 دقائق")
                ]
            )
        case (.arabic, .performance):
            return WorkoutPlan(
                title: "خطة قوة وتركيز",
                exercises: [
                    Exercise(name: "سكوات", sets: 4, repsOrDuration: "8-10 تكرار"),
                    Exercise(name: "ضغط أو بنش", sets: 4, repsOrDuration: "8-10 تكرار"),
                    Exercise(name: "رو", sets: 4, repsOrDuration: "10 تكرار"),
                    Exercise(name: "بلانك جانبي", sets: 3, repsOrDuration: "40 ثانية")
                ]
            )
        case (.arabic, .challenge):
            return WorkoutPlan(
                title: "قمة اليوم: جلسة زخم",
                exercises: [
                    Exercise(name: "Air Squat", sets: 4, repsOrDuration: "15 تكرار"),
                    Exercise(name: "Push-Up", sets: 4, repsOrDuration: "10 تكرار"),
                    Exercise(name: "Mountain Climber", sets: 3, repsOrDuration: "30 ثانية"),
                    Exercise(name: "Farmer Carry أو مشي سريع", sets: 3, repsOrDuration: "90 ثانية")
                ]
            )
        case (.english, .recovery):
            return WorkoutPlan(
                title: "Recovery Reset",
                exercises: [
                    Exercise(name: "4-6 Breathing", sets: 3, repsOrDuration: "60 sec"),
                    Exercise(name: "Light Walk", sets: 2, repsOrDuration: "8 min"),
                    Exercise(name: "Hip and Thoracic Openers", sets: 3, repsOrDuration: "45 sec"),
                    Exercise(name: "Hamstring Stretch", sets: 2, repsOrDuration: "45 sec")
                ]
            )
        case (.english, .activation):
            return WorkoutPlan(
                title: "Quick Activation Session",
                exercises: [
                    Exercise(name: "Dynamic Warm-Up", sets: 2, repsOrDuration: "60 sec"),
                    Exercise(name: "Bodyweight Squat", sets: 3, repsOrDuration: "12 reps"),
                    Exercise(name: "Incline Push-Up", sets: 3, repsOrDuration: "10 reps"),
                    Exercise(name: "Plank Hold", sets: 3, repsOrDuration: "30 sec")
                ]
            )
        case (.english, .balanced):
            return WorkoutPlan(
                title: "Balanced Daily Session",
                exercises: [
                    Exercise(name: "Joint Prep Flow", sets: 2, repsOrDuration: "75 sec"),
                    Exercise(name: "Alternating Lunge", sets: 3, repsOrDuration: "10 each leg"),
                    Exercise(name: "Band Row or Dumbbell Row", sets: 3, repsOrDuration: "12 reps"),
                    Exercise(name: "Brisk Walk", sets: 2, repsOrDuration: "6 min")
                ]
            )
        case (.english, .performance):
            return WorkoutPlan(
                title: "Strength and Focus Block",
                exercises: [
                    Exercise(name: "Squat", sets: 4, repsOrDuration: "8-10 reps"),
                    Exercise(name: "Press or Bench", sets: 4, repsOrDuration: "8-10 reps"),
                    Exercise(name: "Row", sets: 4, repsOrDuration: "10 reps"),
                    Exercise(name: "Side Plank", sets: 3, repsOrDuration: "40 sec")
                ]
            )
        case (.english, .challenge):
            return WorkoutPlan(
                title: "Peaks Momentum Session",
                exercises: [
                    Exercise(name: "Air Squat", sets: 4, repsOrDuration: "15 reps"),
                    Exercise(name: "Push-Up", sets: 4, repsOrDuration: "10 reps"),
                    Exercise(name: "Mountain Climber", sets: 3, repsOrDuration: "30 sec"),
                    Exercise(name: "Farmer Carry or Fast Walk", sets: 3, repsOrDuration: "90 sec")
                ]
            )
        }
    }

    func buildMealPlan(for payload: LocalAppIntentPayload) -> MealPlan {
        let style = mealStyle(for: payload.latestUserMessage ?? "")

        switch (payload.language, style) {
        case (.arabic, .quick):
            return MealPlan(
                meals: [
                    MealPlan.Meal(type: "Breakfast", description: breakfastTextArabic(fromFridge: payload.hasAttachedImage, style: style), calories: 340),
                    MealPlan.Meal(type: "Lunch", description: "ساندويچ بروتين سريع من الموجود مع خضار ولبن أو زبادي جانبي.", calories: 520),
                    MealPlan.Meal(type: "Dinner", description: "سلطة خفيفة مع مصدر بروتين بسيط حتى تبقى المعدة هادئة بالليل.", calories: 390)
                ]
            )
        case (.arabic, .highProtein):
            return MealPlan(
                meals: [
                    MealPlan.Meal(type: "Breakfast", description: breakfastTextArabic(fromFridge: payload.hasAttachedImage, style: style), calories: 410),
                    MealPlan.Meal(type: "Lunch", description: "صدر دجاج أو تونة مع رز معتدل وخضار، حتى تثبّت الشبع والبروتين.", calories: 610),
                    MealPlan.Meal(type: "Dinner", description: "زبادي يوناني أو جبن خفيف مع سلطة وبذور أو خبز خفيف.", calories: 430)
                ]
            )
        case (.arabic, .balanced):
            return MealPlan(
                meals: [
                    MealPlan.Meal(type: "Breakfast", description: breakfastTextArabic(fromFridge: payload.hasAttachedImage, style: style), calories: 360),
                    MealPlan.Meal(type: "Lunch", description: "طبق متوازن من بروتين + كارب نظيف + خضار حتى يبقى أداؤك ثابت.", calories: 560),
                    MealPlan.Meal(type: "Dinner", description: "عشاء أخف: شوربة أو سلطة مع بروتين بسيط حتى تريح الهضم.", calories: 400)
                ]
            )
        case (.english, .quick):
            return MealPlan(
                meals: [
                    MealPlan.Meal(type: "Breakfast", description: breakfastTextEnglish(fromFridge: payload.hasAttachedImage, style: style), calories: 340),
                    MealPlan.Meal(type: "Lunch", description: "A fast protein wrap from what is already on hand with vegetables and yogurt on the side.", calories: 520),
                    MealPlan.Meal(type: "Dinner", description: "A lighter salad with a simple protein source to keep digestion calm at night.", calories: 390)
                ]
            )
        case (.english, .highProtein):
            return MealPlan(
                meals: [
                    MealPlan.Meal(type: "Breakfast", description: breakfastTextEnglish(fromFridge: payload.hasAttachedImage, style: style), calories: 410),
                    MealPlan.Meal(type: "Lunch", description: "Chicken breast or tuna with moderate rice and vegetables to keep protein and satiety high.", calories: 610),
                    MealPlan.Meal(type: "Dinner", description: "Greek yogurt or light cheese with salad and a small seed or toast side.", calories: 430)
                ]
            )
        case (.english, .balanced):
            return MealPlan(
                meals: [
                    MealPlan.Meal(type: "Breakfast", description: breakfastTextEnglish(fromFridge: payload.hasAttachedImage, style: style), calories: 360),
                    MealPlan.Meal(type: "Lunch", description: "A balanced plate of protein, clean carbs, and vegetables to keep output stable.", calories: 560),
                    MealPlan.Meal(type: "Dinner", description: "A lighter dinner such as soup or salad with an easy protein source.", calories: 400)
                ]
            )
        }
    }

    func workoutMode(
        for payload: LocalAppIntentPayload,
        intent: LocalIntentClassification
    ) -> LocalWorkoutMode {
        if intent.wantsSleepGuidance || payload.screenContext == .sleepAnalysis {
            return .recovery
        }

        if payload.screenContext == .peaks || intent.wantsChallengeGuidance {
            return .challenge
        }

        if payload.contextData.steps < 2_500 {
            return .activation
        }

        if payload.contextData.level >= 12 || payload.contextData.calories >= 650 {
            return .performance
        }

        return .balanced
    }

    func mealStyle(for userMessage: String) -> LocalMealStyle {
        if containsAny(userMessage, keywords: Self.quickMealKeywords) {
            return .quick
        }

        if containsAny(userMessage, keywords: Self.highProteinKeywords) {
            return .highProtein
        }

        return .balanced
    }

    func sleepSnapshot(from text: String) -> LocalSleepSnapshot? {
        guard let totalHours = doubleValue(after: "TotalSleepHours:", in: text),
              let deepHours = doubleValue(after: "DeepSleepHours:", in: text),
              let remHours = doubleValue(after: "REMSleepHours:", in: text),
              let coreHours = doubleValue(after: "CoreSleepHours:", in: text),
              let awakeMinutes = intValue(after: "AwakeMinutes:", in: text) else {
            return nil
        }

        return LocalSleepSnapshot(
            totalHours: totalHours,
            deepHours: deepHours,
            remHours: remHours,
            coreHours: coreHours,
            awakeMinutes: awakeMinutes
        )
    }

    func sleepSession(from snapshot: LocalSleepSnapshot) -> SleepSession {
        SleepSession(
            totalSleep: snapshot.totalHours * 3_600,
            deepSleep: snapshot.deepHours * 3_600,
            remSleep: snapshot.remHours * 3_600,
            coreSleep: snapshot.coreHours * 3_600,
            awake: Double(snapshot.awakeMinutes * 60)
        )
    }

    func value(after key: String, in text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let matchedLine = lines.first(where: { $0.hasPrefix(key) }) else {
            return nil
        }

        return String(matchedLine.dropFirst(key.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func doubleValue(after key: String, in text: String) -> Double? {
        guard let rawValue = value(after: key, in: text) else { return nil }
        return Double(rawValue)
    }

    func intValue(after key: String, in text: String) -> Int? {
        guard let rawValue = value(after: key, in: text) else { return nil }
        return Int(rawValue)
    }

    func breakfastTextArabic(
        fromFridge: Bool,
        style: LocalMealStyle
    ) -> String {
        switch style {
        case .quick:
            return fromFridge
                ? "أومليت سريع من الموجود بالثلاجة مع خضار وخبز خفيف."
                : "أومليت سريع مع خضار وخبز خفيف حتى تبدي يومك بدون ثقل."
        case .highProtein:
            return fromFridge
                ? "بيض مع لبن أو زبادي يوناني من الموجود، وياها خضار بسيطة."
                : "بيض مع زبادي يوناني وخضار بسيطة حتى ترفع البروتين من أول اليوم."
        case .balanced:
            return fromFridge
                ? "فطور متوازن من الموجود: بيض أو لبن مع خضار وقطعة كارب خفيفة."
                : "فطور متوازن: بيض أو لبن مع خضار وقطعة كارب خفيفة."
        }
    }

    func breakfastTextEnglish(
        fromFridge: Bool,
        style: LocalMealStyle
    ) -> String {
        switch style {
        case .quick:
            return fromFridge
                ? "A quick omelet from the fridge staples with vegetables and a light bread side."
                : "A quick omelet with vegetables and a light bread side to start clean."
        case .highProtein:
            return fromFridge
                ? "Eggs with yogurt or Greek yogurt from what is on hand, plus a simple vegetable side."
                : "Eggs with Greek yogurt and a simple vegetable side to front-load protein."
        case .balanced:
            return fromFridge
                ? "A balanced breakfast from what is on hand: eggs or yogurt, vegetables, and a light carb."
                : "A balanced breakfast of eggs or yogurt, vegetables, and a light carb."
        }
    }

    func containsAny(_ text: String, keywords: [String]) -> Bool {
        let normalizedText = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return keywords.contains { keyword in
            normalizedText.contains(keyword.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        }
    }

    func buildLatestSleepSession() async throws -> SleepSession {
        let authorized = try await healthManager.requestSleepAuthorizationIfNeeded()
        guard authorized else {
            throw SleepStageFetchError.authorizationDenied
        }

        let stages = try await healthManager.fetchSleepStagesForLastNight()
        guard !stages.isEmpty else {
            throw SleepStageFetchError.sleepAnalysisUnavailable
        }

        let totalSleep = stages
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
        guard totalSleep > 0 else {
            throw SleepStageFetchError.sleepAnalysisUnavailable
        }

        return SleepSession(
            totalSleep: totalSleep,
            deepSleep: totalDuration(for: .deep, in: stages),
            remSleep: totalDuration(for: .rem, in: stages),
            coreSleep: totalDuration(for: .core, in: stages),
            awake: totalDuration(for: .awake, in: stages)
        )
    }

    func totalDuration(
        for stage: SleepStageData.Stage,
        in stages: [SleepStageData]
    ) -> TimeInterval {
        stages
            .filter { $0.stage == stage }
            .reduce(0) { $0 + $1.duration }
    }

    func encodeStructuredResponse(_ response: CaptainStructuredResponse) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(response)

        guard let rawText = String(data: data, encoding: .utf8) else {
            throw LocalBrainServiceError.invalidStructuredResponse
        }

        return rawText
    }

    func decodeStructuredResponse(from rawText: String) throws -> CaptainStructuredResponse {
        guard let data = rawText.data(using: .utf8) else {
            throw LocalBrainServiceError.invalidStructuredResponse
        }

        do {
            return try JSONDecoder().decode(CaptainStructuredResponse.self, from: data)
        } catch {
            throw LocalBrainServiceError.invalidStructuredResponse
        }
    }

    static let workoutKeywords = [
        "workout", "gym", "exercise", "training", "lift", "cardio", "strength",
        "تمرين", "تمارين", "جيم", "رياضة", "كارديو", "مقاومة", "نادي"
    ]

    static let mealKeywords = [
        "meal", "food", "eat", "diet", "recipe", "cook", "kitchen", "fridge",
        "breakfast", "lunch", "dinner", "protein", "وجبة", "اكل", "أكل", "طبخ",
        "مطبخ", "ثلاجة", "فطور", "غداء", "عشاء", "سناك", "بروتين"
    ]

    static let sleepKeywords = [
        "sleep", "recovery", "rest", "insomnia", "wind down", "nap",
        "نوم", "استشفاء", "راحة", "ارق", "أرق", "نعاس"
    ]

    static let vibeKeywords = [
        "vibe", "mood", "music", "playlist", "focus", "energy",
        "مود", "فايب", "ذبذبة", "ذبذبات", "اغاني", "أغاني", "بلايليست", "تركيز", "طاقة"
    ]

    static let challengeKeywords = [
        "peak", "challenge", "discipline", "mission", "quest",
        "قمة", "قمم", "تحدي", "انضباط", "مهمة", "كويست"
    ]

    static let quickMealKeywords = [
        "quick", "fast", "10 min", "10min", "سريع", "بسرعة", "10 دق", "10 دقائق"
    ]

    static let highProteinKeywords = [
        "protein", "high protein", "بروتين", "عالي البروتين"
    ]
}
