import XCTest
@testable import AiQo

/// Verifies `captain_chat_opened` fires exactly once per session boundary.
///
/// The session boundary is `CaptainViewModel.currentSessionID`, which
/// changes only inside `startNewChat()`. View re-entry (`.onAppear`
/// firing again after navigation pop) must not re-emit; only a genuine
/// new chat does.
@MainActor
final class CaptainChat_OpenEvent_Test: XCTestCase {

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

    // MARK: - Single emit per startNewChat

    func testStartNewChatEmitsOpenEventExactlyOnce() {
        let viewModel = CaptainViewModel()
        // CaptainViewModel.init() calls loadPersistedHistory() → startNewChat()
        // before our mock is registered. So drain the initial state and
        // assert from this point forward.
        mock.clear()

        viewModel.startNewChat()

        XCTAssertEqual(mock.eventCount(named: "captain_chat_opened"), 1,
                       "Exactly one captain_chat_opened per startNewChat. " +
                       "Got: \(mock.eventNames)")
    }

    func testRepeatedStartNewChatEmitsPerSession() {
        let viewModel = CaptainViewModel()
        mock.clear()

        viewModel.startNewChat()
        viewModel.startNewChat()
        viewModel.startNewChat()

        XCTAssertEqual(mock.eventCount(named: "captain_chat_opened"), 3,
                       "Each startNewChat() is a new session and should emit.")
    }

    // MARK: - Session ID rotates on each emit

    func testSessionIDRotatesWithEachNewChat() {
        let viewModel = CaptainViewModel()
        let firstID = viewModel.currentSessionID

        viewModel.startNewChat()
        let secondID = viewModel.currentSessionID

        viewModel.startNewChat()
        let thirdID = viewModel.currentSessionID

        XCTAssertNotEqual(firstID, secondID, "Session ID must rotate on new chat.")
        XCTAssertNotEqual(secondID, thirdID, "Each new chat needs a fresh session ID.")
    }

    // MARK: - Event shape

    func testCaptainChatOpenedEventNameIsStable() {
        XCTAssertEqual(AnalyticsEvent.captainChatOpened.name, "captain_chat_opened",
                       "Event name is a public analytics contract; do not rename without notice.")
    }
}
