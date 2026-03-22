import Foundation
import Intents
import UIKit

/// يدير Siri Shortcuts — يخلي المستخدم يتحكم بالتطبيق بالصوت
/// مثال: "يا سيري، ابدأ تمرين مشي" أو "يا سيري، شنو تقدمي اليوم"
@MainActor
final class SiriShortcutsManager {
    static let shared = SiriShortcutsManager()

    private init() {}

    // MARK: - Activity Types

    enum ActivityType: String {
        case startWalk = "com.aiqo.startWalk"
        case startRun = "com.aiqo.startRun"
        case startHIIT = "com.aiqo.startHIIT"
        case openCaptain = "com.aiqo.openCaptain"
        case todaySummary = "com.aiqo.todaySummary"
        case logWater = "com.aiqo.logWater"
        case openKitchen = "com.aiqo.openKitchen"
        case weeklyReport = "com.aiqo.weeklyReport"
    }

    // MARK: - Donate Shortcuts

    /// يسجّل كل الـ shortcuts المتاحة — ينادى عند فتح التطبيق
    func donateAllShortcuts() {
        donateStartWorkout(type: .startWalk, title: "ابدأ تمرين مشي", suggestedPhrase: "ابدأ مشي")
        donateStartWorkout(type: .startRun, title: "ابدأ تمرين جري", suggestedPhrase: "ابدأ جري")
        donateStartWorkout(type: .startHIIT, title: "ابدأ تمرين HIIT", suggestedPhrase: "ابدأ تمرين")
        donateActivity(type: .openCaptain, title: "تكلم مع كابتن حمّودي", suggestedPhrase: "كابتن حمودي")
        donateActivity(type: .todaySummary, title: "ملخص اليوم", suggestedPhrase: "شنو تقدمي")
        donateActivity(type: .logWater, title: "سجّل ماء", suggestedPhrase: "سجل ماء")
        donateActivity(type: .openKitchen, title: "افتح المطبخ", suggestedPhrase: "افتح المطبخ")
        donateActivity(type: .weeklyReport, title: "التقرير الأسبوعي", suggestedPhrase: "تقرير الأسبوع")
    }

    // MARK: - Handle Shortcut

    /// يتعامل مع الـ shortcut لما المستخدم يستخدمه
    func handle(activity: NSUserActivity) -> Bool {
        guard let activityType = ActivityType(rawValue: activity.activityType) else { return false }

        switch activityType {
        case .startWalk:
            NotificationCenter.default.post(name: .siriStartWorkout, object: "walking")
            return true

        case .startRun:
            NotificationCenter.default.post(name: .siriStartWorkout, object: "running")
            return true

        case .startHIIT:
            NotificationCenter.default.post(name: .siriStartWorkout, object: "hiit")
            return true

        case .openCaptain:
            AppRootManager.shared.openCaptainChat()
            return true

        case .todaySummary:
            MainTabRouter.shared.navigate(to: .home)
            return true

        case .logWater:
            Task {
                try? await HealthKitService.shared.logWater(ml: 250)
            }
            return true

        case .openKitchen:
            MainTabRouter.shared.navigate(to: .kitchen)
            return true

        case .weeklyReport:
            NotificationCenter.default.post(name: .siriOpenWeeklyReport, object: nil)
            return true
        }
    }

    // MARK: - Private

    private func donateActivity(type: ActivityType, title: String, suggestedPhrase: String) {
        let activity = NSUserActivity(activityType: type.rawValue)
        activity.title = title
        activity.suggestedInvocationPhrase = suggestedPhrase
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = type.rawValue

        // CSSearchableItemAttributeSet لنتائج البحث
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = title
        attributes.contentDescription = "AiQo - \(title)"
        activity.contentAttributeSet = attributes

        // نسجّل النشاط
        activity.becomeCurrent()
    }

    private func donateStartWorkout(type: ActivityType, title: String, suggestedPhrase: String) {
        donateActivity(type: type, title: title, suggestedPhrase: suggestedPhrase)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let siriStartWorkout = Notification.Name("aiqo.siri.startWorkout")
    static let siriOpenWeeklyReport = Notification.Name("aiqo.siri.openWeeklyReport")
}

// MARK: - CSSearchableItemAttributeSet Import

import CoreSpotlight
