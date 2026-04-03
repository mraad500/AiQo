//
//  CaptainNotificationEngine.swift
//  AiQo – Captain Hamoudi Dual-Persona Notification Engine
//
//  Two personas driven by subscription tier and real-time HealthKit state:
//    - "Hamoudi" (Friend)  : Free/Standard – rare, gentle motivational nudges.
//    - "Captain Hamoudi" (Coach) : Intelligence Pro – strict, physiology-triggered discipline.
//

import Foundation
import HealthKit
import UserNotifications

// MARK: - Supporting Types

/// The two Captain personas gated by subscription tier.
enum PersonaType: String, Sendable {
    case friend  // "Hamoudi"          – gentle, low-frequency
    case coach   // "Captain Hamoudi"  – strict, physiology-aware
}

/// Pro-only preference that controls how aggressively the Coach interrupts.
enum CaptainNotificationFrequency: String, CaseIterable, Sendable {
    case low    // 3 notifications / day
    case normal // 6 notifications / day  (default)
    case high   // 10 notifications / day

    var maxDailySlots: Int {
        switch self {
        case .low:    return 3
        case .normal: return 6
        case .high:   return 10
        }
    }

    /// Minimum cooldown (minutes) between Coach-triggered alerts.
    var cooldownMinutes: Int {
        switch self {
        case .low:    return 180
        case .normal: return 90
        case .high:   return 45
        }
    }
}

// MARK: - Notification Context

enum NotificationContext: String, CaseIterable, Sendable {
    case morningRampUp       // 6:30-9:00 AM
    case hydrationNudge      // 10:00 AM, 1:00 PM, 4:00 PM
    case workoutMotivation   // 11:00 AM, 5:30 PM
    case focusAndMindset     // 9:30 AM, 2:00 PM
    case nutritionFuel       // 12:00 PM, 7:00 PM
    case faithAndSoul        // 5:00 AM, 12:30 PM
    case streakAndProgress   // 8:00 PM
    case sleepWindDown       // 9:30-10:30 PM

    /// Default trigger windows (hour, minute) for each context.
    var scheduleWindows: [(hour: Int, minute: Int)] {
        switch self {
        case .morningRampUp:     return [(7, 0)]
        case .hydrationNudge:    return [(10, 0), (13, 0), (16, 0)]
        case .workoutMotivation: return [(11, 0), (17, 30)]
        case .focusAndMindset:   return [(9, 30), (14, 0)]
        case .nutritionFuel:     return [(12, 0), (19, 0)]
        case .faithAndSoul:      return [(5, 0), (12, 30)]
        case .streakAndProgress: return [(20, 0)]
        case .sleepWindDown:     return [(22, 0)]
        }
    }

    /// Priority weight used by the Coach when pruning to fit frequency cap.
    var coachPriority: Int {
        switch self {
        case .morningRampUp:     return 8
        case .workoutMotivation: return 9
        case .hydrationNudge:    return 6
        case .focusAndMindset:   return 5
        case .nutritionFuel:     return 4
        case .faithAndSoul:      return 3
        case .streakAndProgress: return 7
        case .sleepWindDown:     return 10
        }
    }
}

// MARK: - HealthKit Physiological State

/// Snapshot of today's physiological signals used for trigger evaluation.
struct PhysiologicalState: Sendable {
    let todaySteps: Int
    let sleepHoursLogged: Double
    let hoursSinceLastSleep: Double
    let dayProgressRatio: Double        // 0.0 at midnight, 1.0 at 11:59 PM
    let inactivityMinutes: Int

    /// True when the user appears to have been awake 18+ hours with
    /// active steps but NO recorded sleep data for the current day.
    var isExtendedWakeState: Bool {
        sleepHoursLogged < 0.1 && hoursSinceLastSleep >= 18 && todaySteps > 200
    }

    /// True when rings are essentially empty and the day is 70%+ over.
    var isLateInactiveDay: Bool {
        dayProgressRatio >= 0.70 && todaySteps < 500
    }
}

// MARK: - Catalog Entry

struct CaptainNotificationEntry: Sendable {
    let id: Int
    let text: String
    let context: NotificationContext
    let gender: ActivityNotificationGender
    let language: ActivityNotificationLanguage
}

// MARK: - Catalog (all 120 notifications)

enum CaptainNotificationCatalog: Sendable {

