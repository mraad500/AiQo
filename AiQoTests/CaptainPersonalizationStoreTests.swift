import XCTest
import SwiftData
@testable import AiQo

final class CaptainPersonalizationStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: CaptainPersonalizationStore!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()

        suiteName = "CaptainPersonalizationStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)

        let schema = Schema([CaptainPersonalizationProfile.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )

        store = CaptainPersonalizationStore(defaults: defaults)
        store.configure(container: container)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testSaveAndLoadSnapshotPersistsCaptainPersonalization() {
        let snapshot = CaptainPersonalizationSnapshot(
            primaryGoal: .buildMuscle,
            favoriteSport: .gymResistance,
            preferredWorkoutTime: .evening,
            bedtime: makeDate(hour: 22, minute: 40),
            wakeTime: makeDate(hour: 6, minute: 20),
            recommendedWakeTime: makeDate(hour: 6, minute: 14),
            isAlarmSaved: true
        )

        XCTAssertTrue(store.save(snapshot))

        let loaded = store.currentSnapshot()
        XCTAssertEqual(loaded, snapshot)
        XCTAssertEqual(loaded?.primaryGoal.canonicalGoalText, "Build Muscle")
        XCTAssertEqual(loaded?.preferredWorkoutTime.reminderTime, CaptainReminderTime(hour: 18, minute: 0))
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

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
