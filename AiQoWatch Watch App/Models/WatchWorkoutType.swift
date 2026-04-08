import SwiftUI
import HealthKit

enum WatchWorkoutType: String, CaseIterable, Identifiable {
    case walkOutdoor = "walk_outdoor"
    case runOutdoor = "run_outdoor"
    case walkIndoor = "walk_indoor"
    case runIndoor = "run_indoor"
    case cycling = "cycling"
    case hiit = "hiit"
    case strengthTraining = "strength"
    case yoga = "yoga"
    case swimming = "swimming"

    var id: String { rawValue }

    func localizedName(locale: Locale) -> String {
        switch self {
        case .walkOutdoor:
            return WatchText.localized(ar: "مشي خارجي", en: "Outdoor Walk", locale: locale)
        case .runOutdoor:
            return WatchText.localized(ar: "ركض خارجي", en: "Outdoor Run", locale: locale)
        case .walkIndoor:
            return WatchText.localized(ar: "مشي داخلي", en: "Indoor Walk", locale: locale)
        case .runIndoor:
            return WatchText.localized(ar: "ركض داخلي", en: "Indoor Run", locale: locale)
        case .cycling:
            return WatchText.localized(ar: "دراجة", en: "Cycling", locale: locale)
        case .hiit:
            return WatchText.localized(ar: "تمرين HIIT", en: "HIIT", locale: locale)
        case .strengthTraining:
            return WatchText.localized(ar: "تمارين القوة", en: "Strength", locale: locale)
        case .yoga:
            return WatchText.localized(ar: "يوغا", en: "Yoga", locale: locale)
        case .swimming:
            return WatchText.localized(ar: "سباحة", en: "Swimming", locale: locale)
        }
    }

    var sfSymbol: String {
        switch self {
        case .walkOutdoor, .walkIndoor: return "figure.walk"
        case .runOutdoor, .runIndoor: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .hiit: return "flame.fill"
        case .strengthTraining: return "dumbbell.fill"
        case .yoga: return "figure.mind.and.body"
        case .swimming: return "figure.pool.swim"
        }
    }

    var hkType: HKWorkoutActivityType {
        switch self {
        case .walkOutdoor, .walkIndoor: return .walking
        case .runOutdoor, .runIndoor: return .running
        case .cycling: return .cycling
        case .hiit: return .highIntensityIntervalTraining
        case .strengthTraining: return .traditionalStrengthTraining
        case .yoga: return .yoga
        case .swimming: return .swimming
        }
    }

    var locationType: HKWorkoutSessionLocationType {
        switch self {
        case .walkIndoor, .runIndoor, .strengthTraining, .hiit, .yoga, .swimming: return .indoor
        case .walkOutdoor, .runOutdoor, .cycling: return .outdoor
        }
    }

    /// Alternates sand/mint to match iPhone card pattern
    var cardColor: Color {
        let i = Self.allCases.firstIndex(of: self) ?? 0
        return i.isMultiple(of: 2) ? AiQoWatch.sandCard : AiQoWatch.mintCard
    }

    var iconBgColor: Color {
        let i = Self.allCases.firstIndex(of: self) ?? 0
        return i.isMultiple(of: 2) ? AiQoWatch.sandIcon : AiQoWatch.mintIcon
    }
}