    private static let contextMap: [Int: NotificationContext] = [
        1:  .morningRampUp,
        2:  .streakAndProgress,
        3:  .hydrationNudge,
        4:  .workoutMotivation,
        5:  .focusAndMindset,
        6:  .sleepWindDown,
        7:  .streakAndProgress,
        8:  .workoutMotivation,
        9:  .focusAndMindset,
        10: .workoutMotivation,
        11: .nutritionFuel,
        12: .faithAndSoul,
        13: .streakAndProgress,
        14: .sleepWindDown,
        15: .morningRampUp,
        16: .workoutMotivation,
        17: .streakAndProgress,
        18: .sleepWindDown,
        19: .focusAndMindset,
        20: .focusAndMindset,
        21: .workoutMotivation,
        22: .focusAndMindset,
        23: .streakAndProgress,
        24: .workoutMotivation,
        25: .focusAndMindset,
        26: .workoutMotivation,
        27: .focusAndMindset,
        28: .streakAndProgress,
        29: .nutritionFuel,
        30: .sleepWindDown,
    ]

    // MARK: Male - Arabic

    private static let maleArabic: [String] = [
        "بطل، يوم جديد كدامك!",
        "خطواتك تصنع مستقبلك، كمل!",
        "جسمك محتاج مي، اشرب!",
        "لا توقف، انت كدها!",
        "استمر، الانضباط هو السر!",
        "وقت نومك، ريح جسمك.",
        "عاشت ايدك، إنجاز عظيم!",
        "طاقتك نازلة؟ تحرك هسة.",
        "ركز بهدفك، لا تتشتت.",
        "تمرينك ينتظرك، لا تأجل.",
        "وجبتك جاهزة؟ أكل نظيف.",
        "الصلاة نور، لا تنساها.",
        "كمل خطواتك، مابقى شي!",
        "يومك ناجح، استعد للباجر.",
        "هالتك اليوم تخبل، استمر!",
        "دكة گلبك تدفعك للامام!",
        "بطل القبيلة، خليك بالصدارة!",
        "جر نفس عميق، واسترخي.",
        "وقت التركيز، افصل عن العالم.",
        "صحتك ثروتك، دير بالك عليها.",
        "اكسر حاجز الخوف، وتقدم.",
        "لا تتنازل عن حلمك أبداً!",
        "درعك يلمع، حافظ عليه!",
        "تحدي جديد ينتظرك، استعد.",
        "صفي ذهنك، وابدي من جديد.",
        "تعبك اليوم هو راحة باجر.",
        "خليك مركز، الهدف صار قريب.",
        "لا تكسر السلسلة، يا بطل!",
        "أكل نظيف يعني طاقة أقوى.",
        "نام زين، باجر تحدي جديد.",
    ]

    // MARK: Male - English

    private static let maleEnglish: [String] = [
        "Champion, own your new day!",
        "Your steps build the future.",
        "Your body needs water now.",
        "Don't stop, you got this!",
        "Discipline is your secret weapon.",
        "Time to rest your mind.",
        "Great job, keep pushing forward!",
        "Low energy? Move right now.",
        "Stay focused, ignore the noise.",
        "Your workout is waiting, hero.",
        "Fuel up with clean food.",
        "Stay connected to your soul.",
        "Finish your steps, almost there!",
        "Great day, prepare for tomorrow.",
        "Your aura is glowing today!",
        "Let your heartbeat drive you.",
        "Tribe leader, stay on top!",
        "Take a deep breath now.",
        "Focus time, disconnect the world.",
        "Health is wealth, protect it.",
        "Break your limits, step up.",
        "Never give up your dream!",
        "Keep your shield shining bright!",
        "New challenge awaits, be ready.",
        "Clear your mind, start fresh.",
        "Today's pain is tomorrow's power.",
        "Stay sharp, goal is near.",
        "Don't break your streak, champion!",
        "Clean meal, unstoppable raw energy.",
        "Rest well, conquer tomorrow's challenge.",
    ]

    // MARK: Female - Arabic

