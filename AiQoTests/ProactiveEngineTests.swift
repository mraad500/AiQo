import XCTest
@testable import AiQo

@MainActor
final class ProactiveEngineTests: XCTestCase {

    private let engine = ProactiveEngine.shared
    private var savedBrainV2Flag = false

    override func setUp() {
        super.setUp()
        savedBrainV2Flag = CaptainContextBuilder.isBrainV2Enabled
        CaptainContextBuilder.isBrainV2Enabled = true
    }

    override func tearDown() {
        CaptainContextBuilder.isBrainV2Enabled = savedBrainV2Flag
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeEmotionalState(
        mood: EstimatedMood = .neutral,
        tone: RecommendedTone = .neutral
    ) -> EmotionalState {
        EmotionalState(
            estimatedMood: mood,
            confidence: 0.7,
            signals: [],
            recommendedTone: tone,
            computedAt: Date()
        )
    }

    private func makeContext(
        subscriptionTier: String = "core",
        notificationsSentToday: Int = 0,
        lastNotificationTime: Date? = nil,
        recentDismissedCount: Int = 0,
        currentTime: Date? = nil,
        bedtime: String = "23:00",
        wakeTime: String = "07:00",
        stepsToday: Int = 5000,
        stepGoal: Int = 10000,
        waterIntakePercent: Double = 0.7,
        ringCompletion: Double = 0.5,
        isCurrentlyWorkingOut: Bool = false,
        lastWorkoutEndedAt: Date? = nil,
        trialDay: Int? = nil,
        trendSnapshot: TrendSnapshot? = nil,
        emotionalState: EmotionalState? = nil
    ) -> ProactiveContext {
        ProactiveContext(
            emotionalState: emotionalState ?? makeEmotionalState(),
            trendSnapshot: trendSnapshot,
            notificationsSentToday: notificationsSentToday,
            lastNotificationTime: lastNotificationTime,
            lastNotificationWasOpened: nil,
            recentDismissedCount: recentDismissedCount,
            stepsToday: stepsToday,
            stepGoal: stepGoal,
            caloriesBurnedToday: 200,
            calorieGoal: 500,
            waterIntakePercent: waterIntakePercent,
            ringCompletion: ringCompletion,
            isCurrentlyWorkingOut: isCurrentlyWorkingOut,
            lastWorkoutEndedAt: lastWorkoutEndedAt,
            userName: "أحمد",
            primaryGoal: "fitness",
            favoriteSport: "Running",
            preferredWorkoutTime: "08:00",
            bedtime: bedtime,
            wakeTime: wakeTime,
            trialDay: trialDay,
            subscriptionTier: subscriptionTier,
            currentTime: currentTime ?? Date()
        )
    }

    private func assertBlocked(_ decision: ProactiveDecision, reason: String, file: StaticString = #file, line: UInt = #line) {
        guard case .doNothing(let r) = decision else {
            XCTFail("Expected .doNothing but got sendNotification", file: file, line: line)
            return
        }
        XCTAssertEqual(r, reason, file: file, line: line)
    }

    private func assertSent(_ decision: ProactiveDecision, category: String? = nil, file: StaticString = #file, line: UInt = #line) {
        guard case .sendNotification(_, let cat, _) = decision else {
            XCTFail("Expected .sendNotification but got doNothing", file: file, line: line)
            return
        }
        if let category {
            XCTAssertEqual(cat, category, file: file, line: line)
        }
    }

    // MARK: - Gate 0: Brain V2 Kill Switch

    func testGate0_brainV2Disabled_blocksAll() {
        CaptainContextBuilder.isBrainV2Enabled = false
        let ctx = makeContext()
        assertBlocked(engine.evaluate(context: ctx), reason: "brain_v2_disabled")
    }

    // MARK: - Gate 1: No Subscription

    func testGate1_noSubscription_blocked() {
        let ctx = makeContext(subscriptionTier: "none")
        assertBlocked(engine.evaluate(context: ctx), reason: "no_subscription")
    }

    // MARK: - Gate 2: Budget Exhausted

    func testGate2_budgetExhausted_core() {
        // Core tier: max 3/day
        let ctx = makeContext(notificationsSentToday: 3)
        assertBlocked(engine.evaluate(context: ctx), reason: "budget_exhausted")
    }

    func testGate2_budgetExhausted_intelligencePro() {
        // Intelligence Pro: max 4/day
        let ctx = makeContext(subscriptionTier: "intelligence_pro", notificationsSentToday: 4)
        assertBlocked(engine.evaluate(context: ctx), reason: "budget_exhausted")
    }

    func testGate2_budgetNotExhausted_intelligencePro() {
        // Intelligence Pro with 3 sent (max is 4) → not exhausted
        let time = makeAfternoonTime()
        let ctx = makeContext(
            subscriptionTier: "intelligence_pro",
            notificationsSentToday: 3,
            currentTime: time,
            stepsToday: 2000,
            stepGoal: 10000
        )
        let decision = engine.evaluate(context: ctx)
        // Should pass budget gate and proceed to triggers
        if case .doNothing(let reason) = decision {
            XCTAssertNotEqual(reason, "budget_exhausted")
        }
    }

    // MARK: - Gate 3: Cooldown Active

    func testGate3_cooldownActive_blocked() {
        let oneHourAgo = Date().addingTimeInterval(-3600) // 60 min ago, min is 120
        let ctx = makeContext(lastNotificationTime: oneHourAgo)
        assertBlocked(engine.evaluate(context: ctx), reason: "cooldown_active")
    }

    func testGate3_cooldownExpired_passes() {
        let threeHoursAgo = Date().addingTimeInterval(-10800) // 180 min ago
        let time = makeAfternoonTime()
        let ctx = makeContext(
            lastNotificationTime: threeHoursAgo,
            currentTime: time,
            stepsToday: 2000,
            stepGoal: 10000
        )
        let decision = engine.evaluate(context: ctx)
        if case .doNothing(let reason) = decision {
            XCTAssertNotEqual(reason, "cooldown_active")
        }
    }

    // MARK: - Gate 4: Quiet Hours

    func testGate4_quietHours_blocked() {
        // 1:00 AM is within quiet hours (bedtime 23:00, wake 07:00)
        let nightTime = makeTime(hour: 1, minute: 0)
        let ctx = makeContext(currentTime: nightTime)
        assertBlocked(engine.evaluate(context: ctx), reason: "quiet_hours")
    }

    func testGate4_outsideQuietHours_passes() {
        let afternoon = makeTime(hour: 14, minute: 0)
        let ctx = makeContext(
            currentTime: afternoon,
            stepsToday: 2000,
            stepGoal: 10000
        )
        let decision = engine.evaluate(context: ctx)
        if case .doNothing(let reason) = decision {
            XCTAssertNotEqual(reason, "quiet_hours")
        }
    }

    // MARK: - Gate 5: User Disengaged

    func testGate5_userDisengaged_blocked() {
        let afternoon = makeTime(hour: 14, minute: 0)
        let ctx = makeContext(
            notificationsSentToday: 1,
            recentDismissedCount: 3,
            currentTime: afternoon
        )
        assertBlocked(engine.evaluate(context: ctx), reason: "user_disengaged")
    }

    func testGate5_notDisengaged_tooFewDismissals() {
        let afternoon = makeTime(hour: 14, minute: 0)
        let ctx = makeContext(
            notificationsSentToday: 1,
            recentDismissedCount: 2,
            currentTime: afternoon,
            stepsToday: 2000,
            stepGoal: 10000
        )
        let decision = engine.evaluate(context: ctx)
        if case .doNothing(let reason) = decision {
            XCTAssertNotEqual(reason, "user_disengaged")
        }
    }

    // MARK: - Budget: Trial Tier

    func testBudget_trial_day1_max1() {
        // Trial day 1: max = min(1, 3) = 1
        let ctx = makeContext(
            subscriptionTier: "trial",
            notificationsSentToday: 1,
            trialDay: 1
        )
        assertBlocked(engine.evaluate(context: ctx), reason: "budget_exhausted")
    }

    func testBudget_trial_day5_max3() {
        // Trial day 5: max = min(5, 3) = 3
        let ctx = makeContext(
            subscriptionTier: "trial",
            notificationsSentToday: 3,
            trialDay: 5
        )
        assertBlocked(engine.evaluate(context: ctx), reason: "budget_exhausted")
    }

    // MARK: - Triggers

    func testTrigger_workoutJustEnded() {
        let afternoon = makeTime(hour: 14, minute: 0)
        let ctx = makeContext(
            currentTime: afternoon,
            lastWorkoutEndedAt: afternoon.addingTimeInterval(-60) // 1 min ago
        )
        assertSent(engine.evaluate(context: ctx), category: "workout_complete")
    }

    func testTrigger_currentlyWorkingOut() {
        let afternoon = makeTime(hour: 14, minute: 0)
        let ctx = makeContext(
            currentTime: afternoon,
            isCurrentlyWorkingOut: true
        )
        assertSent(engine.evaluate(context: ctx), category: "activity_spike")
    }

    func testTrigger_ringAlmostComplete() {
        let afternoon = makeTime(hour: 14, minute: 0)
        let ctx = makeContext(
            currentTime: afternoon,
            ringCompletion: 0.85
        )
        assertSent(engine.evaluate(context: ctx), category: "goal_near")
    }

    func testTrigger_noRelevantTrigger() {
        // All gates pass but no trigger fires
        let afternoon = makeTime(hour: 10, minute: 0)
        let ctx = makeContext(
            currentTime: afternoon,
            stepsToday: 8000,
            stepGoal: 10000,
            ringCompletion: 0.5
        )
        assertBlocked(engine.evaluate(context: ctx), reason: "no_relevant_trigger")
    }

    // MARK: - Time Helpers

    private func makeTime(hour: Int, minute: Int) -> Date {
        var cal = Calendar.current
        cal.timeZone = .current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return cal.date(from: comps)!
    }

    private func makeAfternoonTime() -> Date {
        makeTime(hour: 15, minute: 0)
    }
}
