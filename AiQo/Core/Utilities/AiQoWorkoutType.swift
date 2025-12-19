import Foundation
import HealthKit

enum AiQoWorkoutType: String, CaseIterable, Codable {
    case gratitude
    case walkInside
    case walkOutside
    case runningIndoor
    case runningOutside

    var title: String {
        switch self {
        case .gratitude:       return "Gratitude"
        case .walkInside:      return "Walk inside"
        case .walkOutside:     return "Walking outside"
        case .runningIndoor:   return "Running indoor"
        case .runningOutside:  return "Running outside"
        }
    }
  
    var subtitle: String {
        switch self {
        case .gratitude:
            return "Breathing + reflection"
        case .walkInside:
            return "Easy indoor walk"
        case .walkOutside:
            return "Outdoor fresh air"
        case .runningIndoor:
            return "Treadmill focus run"
        case .runningOutside:
            return "Outdoor run"
        }
    }

    /// نوع الـ HealthKit لكل تمرين
    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .gratitude:
            return .mindAndBody
        case .walkInside:
            return .walking
        case .walkOutside:
            return .walking
        case .runningIndoor:
            return .running
        case .runningOutside:
            return .running
        }
    }

    /// موقع التمرين (داخل / خارج) لو تحب تستعمله
    var hkLocationType: HKWorkoutSessionLocationType {
        switch self {
        case .walkInside, .runningIndoor, .gratitude:
            return .indoor
        case .walkOutside, .runningOutside:
            return .outdoor
        }
    }
}
extension AiQoWorkoutType {
    init?(from hk: HKWorkoutActivityType) {
        switch hk {
        case .mindAndBody:
            self = .gratitude
        case .walking:
            self = .walkInside      // تقدر تغيّرها لـ walkOutside إذا تحب
        case .running:
            self = .runningIndoor   // نفس الشي تقدر تغيّرها لـ runningOutside
        default:
            return nil
        }
    }
}