    private static let femaleArabic: [String] = [
        "بطلة، يوم جديد كدامچ!",
        "خطواتچ تصنع مستقبلك، كملي!",
        "جسمچ محتاج مي، اشربي هسة!",
        "لا توقفين، انتي كدها!",
        "استمري، الانضباط هو السر!",
        "وقت نومچ، ريحي جسمچ.",
        "عاشت ايدچ، إنجاز عظيم!",
        "طاقتچ نازلة؟ تحركي هسة.",
        "ركزي بهدفچ، لا تتشتتين.",
        "تمرينچ ينتظرچ، لا تأجلين.",
        "وجبتچ جاهزة؟ أكل نظيف.",
        "الصلاة نور، لا تنسيها.",
        "كملي خطواتچ، مابقى شي!",
        "يومچ ناجح، استعدي للباجر.",
        "هالتچ اليوم تخبل، استمري!",
        "دكة گلبچ تدفعچ للامام!",
        "بطلة القبيلة، خليچ بالصدارة!",
        "جري نفس عميق، واسترخي.",
        "وقت التركيز، افصلي عن العالم.",
        "صحتچ ثروتچ، ديري بالچ عليها.",
        "اكسري حاجز الخوف، وتقدمي.",
        "لا تتنازلين عن حلمچ أبداً!",
        "درعچ يلمع، حافظي عليه!",
        "تحدي جديد ينتظرچ، استعدي.",
        "صفي ذهنچ، وابدي من جديد.",
        "تعبچ اليوم هو راحة باجر.",
        "خليچ مركزة، الهدف صار قريب.",
        "لا تكسرين السلسلة، يا بطلة!",
        "أكل نظيف يعني طاقة أقوى.",
        "نامي زين، باجر تحدي جديد.",
    ]

    // MARK: Female - English

    private static let femaleEnglish: [String] = [
        "Queen, own your new day!",
        "Your steps build the future.",
        "Your body needs water now.",
        "Don't stop, you got this!",
        "Discipline is your secret weapon.",
        "Time to rest your mind.",
        "Great job, keep pushing forward!",
        "Low energy? Move right now.",
        "Stay focused, ignore the noise.",
        "Your workout is waiting, superstar.",
        "Fuel up with clean food.",
        "Stay connected to your soul.",
        "Finish your steps, almost there!",
        "Great day, prepare for tomorrow.",
        "Your aura is glowing today!",
        "Tribe leader, stay on top!",
        "Let your heartbeat drive you.",
        "Tribe leader, stay on top!",
        "Take a deep breath now.",
        "Focus time, disconnect the world.",
        "Health is wealth, protect it.",
        "Break your limits, step up.",
        "Never give up your dream!",
        "Keep your shield shining bright!",
        "New challenge awaits, be ready.",
        "Clear your mind, start fresh.",
        "Today's effort is tomorrow's power.",
        "Stay sharp, goal is near.",
        "Don't break your streak, superstar!",
        "Clean meal, unstoppable raw energy.",
        "Rest well, conquer tomorrow's challenge.",
    ]

    // MARK: - Build full catalog

    static let all: [CaptainNotificationEntry] = {
        var entries: [CaptainNotificationEntry] = []
        var nextID = 1

        func add(
            _ texts: [String],
            gender: ActivityNotificationGender,
            language: ActivityNotificationLanguage
        ) {
            for (index, text) in texts.enumerated() {
                let slot = index + 1
                let context = contextMap[slot] ?? .focusAndMindset
                entries.append(CaptainNotificationEntry(
                    id: nextID,
                    text: text,
                    context: context,
                    gender: gender,
                    language: language
                ))
                nextID += 1
            }
        }

        add(maleArabic,    gender: .male,   language: .arabic)
        add(maleEnglish,   gender: .male,   language: .english)
        add(femaleArabic,  gender: .female,  language: .arabic)
        add(femaleEnglish, gender: .female,  language: .english)

        return entries
    }()
}

// MARK: - Frequency Preference Store

final class CaptainFrequencyStore: Sendable {
    static let shared = CaptainFrequencyStore()
    private init() {}

    private static let key = "aiqo.captain.notificationFrequency"

    var frequency: CaptainNotificationFrequency {
        get {
            if let raw = UserDefaults.standard.string(forKey: Self.key),
               let value = CaptainNotificationFrequency(rawValue: raw) {
                return value
            }
            return .normal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.key)
        }
    }
}

// MARK: - HealthKit Physiology Provider

/// Reads real-time physiological data from HealthKit for trigger evaluation.
final class PhysiologyProvider {
    static let shared = PhysiologyProvider()
    private let store = HKHealthStore()
    private init() {}

