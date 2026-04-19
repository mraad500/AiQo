import XCTest
@testable import AiQo

final class FeedbackLearnerTests: XCTestCase {

    override func setUp() async throws {
        await FeedbackLearner.shared.resetAll()
    }

    override func tearDown() async throws {
        await FeedbackLearner.shared.resetAll()
    }

    func testInitialWeightIsOne() async {
        let w = await FeedbackLearner.shared.weight(for: .inactivityNudge)
        XCTAssertEqual(w, 1.0, accuracy: 0.001)
    }

    func testOpenIncreasesWeight() async {
        let id = UUID()
        await FeedbackLearner.shared.record(.opened(intentID: id), kind: .inactivityNudge)
        let w = await FeedbackLearner.shared.weight(for: .inactivityNudge)
        XCTAssertGreaterThan(w, 1.0)
    }

    func testDismissDecreasesWeight() async {
        let id = UUID()
        await FeedbackLearner.shared.record(.dismissed(intentID: id), kind: .inactivityNudge)
        let w = await FeedbackLearner.shared.weight(for: .inactivityNudge)
        XCTAssertLessThan(w, 1.0)
    }

    func testWeightClampedAtUpperBound() async {
        let id = UUID()
        for _ in 0..<50 {
            await FeedbackLearner.shared.record(.opened(intentID: id), kind: .inactivityNudge)
        }
        let w = await FeedbackLearner.shared.weight(for: .inactivityNudge)
        XCTAssertLessThanOrEqual(w, 1.5)
    }

    func testWeightClampedAtLowerBound() async {
        let id = UUID()
        for _ in 0..<50 {
            await FeedbackLearner.shared.record(.dismissed(intentID: id), kind: .inactivityNudge)
        }
        let w = await FeedbackLearner.shared.weight(for: .inactivityNudge)
        XCTAssertGreaterThanOrEqual(w, 0.3)
    }

    func testAppOpenedAfterBoostsMore() async {
        let id = UUID()
        await FeedbackLearner.shared.record(
            .appOpenedAfter(intentID: id, withinSeconds: 15),
            kind: .memoryCallback
        )
        let w = await FeedbackLearner.shared.weight(for: .memoryCallback)
        XCTAssertGreaterThan(w, 1.05)
    }

    func testSnoozeDecreasesWeightSlightly() async {
        let id = UUID()
        await FeedbackLearner.shared.record(.snoozed(intentID: id), kind: .inactivityNudge)
        let w = await FeedbackLearner.shared.weight(for: .inactivityNudge)
        XCTAssertLessThan(w, 1.0)
        XCTAssertGreaterThanOrEqual(w, 0.5)
    }
}

final class MessageComposerTests: XCTestCase {

    func testArabicMorningTemplate() async {
        let intent = NotificationIntent(kind: .morningKickoff, requestedBy: "test")
        let composed = await MessageComposer.shared.compose(intent: intent, language: "ar")
        XCTAssertEqual(composed.title, "صباحك نور")
    }

    func testEnglishMorningTemplate() async {
        let intent = NotificationIntent(kind: .morningKickoff, requestedBy: "test")
        let composed = await MessageComposer.shared.compose(intent: intent, language: "en")
        XCTAssertEqual(composed.title, "Good morning")
    }

    func testRelationshipNameInjected() async {
        let intent = NotificationIntent(
            kind: .memoryCallback,
            signals: IntentSignals(customPayload: ["relationship_name": "Mama"]),
            requestedBy: "test"
        )
        let composed = await MessageComposer.shared.compose(intent: intent, language: "ar")
        XCTAssertTrue(composed.body.contains("Mama"))
    }

    func testEnglishRelationshipFallback() async {
        let intent = NotificationIntent(
            kind: .memoryCallback,
            signals: IntentSignals(customPayload: ["relationship_name": "Mom"]),
            requestedBy: "test"
        )
        let composed = await MessageComposer.shared.compose(intent: intent, language: "en")
        XCTAssertTrue(composed.body.contains("Mom"))
    }

    func testEveryKindHasTemplate() {
        for kind in NotificationKind.allCases {
            let arTemplate = TemplateLibrary.template(for: kind, language: "ar")
            let enTemplate = TemplateLibrary.template(for: kind, language: "en")
            XCTAssertFalse(arTemplate.title.isEmpty, "Missing AR title for \(kind)")
            XCTAssertFalse(arTemplate.body.isEmpty, "Missing AR body for \(kind)")
            XCTAssertFalse(enTemplate.title.isEmpty, "Missing EN title for \(kind)")
            XCTAssertFalse(enTemplate.body.isEmpty, "Missing EN body for \(kind)")
        }
    }
}
