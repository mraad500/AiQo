import XCTest
@testable import AiQo

/// Locks in the anti-hallucination contract of `ConversationCompactor`:
/// the compacted digest must (1) be empty for short chats, (2) capture the
/// opening goal, user points, the Captain's own commitments, and corrections
/// for long chats, (3) roll forward losslessly across evictions, and — most
/// importantly — (4) never contain a fact that wasn't actually said. A faithful
/// digest is the whole reason long sessions stop "forgetting" and fabricating.
final class ConversationCompactorTests: XCTestCase {

    // MARK: - Helpers

    private func msg(_ text: String, user: Bool, ephemeral: Bool = false) -> ChatMessage {
        ChatMessage(text: text, isUser: user, isEphemeral: ephemeral)
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Strips the clip ellipsis and a possible truncated tail so we can assert a
    /// digest line is a faithful prefix of some real message.
    private func stem(_ line: String) -> String {
        var s = line.hasSuffix("…") ? String(line.dropLast()) : line
        s = normalize(s)
        // After clipping the last (possibly partial) token can differ; compare
        // on a safe prefix.
        return String(s.prefix(40))
    }

    // MARK: - Empty / short chats

    func testEmptyInputProducesEmptyDigest() {
        let digest = ConversationCompactor.compact(droppedMessages: [], priorDigest: nil)
        XCTAssertTrue(digest.isEmpty)
        XCTAssertNil(digest.renderedBlock(language: .arabic))
        XCTAssertNil(digest.renderedBlock(language: .english))
    }

    func testGreetingsOnlyCarryNoDurableSignal() {
        let dropped = [
            msg("هلا", user: true),
            msg("هلا بيك شلونك", user: false),
            msg("تمام", user: true)
        ]
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)
        // No durable user point should be stored from pure greetings/acks.
        XCTAssertTrue(digest.userPoints.isEmpty, "greetings must not become durable points")
    }

    // MARK: - Core extraction

    func testCapturesOpeningIntentAndUserPoints() {
        let dropped = [
            msg("اريد انشف دهون وابني عضلات بنفس الوقت", user: true),
            msg("تمام نبدا خطوة خطوة", user: false),
            msg("عندي حساسية من المكسرات", user: true),
            msg("زين راح انتبهلها", user: false),
            msg("اتمرن الصبح بس", user: true)
        ]
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)

        XCTAssertNotNil(digest.openingIntent)
        XCTAssertEqual(stem(digest.openingIntent!), stem("اريد انشف دهون وابني عضلات بنفس الوقت"))
        // The two later user statements should be retained as points.
        XCTAssertGreaterThanOrEqual(digest.userPoints.count, 2)
        XCTAssertEqual(digest.coveredMessageCount, dropped.count)
        XCTAssertNotNil(digest.renderedBlock(language: .arabic))
    }

    func testCapturesCaptainCommitments() {
        let dropped = [
            msg("سويلي خطة تمرين", user: true),
            msg("رتبتلك خطة 4 اسابيع تركز على الجزء العلوي", user: false),
            msg("اوكي", user: true),
            msg("راح اذكرك الساعة 7 الصبح بالتمرين", user: false)
        ]
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)

        XCTAssertFalse(digest.captainCommitments.isEmpty, "Captain commitments must be captured so it never re-offers or contradicts them")
        let joined = digest.captainCommitments.joined(separator: " | ")
        XCTAssertTrue(joined.contains("خطة") || joined.contains("اذكرك"))
    }

    func testCapturesCorrectionsWithPriority() {
        let dropped = [
            msg("وزني 90 كيلو", user: true),
            msg("زين", user: false),
            msg("لا قصدي وزني 80 مو 90", user: true),
            msg("صح، 80", user: false)
        ]
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)
        XCTAssertFalse(digest.corrections.isEmpty, "explicit corrections must be captured")
        XCTAssertTrue(digest.corrections.contains { $0.contains("80") })
    }

    func testEnglishCorrectionDetected() {
        let dropped = [
            msg("my goal is to bulk up", user: true),
            msg("got it", user: false),
            msg("actually I meant I want to lose fat first", user: true),
            msg("understood", user: false)
        ]
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)
        XCTAssertFalse(digest.corrections.isEmpty)
        XCTAssertNotNil(digest.renderedBlock(language: .english))
    }

    // MARK: - Faithfulness (no fabrication)

    func testEveryDigestLineIsFaithfulToInput() {
        let dropped = [
            msg("اريد اخس 10 كيلو قبل الصيف", user: true),
            msg("رتبتلك برنامج كارديو", user: false),
            msg("ركبتي اليسار تعورني", user: true),
            msg("راح نتجنب الضغط على الركبة", user: false),
            msg("لا قصدي اليمين مو اليسار", user: true),
            msg("تمام اليمين", user: false)
        ]
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)

        let haystack = normalize(dropped.map(\.text).joined(separator: " "))
        let allLines = [digest.openingIntent].compactMap { $0 }
            + digest.userPoints + digest.captainCommitments + digest.corrections
        XCTAssertFalse(allLines.isEmpty)
        for line in allLines {
            let s = stem(line)
            XCTAssertTrue(
                haystack.contains(s),
                "digest line not found verbatim in input (possible fabrication): \(line)"
            )
        }
    }

    func testEphemeralAndEmptyMessagesIgnored() {
        let dropped = [
            msg("اريد ابدا روتين نوم منتظم", user: true),
            msg("  ", user: false),
            msg("نصيحة الصباح", user: false, ephemeral: true),
            msg("انام الساعة 12 واصحى 6", user: true)
        ]
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)
        // Only the 2 real user turns count toward coverage.
        XCTAssertEqual(digest.coveredMessageCount, 2)
    }

    // MARK: - Rolling merge (lossless across evictions)

    func testRollingMergeAccumulatesAndPreservesPrior() {
        let firstBatch = [
            msg("هدفي ابني عضلات", user: true),
            msg("بديت خطة", user: false)
        ]
        let prior = ConversationCompactor.compact(droppedMessages: firstBatch, priorDigest: nil)
        XCTAssertNotNil(prior.openingIntent)

        let secondBatch = [
            msg("اريد اضيف يوم ارجل", user: true),
            msg("ضفتلك يوم ارجل", user: false)
        ]
        let merged = ConversationCompactor.compact(droppedMessages: secondBatch, priorDigest: prior)

        // Opening intent from the first batch must survive the merge.
        XCTAssertEqual(merged.openingIntent, prior.openingIntent)
        // Coverage accumulates across batches.
        XCTAssertEqual(merged.coveredMessageCount, firstBatch.count + secondBatch.count)
        // New user point from the second batch is present.
        XCTAssertTrue(merged.userPoints.contains { $0.contains("يوم ارجل") })
    }

    func testCapsAreBounded() {
        // 30 distinct durable user statements → userPoints must stay capped.
        var dropped: [ChatMessage] = [msg("هدفي الاول هو اللياقة العامة", user: true)]
        for i in 0..<30 {
            dropped.append(msg("نقطة مهمة رقم \(i) عن روتيني الرياضي اليومي", user: true))
            dropped.append(msg("تمام", user: false))
        }
        let digest = ConversationCompactor.compact(droppedMessages: dropped, priorDigest: nil)
        XCTAssertLessThanOrEqual(digest.userPoints.count, ConversationCompactor.maxUserPoints)
    }
}
