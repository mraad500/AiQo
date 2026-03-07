import Foundation
import SwiftUI
import UserNotifications
import ActivityKit
import AppIntents
import AlarmKit

enum AlarmProviderKind: String, Equatable, Sendable {
    case alarmKit
    case notificationFallback
}

struct ScheduledAlarm: Equatable, Sendable {
    let id: String
    let fireDate: Date
    let provider: AlarmProviderKind
}

enum AlarmSaveState: Equatable, Sendable {
    case idle
    case saving
    case saved(message: String)
    case failed(message: String)

    var message: String? {
        switch self {
        case .idle, .saving:
            return nil
        case .saved(let message), .failed(let message):
            return message
        }
    }

    var isSaving: Bool {
        if case .saving = self {
            return true
        }
        return false
    }

    var isSaved: Bool {
        if case .saved = self {
            return true
        }
        return false
    }

    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

enum AlarmSchedulingError: LocalizedError, Equatable {
    case permissionDenied
    case unsupported
    case schedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "تعذر حفظ المنبه لأن الصلاحية غير مفعلة."
        case .unsupported:
            return "حفظ المنبه غير متاح على هذا الإصدار."
        case .schedulingFailed(let message):
            return message
        }
    }
}

@MainActor
protocol AlarmSchedulingService {
    func scheduleWakeAlarm(at wakeDate: Date) async throws -> ScheduledAlarm
}

@MainActor
final class SystemAlarmSchedulingService: AlarmSchedulingService {
    static let shared = SystemAlarmSchedulingService()

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let managedAlarmIdentifierKey = "aiqo.smartwake.managedAlarm.identifier"
    private let managedAlarmProviderKey = "aiqo.smartwake.managedAlarm.provider"

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func scheduleWakeAlarm(at wakeDate: Date) async throws -> ScheduledAlarm {
        let fireDate = normalizedUpcomingDate(from: wakeDate)

        if #available(iOS 26.1, *) {
            return try await scheduleAlarmKitAlarm(at: fireDate)
        } else {
            return try await scheduleNotificationAlarm(at: fireDate)
        }
    }

    private func normalizedUpcomingDate(from wakeDate: Date) -> Date {
        let now = Date()
        guard wakeDate <= now.addingTimeInterval(30) else { return wakeDate }

        let components = calendar.dateComponents([.hour, .minute], from: wakeDate)
        let nextDate = calendar.nextDate(
            after: now,
            matching: DateComponents(
                hour: components.hour,
                minute: components.minute,
                second: 0
            ),
            matchingPolicy: .nextTime,
            direction: .forward
        )

        return nextDate ?? wakeDate.addingTimeInterval(86_400)
    }

    private func persist(_ scheduledAlarm: ScheduledAlarm) {
        defaults.set(scheduledAlarm.id, forKey: managedAlarmIdentifierKey)
        defaults.set(scheduledAlarm.provider.rawValue, forKey: managedAlarmProviderKey)
    }

    private func clearPersistedAlarmRecord() {
        defaults.removeObject(forKey: managedAlarmIdentifierKey)
        defaults.removeObject(forKey: managedAlarmProviderKey)
    }

    private func cancelManagedAlarmIfNeeded() async {
        guard let identifier = defaults.string(forKey: managedAlarmIdentifierKey),
              let providerRawValue = defaults.string(forKey: managedAlarmProviderKey),
              let provider = AlarmProviderKind(rawValue: providerRawValue) else {
            return
        }

        switch provider {
        case .alarmKit:
            if #available(iOS 26.1, *) {
                let alarmID = UUID(uuidString: identifier) ?? UUID()
                try? AlarmManager.shared.cancel(id: alarmID)
            }
        case .notificationFallback:
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }

        clearPersistedAlarmRecord()
    }

    @available(iOS 26.1, *)
    private func scheduleAlarmKitAlarm(at fireDate: Date) async throws -> ScheduledAlarm {
        await cancelManagedAlarmIfNeeded()

        let manager = AlarmManager.shared
        let authorizationState = try await authorizedAlarmState(using: manager)
        guard authorizationState == .authorized else {
            throw AlarmSchedulingError.permissionDenied
        }

        let id = UUID()
        let configuration = AlarmManager.AlarmConfiguration<AiQoWakeAlarmMetadata>.alarm(
            schedule: .fixed(fireDate),
            attributes: makeAlarmAttributes(for: fireDate),
            sound: .default
        )

        do {
            let alarm = try await manager.schedule(id: id, configuration: configuration)
            let scheduledAlarm = ScheduledAlarm(
                id: alarm.id.uuidString,
                fireDate: fireDate,
                provider: .alarmKit
            )
            persist(scheduledAlarm)
            return scheduledAlarm
        } catch let alarmError as AlarmManager.AlarmError {
            throw AlarmSchedulingError.schedulingFailed(message(for: alarmError))
        } catch {
            throw AlarmSchedulingError.schedulingFailed(error.localizedDescription)
        }
    }

    @available(iOS 26.1, *)
    private func authorizedAlarmState(using manager: AlarmManager) async throws -> AlarmManager.AuthorizationState {
        switch manager.authorizationState {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return try await manager.requestAuthorization()
        @unknown default:
            return .denied
        }
    }

    @available(iOS 26.1, *)
    private func makeAlarmAttributes(for fireDate: Date) -> AlarmAttributes<AiQoWakeAlarmMetadata> {
        let alert = makeAlarmAlert()
        let presentation = AlarmPresentation(alert: alert)
        let metadata = AiQoWakeAlarmMetadata(source: "smart_wake", wakeTimestamp: fireDate.timeIntervalSince1970)

        return AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: Color(hex: "96E9C8")
        )
    }

    @available(iOS 26.1, *)
    private func makeAlarmAlert() -> AlarmPresentation.Alert {
        AlarmPresentation.Alert(title: "وقت الاستيقاظ")
    }

    private func scheduleNotificationAlarm(at fireDate: Date) async throws -> ScheduledAlarm {
        await cancelManagedAlarmIfNeeded()

        let granted = await NotificationService.shared.ensureAuthorizationIfNeeded()
        guard granted else {
            throw AlarmSchedulingError.permissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = "AiQo Smart Wake"
        content.body = "هذا تذكير الاستيقاظ المحفوظ من الحاسبة الذكية."
        content.sound = .default

        let dateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let identifier = "aiqo.smartwake.notification.\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await addNotificationRequest(request)
            let scheduledAlarm = ScheduledAlarm(
                id: identifier,
                fireDate: fireDate,
                provider: .notificationFallback
            )
            persist(scheduledAlarm)
            return scheduledAlarm
        } catch {
            throw AlarmSchedulingError.schedulingFailed("تعذر حفظ تذكير الاستيقاظ حالياً.")
        }
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    @available(iOS 26.1, *)
    private func message(for error: AlarmManager.AlarmError) -> String {
        switch error {
        case .maximumLimitReached:
            return "وصلت إلى الحد الأقصى من المنبهات المحفوظة حالياً."
        @unknown default:
            return "تعذر حفظ المنبه حالياً."
        }
    }
}

@available(iOS 26.1, *)
private struct AiQoWakeAlarmMetadata: AlarmMetadata {
    let source: String
    let wakeTimestamp: TimeInterval
}