    /// Fetches a snapshot of the user's current physiological state.
    func fetchCurrentState() async -> PhysiologicalState {
        async let steps = fetchTodaySteps()
        async let sleep = fetchTodaySleepHours()
        async let lastSleep = fetchHoursSinceLastSleep()

        let resolvedSteps = await steps
        let resolvedSleep = await sleep
        let resolvedLastSleep = await lastSleep

        let dayProgress = Self.currentDayProgress()
        let inactivity = InactivityTracker.shared.currentInactivityMinutes

        return PhysiologicalState(
            todaySteps: resolvedSteps,
            sleepHoursLogged: resolvedSleep,
            hoursSinceLastSleep: resolvedLastSleep,
            dayProgressRatio: dayProgress,
            inactivityMinutes: inactivity
        )
    }

    // MARK: Steps

    private func fetchTodaySteps() async -> Int {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: Date(), options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(value))
            }
            store.execute(query)
        }
    }

    // MARK: Sleep

    private func fetchTodaySleepHours() async -> Double {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else { return 0 }

        // Look back 18 hours to capture overnight sleep.
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: Date(), options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                var totalSeconds: TimeInterval = 0
                for sample in (samples as? [HKCategorySample]) ?? [] {
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    let isAsleep: Bool
                    if #available(iOS 16.0, *) {
                        isAsleep = value == .asleepCore
                            || value == .asleepDeep
                            || value == .asleepREM
                            || value == .asleepUnspecified
                    } else {
                        isAsleep = value == .asleep
                    }
                    if isAsleep {
                        totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            store.execute(query)
        }
    }

    /// Hours elapsed since the end of the user's last recorded sleep session.
    private func fetchHoursSinceLastSleep() async -> Double {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else { return 24 } // Assume worst case if unavailable

        let start = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: Date(), options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate, ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let latest = samples?.first as? HKCategorySample else {
                    continuation.resume(returning: 24)
                    return
                }
                let hours = Date().timeIntervalSince(latest.endDate) / 3600.0
                continuation.resume(returning: max(0, hours))
            }
            store.execute(query)
        }
    }

    // MARK: Day Progress

    /// Returns 0.0 at midnight, 1.0 at 11:59 PM.
    static func currentDayProgress() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(startOfDay)
        return min(elapsed / 86_400.0, 1.0)
    }
}

// MARK: - Captain Notification Engine

final class CaptainNotificationEngine: @unchecked Sendable {

    static let shared = CaptainNotificationEngine()
    private init() {}

    static let categoryIdentifier = "CAPTAIN_BEHAVIORAL_NUDGE"
    private static let identifierPrefix  = "aiqo.captain.nudge"
    private static let coachPrefix       = "aiqo.captain.coach"
    private static let lastScheduleKey   = "aiqo.captain.engine.lastScheduleDate"
    private static let lastPickedIDsKey  = "aiqo.captain.engine.lastPickedIDs"
    private static let lastCoachFireKey  = "aiqo.captain.engine.lastCoachFire"
    private static let coachCountKey     = "aiqo.captain.engine.coachCountToday"
    private static let coachCountDateKey = "aiqo.captain.engine.coachCountDate"

    // MARK: - Notification Category

