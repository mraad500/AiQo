import Foundation

enum HydrationPaceStatus: String, Sendable, CaseIterable {
    case ahead
    case onTrack
    case behind
    case veryBehind
}

enum HydrationSource: String, Sendable {
    case manual
    case appleHealth
}

struct HydrationDailyState: Sendable, Equatable {
    let goalML: Double
    let consumedML: Double
    let expectedByNowML: Double
    let lastDrinkDate: Date?
    let lastDrinkSource: HydrationSource?
    let paceStatus: HydrationPaceStatus

    var remainingML: Double {
        max(0, goalML - consumedML)
    }

    var progressFraction: Double {
        guard goalML > 0 else { return 0 }
        return min(1, consumedML / goalML)
    }

    static let zero = HydrationDailyState(
        goalML: 2000,
        consumedML: 0,
        expectedByNowML: 0,
        lastDrinkDate: nil,
        lastDrinkSource: nil,
        paceStatus: .onTrack
    )
}

enum HydrationReminderIntensity: Sendable {
    case gentle
    case stronger
}

enum HydrationEvaluation: Sendable, Equatable {
    case suppress(reason: SuppressReason)
    case remind(intensity: HydrationReminderIntensity)

    enum SuppressReason: String, Sendable {
        case beforeWakeWindow
        case afterWakeWindow
        case quietHours
        case recentDrink
        case paceOK
        case trackingDisabled
    }

    static func == (lhs: HydrationEvaluation, rhs: HydrationEvaluation) -> Bool {
        switch (lhs, rhs) {
        case (.suppress(let a), .suppress(let b)):
            return a == b
        case (.remind(.gentle), .remind(.gentle)),
             (.remind(.stronger), .remind(.stronger)):
            return true
        default:
            return false
        }
    }
}
