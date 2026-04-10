// ===============================================
// File: ProactiveEngine.swift
// Phase 4 — Captain Hamoudi Brain V2
// Centralized decision engine for all proactive
// notifications. Controls budget, gates, triggers.
// ===============================================

import Foundation

// MARK: - Decision Models

enum ProactiveDecision: Sendable {
    case sendNotification(content: String, category: String, priority: ProactivePriority)
    case doNothing(reason: String)
}

enum ProactivePriority: Int, Comparable, Sendable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Context

struct ProactiveContext: Sendable {
    let emotionalState: EmotionalState
    let trendSnapshot: TrendSnapshot?

    let notificationsSentToday: Int
    let lastNotificationTime: Date?
    let lastNotificationWasOpened: Bool?
    let recentDismissedCount: Int

    let stepsToday: Int
    let stepGoal: Int
    let caloriesBurnedToday: Int
    let calorieGoal: Int
    let waterIntakePercent: Double
    let ringCompletion: Double
    let isCurrentlyWorkingOut: Bool
    let lastWorkoutEndedAt: Date?

    let userName: String
    let primaryGoal: String
    let favoriteSport: String
    let preferredWorkoutTime: String
    let bedtime: String
    let wakeTime: String

    let trialDay: Int?
    let subscriptionTier: String

    let currentTime: Date
}

// MARK: - Budget

struct NotificationBudget: Sendable {
    let maxPerDay: Int
    let minIntervalMinutes: Int
    let quietHoursStart: String
    let quietHoursEnd: String

    static func forContext(_ context: ProactiveContext) -> NotificationBudget {
        let max: Int
        switch context.subscriptionTier {
        case "trial":
            max = min(context.trialDay ?? 1, 3)
        case "core":
            max = 3
        case "intelligence_pro":
            max = 4
        default:
            max = 0
        }
        return NotificationBudget(
            maxPerDay: max,
            minIntervalMinutes: 120,
            quietHoursStart: context.bedtime,
            quietHoursEnd: context.wakeTime
        )
    }
}

// MARK: - Engine

final class ProactiveEngine: Sendable {
    static let shared = ProactiveEngine()
    private init() {}

    func evaluate(context: ProactiveContext) -> ProactiveDecision {
        // Kill switch: if Brain V2 is disabled, defer to legacy notification system
        guard CaptainContextBuilder.isBrainV2Enabled else {
            return .doNothing(reason: "brain_v2_disabled")
        }

        let budget = NotificationBudget.forContext(context)

        // Gate 1: No subscription
        guard context.subscriptionTier != "none" else {
            return blocked("no_subscription", budget: budget, context: context)
        }

        // Gate 2: Budget exhausted
        guard context.notificationsSentToday < budget.maxPerDay else {
            return blocked("budget_exhausted", budget: budget, context: context)
        }

        // Gate 3: Cooldown active
        if let lastTime = context.lastNotificationTime {
            let minutesSince = context.currentTime.timeIntervalSince(lastTime) / 60
            if minutesSince < Double(budget.minIntervalMinutes) {
                return blocked("cooldown_active", budget: budget, context: context)
            }
        }

        // Gate 4: Quiet hours
        if isWithinQuietHours(
            currentTime: context.currentTime,
            bedtime: budget.quietHoursStart,
            wakeTime: budget.quietHoursEnd
        ) {
            return blocked("quiet_hours", budget: budget, context: context)
        }

        // Gate 5: User disengaged
        if context.recentDismissedCount >= 3 && context.notificationsSentToday >= 1 {
            return blocked("user_disengaged", budget: budget, context: context)
        }

        // TRIGGER CHECKS (priority order)

        // CRITICAL: Workout just ended
        if let workoutEnd = context.lastWorkoutEndedAt,
           context.currentTime.timeIntervalSince(workoutEnd) < 300 {
            return approved(
                content: "\(context.userName)، تمرين حلو! 🔥 لا تنسى تشرب ماي وتتمدد",
                category: "workout_complete",
                priority: .critical,
                budget: budget,
                context: context
            )
        }

        // HIGH: Currently working out
        if context.isCurrentlyWorkingOut {
            return approved(
                content: "ها \(context.userName) كاعد تتحرك! افتح لك تمرين \(context.favoriteSport)؟ 💪",
                category: "activity_spike",
                priority: .high,
                budget: budget,
                context: context
            )
        }

        // HIGH: Ring almost complete
        if context.ringCompletion >= 0.80 && context.ringCompletion < 1.0 {
            let remaining = max(0, context.stepGoal - context.stepsToday)
            return approved(
                content: "باقي \(remaining) خطوة بس \(context.userName)! مشية قصيرة وتكمل 💪",
                category: "goal_near",
                priority: .high,
                budget: budget,
                context: context
            )
        }

        let hour = Calendar.current.component(.hour, from: context.currentTime)

        // MEDIUM: Steps below average + afternoon/evening
        if context.stepsToday < context.stepGoal / 2 && (14...22).contains(hour) {
            let content: String
            if context.emotionalState.recommendedTone == .gentle {
                content = "مشية قصيرة تخليك تحس أحسن \(context.userName)... شتقول؟ 🚶"
            } else {
                content = "يلا \(context.userName) قوم تحرك! خطواتك اليوم قليلة 🏃"
            }
            return approved(
                content: content,
                category: "activity_nudge",
                priority: .medium,
                budget: budget,
                context: context
            )
        }

        // MEDIUM: Water low
        if context.waterIntakePercent < 0.5 && hour > 12 {
            return approved(
                content: "حمودي يذكّرك \(context.userName)... جسمك يحتاج ماي 💧",
                category: "water_reminder",
                priority: .medium,
                budget: budget,
                context: context
            )
        }

        // MEDIUM: Sleep declining
        if let trend = context.trendSnapshot,
           trend.sleepTrend == .declining,
           trend.sleepChangePct < -15,
           (20...23).contains(hour) {
            return approved(
                content: "نومك تراجع هالأيام \(context.userName)... حاول تنام أبكر الليلة 🌙",
                category: "sleep_nudge",
                priority: .medium,
                budget: budget,
                context: context
            )
        }

        // LOW: Streak breaking
        if let trend = context.trendSnapshot, trend.streakMomentum == .breaking {
            return approved(
                content: "لا تضيع الـ streak \(context.userName)... تمرين قصير يكفي ✊",
                category: "streak_protection",
                priority: .low,
                budget: budget,
                context: context
            )
        }

        // LOW: Morning kickoff
        if isMorningWindow(context.currentTime, wakeTime: context.wakeTime)
            && context.notificationsSentToday == 0 {
            let content: String
            if let day = context.trialDay {
                if day == 1 {
                    content = "هلا \(context.userName)! أنا كابتن حمودي، اليوم أول يوم وياك 💪"
                } else if day <= 3 {
                    let sleepNote = context.emotionalState.signals.contains("good_sleep") ? "نومك كان زين" : "حاول تنام أحسن الليلة"
                    content = "صباح الخير \(context.userName)! \(sleepNote) ⚡️"
                } else {
                    let trendNote = context.trendSnapshot?.stepsTrend == .improving ? "خطواتك بتحسن" : "يلا نبدأ اليوم"
                    content = "صباح الخير \(context.userName)! \(trendNote) 💪"
                }
            } else {
                content = "صباح الخير \(context.userName)! يلا نبدأ اليوم ⚡️"
            }
            return approved(
                content: content,
                category: "morning_kickoff",
                priority: .low,
                budget: budget,
                context: context
            )
        }

        return blocked("no_relevant_trigger", budget: budget, context: context)
    }