    static var notificationCategory: UNNotificationCategory {
        let openChat = UNNotificationAction(
            identifier: "OPEN_CAPTAIN_CHAT",
            title: NSLocalizedString("فتح المحادثة", comment: "Open chat"),
            options: [.foreground]
        )
        return UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [openChat],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    // MARK: - Persona Resolution

    /// Determines the active persona based on the user's subscription tier.
    /// Coach persona is STRICTLY gated behind Intelligence Pro.
    @MainActor
    func resolvePersona() -> PersonaType {
        let tier = AccessManager.shared.activeTier
        return tier >= .intelligencePro ? .coach : .friend
    }

    // MARK: - Public: Get Notification Text

    func getNotification(
        for context: NotificationContext,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) -> String {
        let matches = CaptainNotificationCatalog.all.filter {
            $0.context == context && $0.gender == gender && $0.language == language
        }
        return matches.randomElement()?.text
            ?? (language == .arabic ? "يلا نبدي!" : "Let's go!")
    }

    // MARK: - Public: Schedule Daily Notifications (Persona-Aware)

    /// Main entry point. Reads tier, resolves persona, schedules accordingly.
    @MainActor
    func scheduleDailyNotifications() {
        guard AppSettingsStore.shared.notificationsEnabled else {
            print("🔕 [Captain Engine] Notifications disabled globally")
            return
        }

        if hasScheduledToday() {
            print("📅 [Captain Engine] Already scheduled today")
            return
        }

        cancelAllScheduledNotifications()
        resetDailyCoachCount()

        let persona = resolvePersona()
        let language = resolveCaptainLanguage()
        let gender = resolveGender()

        switch persona {
        case .friend:
            scheduleFriendNotifications(language: language, gender: gender)
        case .coach:
            let freq = CaptainFrequencyStore.shared.frequency
            scheduleCoachNotifications(language: language, gender: gender, frequency: freq)
        }

        UserDefaults.standard.set(Date(), forKey: Self.lastScheduleKey)
        print("✅ [Captain Engine] Scheduled as \(persona.rawValue) (\(language), \(gender))")
    }

    // MARK: - Public: Evaluate HealthKit Triggers (Pro-Only Real-Time)

    /// Called from HealthKitManager's data-processing loop. Evaluates
    /// physiological state and fires Coach or Friend triggers accordingly.
    func evaluateHealthKitTriggers() {
        Task {
            let persona = await MainActor.run { resolvePersona() }
            let state = await PhysiologyProvider.shared.fetchCurrentState()
            let language = resolveCaptainLanguage()
            let gender = resolveGender()

            await evaluateTriggers(
                persona: persona,
                state: state,
                language: language,
                gender: gender
            )
        }
    }

    // MARK: - Trigger Evaluation

    @MainActor
    private func evaluateTriggers(
        persona: PersonaType,
        state: PhysiologicalState,
        language: ActivityNotificationLanguage,
        gender: ActivityNotificationGender
    ) {
        // ────────────────────────────────────────────
        // TRIGGER 1: 18-Hour Extended Wake (Coach only)
        // ────────────────────────────────────────────
        if persona == .coach, state.isExtendedWakeState {
            guard canFireCoach() else { return }
            let title = language == .arabic
                ? "كابتن حمودي - أمر نوم! 🛑"
                : "Captain Hamoudi - Sleep Order! 🛑"
            let body = gender == .male
                ? (language == .arabic
                    ? "بطل، صار الك ١٨ ساعة صاحي! جسمك يصرخ يريد راحة. نام هسة، هذا أمر مو طلب!"
                    : "Champion, 18+ hours awake! Your body is screaming for rest. Sleep NOW, that's an order!")
                : (language == .arabic
                    ? "بطلة، صار الچ ١٨ ساعة صاحية! جسمچ يصرخ يريد راحة. نامي هسة، هذا أمر مو طلب!"
                    : "Queen, 18+ hours awake! Your body is screaming for rest. Sleep NOW, that's an order!")
            fireCoachNotification(title: title, body: body, context: .sleepWindDown)
            return
        }

        // ────────────────────────────────────────────
        // TRIGGER 2: Late Inactive Day (70%+ day, empty rings)
        // ────────────────────────────────────────────
        if state.isLateInactiveDay {
            if persona == .coach {
                guard canFireCoach() else { return }
                let title = language == .arabic
                    ? "كابتن حمودي - تحرك هسة! ⚡"
                    : "Captain Hamoudi - Move NOW! ⚡"
                let body = gender == .male
                    ? (language == .arabic
                        ? "يومك راح يخلص وما سويت شي! قوم تحرك هسة، الوقت يركض!"
                        : "Your day is almost over and you've done nothing! Get up and move, time is running out!")
                    : (language == .arabic
                        ? "يومچ راح يخلص وما سويتي شي! قومي تحركي هسة، الوقت يركض!"
                        : "Your day is almost over and you've done nothing! Get up and move, time is running out!")
                fireCoachNotification(title: title, body: body, context: .workoutMotivation)
            } else {
                // Friend persona: gentle nudge
                let title = language == .arabic
                    ? "حمودي يذكرك 💛"
                    : "Hamoudi Reminder 💛"
                let body = getNotification(for: .workoutMotivation, gender: gender, language: language)
                fireFriendNotification(title: title, body: body, context: .workoutMotivation)
            }
            return
        }

        // ────────────────────────────────────────────
        // TRIGGER 3: High Inactivity (Coach: strict / Friend: gentle)
        // ────────────────────────────────────────────
        let inactivityThreshold = persona == .coach ? 60 : 90
        if state.inactivityMinutes >= inactivityThreshold, state.dayProgressRatio > 0.25 {
            if persona == .coach {
                guard canFireCoach() else { return }
                let title = language == .arabic
                    ? "كابتن حمودي ⚡"
                    : "Captain Hamoudi ⚡"
                let body = getNotification(for: .workoutMotivation, gender: gender, language: language)
                fireCoachNotification(title: title, body: body, context: .workoutMotivation)
            } else {
                let title = language == .arabic
                    ? "حمودي 💛"
                    : "Hamoudi 💛"
                let body = getNotification(for: .hydrationNudge, gender: gender, language: language)
                fireFriendNotification(title: title, body: body, context: .hydrationNudge)
            }
        }
    }

    // MARK: - Friend Scheduling (Free / Standard)

    /// Schedules a sparse set of gentle nudges throughout the day.
    /// Friend persona gets at most 3 notifications: morning, midday, evening.
    private func scheduleFriendNotifications(
        language: ActivityNotificationLanguage,
        gender: ActivityNotificationGender
    ) {
        let friendWindows: [(context: NotificationContext, hour: Int, minute: Int)] = [
            (.morningRampUp,  7,  0),
            (.hydrationNudge, 13, 0),
            (.sleepWindDown,  22, 0),
        ]

        let previousIDs = Set(
            UserDefaults.standard.array(forKey: Self.lastPickedIDsKey) as? [Int] ?? []
        )
        var pickedIDs: [Int] = []

        for window in friendWindows {
            let entry = pickEntry(
                context: window.context,
                gender: gender,
                language: language,
                excluding: previousIDs
            )
            guard let entry else { continue }
            pickedIDs.append(entry.id)

            let title = friendTitle(for: window.context, language: language)
            scheduleCalendarNotification(
                identifier: "\(Self.identifierPrefix).friend.\(window.context.rawValue)",
                title: title,
                body: entry.text,
                hour: window.hour,
                minute: window.minute,
                persona: .friend,
                context: window.context
            )
        }

        UserDefaults.standard.set(pickedIDs, forKey: Self.lastPickedIDsKey)
        print("👋 [Captain Engine] Friend: scheduled \(pickedIDs.count) gentle nudges")
    }

    // MARK: - Coach Scheduling (Intelligence Pro)

    /// Schedules notifications honoring the user's frequency cap.
    /// Context windows are pruned by priority to fit within the budget.
    private func scheduleCoachNotifications(
        language: ActivityNotificationLanguage,
        gender: ActivityNotificationGender,
        frequency: CaptainNotificationFrequency
    ) {
        // Flatten all windows and sort by priority descending, then by time.
        var allWindows: [(context: NotificationContext, hour: Int, minute: Int, priority: Int)] = []
        for ctx in NotificationContext.allCases {
            for w in ctx.scheduleWindows {
                allWindows.append((ctx, w.hour, w.minute, ctx.coachPriority))
            }
        }
        allWindows.sort { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return (lhs.hour * 60 + lhs.minute) < (rhs.hour * 60 + rhs.minute)
        }

        // Prune to frequency cap
        let capped = Array(allWindows.prefix(frequency.maxDailySlots))

        let previousIDs = Set(
            UserDefaults.standard.array(forKey: Self.lastPickedIDsKey) as? [Int] ?? []
        )
        var pickedIDs: [Int] = []

        for window in capped {
            let entry = pickEntry(
                context: window.context,
                gender: gender,
                language: language,
                excluding: previousIDs
            )
            guard let entry else { continue }
            pickedIDs.append(entry.id)

            let title = coachTitle(for: window.context, language: language)
            scheduleCalendarNotification(
                identifier: "\(Self.identifierPrefix).coach.\(window.context.rawValue).\(window.hour).\(window.minute)",
                title: title,
                body: entry.text,
                hour: window.hour,
                minute: window.minute,
                persona: .coach,
                context: window.context
            )
        }

        UserDefaults.standard.set(pickedIDs, forKey: Self.lastPickedIDsKey)
        print("🫡 [Captain Engine] Coach (\(frequency.rawValue)): scheduled \(pickedIDs.count) notifications")
    }

    // MARK: - Immediate Notification Firing

    private func fireCoachNotification(
        title: String,
        body: String,
        context: NotificationContext
    ) {
        markCoachFired()
        fire(
            identifier: "\(Self.coachPrefix).\(context.rawValue).\(Int(Date().timeIntervalSince1970))",
            title: title,
            body: body,
            persona: .coach,
            context: context
        )
    }

    private func fireFriendNotification(
        title: String,
        body: String,
        context: NotificationContext
    ) {
        fire(
            identifier: "\(Self.identifierPrefix).friend.rt.\(context.rawValue).\(Int(Date().timeIntervalSince1970))",
            title: title,
            body: body,
            persona: .friend,
            context: context
        )
    }

    private func fire(
        identifier: String,
        title: String,
        body: String,
        persona: PersonaType,
        context: NotificationContext
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = persona == .coach ? .defaultCritical : .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "type": "captainBehavioral",
            "persona": persona.rawValue,
            "context": context.rawValue,
            "deepLink": "aiqo://captain",
            "source": "captain_hamoudi",
        ]

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ [Captain Engine] Fire failed: \(error.localizedDescription)")
            } else {
                print("🔥 [Captain Engine] Fired \(persona.rawValue): \(title)")
            }
        }
    }

    // MARK: - Calendar Scheduling Helper

    private func scheduleCalendarNotification(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        persona: PersonaType,
        context: NotificationContext
    ) {
        let now = Date()
        let calendar = Calendar.current

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let targetDate = calendar.date(from: components) else { return }
        let fireDate = targetDate > now
            ? targetDate
            : calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate

        let triggerComponents = calendar.dateComponents([.hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents, repeats: false
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = persona == .coach ? .defaultCritical : .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "type": "captainBehavioral",
            "persona": persona.rawValue,
            "context": context.rawValue,
            "deepLink": "aiqo://captain",
            "source": "captain_hamoudi",
        ]

        let request = UNNotificationRequest(
            identifier: identifier, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ [Captain Engine] Schedule failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Coach Frequency & Cooldown Guards

    /// Returns `true` if the Coach is allowed to fire right now
    /// (respects both daily count cap and per-notification cooldown).
    private func canFireCoach() -> Bool {
        let frequency = CaptainFrequencyStore.shared.frequency
        let defaults = UserDefaults.standard

        // Daily count gate
        let countDate = defaults.object(forKey: Self.coachCountDateKey) as? Date
        let isToday = countDate.map { Calendar.current.isDateInToday($0) } ?? false
        let count = isToday ? defaults.integer(forKey: Self.coachCountKey) : 0
        guard count < frequency.maxDailySlots else {
            print("🛑 [Captain Engine] Coach daily cap reached (\(count)/\(frequency.maxDailySlots))")
            return false
        }

        // Cooldown gate
        if let lastFire = defaults.object(forKey: Self.lastCoachFireKey) as? Date {
            let elapsed = Int(Date().timeIntervalSince(lastFire) / 60)
            guard elapsed >= frequency.cooldownMinutes else {
                print("⏳ [Captain Engine] Coach cooldown active (\(elapsed)/\(frequency.cooldownMinutes) min)")
                return false
            }
        }

        return true
    }

    private func markCoachFired() {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: Self.lastCoachFireKey)

        let countDate = defaults.object(forKey: Self.coachCountDateKey) as? Date
        let isToday = countDate.map { Calendar.current.isDateInToday($0) } ?? false
        let current = isToday ? defaults.integer(forKey: Self.coachCountKey) : 0
        defaults.set(current + 1, forKey: Self.coachCountKey)
        if !isToday {
            defaults.set(Date(), forKey: Self.coachCountDateKey)
        }
    }

    private func resetDailyCoachCount() {
        let defaults = UserDefaults.standard
        let countDate = defaults.object(forKey: Self.coachCountDateKey) as? Date
        let isToday = countDate.map { Calendar.current.isDateInToday($0) } ?? false
        if !isToday {
            defaults.set(0, forKey: Self.coachCountKey)
            defaults.set(Date(), forKey: Self.coachCountDateKey)
        }
    }

    // MARK: - Cancel

    func cancelAllScheduledNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(Self.identifierPrefix) || $0.hasPrefix(Self.coachPrefix)
                }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Force Reschedule (settings change / debug)

    @MainActor
    func forceReschedule() {
        UserDefaults.standard.removeObject(forKey: Self.lastScheduleKey)
        scheduleDailyNotifications()
    }

    // MARK: - Private Helpers

    private func resolveCaptainLanguage() -> ActivityNotificationLanguage {
        switch AppSettingsStore.shared.appLanguage {
        case .arabic:  return .arabic
        case .english: return .english
        }
    }

    private func resolveGender() -> ActivityNotificationGender {
        if let profileGender = UserProfileStore.shared.current.gender {
            return profileGender
        }
        return NotificationPreferencesStore.shared.gender
    }

    private func hasScheduledToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: Self.lastScheduleKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastDate)
    }

    private func pickEntry(
        context: NotificationContext,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage,
        excluding previousIDs: Set<Int>
    ) -> CaptainNotificationEntry? {
        let pool = CaptainNotificationCatalog.all.filter {
            $0.context == context && $0.gender == gender && $0.language == language
        }
        let fresh = pool.filter { !previousIDs.contains($0.id) }
        return (fresh.isEmpty ? pool : fresh).randomElement()
    }

    // MARK: - Persona Titles

    private func friendTitle(
        for context: NotificationContext,
        language: ActivityNotificationLanguage
    ) -> String {
        switch context {
        case .morningRampUp:     return language == .arabic ? "صباح الخير من حمودي ☀️"   : "Good Morning from Hamoudi ☀️"
        case .hydrationNudge:    return language == .arabic ? "حمودي يذكرك 💧"            : "Hamoudi Reminder 💧"
        case .workoutMotivation: return language == .arabic ? "حمودي يحمسك 💪"            : "Hamoudi Cheers 💪"
        case .focusAndMindset:   return language == .arabic ? "حمودي معاك 🎯"             : "Hamoudi With You 🎯"
        case .nutritionFuel:     return language == .arabic ? "حمودي يذكرك 🍽️"           : "Hamoudi Reminder 🍽️"
        case .faithAndSoul:      return language == .arabic ? "حمودي 🤲"                  : "Hamoudi 🤲"
        case .streakAndProgress: return language == .arabic ? "حمودي فخور بيك 🔥"         : "Hamoudi is Proud 🔥"
        case .sleepWindDown:     return language == .arabic ? "حمودي يقولك تصبح بخير 🌙" : "Hamoudi Says Goodnight 🌙"
        }
    }

    private func coachTitle(
        for context: NotificationContext,
        language: ActivityNotificationLanguage
    ) -> String {
        switch context {
        case .morningRampUp:     return language == .arabic ? "كابتن حمودي - صباح التمرين ☀️" : "Captain Hamoudi - Rise Up ☀️"
        case .hydrationNudge:    return language == .arabic ? "كابتن حمودي - اشرب! 💧"        : "Captain Hamoudi - Hydrate! 💧"
        case .workoutMotivation: return language == .arabic ? "كابتن حمودي - تمرين! 💪"       : "Captain Hamoudi - Workout! 💪"
        case .focusAndMindset:   return language == .arabic ? "كابتن حمودي - ركز! 🎯"         : "Captain Hamoudi - Focus! 🎯"
        case .nutritionFuel:     return language == .arabic ? "كابتن حمودي - كل نظيف! 🍽️"    : "Captain Hamoudi - Eat Clean! 🍽️"
        case .faithAndSoul:      return language == .arabic ? "كابتن حمودي 🤲"                 : "Captain Hamoudi 🤲"
        case .streakAndProgress: return language == .arabic ? "كابتن حمودي - لا توقف! 🔥"     : "Captain Hamoudi - Keep Going! 🔥"
        case .sleepWindDown:     return language == .arabic ? "كابتن حمودي - نام هسة! 🌙"     : "Captain Hamoudi - Sleep Now! 🌙"
        }
    }

    // MARK: - Debug

    func printSchedulingSummary() {
        Task { @MainActor in
            let persona = resolvePersona()
            let frequency = CaptainFrequencyStore.shared.frequency
            print("═══════════════════════════════════════")
            print("📊 [Captain Engine] Scheduling Summary")
            print("  Persona : \(persona.rawValue)")
            print("  Tier    : \(AccessManager.shared.activeTier.displayName)")
            print("  Frequency: \(frequency.rawValue) (max \(frequency.maxDailySlots)/day)")
            print("═══════════════════════════════════════")
        }

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ours = requests.filter {
                $0.identifier.hasPrefix(Self.identifierPrefix) || $0.identifier.hasPrefix(Self.coachPrefix)
            }
            for req in ours {
                if let trigger = req.trigger as? UNCalendarNotificationTrigger {
                    let h = trigger.dateComponents.hour ?? 0
                    let m = trigger.dateComponents.minute ?? 0
                    let p = req.content.userInfo["persona"] as? String ?? "?"
                    print("  \(String(format: "%02d:%02d", h, m)) [\(p)] \(req.content.body)")
                }
            }
            print("═══════════════════════════════════════")
        }
    }
}
