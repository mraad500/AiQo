import Foundation

// MARK: - Briefing Language & Gender

enum BriefingLanguage: String, Codable {
    case arabic, english

    static func from(_ appLanguage: AppLanguage) -> BriefingLanguage {
        appLanguage == .english ? .english : .arabic
    }
}

enum BriefingGender: String, Codable {
    case male, female, unspecified

    static func from(_ profileGender: ActivityNotificationGender?) -> BriefingGender {
        switch profileGender {
        case .male:   return .male
        case .female: return .female
        case nil:     return .unspecified
        }
    }
}

// MARK: - Briefing Context

struct BriefingContext {
    let stepsToday: Int
    let stepsGoal: Int
    let activeCaloriesToday: Double
    let sleepHoursLastNight: Double?
    let dailyRingProgress: Double  // 0.0 - 1.0+
    let userFirstName: String
    let language: BriefingLanguage
    let gender: BriefingGender
    let userTier: SubscriptionTier
}

// MARK: - Briefing Content

struct BriefingContent {
    let title: String
    let body: String
    let categoryIdentifier: String
}

// MARK: - Briefing Content Generator

@MainActor
final class BriefingContentGenerator {
    static let shared = BriefingContentGenerator()

    private let intelligenceManager = CaptainIntelligenceManager.shared

    private init() {}

    func generate(for slot: BriefingSlot, context: BriefingContext) async -> BriefingContent {
        let body: String

        switch context.userTier {
        case .none:
            // Core tier: fallback only (no AI)
            let fb = FallbackTemplates.text(for: slot, language: context.language, gender: context.gender, firstName: context.userFirstName)
            return BriefingContent(title: fb.title, body: fb.body, categoryIdentifier: "CAPTAIN_BRIEFING")
        case .standard, .intelligencePro:
            body = await generateWithAI(for: slot, context: context)
        }

        let trimmed = String(body.prefix(120))
        MemoryStore.shared.storeBriefingBody(trimmed)

        let title = FallbackTemplates.text(for: slot, language: context.language, gender: context.gender, firstName: context.userFirstName).title
        return BriefingContent(title: title, body: trimmed, categoryIdentifier: "CAPTAIN_BRIEFING")
    }

    // MARK: - AI Generation

    private func generateWithAI(for slot: BriefingSlot, context: BriefingContext) async -> String {
        let prompt = buildPrompt(for: slot, context: context)

        // Try cloud with 4s timeout, fallback to local, fallback to templates
        do {
            let result = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { [self] in
                    try await self.intelligenceManager.generateCaptainResponse(for: prompt)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 4_000_000_000)
                    throw CancellationError()
                }
                let first = try await group.next()!
                group.cancelAll()
                return first
            }

            // Replace {USER} placeholder with real name on-device
            let personalized = result.replacingOccurrences(of: "{USER}", with: context.userFirstName)
            let compact = personalized.trimmingCharacters(in: .whitespacesAndNewlines)
            if !compact.isEmpty { return compact }
        } catch {
            // Cloud failed or timed out — try local
        }

        do {
            let result = try await intelligenceManager.generateCaptainResponse(for: prompt, forcedRoute: .onDevice)
            let personalized = result.replacingOccurrences(of: "{USER}", with: context.userFirstName)
            let compact = personalized.trimmingCharacters(in: .whitespacesAndNewlines)
            if !compact.isEmpty { return compact }
        } catch {
            // Local failed
        }

        // Deterministic fallback
        return FallbackTemplates.text(for: slot, language: context.language, gender: context.gender, firstName: context.userFirstName).body
    }

    // MARK: - Prompt Building (6 combinations: 2 languages x 3 genders)

    private func buildPrompt(for slot: BriefingSlot, context: BriefingContext) -> String {
        let steps = context.stepsToday
        let goal = context.stepsGoal
        let sleepText = context.sleepHoursLastNight.map { String(format: "%.1f", $0) } ?? "N/A"
        let slotName = slot.displayName(language: context.language)

        let recentBodies = MemoryStore.shared.recentBriefingBodies(limit: 3)
        let avoidance = recentBodies.isEmpty ? "" : recentBodies.joined(separator: " | ")

        switch context.language {
        case .arabic:
            return buildArabicPrompt(slot: slot, slotName: slotName, gender: context.gender, steps: steps, goal: goal, sleepText: sleepText, avoidance: avoidance)
        case .english:
            return buildEnglishPrompt(slot: slot, slotName: slotName, gender: context.gender, steps: steps, goal: goal, sleepText: sleepText, avoidance: avoidance)
        }
    }

    private func buildArabicPrompt(slot: BriefingSlot, slotName: String, gender: BriefingGender, steps: Int, goal: Int, sleepText: String, avoidance: String) -> String {
        let genderDirective: String
        switch gender {
        case .male:
            genderDirective = "المستخدم: {USER}، ذكر. استعمل الصيغة المذكرة دائماً."
        case .female:
            genderDirective = "المستخدم: {USER}، أنثى. استعملي الصيغة المؤنثة دائماً."
        case .unspecified:
            genderDirective = "المستخدم: {USER}. استعمل صيغة محايدة بدون تذكير أو تأنيث."
        }

        var prompt = """
        أنت كابتن حمودي، مدرب صحي عراقي بصوت دافئ وحازم.
        \(genderDirective)
        المهمة: اكتب إشعار \(slotName) لا يتجاوز 120 حرف.
        السياق: \(steps)/\(goal) خطوة، \(sleepText) ساعات نوم.
        إيموجي واحدة كحد أقصى.
        """
        if !avoidance.isEmpty {
            prompt += "\nلا تكرر: \(avoidance)"
        }
        return prompt
    }

    private func buildEnglishPrompt(slot: BriefingSlot, slotName: String, gender: BriefingGender, steps: Int, goal: Int, sleepText: String, avoidance: String) -> String {
        let genderDirective: String
        switch gender {
        case .male:
            genderDirective = "User: {USER}, male. Use masculine framing naturally, never corny."
        case .female:
            genderDirective = "User: {USER}, female. Use feminine framing naturally, never corny."
        case .unspecified:
            genderDirective = "User: {USER}. Use gender-neutral framing."
        }

        var prompt = """
        You are Captain Hamoudi, a warm but firm health coach.
        \(genderDirective)
        Task: Write a \(slotName) notification, max 120 characters.
        Context: \(steps)/\(goal) steps, \(sleepText)h sleep.
        Max 1 emoji.
        """
        if !avoidance.isEmpty {
            prompt += "\nAvoid repeating: \(avoidance)"
        }
        return prompt
    }
}

