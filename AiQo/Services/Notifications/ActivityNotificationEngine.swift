//
//  ActivityNotificationEngine.swift
//  AiQo - Smart Angel Numbers Notification Engine
//
//  📍 Location: Services > Notifications
//
//  🎯 Sniper Logic: 3 random times per day (different from yesterday)
//  ⏰ Smart Spacing: Each notification is far from the others
//  ✨ Dynamic Content based on time
//  🔗 Deep Linking to Captain Screen
//

import Foundation
import UserNotifications

final class ActivityNotificationEngine {

    static let shared = ActivityNotificationEngine()
    private init() {}

    #if DEBUG
    private let isNotificationDebugMode = true
    #else
    private let isNotificationDebugMode = false
    #endif

    // MARK: - Storage Keys
    
    private let lastProgressKey = "aiqo.activity.lastProgress"
    private let lastGoalCompletedDateKey = "aiqo.activity.lastGoalCompletedDate"
    private let lastAlmostThereDateKey = "aiqo.activity.lastAlmostThereDate"
    private let lastAlmostThereMilestoneKey = "aiqo.activity.lastAlmostThereMilestone"
    private let selectedAngelTimesKey = "aiqo.activity.selectedAngelTimes"
    private let lastScheduleDateKey = "aiqo.activity.lastScheduleDate"
    private let yesterdayTimesKey = "aiqo.activity.yesterdayTimes"  // ✅ جديد: حفظ أوقات أمس
    
    // MARK: - Notification Category & Actions
    
