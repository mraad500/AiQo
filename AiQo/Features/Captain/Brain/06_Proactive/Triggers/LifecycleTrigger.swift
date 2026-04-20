import Foundation

/// Trial-day milestone trigger. Returns nil until BATCH 8 wires FreeTrialManager.
struct TrialDayTrigger: Trigger {
    let id = "trial_day"
    let kind = NotificationKind.trialDay

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        return nil
    }
}
