import Foundation

// MARK: - Analytics Event

/// حدث تحليلي واحد — اسم + خصائص اختيارية
struct AnalyticsEvent {
    let name: String
    let properties: [String: Any]

    init(_ name: String, properties: [String: Any] = [:]) {
        self.name = name
        self.properties = properties
    }
}

// MARK: - Pre-defined Events

extension AnalyticsEvent {

    // MARK: App Lifecycle
    static let appLaunched = AnalyticsEvent("app_launched")
    static let appBecameActive = AnalyticsEvent("app_became_active")
    static let appEnteredBackground = AnalyticsEvent("app_entered_background")

    // MARK: Onboarding
    static func onboardingStepViewed(_ step: Int) -> AnalyticsEvent {
        AnalyticsEvent("onboarding_step_viewed", properties: ["step": step])
    }
    static let onboardingCompleted = AnalyticsEvent("onboarding_completed")
    static let onboardingSkipped = AnalyticsEvent("onboarding_skipped")

    // MARK: Authentication
    static let loginStarted = AnalyticsEvent("login_started")
    static let loginCompleted = AnalyticsEvent("login_completed")
    static let logoutCompleted = AnalyticsEvent("logout_completed")

    // MARK: Navigation
    static func tabSelected(_ tab: String) -> AnalyticsEvent {
        AnalyticsEvent("tab_selected", properties: ["tab": tab])
    }

    static func screenViewed(_ screen: String) -> AnalyticsEvent {
        AnalyticsEvent("screen_viewed", properties: ["screen": screen])
    }

    // MARK: Captain (AI Coach)
    static let captainChatOpened = AnalyticsEvent("captain_chat_opened")
    static func captainMessageSent(length: Int) -> AnalyticsEvent {
        AnalyticsEvent("captain_message_sent", properties: ["message_length": length])
    }
    static func captainResponseReceived(latencyMs: Int) -> AnalyticsEvent {
        AnalyticsEvent("captain_response_received", properties: ["latency_ms": latencyMs])
    }
    static func captainResponseFailed(error: String) -> AnalyticsEvent {
        AnalyticsEvent("captain_response_failed", properties: ["error": error])
    }
    static func captainResponseTruncated(screen: String) -> AnalyticsEvent {
        AnalyticsEvent("captain_response_truncated", properties: ["screen": screen])
    }
    static let captainVoicePlayed = AnalyticsEvent("captain_voice_played")
    static let captainHistoryViewed = AnalyticsEvent("captain_history_viewed")

    // MARK: Workouts
    static func workoutStarted(type: String) -> AnalyticsEvent {
        AnalyticsEvent("workout_started", properties: ["type": type])
    }
    static func workoutCompleted(type: String, durationMin: Int, calories: Int) -> AnalyticsEvent {
        AnalyticsEvent("workout_completed", properties: [
            "type": type,
            "duration_min": durationMin,
            "calories": calories
        ])
    }
    static let workoutCancelled = AnalyticsEvent("workout_cancelled")
    static let visionCoachStarted = AnalyticsEvent("vision_coach_started")
    static func visionCoachCompleted(reps: Int, accuracy: Double) -> AnalyticsEvent {
        AnalyticsEvent("vision_coach_completed", properties: [
            "reps": reps,
            "accuracy": accuracy
        ])
    }

    // MARK: Quests
    static func questStarted(id: String) -> AnalyticsEvent {
        AnalyticsEvent("quest_started", properties: ["quest_id": id])
    }
    static func questCompleted(id: String) -> AnalyticsEvent {
        AnalyticsEvent("quest_completed", properties: ["quest_id": id])
    }

    // MARK: Kitchen
    static let kitchenOpened = AnalyticsEvent("kitchen_opened")
    static let mealPlanGenerated = AnalyticsEvent("meal_plan_generated")
    static let fridgeItemAdded = AnalyticsEvent("fridge_item_added")

    // MARK: Tribe (Social)
    static let tribeCreated = AnalyticsEvent("tribe_created")
    static let tribeJoined = AnalyticsEvent("tribe_joined")
    static let tribeLeft = AnalyticsEvent("tribe_left")
    static let tribeLeaderboardViewed = AnalyticsEvent("tribe_leaderboard_viewed")
    static let tribeArenaViewed = AnalyticsEvent("tribe_arena_viewed")

    // MARK: Spotify / Vibe
    static let spotifyConnected = AnalyticsEvent("spotify_connected")
    static func spotifyTrackPlayed(trackName: String) -> AnalyticsEvent {
        AnalyticsEvent("spotify_track_played", properties: ["track": trackName])
    }

    // MARK: Health
    static func healthPermissionGranted(type: String) -> AnalyticsEvent {
        AnalyticsEvent("health_permission_granted", properties: ["type": type])
    }
    static let healthPermissionDenied = AnalyticsEvent("health_permission_denied")
    static func dailySummaryGenerated(steps: Int, calories: Int, sleepHours: Double) -> AnalyticsEvent {
        AnalyticsEvent("daily_summary_generated", properties: [
            "steps": steps,
            "calories": calories,
            "sleep_hours": sleepHours
        ])
    }

    // MARK: Premium / Subscription
    static let paywallViewed = AnalyticsEvent("paywall_viewed")
    static func subscriptionStarted(plan: String, price: String) -> AnalyticsEvent {
        AnalyticsEvent("subscription_started", properties: [
            "plan": plan,
            "price": price
        ])
    }
    static func subscriptionFailed(plan: String, error: String) -> AnalyticsEvent {
        AnalyticsEvent("subscription_failed", properties: [
            "plan": plan,
            "error": error
        ])
    }
    static let subscriptionRestored = AnalyticsEvent("subscription_restored")
    static let subscriptionCancelled = AnalyticsEvent("subscription_cancelled")
    static let freeTrialStarted = AnalyticsEvent("free_trial_started")

    // MARK: Notifications
    static let notificationPermissionGranted = AnalyticsEvent("notification_permission_granted")
    static let notificationPermissionDenied = AnalyticsEvent("notification_permission_denied")
    static func notificationTapped(type: String) -> AnalyticsEvent {
        AnalyticsEvent("notification_tapped", properties: ["type": type])
    }

    // MARK: Settings
    static func languageChanged(to language: String) -> AnalyticsEvent {
        AnalyticsEvent("language_changed", properties: ["language": language])
    }
    static let memoryCleared = AnalyticsEvent("memory_cleared")

    // MARK: Trial Journey
    static let trialJourneyStarted = AnalyticsEvent("trial_journey_started")
    static func trialNotificationFired(kind: String) -> AnalyticsEvent {
        AnalyticsEvent("trial_notification_fired", properties: ["kind": kind])
    }
    static func trialNotificationOpened(kind: String) -> AnalyticsEvent {
        AnalyticsEvent("trial_notification_opened", properties: ["kind": kind])
    }
    static func weeklyReportGenerated(weekNumber: Int) -> AnalyticsEvent {
        AnalyticsEvent("weekly_report_generated", properties: ["week_number": weekNumber])
    }
    static func paywallShown(source: String) -> AnalyticsEvent {
        AnalyticsEvent("paywall_shown", properties: ["source": source])
    }

    // MARK: Errors
    static func errorOccurred(domain: String, message: String) -> AnalyticsEvent {
        AnalyticsEvent("error_occurred", properties: [
            "domain": domain,
            "message": message
        ])
    }
}
