import UserNotifications
import UIKit
import Foundation
import HealthKit

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermissions() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                self.configureCategories()
                return
            }

            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("❌ Permission error: \(error)")
                }
                if granted {
                    self.configureCategories()
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }

    func configureCategories() {
        ActivityNotificationEngine.shared.registerNotificationCategories()
        CaptainSmartNotificationService.shared.registerNotificationCategories()
    }

    func sendImmediateNotification(body: String, type: String) {
        let content = UNMutableNotificationContent()
        content.title = "AiQo"
        content.body = body
        content.sound = .default
        content.userInfo = ["notification_type": type]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // دالة جديدة لمعالجة البيانات القادمة من الخلفية (اختياري)
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        // إذا كنت تريد تنفيذ شيء معين عند وصول إشعار صامت
        print("Handling remote data: \(userInfo)")
    }

    func handle(response: UNNotificationResponse) {
        guard
            let typeRaw = response.notification.request.content.userInfo["notification_type"] as? String,
            let type = NotificationType(rawValue: typeRaw)
        else { return }
        routeFromNotification(type: type)
    }

    // ✅✅ هاي الدالة الضرورية للـ SceneDelegate
    func handleInitial(response: UNNotificationResponse, window: UIWindow?) {
        guard
            let typeRaw = response.notification.request.content.userInfo["notification_type"] as? String,
            let type = NotificationType(rawValue: typeRaw)
        else { return }
        routeFromNotification(type: type, window: window)
    }

    private func routeFromNotification(type: NotificationType, window: UIWindow? = nil) {
        _ = window // kept for backward compatibility with current callers

        Task { @MainActor in
            switch type {
            case .dailyStepsReminder, .workoutReminder:
                MainTabRouter.shared.navigate(to: .gym)
            case .waterReminder:
                MainTabRouter.shared.navigate(to: .kitchen)
            case .checkInReminder:
                MainTabRouter.shared.navigate(to: .home)
            }
        }
    }
}

// MARK: - Captain Smart Notifications

struct WorkoutCoachingSummary {
    let duration: TimeInterval
    let calories: Double
    let averageHeartRate: Double
    let distanceMeters: Double
    let estimatedSteps: Int
    let workoutType: String

    init(
        duration: TimeInterval,
        calories: Double,
        averageHeartRate: Double,
        distanceMeters: Double,
        estimatedSteps: Int,
        workoutType: String = "Workout"
    ) {
        self.duration = duration
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.distanceMeters = distanceMeters
        self.estimatedSteps = estimatedSteps
        self.workoutType = workoutType
    }
}

final class CaptainSmartNotificationService {
    static let shared = CaptainSmartNotificationService()

    static let categoryIdentifier = "aiqo.captain.smart"
    private let intelligenceManager = CaptainIntelligenceManager.shared
    private let defaults = UserDefaults.standard
    private let lastInactivitySentAtKey = "aiqo.captain.lastInactivitySentAt"
    private let inactivityCooldownSeconds: TimeInterval = 45 * 60

    private init() {}

    func registerNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_CAPTAIN",
            title: "Open Captain",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func evaluateInactivityAndNotifyIfNeeded() async {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let inactivityMinutes = InactivityTracker.shared.currentInactivityMinutes
        guard inactivityMinutes >= 45 else { return }
        guard canSendInactivityNow() else { return }

        let currentSteps = HealthKitManager.shared.todaySteps
        let message = await generateInactivityMessage(currentSteps: currentSteps)

        sendCaptainNotification(
            title: "Captain Hamoudi",
            body: message,
            type: "inactivity",
            messageText: message
        )
        defaults.set(Date(), forKey: lastInactivitySentAtKey)
    }

    func handleWorkoutCompleted(summary: WorkoutCoachingSummary) async {
        await AIWorkoutSummaryService.shared.handleWorkoutEnded(
            workoutType: summary.workoutType,
            duration: summary.duration,
            keyMetrics: [
                "calories": summary.calories,
                "averageHeartRate": summary.averageHeartRate,
                "distanceKm": summary.distanceMeters / 1000.0,
                "estimatedSteps": Double(summary.estimatedSteps)
            ],
            endedAt: Date()
        )
    }

