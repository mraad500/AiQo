import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class CrisisDetectorTests: XCTestCase {

    func testAcuteSeverityOnCrisisText() async throws {
        let detector = try await makeDetector()

        let signal = await detector.evaluate(message: "I want to kill myself")

        XCTAssertEqual(signal.severity, .acute)
        XCTAssertEqual(signal.source, .text)
    }

    func testAcuteSeverityArabic() async throws {
        let detector = try await makeDetector()

        let signal = await detector.evaluate(message: "ما أبي أعيش")

        XCTAssertEqual(signal.severity, .acute)
        XCTAssertEqual(signal.source, .text)
    }

    func testConcerningSeverityOnHighNegativeEmotionPattern() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let detector = try await makeDetector(
            now: now,
            emotions: [
                ("panic", .anxiety, 0.9, now.addingTimeInterval(-1_000)),
                ("grief", .grief, 0.8, now.addingTimeInterval(-2_000)),
                ("shame", .shame, 0.7, now.addingTimeInterval(-3_000))
            ]
        )

        let signal = await detector.evaluate(message: "hello")

        XCTAssertEqual(signal.severity, .concerning)
        XCTAssertEqual(signal.source, .emotionalPattern)
        XCTAssertTrue(signal.context.contains("3"))
    }

    func testWatchfulSeverityOnExtremeSleepDeprivation() async throws {
        let detector = try await makeDetector(sleepHours: 2.4)

        let signal = await detector.evaluate(message: "how's my day looking?")

        XCTAssertEqual(signal.severity, .watchful)
        XCTAssertEqual(signal.source, .bioSignal)
    }

    func testNoConcernOnNeutralText() async throws {
        let detector = try await makeDetector()

        let signal = await detector.evaluate(message: "What's the weather?")

        XCTAssertEqual(signal.severity, .noConcern)
    }

    func testSeverityOrdering() {
        XCTAssertLessThan(CrisisDetector.Signal.Severity.noConcern, .acute)
        XCTAssertLessThan(CrisisDetector.Signal.Severity.watchful, .concerning)
    }

    private func makeDetector(
        now: Date = Date(timeIntervalSince1970: 1_700_000_000),
        emotions: [(trigger: String, emotion: EmotionKind, intensity: Double, date: Date)] = [],
        sleepHours: Double = 8.0
    ) async throws -> CrisisDetector {
        let container = try makeInMemoryContainer()
        let emotionalStore = EmotionalStore(nowProvider: { now })
        await emotionalStore.configure(container: container)

        for entry in emotions {
            _ = await emotionalStore.record(
                trigger: entry.trigger,
                emotion: entry.emotion,
                intensity: entry.intensity,
                date: entry.date
            )
        }

        let bioStateEngine = BioStateEngine(
            fetchMetrics: {
                CaptainDailyHealthMetrics(
                    stepCount: 0,
                    activeEnergyKilocalories: 0,
                    averageOrCurrentHeartRateBPM: nil,
                    sleepHours: sleepHours
                )
            },
            clock: { now }
        )

        return CrisisDetector(
            emotionalStore: emotionalStore,
            bioStateEngine: bioStateEngine,
            nowProvider: { now }
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: MemorySchemaV4.self),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }
}

final class SafetyNetTests: XCTestCase {

    func testRecordAddsToBuffer() async {
        let safetyNet = SafetyNet(signalBufferLimit: 10)
        let signal = CrisisDetector.Signal(
            severity: .watchful,
            source: .text,
            context: "test",
            detectedAt: Date()
        )

        await safetyNet.record(signal)
        let count = await safetyNet.signalCount(in: 3600)

        XCTAssertEqual(count, 1)
    }

    func testBufferTrimsOldestSignals() async {
        let safetyNet = SafetyNet(signalBufferLimit: 2)

        for idx in 0..<3 {
            let signal = CrisisDetector.Signal(
                severity: .watchful,
                source: .text,
                context: "signal-\(idx)",
                detectedAt: Date()
            )
            await safetyNet.record(signal)
        }

        let count = await safetyNet.signalCount(in: 3600)
        XCTAssertEqual(count, 2)
    }

