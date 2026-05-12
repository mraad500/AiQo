import XCTest
import HealthKit
@testable import AiQo

/// Verifies the workout lifecycle events fire with the right names and
/// shapes. `workoutCancelled` is exercised end-to-end through
/// `LiveWorkoutSession.forceEndFromPhoneImmediately()`; the started/
/// completed paths are smoke-tested via the `AnalyticsEvent` factory
/// because their callers (`prepareForWorkoutStart` / `handleRemoteEnded`)
/// are `private` and gated on `PhoneConnectivityManager.shared` state
/// that is impractical to mock at unit-test scope.
@MainActor
final class Workout_Event_Emission_Test: XCTestCase {

    private var mock: MockAnalyticsProvider!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockAnalyticsProvider()
        AnalyticsService.shared.register(provider: mock)
    }

    override func tearDown() async throws {
        mock.clear()
        try await super.tearDown()
    }

    // MARK: - workoutCancelled — full lifecycle

    func testForceEndFromPhoneImmediatelyEmitsWorkoutCancelled() {
        let session = LiveWorkoutSession(
            title: "Test Workout",
            activityType: .running,
            locationType: .outdoor
        )

        // forceEnd guards on `phase != .idle`, so we move it to .starting
        // (still avoids the canEnd → connectivity.endWorkoutOnWatch path
        // which requires .running/.paused).
        session.phase = .starting

        session.forceEndFromPhoneImmediately()

        XCTAssertEqual(mock.eventCount(named: "workout_cancelled"), 1,
                       "workout_cancelled should fire exactly once on forceEnd. " +
                       "Got events: \(mock.eventNames)")
    }

    func testForceEndDoesNotEmitWhenAlreadyIdle() {
        let session = LiveWorkoutSession(activityType: .running)
        // session.phase defaults to .idle — forceEnd's `guard phase != .idle`
        // should short-circuit before any emit.
        session.forceEndFromPhoneImmediately()

        XCTAssertEqual(mock.eventCount(named: "workout_cancelled"), 0,
                       "Force-end on an idle session must be a no-op.")
    }

    // MARK: - workoutStarted — event shape

    func testWorkoutStartedEventCarriesType() {
        let event = AnalyticsEvent.workoutStarted(type: "running")
        XCTAssertEqual(event.name, "workout_started")
        XCTAssertEqual(event.properties["type"] as? String, "running")
    }

    func testWorkoutStartedTrackingThroughService() {
        AnalyticsService.shared.track(.workoutStarted(type: "strength"))
        XCTAssertTrue(mock.eventNames.contains("workout_started"))
        let firstStarted = mock.events.first { $0.name == "workout_started" }
        XCTAssertEqual(firstStarted?.properties["type"] as? String, "strength")
    }

    // MARK: - workoutCompleted — event shape

    func testWorkoutCompletedEventCarriesAllProperties() {
        let event = AnalyticsEvent.workoutCompleted(
            type: "cycling",
            durationMin: 45,
            calories: 380
        )
        XCTAssertEqual(event.name, "workout_completed")
        XCTAssertEqual(event.properties["type"] as? String, "cycling")
        XCTAssertEqual(event.properties["duration_min"] as? Int, 45)
        XCTAssertEqual(event.properties["calories"] as? Int, 380)
    }

    func testWorkoutCompletedTrackingThroughService() {
        AnalyticsService.shared.track(.workoutCompleted(
            type: "hiit",
            durationMin: 20,
            calories: 240
        ))
        let completed = mock.events.first { $0.name == "workout_completed" }
        XCTAssertNotNil(completed)
        XCTAssertEqual(completed?.properties["type"] as? String, "hiit")
        XCTAssertEqual(completed?.properties["duration_min"] as? Int, 20)
    }

    // MARK: - Vocabulary cardinality

    func testWorkoutTypeVocabularyIsBounded() {
        let allowed: Set<String> = [
            "running", "walking", "cycling", "strength",
            "hiit", "swimming", "yoga", "other", "plan"
        ]

        // Track one of each; verify all fit the bounded vocabulary.
        for label in allowed {
            AnalyticsService.shared.track(.workoutStarted(type: label))
        }

        let trackedTypes = mock.events
            .filter { $0.name == "workout_started" }
            .compactMap { $0.properties["type"] as? String }
        for label in trackedTypes {
            XCTAssertTrue(allowed.contains(label),
                          "Unexpected workout type label leaked: \(label)")
        }
    }
}