    static let categoryIdentifier = "CAPTAIN_ANGEL_REMINDER"
    static let actionOpenChat = "OPEN_CAPTAIN_CHAT"
    static var notificationCategory: UNNotificationCategory {
        let openChatAction = UNNotificationAction(
            identifier: Self.actionOpenChat,
            title: NSLocalizedString("فتح المحادثة", comment: "Open chat action"),
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openChatAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }
    
    // MARK: - Angel Numbers Configuration
    
    /// ✅ الأوقات المحددة فقط
    private let allAngelNumberTimes: [(hour: Int, minute: Int)] = [
        (1, 11),   // 01:11
        (2, 22),   // 02:22
        (3, 33),   // 03:33
        (4, 44),   // 04:44
        (5, 55),   // 05:55
        (10, 10),  // 10:10
        (11, 11),  // 11:11 ⭐
        (12, 12),  // 12:12
        (12, 21),  // 12:21
    ]
    
    /// تحويل الوقت لدقائق من بداية اليوم
    private func toMinutes(_ time: (hour: Int, minute: Int)) -> Int {
        return time.hour * 60 + time.minute
    }
    
    /// حساب الفرق بين وقتين بالدقائق
    private func timeDifference(_ time1: (hour: Int, minute: Int), _ time2: (hour: Int, minute: Int)) -> Int {
        return abs(toMinutes(time1) - toMinutes(time2))
    }
    
    // MARK: - 🎯 Smart Selection: 3 Times with Maximum Spacing
    
    /// اختيار 3 أوقات متباعدة ومختلفة عن أمس
    private func selectSmartAngelTimes() -> [(hour: Int, minute: Int)] {
        var availableTimes = allAngelNumberTimes
        
        // 1. استبعاد أوقات أمس
        let yesterdayTimes = getYesterdayTimes()
        if !yesterdayTimes.isEmpty {
            availableTimes = availableTimes.filter { time in
                !yesterdayTimes.contains(where: { $0.hour == time.hour && $0.minute == time.minute })
            }
            print("📅 [AiQo] Excluded yesterday's times: \(yesterdayTimes.map { "\($0.hour):\(String(format: "%02d", $0.minute))" })")
        }
        
        // 2. إذا ما بقى أوقات كافية، نرجع للقائمة الكاملة
        if availableTimes.count < 3 {
            availableTimes = allAngelNumberTimes
            print("⚠️ [AiQo] Not enough times after exclusion, using full list")
        }
        
        // 3. اختيار 3 أوقات متباعدة
        let selected = selectSpacedTimes(from: availableTimes, count: 3)
        
        // 4. حفظ الأوقات المختارة كـ "أوقات أمس" للغد
        saveYesterdayTimes(selected)
        
        return selected
    }
    
    /// اختيار أوقات متباعدة قدر الإمكان
    private func selectSpacedTimes(from times: [(hour: Int, minute: Int)], count: Int) -> [(hour: Int, minute: Int)] {
        guard times.count >= count else { return times }
        
        // ترتيب الأوقات
        let sortedTimes = times.sorted { toMinutes($0) < toMinutes($1) }
        
        var bestCombination: [(hour: Int, minute: Int)] = []
        var bestMinSpacing = 0
        
        // تجربة كل التوليفات للحصول على أفضل تباعد
        let indices = Array(0..<sortedTimes.count)
        let combinations = generateCombinations(indices, count: count)
        
        for combo in combinations {
            let selectedTimes = combo.map { sortedTimes[$0] }
            let minSpacing = calculateMinSpacing(selectedTimes)
            
            if minSpacing > bestMinSpacing {
                bestMinSpacing = minSpacing
                bestCombination = selectedTimes
            }
        }
        
        print("🎯 [AiQo] Best spacing: \(bestMinSpacing) minutes between notifications")
        
        return bestCombination.sorted { toMinutes($0) < toMinutes($1) }
    }
    
    /// حساب أقل مسافة بين الأوقات المختارة
    private func calculateMinSpacing(_ times: [(hour: Int, minute: Int)]) -> Int {
        guard times.count >= 2 else { return Int.max }
        
        let sorted = times.sorted { toMinutes($0) < toMinutes($1) }
        var minSpacing = Int.max
        
        for i in 0..<(sorted.count - 1) {
            let spacing = timeDifference(sorted[i], sorted[i + 1])
            minSpacing = min(minSpacing, spacing)
        }
        
        return minSpacing
    }
    
    /// توليد كل التوليفات الممكنة
    private func generateCombinations(_ array: [Int], count: Int) -> [[Int]] {
        guard count > 0 else { return [[]] }
        guard !array.isEmpty else { return [] }
        
        if count == 1 {
            return array.map { [$0] }
        }
        
        var result: [[Int]] = []
        for (index, element) in array.enumerated() {
            let remaining = Array(array[(index + 1)...])
            let subCombinations = generateCombinations(remaining, count: count - 1)
            for var combo in subCombinations {
                combo.insert(element, at: 0)
                result.append(combo)
            }
        }
        return result
    }
    
    // MARK: - Yesterday Times Management
    
    private func saveYesterdayTimes(_ times: [(hour: Int, minute: Int)]) {
        let data = times.map { ["hour": $0.hour, "minute": $0.minute] }
        UserDefaults.standard.set(data, forKey: yesterdayTimesKey)
    }
    
    private func getYesterdayTimes() -> [(hour: Int, minute: Int)] {
        guard let data = UserDefaults.standard.array(forKey: yesterdayTimesKey) as? [[String: Int]] else {
            return []
        }
        return data.compactMap { dict in
            guard let hour = dict["hour"], let minute = dict["minute"] else { return nil }
            return (hour, minute)
        }
    }
    
    // MARK: - Storage Functions
    
    private func saveSelectedTimes(_ times: [(hour: Int, minute: Int)]) {
        let data = times.map { ["hour": $0.hour, "minute": $0.minute] }
        UserDefaults.standard.set(data, forKey: selectedAngelTimesKey)
        UserDefaults.standard.set(Date(), forKey: lastScheduleDateKey)
    }
    
    private func getSavedSelectedTimes() -> [(hour: Int, minute: Int)]? {
        guard let data = UserDefaults.standard.array(forKey: selectedAngelTimesKey) as? [[String: Int]] else {
            return nil
        }
        return data.compactMap { dict in
            guard let hour = dict["hour"], let minute = dict["minute"] else { return nil }
            return (hour, minute)
        }
    }
    
    private func hasScheduledToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastScheduleDateKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastDate)
    }
    
    // MARK: - ✨ Dynamic Content Based on Time
    
    func generateAngelMessage(hour: Int, minute: Int, language: ActivityNotificationLanguage) -> (title: String, body: String) {
        let timeString = String(format: "%d:%02d", hour, minute)
        
        switch (hour, minute) {
        case (1, 11):
            return language == .arabic
                ? ("بداية جديدة 🌙", "الساعة 1:11.. وقت البدايات الجديدة!")
                : ("New Beginning 🌙", "1:11.. Time for new beginnings!")
            
        case (2, 22):
            return language == .arabic
                ? ("توازن الليل ⚖️", "الساعة 2:22.. وقت التوازن والسكينة")
                : ("Night Balance ⚖️", "2:22.. Time for balance and peace")
            
        case (3, 33):
            return language == .arabic
                ? ("طاقة إيجابية ✨", "الساعة 3:33.. الكون يرسلك طاقة!")
                : ("Positive Energy ✨", "3:33.. The universe sends you energy!")
            
        case (4, 44):
            return language == .arabic
                ? ("حماية ملائكية 👼", "الساعة 4:44.. الملائكة معاك!")
                : ("Angelic Protection 👼", "4:44.. Angels are with you!")
            
        case (5, 55):
            return language == .arabic
                ? ("تغيير قادم 🔄", "الساعة 5:55.. استعد للتغيير!")
                : ("Change Coming 🔄", "5:55.. Get ready for change!")
            
        case (10, 10):
            return language == .arabic
                ? ("صباح النشاط 🌅", "الساعة 10:10.. أحلى وقت للحركة!")
                : ("Active Morning 🌅", "10:10.. Perfect time to move!")
            
        case (11, 11):
            return language == .arabic
                ? ("وقت الأمنية ✨", "الساعة 11:11.. اتمنّى أمنية وتحرّك! 🌟")
                : ("Make a Wish ✨", "It's 11:11.. Make a wish and move! 🌟")
            
        case (12, 12):
            return language == .arabic
                ? ("منتصف اليوم ☀️", "الساعة 12:12.. نص اليوم راح، تحرّكت؟")
                : ("Midday Check ☀️", "12:12.. Half the day is gone, did you move?")
            
        case (12, 21):
            return language == .arabic
                ? ("انعكاس الطاقة 🔮", "الساعة 12:21.. وقت التأمل والحركة!")
                : ("Energy Mirror 🔮", "12:21.. Time for reflection and movement!")
            
        default:
            let arabicMessages = [
                "الساعة \(timeString).. وقت الانسجام والحركة! 💫",
                "\(timeString) - رقم ملائكي! قوم تحرّك 🚶‍♂️",
                "الساعة \(timeString).. الكون يذكّرك تتحرك! ✨"
            ]
            
            let englishMessages = [
                "It's \(timeString).. Alignment time, move! 💫",
                "\(timeString) - Angel number! Time to move 🚶‍♂️",
                "It's \(timeString).. Universe reminder to move! ✨"
            ]
            
            let messages = language == .arabic ? arabicMessages : englishMessages
            let body = messages.randomElement() ?? messages[0]
            let title = language == .arabic ? "تحرّك الآن" : "Move Now"
            
            return (title, body)
        }
    }
    
    // MARK: - 🔗 Deep Linking Setup
    
    func registerNotificationCategories() {
        NotificationCategoryManager.shared.registerAllCategories()
        print("✅ [AiQo] Notification categories registered")
    }
    
    // MARK: - Main Scheduling Function
    
    func scheduleAngelNumberNotifications(
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) {
        // منع الجدولة المتكررة في نفس اليوم
        if hasScheduledToday(), !isNotificationDebugMode {
            print("👼 [AiQo] Already scheduled today, skipping...")
            if let savedTimes = getSavedSelectedTimes() {
                print("📅 [AiQo] Today's times: \(savedTimes.map { "\($0.hour):\(String(format: "%02d", $0.minute))" })")
            }
            return
        }
        
        // إلغاء الإشعارات السابقة
        cancelAllScheduledAngelNotifications()
        
        // 🎯 اختيار 3 أوقات ذكية (متباعدة ومختلفة عن أمس)
        let selectedTimes = selectSmartAngelTimes()
        saveSelectedTimes(selectedTimes)
        
        print("🎯 [AiQo] Smart Selection: \(selectedTimes.map { "\($0.hour):\(String(format: "%02d", $0.minute))" })")
        
        let now = Date()
        let calendar = Calendar.current
        var scheduledCount = 0
        
        for time in selectedTimes {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0
            
            guard let scheduledDate = calendar.date(from: components) else { continue }
            
            // إذا الوقت فات، جدوله لباجر
            let finalDate: Date
            if scheduledDate <= now {
                finalDate = calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? scheduledDate
                print("⏭️ [AiQo] Time passed, scheduling for tomorrow: \(time.hour):\(String(format: "%02d", time.minute))")
            } else {
                finalDate = scheduledDate
            }
            
            scheduleAngelNotification(
                at: finalDate,
                hour: time.hour,
                minute: time.minute,
                gender: gender,
                language: language
            )
            scheduledCount += 1
        }
        
        print("✅ [AiQo] Scheduled \(scheduledCount) angel notifications")
    }
    
    private func scheduleAngelNotification(
        at date: Date,
        hour: Int,
        minute: Int,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) {
        let content = UNMutableNotificationContent()
        
        let (title, body) = generateAngelMessage(hour: hour, minute: minute, language: language)
        
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        
        content.userInfo = [
            "type": "angelNumber",
            "scheduledTime": date.timeIntervalSince1970,
            "hour": hour,
            "minute": minute,
            "messageText": body,
            "deepLink": "aiqo://captain",
            "source": "captain_hamoudi"
        ]
        
        let calendar = Calendar.current
        let triggerComponents = calendar.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let identifier = "aiqo.angel.\(hour).\(minute)"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [AiQo] Failed to schedule: \(error)")
            } else {
                print("✅ [AiQo] Scheduled: \(hour):\(String(format: "%02d", minute)) - \"\(title)\"")
            }
        }
    }
    
    func cancelAllScheduledAngelNotifications() {
        let identifiers = allAngelNumberTimes.map { "aiqo.angel.\($0.hour).\($0.minute)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ [AiQo] Cancelled all scheduled angel notifications")
    }
    
    // MARK: - Inactivity Check
    
    func shouldDeliverAngelNotification(stepsInLastHour: Int) -> Bool {
        let threshold = isNotificationDebugMode ? 10 : 100
        
        if stepsInLastHour < threshold {
            print("👼 [AiQo] Notification approved - steps: \(stepsInLastHour)")
            return true
        } else {
            print("🚶 [AiQo] Notification skipped - user active with \(stepsInLastHour) steps")
            return false
        }
    }
    
    // MARK: - Original Evaluation Logic
    
    func evaluateAndSendIfNeeded(
        steps: Int,
        calories: Double,
        stepsGoal: Int,
        caloriesGoal: Double,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let inactivityMinutes = InactivityTracker.shared.currentInactivityMinutes
        
        let stepsProgress = getActivityPercentage(current: Double(steps), goal: Double(stepsGoal))
        let caloriesProgress = getActivityPercentage(current: calories, goal: caloriesGoal)
        let progress = max(stepsProgress, caloriesProgress)

        print("📊 [AiQo ENG] Progress: \(String(format: "%.2f", progress)), Inactive: \(inactivityMinutes)m")

        guard let type = getNotificationTypeBasedOnProgress(
            progress: progress,
            inactivityMinutes: inactivityMinutes
        ) else { return }

        if type == .moveNow {
            print("⏰ [AiQo] moveNow handled by Angel Numbers")
            return
        }

        if type == .goalCompleted, hasSentGoalCompletedToday() { return }
        if type == .almostThere, !shouldSendAlmostThere(progress: progress) { return }

        guard let notification = NotificationRepository.shared.getNotification(
            type: type,
            gender: gender,
            language: language
        ) else { return }

        let title = getShortTitle(for: type, language: language)
        
        print("🚀 [AiQo ENG] Sending: \(notification.text)")
        sendImmediateNotification(title: title, body: notification.text, type: type)

        if type == .goalCompleted {
            markGoalCompletedSent()
        } else if type == .almostThere {
            markAlmostThereSent(progress: progress)
        }
    }
    
    private func sendImmediateNotification(title: String, body: String, type: ActivityNotificationType) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        
        content.userInfo = [
            "type": type.rawValue,
            "messageText": body,
            "deepLink": "aiqo://captain",
            "source": "captain_hamoudi"
        ]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Helper Functions
    
    private func getShortTitle(for type: ActivityNotificationType, language: ActivityNotificationLanguage) -> String {
        switch type {
        case .moveNow:
            return language == .arabic ? "تحرّك الآن" : "Move Now"
        case .almostThere:
            return language == .arabic ? "قريب جداً" : "Almost There"
        case .goalCompleted:
            return language == .arabic ? "مبروك! 🎉" : "Goal Done!"
        }
    }
    
    private func getActivityPercentage(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.5)
    }
    
    private func getNotificationTypeBasedOnProgress(progress: Double, inactivityMinutes: Int) -> ActivityNotificationType? {
        if progress >= 1.0 { return .goalCompleted }
        if progress >= 0.6 && progress < 0.9 { return .almostThere }
        
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: lastProgressKey)
        defaults.set(progress, forKey: lastProgressKey)
        
        let threshold = isNotificationDebugMode ? 2 : 60
        if inactivityMinutes >= threshold, progress <= last {
            return .moveNow
        }
        
        return nil
    }

    private func hasSentGoalCompletedToday() -> Bool {
        guard let date = UserDefaults.standard.object(forKey: lastGoalCompletedDateKey) as? Date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func markGoalCompletedSent() {
        UserDefaults.standard.set(Date(), forKey: lastGoalCompletedDateKey)
    }

    private func shouldSendAlmostThere(progress: Double) -> Bool {
        let milestone = progress >= 0.75 ? 75 : 60
        let defaults = UserDefaults.standard

        guard let lastDate = defaults.object(forKey: lastAlmostThereDateKey) as? Date,
              Calendar.current.isDateInToday(lastDate) else {
            return true
        }

        let lastMilestone = defaults.integer(forKey: lastAlmostThereMilestoneKey)
        return milestone > lastMilestone
    }

    private func markAlmostThereSent(progress: Double) {
        let defaults = UserDefaults.standard
        let milestone = progress >= 0.75 ? 75 : 60
        defaults.set(Date(), forKey: lastAlmostThereDateKey)
        defaults.set(milestone, forKey: lastAlmostThereMilestoneKey)
    }
    
    // MARK: - Debug Utilities
    
    func getSelectedTimesForDebug() -> [(hour: Int, minute: Int)] {
        return getSavedSelectedTimes() ?? []
    }
    
    func getYesterdayTimesForDebug() -> [(hour: Int, minute: Int)] {
        return getYesterdayTimes()
    }
    
    func forceReschedule(gender: ActivityNotificationGender, language: ActivityNotificationLanguage) {
        UserDefaults.standard.removeObject(forKey: lastScheduleDateKey)
        scheduleAngelNumberNotifications(gender: gender, language: language)
    }
    
    func sendTestNotification(language: ActivityNotificationLanguage = .arabic) {
        let (title, body) = generateAngelMessage(hour: 11, minute: 11, language: language)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "type": "angelNumber",
            "messageText": body,
            "deepLink": "aiqo://captain",
            "source": "captain_hamoudi"
        ]
        
        let request = UNNotificationRequest(
            identifier: "aiqo.test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification failed: \(error)")
            } else {
                print("✅ Test notification scheduled in 3 seconds")
            }
        }
    }
    
    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 [AiQo] Pending notifications: \(requests.count)")
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let hour = trigger.dateComponents.hour ?? 0
                    let minute = trigger.dateComponents.minute ?? 0
                    print("  - \(request.identifier): \(hour):\(String(format: "%02d", minute))")
                }
            }
        }
    }
    
    /// طباعة ملخص الجدولة الذكية
    func printSmartSchedulingSummary() {
        print("═══════════════════════════════════════")
        print("📊 [AiQo] Smart Scheduling Summary")
        print("═══════════════════════════════════════")
        print("📅 Yesterday's times: \(getYesterdayTimes().map { "\($0.hour):\(String(format: "%02d", $0.minute))" })")
        print("📅 Today's times: \(getSelectedTimesForDebug().map { "\($0.hour):\(String(format: "%02d", $0.minute))" })")
        printPendingNotifications()
        print("═══════════════════════════════════════")
    }
}
