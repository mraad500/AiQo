import XCTest
@testable import AiQo

final class CaptainPersonalizationReminderMappingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    func testWorkoutReminderMappingUsesExpectedClockTimes() {
        XCTAssertEqual(CaptainWorkoutTimePreference.earlyMorning.reminderTime, CaptainReminderTime(hour: 6, minute: 30))
        XCTAssertEqual(CaptainWorkoutTimePreference.morning.reminderTime, CaptainReminderTime(hour: 8, minute: 0))
        XCTAssertEqual(CaptainWorkoutTimePreference.afternoon.reminderTime, CaptainReminderTime(hour: 13, minute: 0))
        XCTAssertEqual(CaptainWorkoutTimePreference.evening.reminderTime, CaptainReminderTime(hour: 18, minute: 0))
        XCTAssertEqual(CaptainWorkoutTimePreference.night.reminderTime, CaptainReminderTime(hour: 21, minute: 0))
    }

    func testSleepReminderTimeIsThirtyMinutesBeforeBedtime() {
        let bedtime = makeDate(hour: 23, minute: 10)

        let reminder = CaptainPersonalizationReminderMapper.sleepReminderTime(
            bedtime: bedtime,
            calendar: calendar
        )

        XCTAssertEqual(reminder, CaptainReminderTime(hour: 22, minute: 40))
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 9,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? Date()
    }
}