    // MARK: - Helpers

    private func isWithinQuietHours(currentTime: Date, bedtime: String, wakeTime: String) -> Bool {
        guard let bed = parseTime(bedtime), let wake = parseTime(wakeTime) else {
            // Fallback to system quiet hours (23:00-07:00)
            let hour = Calendar.current.component(.hour, from: currentTime)
            return hour >= 23 || hour < 7
        }

        let cal = Calendar.current
        let hour = cal.component(.hour, from: currentTime)
        let minute = cal.component(.minute, from: currentTime)
        let tsMinutes = hour * 60 + minute
        let bedMinutes = bed.hour * 60 + bed.minute
        let wakeMinutes = wake.hour * 60 + wake.minute

        if bedMinutes <= wakeMinutes {
            return tsMinutes >= bedMinutes && tsMinutes < wakeMinutes
        } else {
            return tsMinutes >= bedMinutes || tsMinutes < wakeMinutes
        }
    }

    private func isMorningWindow(_ date: Date, wakeTime: String) -> Bool {
        guard let wake = parseTime(wakeTime) else { return false }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let tsMinutes = hour * 60 + minute
        let wakeMinutes = wake.hour * 60 + wake.minute
        let diff = tsMinutes - wakeMinutes
        return diff >= 0 && diff <= 60
    }

    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func approved(
        content: String,
        category: String,
        priority: ProactivePriority,
        budget: NotificationBudget,
        context: ProactiveContext
    ) -> ProactiveDecision {
        #if DEBUG
        print("[ProactiveEngine] ✅ Sending: \(category) (\(priority)) | Budget: \(context.notificationsSentToday)/\(budget.maxPerDay) | Tier: \(context.subscriptionTier)")
        #endif
        return .sendNotification(content: content, category: category, priority: priority)
    }

    private func blocked(
        _ reason: String,
        budget: NotificationBudget,
        context: ProactiveContext
    ) -> ProactiveDecision {
        #if DEBUG
        print("[ProactiveEngine] ⛔ Blocked: \(reason) | Budget: \(context.notificationsSentToday)/\(budget.maxPerDay) | Tier: \(context.subscriptionTier)")
        #endif
        return .doNothing(reason: reason)
    }
}