    private func canSendInactivityNow() -> Bool {
        guard let last = defaults.object(forKey: lastInactivitySentAtKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= inactivityCooldownSeconds
    }

    private func sendCaptainNotification(title: String, body: String, type: String, messageText: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "notification_type": type,
            "source": "captain_hamoudi",
            "messageText": messageText,
            "deepLink": "aiqo://captain"
        ]

        let request = UNNotificationRequest(
            identifier: "aiqo.captain.smart.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func generateInactivityMessage(currentSteps: Int) async -> String {
        let prompt = """
        User inactivity alert context:
        - Current steps today: \(max(0, currentSteps))
        - The user has been inactive for at least 45 minutes.
        Provide one short Iraqi Arabic motivational line (max 14 words) with one concrete next action.
        """

        do {
            let message = try await intelligenceManager.generateCaptainResponse(for: prompt)
            let compact = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !compact.isEmpty {
                return compact
            }
        } catch {
            // Fall back to deterministic local text.
        }

        if currentSteps < 2000 {
            return "يلا بطل، قوم هسه وخلي أول ألف خطوة باسمك اليوم."
        } else if currentSteps < 6000 {
            return "ممتاز، كمل نفس الهمة وخل نرفعها شوي شوي."
        } else {
            return "عفية عليك، تقدمك واضح اليوم، استمر وخليها عادة."
        }
    }
}

enum CoachNotificationLanguage: String, CaseIterable {
    case arabic = "ar"
    case english = "en"

    init(preferenceValue: String?) {
        let normalized = preferenceValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch normalized {
        case "en", "english":
            self = .english
        case "ar", "arabic":
            self = .arabic
        default:
            self = .arabic
        }
    }
}

@MainActor
final class AIWorkoutSummaryService {
    static let shared = AIWorkoutSummaryService()

    private let healthStore = HKHealthStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let intelligenceManager = CaptainIntelligenceManager.shared

    private let workoutAnchorKey = "aiqo.ai.workout.anchor"
    private let processedWorkoutIDsKey = "aiqo.ai.workout.processed.ids"
    private let processedWorkoutLimit = 220
    private let fingerprintWindowSeconds: TimeInterval = 180
    private let fingerprintLimit = 40

    private var workoutObserverQuery: HKObserverQuery?
    private var workoutAnchor: HKQueryAnchor?
    private var processedWorkoutIDs: [String] = []
    private var recentFingerprints: [String: Date] = [:]
    private var isMonitoring = false
    private var isSyncing = false
    private var pendingSync = false

    private init() {
        processedWorkoutIDs = defaults.stringArray(forKey: processedWorkoutIDsKey) ?? []
        trimProcessedWorkouts()
        workoutAnchor = loadPersistedAnchor()
    }

    // MARK: - Public API

    func startMonitoringWorkoutEnds() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard await ensureAuthorization() else { return }

        await enableBackgroundDelivery()
        await installWorkoutObserverIfNeeded()
        await syncNewWorkouts()
    }

