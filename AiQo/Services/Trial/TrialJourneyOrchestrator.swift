import Foundation
import HealthKit
import UserNotifications

@MainActor
final class TrialJourneyOrchestrator {
    static let shared = TrialJourneyOrchestrator()

    private struct Config {
        static let triggerCooldown: TimeInterval = 90 * 60
        static let inactivityThresholdSeconds: TimeInterval = 3 * 3600
        static let paceSpikeMinKmH: Double = 5.5
        static let paceSpikeWindowSeconds: TimeInterval = 180
        static let dailyCaps: [Int: Int] = [1: 1, 2: 2, 3: 3, 4: 3, 5: 3, 6: 3, 7: 3]
    }

    private enum Keys {
        static let lastTriggerFiredAt  = "aiqo.trial.lastTriggerFiredAt"
        static let firedTodayCount     = "aiqo.trial.firedTodayCount"
        static let firedTodayDate      = "aiqo.trial.firedTodayDate"
        static let firedKindsToday     = "aiqo.trial.firedKindsToday"
        static let welcomeFired        = "aiqo.trial.welcomeFired"
        static let day6PreviewFired    = "aiqo.trial.day6PreviewFired"
        static let day7RecapFired      = "aiqo.trial.day7RecapFired"
    }

    private var stepObserverQuery: HKObserverQuery?
    private var workoutObserverQuery: HKObserverQuery?
    private let hkStore = HKHealthStore()
    private var isStarted = false

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else { return }

        guard FreeTrialManager.shared.isInsideTrialWindow else {
            scheduleNextSundayPostTrialIfEligible()
            return
        }

