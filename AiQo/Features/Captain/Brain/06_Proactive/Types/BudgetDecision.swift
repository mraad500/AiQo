import Foundation

/// Decision produced by GlobalBudget on every intent request.
public enum BudgetDecision: Sendable {
    case allowed
    case allowedWithOverride(reason: String)   // critical priority overrode a cap
    case deferredToMorning                     // quiet hours — re-deliver at user's wake
    case rejected(Reason)

    public enum Reason: String, Sendable {
        case pendingLimitReached
        case dailyLimitReached
        case cooldown
        case quietHours
        case expired
        case duplicate                         // same kind + recent delivery
        case tierDisabled                      // tier disallows this kind
    }

    public var isAllowed: Bool {
        switch self {
        case .allowed, .allowedWithOverride:
            return true
        default:
            return false
        }
    }
}
