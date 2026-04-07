import Foundation
import SwiftUI
import ActivityKit
import AlarmKit

enum AlarmAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case unsupported
}

struct ScheduledAlarm: Equatable, Sendable {
    let id: String
    let fireDate: Date
}

enum AlarmSaveState: Equatable, Sendable {
    case idle
    case requestingPermission
    case saving
    case saved
    case denied(message: String)
    case failed(message: String)

    var message: String? {
        switch self {
        case .idle, .requestingPermission, .saving, .saved:
            return nil
        case .denied(let message), .failed(let message):
            return message
        }
    }

    var isBusy: Bool {
        switch self {
        case .requestingPermission, .saving:
            return true
        default:
            return false
        }
    }

    var isSaved: Bool {
        if case .saved = self {
            return true
        }
        return false
    }

    var isDenied: Bool {
        if case .denied = self {
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
    case invalidWakeDate
    case schedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "تحتاج تسمح للتطبيق بإنشاء منبه. فعّل إذن المنبه حتى ينحفظ الوقت."
        case .unsupported:
            return "حفظ المنبه عبر AlarmKit غير متاح على هذا الجهاز حالياً."
        case .invalidWakeDate:
            return "تعذر تحويل الوقت المحدد إلى منبه صالح."
        case .schedulingFailed(let message):
            return message
        }
    }
}

@MainActor
protocol AlarmSchedulingService {
    func authorizationStatus() async -> AlarmAuthorizationStatus
    func requestAuthorizationIfNeeded() async throws -> AlarmAuthorizationStatus
    func scheduleWakeAlarm(at wakeDate: Date) async throws -> ScheduledAlarm
}

@MainActor
enum AlarmSchedulingServiceFactory {
    static func makeDefault() -> any AlarmSchedulingService {
        if #available(iOS 26.1, *) {
            return AlarmKitSchedulingService.shared
        }

        return UnsupportedAlarmSchedulingService.shared
    }
}

@MainActor
final class UnsupportedAlarmSchedulingService: AlarmSchedulingService {
    static let shared = UnsupportedAlarmSchedulingService()

    func authorizationStatus() async -> AlarmAuthorizationStatus {
        .unsupported
    }

    func requestAuthorizationIfNeeded() async throws -> AlarmAuthorizationStatus {
        .unsupported
    }

    func scheduleWakeAlarm(at wakeDate: Date) async throws -> ScheduledAlarm {
        throw AlarmSchedulingError.unsupported
    }
}

@MainActor
@available(iOS 26.1, *)
final class AlarmKitSchedulingService: AlarmSchedulingService {
    static let shared = AlarmKitSchedulingService()

    private let calendar: Calendar
    private static let managedAlarmID = UUID(uuidString: "B8B502C3-4F52-4C18-B4E6-7E718F00A1F4")!

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func authorizationStatus() async -> AlarmAuthorizationStatus {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    func requestAuthorizationIfNeeded() async throws -> AlarmAuthorizationStatus {
        let currentStatus = await authorizationStatus()
        switch currentStatus {
        case .authorized, .denied, .unsupported:
            return currentStatus
        case .notDetermined:
            let updatedStatus = try await AlarmManager.shared.requestAuthorization()
            switch updatedStatus {
            case .authorized:
                return .authorized
            case .denied:
                return .denied
            case .notDetermined:
                return .notDetermined
            @unknown default:
                return .denied
            }
        }
    }

    func scheduleWakeAlarm(at wakeDate: Date) async throws -> ScheduledAlarm {
        guard let fireDate = nextFutureOccurrence(from: wakeDate) else {
            throw AlarmSchedulingError.invalidWakeDate
        }

        guard await authorizationStatus() == .authorized else {
            throw AlarmSchedulingError.permissionDenied
        }

        try? AlarmManager.shared.cancel(id: Self.managedAlarmID)

        let configuration = AlarmManager.AlarmConfiguration<AiQoSmartWakeAlarmMetadata>.alarm(
            schedule: .fixed(fireDate),
            attributes: makeAlarmAttributes(for: fireDate),
            sound: .default
        )

        do {
            let alarm = try await AlarmManager.shared.schedule(
                id: Self.managedAlarmID,
                configuration: configuration
            )

            MorningHabitOrchestrator.shared.configureScheduledWake(at: fireDate)

            return ScheduledAlarm(
                id: alarm.id.uuidString,
                fireDate: fireDate
            )
        } catch let error as AlarmManager.AlarmError {
            throw AlarmSchedulingError.schedulingFailed(message(for: error))
        } catch {
            throw AlarmSchedulingError.schedulingFailed("صار خطأ أثناء حفظ المنبه. حاول مرة ثانية.")
        }
    }

    private func nextFutureOccurrence(from wakeDate: Date) -> Date? {
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: wakeDate)

        guard let hour = timeComponents.hour,
              let minute = timeComponents.minute else {
            return nil
        }

        let todayCandidate = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        )

        if let todayCandidate, todayCandidate > now.addingTimeInterval(30) {
            return todayCandidate
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)
        return tomorrow.flatMap {
            calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: $0
            )
        }
    }

    private func makeAlarmAttributes(for fireDate: Date) -> AlarmAttributes<AiQoSmartWakeAlarmMetadata> {
        let alert = AlarmPresentation.Alert(title: "AiQo Smart Wake")
        let presentation = AlarmPresentation(alert: alert)
        let metadata = AiQoSmartWakeAlarmMetadata(
            source: "smart_wake",
            scheduledTimestamp: fireDate.timeIntervalSince1970
        )

        return AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: Color(hex: "96E9C8")
        )
    }

    private func message(for error: AlarmManager.AlarmError) -> String {
        switch error {
        case .maximumLimitReached:
            return "وصلت للحد الأقصى من المنبهات المحفوظة. احذف منبهًا ثم حاول مرة ثانية."
        @unknown default:
            return "صار خطأ أثناء حفظ المنبه. حاول مرة ثانية."
        }
    }
}

@available(iOS 26.1, *)
private struct AiQoSmartWakeAlarmMetadata: AlarmMetadata {
    let source: String
    let scheduledTimestamp: TimeInterval
}