        isStarted = true
        scheduleStaticNotifications()
        installHealthKitObservers()
        AnalyticsService.shared.track(.trialJourneyStarted)
    }

    func stop() {
        if let q = stepObserverQuery { hkStore.stop(q) }
        if let q = workoutObserverQuery { hkStore.stop(q) }
        stepObserverQuery = nil
        workoutObserverQuery = nil
        isStarted = false
    }

    func refresh() {
        if FreeTrialManager.shared.isInsideTrialWindow {
            start()
        } else {
            stop()
            scheduleNextSundayPostTrialIfEligible()
        }
    }

    // MARK: - Static notifications

    private func scheduleStaticNotifications() {
        guard let day = FreeTrialManager.shared.currentTrialDay else { return }

        if day == 1, !UserDefaults.standard.bool(forKey: Keys.welcomeFired) {
            scheduleWelcomeEvening()
        }

        if day < 7 {
            scheduleMorningBriefForTomorrow()
        }

        if day == 6, !UserDefaults.standard.bool(forKey: Keys.day6PreviewFired) {
            scheduleDay6PaywallPreview()
        }

        if day == 7, !UserDefaults.standard.bool(forKey: Keys.day7RecapFired) {
            scheduleDay7WeeklyRecap()
        }
    }

    private func scheduleWelcomeEvening() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 19
        components.minute = 30

        guard let target = Calendar.current.date(from: components) else { return }

        if target <= Date() {
            fireWelcomeIfDataAvailable()
            return
        }

        let adjusted = SmartNotificationScheduler.shared.adjustedAutomationDate(for: target)
        scheduleAtDate(adjusted, kind: .welcomeEvening, identifier: "trial.welcome.evening", requireSteps: true)
        UserDefaults.standard.set(true, forKey: Keys.welcomeFired)
    }

    private func fireWelcomeIfDataAvailable() {
        Task {
            let steps = (await HealthKitManager.shared.todayStepCount()) ?? 0
            guard steps > 0 else { return }
            await MainActor.run {
                fireImmediate(kind: .welcomeEvening, ctx: makeContext(steps: steps))
                UserDefaults.standard.set(true, forKey: Keys.welcomeFired)
            }
        }
    }

    private func scheduleMorningBriefForTomorrow() {
        let prefs = TrialPersonalizationReader.current()
        let (hour, minute) = TrialPersonalizationReader.morningBriefTime(for: prefs.workoutTime)

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.day = (components.day ?? 0) + 1
        components.hour = hour
        components.minute = minute

        guard let target = Calendar.current.date(from: components) else { return }
        let adjusted = SmartNotificationScheduler.shared.adjustedAutomationDate(for: target)

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["trial.morningBrief.tomorrow"]
        )
        scheduleAtDate(adjusted, kind: .morningBrief, identifier: "trial.morningBrief.tomorrow", requireSteps: false)
    }

    private func scheduleDay6PaywallPreview() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 0

        guard let target = Calendar.current.date(from: components) else { return }
        let adjusted = SmartNotificationScheduler.shared.adjustedAutomationDate(for: target)

        scheduleAtDate(
            adjusted,
            kind: .day6PaywallPreview,
            identifier: "trial.day6.preview",
            deepLink: "aiqo://paywall?source=day6Preview"
        )
        UserDefaults.standard.set(true, forKey: Keys.day6PreviewFired)
    }

    private func scheduleDay7WeeklyRecap() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 18
        components.minute = 0

        guard let target = Calendar.current.date(from: components) else { return }
        let adjusted = SmartNotificationScheduler.shared.adjustedAutomationDate(for: target)

        scheduleAtDate(
            adjusted,
            kind: .day7WeeklyRecapReady,
            identifier: "trial.day7.recap",
            deepLink: "aiqo://memory?section=weekly"
        )
        UserDefaults.standard.set(true, forKey: Keys.day7RecapFired)
    }

    // MARK: - HealthKit observers

    private func installHealthKitObservers() {
        installStepObserver()
        installWorkoutObserver()
    }

    private func installStepObserver() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, _ in
            Task { @MainActor in
                await self?.evaluateStepBasedTriggers()
            }
        }
        hkStore.execute(query)
        hkStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
        stepObserverQuery = query
    }

    private func installWorkoutObserver() {
        let type = HKObjectType.workoutType()

        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, _, _ in
            Task { @MainActor in
                await self?.evaluateWorkoutCompleted()
            }
        }
        hkStore.execute(query)
        hkStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        workoutObserverQuery = query
    }

    // MARK: - Trigger evaluation

    private func evaluateStepBasedTriggers() async {
        guard FreeTrialManager.shared.isInsideTrialWindow else { return }
        guard !isAtDailyCap() else { return }
        guard !isInCooldown() else { return }

        let steps = (await HealthKitManager.shared.todayStepCount()) ?? 0

        if let pace = await HealthKitManager.shared.recentWalkingPaceKmH(window: Config.paceSpikeWindowSeconds),
           pace >= Config.paceSpikeMinKmH {
            await fireTrigger(.paceSpike, steps: steps)
            return
        }

        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 17 {
            let goal = HealthKitManager.shared.dailyStepGoal
            let ratio = Double(steps) / Double(max(goal, 1))
            if ratio >= 0.8 && ratio < 1.0 {
                await fireTrigger(.goalApproach, steps: steps)
                return
            }
        }

        if (9...18).contains(hour) {
            if let age = await HealthKitManager.shared.secondsSinceLastStepSample(),
               age >= Config.inactivityThresholdSeconds {
                await fireTrigger(.inactivityGap, steps: steps)
                return
            }
        }
    }

    private func evaluateWorkoutCompleted() async {
        guard FreeTrialManager.shared.isInsideTrialWindow else { return }
        guard !isAtDailyCap() else { return }

        guard let summary = await HealthKitManager.shared.latestWorkoutSummary() else { return }
        let kind: TrialNotificationKind = (summary.activityType == .running) ? .runDetected : .workoutCompleted
        await fireTrigger(kind, steps: nil, calories: Int(summary.calories))
    }

    // MARK: - Firing primitives

    private func fireTrigger(_ kind: TrialNotificationKind, steps: Int?, calories: Int? = nil) async {
        guard !isAtDailyCap() else { return }
        guard !isInCooldown() else { return }
        guard !alreadyFiredKindToday(kind) else { return }

        let ctx = makeContext(steps: steps, calories: calories)
        fireImmediate(kind: kind, ctx: ctx)
        markCooldown()
        markFired(kind: kind)
    }

    private func fireImmediate(kind: TrialNotificationKind, ctx: TrialCopyContext) {
        if !DevOverride.unlockAllFeatures {
            guard TierGate.shared.canAccess(.captainNotifications) else {
                diag.info("TrialJourneyOrchestrator immediate blocked by TierGate(.captainNotifications)")
                return
            }
        }
        let language = AppSettingsStore.shared.appLanguage == .arabic ? "ar" : "en"
        let title = TrialNotificationCopy.title(for: kind, ctx: ctx, language: language)
        let body = TrialNotificationCopy.body(for: kind, ctx: ctx, language: language)
        let identifier = "trial.\(kind.rawValue).\(Int(Date().timeIntervalSince1970))"
        let intent = NotificationIntent(
            kind: .trialDay,
            requestedBy: "TrialJourneyOrchestrator.fireImmediate"
        )
        Task {
            await NotificationBrain.shared.request(
                intent,
                precomposedTitle: title,
                precomposedBody: body,
                categoryIdentifier: NotificationCategoryManager.trialJourneyCategory,
                userInfo: ["trialKind": kind.rawValue],
                identifier: identifier
            )
            AnalyticsService.shared.track(.trialNotificationFired(kind: kind.rawValue))
        }
    }

    private func scheduleAtDate(_ date: Date, kind: TrialNotificationKind, identifier: String, requireSteps: Bool = false, deepLink: String? = nil) {
        Task {
            var ctx = makeContext()
            if requireSteps {
                let steps = (await HealthKitManager.shared.todayStepCount()) ?? 0
                guard steps > 0 else { return }
                ctx = makeContext(steps: steps)
            }

            let (title, body, canAccess): (String, String, Bool) = await MainActor.run {
                let language = AppSettingsStore.shared.appLanguage == .arabic ? "ar" : "en"
                let t = TrialNotificationCopy.title(for: kind, ctx: ctx, language: language)
                let b = TrialNotificationCopy.body(for: kind, ctx: ctx, language: language)
                let access = DevOverride.unlockAllFeatures || TierGate.shared.canAccess(.captainNotifications)
                return (t, b, access)
            }

            guard canAccess else {
                diag.info("TrialJourneyOrchestrator scheduled blocked by TierGate(.captainNotifications)")
                return
            }

            var info: [String: String] = ["trialKind": kind.rawValue]
            if let deepLink { info["deepLink"] = deepLink }

            let intent = NotificationIntent(
                kind: .trialDay,
                requestedBy: "TrialJourneyOrchestrator.scheduleAtDate"
            )
            await NotificationBrain.shared.request(
                intent,
                fireDate: date,
                precomposedTitle: title,
                precomposedBody: body,
                categoryIdentifier: NotificationCategoryManager.trialJourneyCategory,
                userInfo: info,
                identifier: identifier
            )
        }
    }

    // MARK: - Caps & cooldown

    private func isAtDailyCap() -> Bool {
        guard let day = FreeTrialManager.shared.currentTrialDay else { return true }
        let cap = Config.dailyCaps[day] ?? 1
        rolloverIfNewDay()
        return UserDefaults.standard.integer(forKey: Keys.firedTodayCount) >= cap
    }

    private func isInCooldown() -> Bool {
        let last = UserDefaults.standard.double(forKey: Keys.lastTriggerFiredAt)
        guard last > 0 else { return false }
        return Date().timeIntervalSince1970 - last < Config.triggerCooldown
    }

    private func markCooldown() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastTriggerFiredAt)
        rolloverIfNewDay()
        let count = UserDefaults.standard.integer(forKey: Keys.firedTodayCount)
        UserDefaults.standard.set(count + 1, forKey: Keys.firedTodayCount)
    }

    private func rolloverIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let stored = UserDefaults.standard.object(forKey: Keys.firedTodayDate) as? Date
        if stored == nil || stored! < today {
            UserDefaults.standard.set(today, forKey: Keys.firedTodayDate)
            UserDefaults.standard.set(0, forKey: Keys.firedTodayCount)
            UserDefaults.standard.set([String](), forKey: Keys.firedKindsToday)
        }
    }

    private func alreadyFiredKindToday(_ kind: TrialNotificationKind) -> Bool {
        rolloverIfNewDay()
        let kinds = UserDefaults.standard.stringArray(forKey: Keys.firedKindsToday) ?? []
        return kinds.contains(kind.rawValue)
    }

    private func markFired(kind: TrialNotificationKind) {
        var kinds = UserDefaults.standard.stringArray(forKey: Keys.firedKindsToday) ?? []
        kinds.append(kind.rawValue)
        UserDefaults.standard.set(kinds, forKey: Keys.firedKindsToday)
    }

    private func makeContext(steps: Int? = nil, calories: Int? = nil) -> TrialCopyContext {
        let prefs = TrialPersonalizationReader.current()
        return TrialCopyContext(
            firstName: prefs.firstName,
            steps: steps,
            calories: calories,
            sleepHours: nil,
            preferredSportLocalized: prefs.sport?.localizedTitle,
            preferredGoalLocalized: prefs.goal?.localizedTitle,
            weekNumber: nil
        )
    }

    // MARK: - Post-trial Sunday weekly notification

    private func scheduleNextSundayPostTrialIfEligible() {
        guard FreeTrialManager.shared.hasUsedTrial else { return }
        guard AccessManager.shared.activeTier == .none else { return }

        var components = DateComponents()
        components.weekday = 1    // Sunday
        components.hour = 18
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let language = AppSettingsStore.shared.appLanguage == .arabic ? "ar" : "en"
        let week = WeeklyMemoryConsolidator.shared.latestWeekNumber() ?? 1

        let ctx = TrialCopyContext(
            firstName: UserProfileStore.shared.current.name.components(separatedBy: " ").first,
            steps: nil, calories: nil, sleepHours: nil,
            preferredSportLocalized: nil, preferredGoalLocalized: nil,
            weekNumber: week
        )

        let content = UNMutableNotificationContent()
        content.title = TrialNotificationCopy.title(for: .postTrialWeeklyReport, ctx: ctx, language: language)
        content.body  = TrialNotificationCopy.body(for: .postTrialWeeklyReport, ctx: ctx, language: language)
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryManager.trialJourneyCategory
        content.userInfo = ["deepLink": "aiqo://memory?section=weekly"]

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["trial.postTrial.sundayReport"]
        )

        let request = UNNotificationRequest(
            identifier: "trial.postTrial.sundayReport",
            content: content,
            trigger: trigger
        )
        if !DevOverride.unlockAllFeatures {
            guard TierGate.shared.canAccess(.captainNotifications) else {
                diag.info("TrialJourneyOrchestrator sundayReport blocked by TierGate(.captainNotifications)")
                return
            }
        }
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
