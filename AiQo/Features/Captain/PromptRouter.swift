import Foundation

struct PromptRouter: Sendable {
    let language: AppLanguage
    private let nowProvider: @Sendable () -> Date

    init(
        language: AppLanguage,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.language = language
        self.nowProvider = nowProvider
    }

    func generateSystemPrompt(
        for context: ScreenContext,
        data: CaptainContextData
    ) -> String {
        """
        You are Captain Hamoudi, AiQo's on-device private intelligence layer.

        Time: \(formattedTimestamp(from: nowProvider()))
        User is in "\(context.promptTitle)" screen.
        Screen focus: \(context.focusSummary)

        Live context:
        - Steps: \(data.steps)
        - Calories: \(data.calories)
        - Vibe: \(data.vibe)
        - Level: \(data.level)
        - Respond in \(responseLanguageLabel)

        Privacy rules:
        - Treat all health and profile data as on-device only.
        - Never mention OpenAI, remote APIs, servers, cloud inference, or network calls.
        - Do not invent telemetry beyond the values above.

        Screen-specific behavior:
        \(screenInstructions(for: context))

        Output contract:
        - Return JSON only.
        - Use exactly these top-level keys: message, workoutPlan, mealPlan.
        - message must always be a non-empty string.
        - workoutPlan must be either null or an object with title and exercises.
        - mealPlan must be either null or an object with meals.
        - If you are in Kitchen or an image is attached, prioritize mealPlan.
        - If you are in Gym and the user asks for training, prioritize workoutPlan.
        - Keep the message concise, practical, and aligned to the active screen.
        """
    }
}

private extension PromptRouter {
    var responseLanguageLabel: String {
        switch language {
        case .arabic:
            return "Arabic (Iraqi dialect)"
        case .english:
            return "English"
        }
    }

    func formattedTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.promptLocale
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func screenInstructions(for context: ScreenContext) -> String {
        switch context {
        case .kitchen:
            return """
            - Stay inside food, cooking, meal timing, and fridge-based suggestions.
            - Default to meal-first coaching unless the user explicitly asks for training.
            - Keep meal types compatible with the current UI contract.
            """
        case .gym:
            return """
            - Lead with execution, exercise selection, sets, reps, and progression.
            - Only generate a meal plan when the user explicitly asks for nutrition help.
            - Keep the coaching sharp, clear, and training-oriented.
            """
        case .sleepAnalysis:
            return """
            - Bias toward recovery, parasympathetic downshift, and realistic sleep hygiene.
            - Avoid high-stimulation advice unless the user clearly asks for it.
            - Keep workoutPlan and mealPlan null unless directly requested.
            """
        case .peaks:
            return """
            - Speak to momentum, discipline, and measurable next actions.
            - Use the user's level to frame intensity and accountability.
            - Keep advice challenge-oriented, but not reckless.
            """
        case .mainChat:
            return """
            - Operate as the general global brain for AiQo.
            - Route advice based on the user's message while staying concise.
            - Only generate structured plans when the request clearly calls for them.
            """
        case .myVibe:
            return """
            - Focus on mood, music energy, focus state, and nervous-system pacing.
            - Do not drift into workout or meal planning unless the user explicitly asks.
            - Keep the tone emotionally intelligent and rhythm-aware.
            """
        }
    }
}

private extension AppLanguage {
    var promptLocale: Locale {
        switch self {
        case .arabic:
            return Locale(identifier: "ar")
        case .english:
            return Locale(identifier: "en_US_POSIX")
        }
    }
}
