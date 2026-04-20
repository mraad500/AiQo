import Foundation

/// Deterministic Iraqi Arabic coach copy for proactive nudges.
/// No LLM calls — no privacy surface. All numeric inputs are expected to be bucketed by the caller.
enum IraqiCoachTemplates {

    struct Input {
        let steps: Int
        let stepGoal: Int
        let heartRate: Int?
        let sleepHours: Double?
        let timeOfDay: TimeOfDay
    }

    enum TimeOfDay {
        case morning, midday, afternoon, evening, night
    }

    static func iraqi(_ input: Input) -> String {
        let stepsBucket = (input.steps / 1000) * 1000

        if input.steps < 3000 && (input.timeOfDay == .afternoon || input.timeOfDay == .evening) {
            return "شكد باقي عالليل؟ خلنا نمشي شوية، ما تسوي كلش يعني. خمس دقايق تكفي."
        }

        if input.steps < 6000 {
            return "مشيت \(stepsBucket) تقريباً. مو بطل، بس نقدر نضيف شوية. قوم شوف شنو تقدر تسوي."
        }

        if input.steps >= input.stepGoal - 2000 && input.steps < input.stepGoal {
            return "قريب جداً من الهدف. ما تخلي نفسك توقف هسة، الختام أهم من البداية."
        }

        if input.steps >= input.stepGoal {
            return "هدف اليوم محقق. فد شي ذيج، خلي الباقي راحة واستمتاع."
        }

        return "اليوم لساع طويل. كلشي خطوة زيادة تحسب. يلا، نكمل."
    }

    static func english(_ input: Input) -> String {
        let stepsBucket = (input.steps / 1000) * 1000

        if input.steps < 3000 && (input.timeOfDay == .afternoon || input.timeOfDay == .evening) {
            return "Day's winding down. A short 5-minute walk now can change how tomorrow starts."
        }
        if input.steps < 6000 {
            return "You're around \(stepsBucket) steps. Not bad, but we can do a little more. Get up for a minute."
        }
        if input.steps >= input.stepGoal - 2000 && input.steps < input.stepGoal {
            return "You're close to your goal. Don't stop now — the finish matters more than the start."
        }
        if input.steps >= input.stepGoal {
            return "Goal hit. The rest is yours — enjoy it."
        }
        return "The day's still long. Every extra step counts. Let's keep going."
    }
}
