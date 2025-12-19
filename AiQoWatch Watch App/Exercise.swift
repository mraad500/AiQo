import Foundation
import HealthKit

enum ExerciseKind: String, CaseIterable, Identifiable {
    case gratitude
    case walkInside
    case walkOutside
    case runIndoor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gratitude: return "Gratitude"
        case .walkInside: return "Walk inside"
        case .walkOutside: return "Walking outside"
        case .runIndoor: return "Running indoor"
        }
    }

    var subtitle: String {
        switch self {
        case .gratitude: return "Breathing + reflection"
        case .walkInside: return "Easy indoor walk"
        case .walkOutside: return "Outdoor walk"
        case .runIndoor: return "Treadmill / indoor run"
        }
    }

    var symbol: String {
        switch self {
        case .gratitude: return "sparkles"
        case .walkInside: return "figure.walk"
        case .walkOutside: return "figure.walk.motion"
        case .runIndoor: return "figure.run"
        }
    }

    /// خريطة التمرين إلى HealthKit workout type
    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .gratitude:
            // ماكو "gratitude" كتمرين رسمي.
            // نستخدم Mind and Body حتى تكون تجربة “جلسة” وبدون تعقيد.
            return .mindAndBody
        case .walkInside, .walkOutside:
            return .walking
        case .runIndoor:
            return .running
        }
    }

    var hkLocation: HKWorkoutSessionLocationType {
        switch self {
        case .walkOutside: return .outdoor
        case .walkInside, .runIndoor, .gratitude: return .indoor
        }
    }
}
