import SwiftUI
import UserNotifications

#if canImport(WatchKit)
import WatchKit
#else
class WKUserNotificationHostingController<Content: View>: NSObject {
    var body: Content { fatalError("WatchKit is unavailable on this build target.") }
    func didReceive(_ notification: UNNotification) {}
}
#endif

final class WorkoutNotificationController: WKUserNotificationHostingController<WorkoutNotificationView> {
    private var payload: WorkoutNotificationPayload = .placeholder

    override var body: WorkoutNotificationView {
        WorkoutNotificationView(payload: payload)
    }

    override func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let userInfo = content.userInfo
        let type = userInfo["type"] as? String

        if type == WorkoutNotificationCenter.summaryIdentifier {
            let km = userInfo["distanceKm"] as? Double ?? 0
            let elapsed = userInfo["elapsed"] as? Int ?? 0
            let calories = userInfo["calories"] as? Int ?? 0
            let minutes = elapsed / 60
            let calorieGoal = 600
            let minuteGoal = 45
            payload = WorkoutNotificationPayload(
                kind: .summary,
                title: "AiQo",
                subtitle: "Workout summary",
                caloriesText: "\(max(0, calories))/\(calorieGoal)CAL",
                minutesText: "\(max(0, minutes))/\(minuteGoal)MIN",
                distanceText: "\(standHours(from: minutes))/13HRS",
                caloriesProgress: progress(current: Double(calories), goal: Double(calorieGoal)),
                minutesProgress: progress(current: Double(minutes), goal: Double(minuteGoal)),
                distanceProgress: progress(current: Double(standHours(from: minutes)), goal: 13),
                footerText: "TIME \(elapsedString(elapsed))",
                weeklyDistanceText: String(format: "%.2fKM", max(0, km)),
                weeklyProgressPoints: weeklyTrend(fromTotalKm: km),
                weeklyMonthText: monthShort(from: .now)
            )
            return
        }

        let kmMilestone = userInfo["km"] as? Int ?? 0
        let bpm = userInfo["heartRate"] as? Int ?? 0
        let calories = userInfo["calories"] as? Int ?? 0
        let elapsed = userInfo["elapsed"] as? Int ?? 0
        let distanceMeters = userInfo["distanceMeters"] as? Double ?? 0
        let distanceKm = max(0, distanceMeters) / 1000
        let minutes = elapsed / 60
        let calorieGoal = 600
        let minuteGoal = 45
        payload = WorkoutNotificationPayload(
            kind: .milestone,
            title: "AiQo",
            subtitle: "Live workout",
            caloriesText: "\(max(0, calories))/\(calorieGoal)CAL",
            minutesText: "\(max(0, minutes))/\(minuteGoal)MIN",
            distanceText: "\(standHours(from: minutes))/13HRS",
            caloriesProgress: progress(current: Double(calories), goal: Double(calorieGoal)),
            minutesProgress: progress(current: Double(minutes), goal: Double(minuteGoal)),
            distanceProgress: progress(current: Double(standHours(from: minutes)), goal: 13),
            footerText: "\(max(0, bpm)) BPM • \(max(0, kmMilestone)) KM",
            weeklyDistanceText: String(format: "%.2fKM", distanceKm),
            weeklyProgressPoints: weeklyTrend(fromTotalKm: distanceKm),
            weeklyMonthText: monthShort(from: .now)
        )
    }

    private func elapsedString(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func progress(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(current / goal, 0), 1)
    }

    private func standHours(from minutes: Int) -> Int {
        min(13, max(1, Int(round(Double(max(0, minutes)) / 6.0))))
    }

    private func monthShort(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private func weeklyTrend(fromTotalKm totalKm: Double) -> [Double] {
        let safe = max(0.2, totalKm)
        let factors: [Double] = [0.10, 0.16, 0.24, 0.34, 0.52, 0.71, 1.0]
        return factors.map { safe * $0 }
    }
}
