import Foundation

enum ScreenContext: String, CaseIterable, Sendable {
    case kitchen
    case gym
    case sleepAnalysis
    case peaks
    case mainChat
    case myVibe

    var promptTitle: String {
        switch self {
        case .kitchen:
            return "Kitchen (المطبخ)"
        case .gym:
            return "Gym (الجيم)"
        case .sleepAnalysis:
            return "Sleep Analysis (تحليل النوم)"
        case .peaks:
            return "Peaks (قِمَم)"
        case .mainChat:
            return "Main Chat (الدردشة الرئيسية)"
        case .myVibe:
            return "My Vibe (ذبذباتي)"
        }
    }

    var focusSummary: String {
        switch self {
        case .kitchen:
            return "Food, fridge logic, meal suggestions, and practical nutrition choices."
        case .gym:
            return "Training guidance, structured workouts, and action-first fitness coaching."
        case .sleepAnalysis:
            return "Sleep quality, recovery, wind-down guidance, and low-stimulus coaching."
        case .peaks:
            return "Momentum, discipline, measurable challenges, and level-based progression."
        case .mainChat:
            return "General captain coaching across health, habits, and daily execution."
        case .myVibe:
            return "Mood, music, focus, emotional regulation, and energy pacing."
        }
    }

    var prefersWorkoutPlan: Bool {
        self == .gym
    }

    var prefersMealPlan: Bool {
        self == .kitchen
    }
}