// MARK: - Fallback Templates (30 entries: 5 slots x 2 languages x 3 genders)

private struct FallbackTemplates {
    static func text(
        for slot: BriefingSlot,
        language: BriefingLanguage,
        gender: BriefingGender,
        firstName: String
    ) -> (title: String, body: String) {
        switch (language, slot, gender) {

        // MORNING HERO
        case (.arabic, .morningHero, .male):
            return ("صباح الخير \(firstName)", "قوم استانست عليك، اليوم يومك يا بطل 💪")
        case (.arabic, .morningHero, .female):
            return ("صباح الخير \(firstName)", "قومي استانست عليج، اليوم يومج يا بطلة 💪")
        case (.arabic, .morningHero, .unspecified):
            return ("صباح الخير \(firstName)", "اليوم يوم جديد، خلنا نبدأ بقوة 💪")
        case (.english, .morningHero, .male):
            return ("Morning, \(firstName)", "New day, brother. Let's move 💪")
        case (.english, .morningHero, .female):
            return ("Morning, \(firstName)", "New day, queen. Let's move 💪")
        case (.english, .morningHero, .unspecified):
            return ("Morning, \(firstName)", "New day. Let's get moving 💪")

        // MIDDAY PULSE
        case (.arabic, .middayPulse, .male):
            return ("شحنة الظهر", "\(firstName)، شد حيلك، باقي عليك شوي وتوصل هدفك")
        case (.arabic, .middayPulse, .female):
            return ("شحنة الظهر", "\(firstName)، شدي حيلج، باقي عليج شوي وتوصلين هدفج")
        case (.arabic, .middayPulse, .unspecified):
            return ("شحنة الظهر", "\(firstName)، الهدف قريب، خلنا نكمل")
        case (.english, .middayPulse, .male):
            return ("Midday Pulse", "\(firstName), keep pushing brother. Goal is close.")
        case (.english, .middayPulse, .female):
            return ("Midday Pulse", "\(firstName), keep pushing queen. Goal is close.")
        case (.english, .middayPulse, .unspecified):
            return ("Midday Pulse", "\(firstName), keep going. Goal is close.")

        // EVENING REFLECTION
        case (.arabic, .eveningReflection, .male):
            return ("لحظة المساء", "\(firstName)، شلون يومك؟ خل نشوف وين وصلت")
        case (.arabic, .eveningReflection, .female):
            return ("لحظة المساء", "\(firstName)، شلون يومج؟ خل نشوف وين وصلتي")
        case (.arabic, .eveningReflection, .unspecified):
            return ("لحظة المساء", "\(firstName)، خلاصة اليوم جاهزة")
        case (.english, .eveningReflection, .male):
            return ("Evening Check-in", "\(firstName), how was the day brother? Let's review.")
        case (.english, .eveningReflection, .female):
            return ("Evening Check-in", "\(firstName), how was the day sister? Let's review.")
        case (.english, .eveningReflection, .unspecified):
            return ("Evening Check-in", "\(firstName), let's review your day.")

        // WIND DOWN
        case (.arabic, .windDown, .male):
            return ("استعداد النوم", "\(firstName)، خلص اليوم، نام زين عشان باجر يومك أقوى")
        case (.arabic, .windDown, .female):
            return ("استعداد النوم", "\(firstName)، خلص اليوم، نامي زين عشان باجر يومج أقوى")
        case (.arabic, .windDown, .unspecified):
            return ("استعداد النوم", "\(firstName)، وقت الراحة، استعد لنوم عميق")
        case (.english, .windDown, .male):
            return ("Wind Down", "\(firstName), day's done brother. Sleep deep, rise stronger.")
        case (.english, .windDown, .female):
            return ("Wind Down", "\(firstName), day's done queen. Sleep deep, rise stronger.")
        case (.english, .windDown, .unspecified):
            return ("Wind Down", "\(firstName), time to rest. Sleep deep.")

        // WORKOUT SUMMARY
        case (.arabic, .workoutSummary, .male):
            return ("تمرين قوي \(firstName)", "خلصت تمرينك يا بطل، شوف ملخصك")
        case (.arabic, .workoutSummary, .female):
            return ("تمرين قوي \(firstName)", "خلصتي تمرينج يا بطلة، شوفي ملخصج")
        case (.arabic, .workoutSummary, .unspecified):
            return ("تمرين مكتمل", "\(firstName)، تمرينك جاهز، شوف الملخص")
        case (.english, .workoutSummary, .male):
            return ("Strong session \(firstName)", "Workout done brother. Tap to see your summary.")
        case (.english, .workoutSummary, .female):
            return ("Strong session \(firstName)", "Workout done queen. Tap to see your summary.")
        case (.english, .workoutSummary, .unspecified):
            return ("Workout Complete", "\(firstName), tap to see your summary.")
        }
    }
}