    func testInterveneReturnsImmediateReferral() async {
        let safetyNet = SafetyNet(signalBufferLimit: 10)
        let signal = CrisisDetector.Signal(
            severity: .acute,
            source: .text,
            context: "test",
            detectedAt: Date()
        )

        await safetyNet.record(signal)
        let decision = await safetyNet.shouldIntervene(for: signal, language: .english)

        if case .professionalReferral(let urgency) = decision {
            XCTAssertEqual(urgency, .immediate)
        } else {
            XCTFail("expected professionalReferral(immediate), got \(decision)")
        }
    }
}

final class InterventionPolicyTests: XCTestCase {

    func testNoConcernDoesNothing() {
        let signal = CrisisDetector.Signal(
            severity: .noConcern,
            source: .text,
            context: "",
            detectedAt: Date()
        )

        XCTAssertEqual(
            InterventionPolicy.decide(signal: signal, recentHistory: [], language: .english),
            .doNothing
        )
    }

    func testWatchfulReturnsGentleCheckIn() {
        let signal = CrisisDetector.Signal(
            severity: .watchful,
            source: .bioSignal,
            context: "",
            detectedAt: Date()
        )

        XCTAssertEqual(
            InterventionPolicy.decide(signal: signal, recentHistory: [], language: .english),
            .gentleCheckIn
        )
    }

    func testConcerningReturnsReflectiveMessageOnFirstOccurrence() {
        let signal = CrisisDetector.Signal(
            severity: .concerning,
            source: .emotionalPattern,
            context: "",
            detectedAt: Date()
        )

        let decision = InterventionPolicy.decide(
            signal: signal,
            recentHistory: [signal],
            language: .english
        )

        if case .reflectiveMessage(let text) = decision {
            XCTAssertFalse(text.isEmpty)
        } else {
            XCTFail("expected reflectiveMessage, got \(decision)")
        }
    }

    func testRepeatedConcerningUpgradesToReferral() {
        let now = Date()
        let history = (0..<3).map { index in
            CrisisDetector.Signal(
                severity: .concerning,
                source: .emotionalPattern,
                context: "",
                detectedAt: now.addingTimeInterval(-Double(index) * 86_400)
            )
        }
        let latest = CrisisDetector.Signal(
            severity: .concerning,
            source: .emotionalPattern,
            context: "",
            detectedAt: now
        )

        let decision = InterventionPolicy.decide(
            signal: latest,
            recentHistory: history + [latest],
            language: .english
        )

        if case .professionalReferral(let urgency) = decision {
            XCTAssertEqual(urgency, .suggested)
        } else {
            XCTFail("expected professionalReferral(suggested), got \(decision)")
        }
    }

    func testAcuteReturnsImmediateReferral() {
        let signal = CrisisDetector.Signal(
            severity: .acute,
            source: .text,
            context: "",
            detectedAt: Date()
        )

        let decision = InterventionPolicy.decide(
            signal: signal,
            recentHistory: [],
            language: .english
        )

        if case .professionalReferral(let urgency) = decision {
            XCTAssertEqual(urgency, .immediate)
        } else {
            XCTFail("expected professionalReferral(immediate), got \(decision)")
        }
    }
}

final class BrainOrchestratorSafetyTests: XCTestCase {

    func testAcuteMessageReturnsImmediateSafetyReplyInEnglish() async throws {
        let request = makeRequest(
            message: "I want to kill myself",
            language: .english
        )

        let reply = try await BrainOrchestrator().processMessage(request: request, userName: nil)

        XCTAssertTrue(reply.message.contains("local emergency services"))
    }

    func testAcuteMessageReturnsImmediateSafetyReplyInArabic() async throws {
        let request = makeRequest(
            message: "ما أبي أعيش",
            language: .arabic
        )

        let reply = try await BrainOrchestrator().processMessage(request: request, userName: nil)

        XCTAssertTrue(reply.message.contains("خدمات الطوارئ المحلية"))
    }

    private func makeRequest(
        message: String,
        language: AppLanguage
    ) -> HybridBrainRequest {
        HybridBrainRequest(
            conversation: [
                CaptainConversationMessage(role: .user, content: message)
            ],
            screenContext: .mainChat,
            language: language,
            contextData: CaptainContextData(
                steps: 0,
                calories: 0,
                vibe: "",
                level: 1
            ),
            userProfileSummary: "",
            intentSummary: "",
            workingMemorySummary: "",
            attachedImageData: nil
        )
    }
}