    func handleWorkoutEnded(
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double],
        endedAt: Date,
        workoutID: String? = nil
    ) async {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        if let workoutID {
            guard !processedWorkoutIDs.contains(workoutID) else { return }
            markProcessedWorkout(id: workoutID)
        }

        let fingerprint = buildFingerprint(
            workoutType: workoutType,
            duration: duration,
            keyMetrics: keyMetrics,
            endedAt: endedAt
        )
        guard !shouldSkipFingerprint(fingerprint, endedAt: endedAt) else { return }

        let language = preferredLanguage()
        let prompt = buildPrompt(
            language: language,
            workoutType: workoutType,
            duration: duration,
            keyMetrics: keyMetrics
        )

        let rawMessage: String
        do {
            rawMessage = try await intelligenceManager.generateCaptainResponse(for: prompt)
        } catch {
            rawMessage = fallbackMessage(
                language: language,
                workoutType: workoutType,
                duration: duration,
                keyMetrics: keyMetrics
            )
        }

        let finalMessage = normalizedToTwentyWords(
            rawMessage,
            language: language,
            workoutType: workoutType,
            duration: duration,
            keyMetrics: keyMetrics
        )

        scheduleWorkoutSummaryNotification(message: finalMessage)
    }

    // MARK: - Workout Monitoring

    private func installWorkoutObserverIfNeeded() async {
        guard !isMonitoring else { return }

        let type = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
            guard let self else {
                completion()
                return
            }

            Task {
                await self.syncNewWorkouts()
                completion()
            }
        }

        workoutObserverQuery = query
        healthStore.execute(query)
        isMonitoring = true
    }

    private func syncNewWorkouts() async {
        if isSyncing {
            pendingSync = true
            return
        }
        isSyncing = true

        repeat {
            pendingSync = false

            let (workouts, newAnchor) = await fetchAnchoredWorkouts(anchor: workoutAnchor)
            if let newAnchor {
                workoutAnchor = newAnchor
                persistAnchor(newAnchor)
            }

            let sorted = workouts.sorted { $0.endDate < $1.endDate }
            for workout in sorted {
                let keyMetrics = await buildKeyMetrics(for: workout)
                await handleWorkoutEnded(
                    workoutType: Self.workoutTitle(for: workout.workoutActivityType),
                    duration: workout.duration,
                    keyMetrics: keyMetrics,
                    endedAt: workout.endDate,
                    workoutID: workout.uuid.uuidString
                )
            }
        } while pendingSync

        isSyncing = false
    }

    private func fetchAnchoredWorkouts(anchor: HKQueryAnchor?) async -> ([HKWorkout], HKQueryAnchor?) {
        await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKObjectType.workoutType(),
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: (workouts, newAnchor))
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Metrics & Prompting

    private func buildKeyMetrics(for workout: HKWorkout) async -> [String: Double] {
        let calories = totalActiveCalories(for: workout)
        let distanceKm = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000.0
        let samples = await fetchHeartRateSamples(start: workout.startDate, end: workout.endDate)
        let zoneBounds = resolveZoneBounds()

        var belowSeconds = 0.0
        var zone2Seconds = 0.0
        var peakSeconds = 0.0

        if samples.isEmpty {
            let avg = averageHeartRate(for: workout, samples: [])
            let safeDuration = max(workout.duration, 1)
            if avg < zoneBounds.lower {
                belowSeconds = safeDuration
            } else if avg <= zoneBounds.upper {
                zone2Seconds = safeDuration
            } else {
                peakSeconds = safeDuration
            }
        } else {
            let sorted = samples.sorted { $0.startDate < $1.startDate }
            for index in sorted.indices {
                let sample = sorted[index]
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let nextDate = index < sorted.count - 1 ? sorted[index + 1].startDate : workout.endDate
                let segmentSeconds = max(1, min(nextDate.timeIntervalSince(sample.startDate), 20))

                if bpm < zoneBounds.lower {
                    belowSeconds += segmentSeconds
                } else if bpm <= zoneBounds.upper {
                    zone2Seconds += segmentSeconds
                } else {
                    peakSeconds += segmentSeconds
                }
            }
        }

        let trackedSeconds = max(1, belowSeconds + zone2Seconds + peakSeconds)
        let averageHR = averageHeartRate(for: workout, samples: samples)

        return [
            "calories": calories,
            "distanceKm": distanceKm,
            "averageHeartRate": averageHR,
            "belowPercent": (belowSeconds / trackedSeconds) * 100,
            "zone2Percent": (zone2Seconds / trackedSeconds) * 100,
            "peakPercent": (peakSeconds / trackedSeconds) * 100,
            "belowMinutes": belowSeconds / 60,
            "zone2Minutes": zone2Seconds / 60,
            "peakMinutes": peakSeconds / 60
        ]
    }

    private func totalActiveCalories(for workout: HKWorkout) -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let sumQuantity = workout.statistics(for: energyType)?.sumQuantity() else {
            return 0
        }
        return sumQuantity.doubleValue(for: .kilocalorie())
    }

    private func averageHeartRate(for workout: HKWorkout, samples: [HKQuantitySample]) -> Double {
        let unit = HKUnit.count().unitDivided(by: .minute())
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let avgQuantity = workout.statistics(for: heartRateType)?.averageQuantity() {
            return avgQuantity.doubleValue(for: unit)
        }

        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0.0) { partial, sample in
            partial + sample.quantity.doubleValue(for: unit)
        }
        return sum / Double(samples.count)
    }

    private func fetchHeartRateSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func resolveZoneBounds() -> (lower: Double, upper: Double) {
        var age = UserProfileStore.shared.current.age
        if !(13...100).contains(age), let birthDate = UserProfileStore.shared.current.birthDate {
            age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
        }
        if !(13...100).contains(age) {
            age = 30
        }

        let maxHeartRate = max(100, 220 - age)
        let lower = Double(maxHeartRate) * 0.60
        let upper = Double(maxHeartRate) * 0.70
        return (lower, upper)
    }

    private func buildPrompt(
        language: CoachNotificationLanguage,
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double]
    ) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        let calories = Int((keyMetrics["calories"] ?? 0).rounded())
        let averageHR = Int((keyMetrics["averageHeartRate"] ?? 0).rounded())
        let zone2 = Int((keyMetrics["zone2Percent"] ?? 0).rounded())
        let below = Int((keyMetrics["belowPercent"] ?? 0).rounded())
        let peak = Int((keyMetrics["peakPercent"] ?? 0).rounded())
        let distance = String(format: "%.2f", keyMetrics["distanceKm"] ?? 0)

        if language == .arabic {
            let direction: String
            if zone2 >= 55 {
                direction = "إذا قضى معظم الوقت في Zone 2 امدحه."
            } else if peak >= 35 {
                direction = "إذا دفع النبض فوق الحد كثيراً شجعه يهدّي الإيقاع."
            } else {
                direction = "شجعه يثبت الإيقاع ويرفع الجودة بالحصة الجاية."
            }

            return """
            أنت كابتن حمودي. اكتب ملخص تحفيزي باللهجة العراقية من 20 كلمة بالضبط، جملة واحدة فقط.
            بيانات التمرين:
            النوع: \(workoutType)
            المدة: \(minutes) دقيقة
            السعرات: \(calories)
            معدل النبض: \(averageHR) bpm
            المسافة: \(distance) كم
            توزيع النبض: تحت \(below)% | زون2 \(zone2)% | فوق/بيك \(peak)%
            \(direction)
            ممنوع الهاشتاك والإيموجي.
            """
        }

        let direction: String
        if zone2 >= 55 {
            direction = "Praise their pacing because they stayed mostly in Zone 2."
        } else if peak >= 35 {
            direction = "Encourage better control because they pushed too hard for too long."
        } else {
            direction = "Encourage steady progression and cleaner pacing next session."
        }

        return """
        You are Captain Hamoudi. Write exactly 20 words in English, one sentence only.
        Workout data:
        Type: \(workoutType)
        Duration: \(minutes) minutes
        Calories: \(calories)
        Average HR: \(averageHR) bpm
        Distance: \(distance) km
        HR zones: Below \(below)% | Zone2 \(zone2)% | Peak/Above \(peak)%
        \(direction)
        No hashtags and no emoji.
        """
    }

    private func fallbackMessage(
        language: CoachNotificationLanguage,
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double]
    ) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        let zone2 = keyMetrics["zone2Percent"] ?? 0
        let peak = keyMetrics["peakPercent"] ?? 0

        if language == .arabic {
            if zone2 >= 55 {
                return "عفية بطل، تمرين \(workoutType) لمدة \(minutes) دقيقة كان موزون جداً بالزون تو، كمل بنفس الثبات والنتائج راح تصعد بسرعة."
            }
            if peak >= 35 {
                return "قوي يا بطل، تمرين \(workoutType) \(minutes) دقيقة كان حماسي، المرة الجاية هدي النفس شوي حتى تحافظ على جودة أعلى."
            }
            return "ممتاز يا بطل، تمرين \(workoutType) \(minutes) دقيقة نظيف، استمر بنفس الإيقاع وزيد الجودة تدريجياً وبذكاء بالحصة الجاية."
        }

        if zone2 >= 55 {
            return "Strong work on \(workoutType), \(minutes) minutes with excellent Zone 2 control. Keep this rhythm and your engine gets stronger."
        }
        if peak >= 35 {
            return "Powerful \(workoutType) session for \(minutes) minutes. Next round, control surges better so intensity stays productive and recovery improves faster."
        }
        return "Solid \(workoutType) effort for \(minutes) minutes. Stay consistent, pace smartly, and stack quality sessions to unlock bigger performance gains."
    }

    private func normalizedToTwentyWords(
        _ text: String,
        language: CoachNotificationLanguage,
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double]
    ) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var words = compact.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count < 8 {
            words = fallbackMessage(
                language: language,
                workoutType: workoutType,
                duration: duration,
                keyMetrics: keyMetrics
            ).split(whereSeparator: \.isWhitespace).map(String.init)
        }

        if words.count > 20 {
            words = Array(words.prefix(20))
        } else if words.count < 20 {
            let fillers = language == .arabic
                ? ["عفية", "استمر", "بثبات", "وتنفس", "أقوى"]
                : ["keep", "steady", "strong", "and", "focused"]
            var index = 0
            while words.count < 20 {
                words.append(fillers[index % fillers.count])
                index += 1
            }
        }

        return words.joined(separator: " ")
    }

    private func scheduleWorkoutSummaryNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "كابتن حمودي 🫡"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = CaptainSmartNotificationService.categoryIdentifier
        content.userInfo = [
            "notification_type": "workout_complete",
            "source": "captain_hamoudi",
            "messageText": message,
            "deepLink": "aiqo://captain"
        ]

        let request = UNNotificationRequest(
            identifier: "aiqo.captain.workout.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        notificationCenter.add(request)
    }

    // MARK: - Dedup

    private func markProcessedWorkout(id: String) {
        guard !processedWorkoutIDs.contains(id) else { return }
        processedWorkoutIDs.append(id)
        trimProcessedWorkouts()
        defaults.set(processedWorkoutIDs, forKey: processedWorkoutIDsKey)
    }

    private func trimProcessedWorkouts() {
        if processedWorkoutIDs.count > processedWorkoutLimit {
            processedWorkoutIDs = Array(processedWorkoutIDs.suffix(processedWorkoutLimit))
        }
    }

    private func buildFingerprint(
        workoutType: String,
        duration: TimeInterval,
        keyMetrics: [String: Double],
        endedAt: Date
    ) -> String {
        let minuteBucket = Int(endedAt.timeIntervalSince1970 / 60)
        let calories = Int((keyMetrics["calories"] ?? 0).rounded())
        let avgHR = Int((keyMetrics["averageHeartRate"] ?? 0).rounded())
        let zone2 = Int((keyMetrics["zone2Percent"] ?? 0).rounded())
        let peak = Int((keyMetrics["peakPercent"] ?? 0).rounded())
        let seconds = Int(duration.rounded())
        return "\(workoutType.lowercased())|\(seconds)|\(calories)|\(avgHR)|\(zone2)|\(peak)|\(minuteBucket)"
    }

    private func shouldSkipFingerprint(_ fingerprint: String, endedAt: Date) -> Bool {
        recentFingerprints = recentFingerprints.filter {
            abs(endedAt.timeIntervalSince($0.value)) <= fingerprintWindowSeconds
        }

        if let last = recentFingerprints[fingerprint],
           abs(endedAt.timeIntervalSince(last)) <= fingerprintWindowSeconds {
            return true
        }

        recentFingerprints[fingerprint] = endedAt
        if recentFingerprints.count > fingerprintLimit {
            let sorted = recentFingerprints.sorted { $0.value > $1.value }
            recentFingerprints = Dictionary(
                uniqueKeysWithValues: sorted.prefix(fingerprintLimit).map { ($0.key, $0.value) }
            )
        }
        return false
    }

    // MARK: - Auth & Background

    private func ensureAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return false
        }

        let readTypes: Set<HKObjectType> = [HKObjectType.workoutType(), heartRateType]
        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
            return true
        } catch {
            return false
        }
    }

    private func enableBackgroundDelivery() async {
        await withCheckedContinuation { continuation in
            healthStore.enableBackgroundDelivery(
                for: HKObjectType.workoutType(),
                frequency: .immediate
            ) { _, _ in
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Persistence

    private func persistAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
            return
        }
        defaults.set(data, forKey: workoutAnchorKey)
    }

    private func loadPersistedAnchor() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: workoutAnchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    // MARK: - Utilities

    private func preferredLanguage() -> CoachNotificationLanguage {
        if let raw = defaults.string(forKey: "notificationLanguage") {
            return CoachNotificationLanguage(preferenceValue: raw)
        }

        let legacyRaw = NotificationPreferencesStore.shared.language.rawValue
        return CoachNotificationLanguage(preferenceValue: legacyRaw)
    }

    private static func workoutTitle(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Functional Strength"
        case .coreTraining: return "Core"
        default: return "Workout"
        }
    }
}
