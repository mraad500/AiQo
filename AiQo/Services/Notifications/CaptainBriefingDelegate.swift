import Foundation
import UserNotifications
import UIKit

// MARK: - Captain Briefing Delegate

final class CaptainBriefingDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CaptainBriefingDelegate()

    private let calendar = Calendar.current

    private override init() {
        super.init()
    }

    // MARK: - willPresent (smart-skip + quiet hours + app-open suppression)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let slotRaw = userInfo["slot"] as? String

        // Non-briefing notifications: pass through
        guard let slotRaw, let slot = BriefingSlot(rawValue: slotRaw) else {
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .list, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
            return
        }

        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Rule: Quiet hours (23:00 - 05:00) → list only, no banner/sound
        if hour >= BriefingRules.quietHoursStart || hour < BriefingRules.quietHoursEnd {
            completionHandler([.list])
            return
        }

        // Rule: App-open suppression (within last 60 minutes)
        let settings = BriefingSettingsStore.shared.settings
        if let lastAppOpen = settings.lastAppOpenDate,
           now.timeIntervalSince(lastAppOpen) < Double(BriefingRules.appOpenSuppressionMinutes * 60) {
            completionHandler([]) // Drop silently
            return
        }

        // Rule: Smart skip for Slots 2 & 3 (daily ring >= 100%)
        if slot == .middayPulse || slot == .eveningReflection {
            Task { @MainActor in
                let context = await CaptainBriefingScheduler.shared.buildBriefingContext()
                if context.dailyRingProgress >= BriefingRules.dailyRingCompleteThreshold {
                    completionHandler([]) // Drop silently — user already met goal
                    return
                }

                // Generate real content if needed
                if userInfo["needsContentGeneration"] as? Bool == true {
                    _ = await BriefingContentGenerator.shared.generate(for: slot, context: context)
                    // Update the notification content dynamically is not possible in willPresent,
                    // so we show the placeholder. For fixed-time slots, the content generation
                    // should happen at scheduling time or via notification service extension.
                }

                if #available(iOS 14.0, *) {
                    completionHandler([.banner, .list, .sound, .badge])
                } else {
                    completionHandler([.alert, .sound, .badge])
                }
            }
            return
        }

        // Default: show the notification
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // MARK: - didReceive (notification tap routing)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let notifType = (userInfo["source"] as? String) ?? response.notification.request.identifier

        AnalyticsService.shared.track(.notificationTapped(type: notifType))

        if let source = userInfo["source"] as? String, source == "captain_hamoudi" {
            CaptainNotificationHandler.shared.handleIncomingNotification(userInfo: userInfo)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                CaptainNavigationHelper.shared.navigateToCaptainScreen()
            }
        } else if let source = userInfo["source"] as? String, source == MorningHabitOrchestrator.notificationSource {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AppRootManager.shared.openCaptainChat()
            }
        }

        completionHandler()
    }
}
