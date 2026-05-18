import XCTest
@testable import AiQo

/// Covers the pure fire-time resolution for time-based standing directives.
/// (Mirrors the tested `CaptainReminderScheduler.resolveFireDate` seam.)
@MainActor
final class DirectiveNotificationSchedulerTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return c
    }

    private func time(_ hour: Int, _ minute: Int) -> Date {
        let comps = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026, month: 5, day: 18,
            hour: hour, minute: minute
        )
        return calendar.date(from: comps) ?? Date()
    }

    func testEveryMorningUsesWakeTime() {
        let clock = DirectiveNotificationScheduler.fireClock(
            trigger: .everyMorning,
            wakeTime: time(6, 20),
            bedtime: nil,
            calendar: calendar
        )
        XCTAssertEqual(clock?.hour, 6)
        XCTAssertEqual(clock?.minute, 20)
    }

    func testEveryMorningFallsBackToEightAMWhenNoWakeTime() {
        let clock = DirectiveNotificationScheduler.fireClock(
            trigger: .everyMorning, wakeTime: nil, bedtime: nil, calendar: calendar
        )
        XCTAssertEqual(clock?.hour, 8)
        XCTAssertEqual(clock?.minute, 0)
    }

    func testBeforeBedtimeFiresThirtyMinutesBeforeBed() {
        let clock = DirectiveNotificationScheduler.fireClock(
            trigger: .beforeBedtime,
            wakeTime: nil,
            bedtime: time(22, 40),
            calendar: calendar
        )
        // 22:40 − 30m = 22:10 so the reminder lands *before* sleep.
        XCTAssertEqual(clock?.hour, 22)
        XCTAssertEqual(clock?.minute, 10)
    }

    func testBeforeBedtimeFallsBackToNineThirtyPMWhenNoBedtime() {
        let clock = DirectiveNotificationScheduler.fireClock(
            trigger: .beforeBedtime, wakeTime: nil, bedtime: nil, calendar: calendar
        )
        XCTAssertEqual(clock?.hour, 21)
        XCTAssertEqual(clock?.minute, 30)
    }

    func testNonTimeScheduledTriggersReturnNil() {
        for trigger in [DirectiveTrigger.afterWorkout, .afterPoorSleep, .weeklyReview] {
            XCTAssertNil(
                DirectiveNotificationScheduler.fireClock(
                    trigger: trigger, wakeTime: time(6, 0), bedtime: time(22, 0),
                    calendar: calendar
                ),
                "\(trigger) must not be time-scheduled by this scheduler"
            )
        }
    }
}
