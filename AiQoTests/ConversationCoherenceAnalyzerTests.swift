// ===============================================
// File: ConversationCoherenceAnalyzerTests.swift
// Brain Refactor §34 — coverage for the analyzer that catches the
// "Captain suggests walking after a 45-min walk" bug class.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class ConversationCoherenceAnalyzerTests: XCTestCase {

    private var analyzer: ConversationCoherenceAnalyzer { .shared }

    // MARK: - Empty / no-signal cases

    func testEmptyConversationProducesEmptyTags() {
        let tags = analyzer.analyze(conversation: [], recentActivity: nil)
        XCTAssertTrue(tags.isEmpty)
        XCTAssertTrue(tags.familiesToAvoid.isEmpty)
    }

    func testCaptainOnlyTurnsAreIgnored() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(role: .assistant, content: "أهلاً يا محمد")
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertTrue(tags.isEmpty)
    }

    // MARK: - Recent activity surfaces immediately

    func testRecentWalkSurfacesAsAvoidEntry() {
        let snapshot = RecentActivitySnapshot(
            title: "مشي",
            family: .walking,
            durationMinutes: 45,
            activeCalories: 261,
            distanceKm: 3.11,
            endedAt: Date().addingTimeInterval(-30 * 60),
            minutesSinceEnd: 30
        )
        let tags = analyzer.analyze(conversation: [], recentActivity: snapshot)
        XCTAssertEqual(tags.familiesToAvoid, [.walking])
        XCTAssertEqual(tags.completedClaims.first?.family, .walking)
    }

    func testStaleActivityDoesNotConstrain() {
        let snapshot = RecentActivitySnapshot(
            title: "مشي",
            family: .walking,
            durationMinutes: 45,
            activeCalories: 261,
            distanceKm: 3.11,
            endedAt: Date().addingTimeInterval(-23 * 3600),
            minutesSinceEnd: 23 * 60
        )
        let tags = analyzer.analyze(conversation: [], recentActivity: snapshot)
        XCTAssertTrue(tags.familiesToAvoid.isEmpty,
                     "Stale activity (>6h ago) must not seed avoid-list")
    }

    // MARK: - User-stated completion (the screenshot bug)

    /// Reproduces the 2026-05-09 screenshot exactly: user reports a 45-minute
    /// walk in chat, then asks an open-ended "what should we do?" The analyzer
    /// must catch the walk so the prompt layer can block a walk suggestion.
    func testReproducesScreenshotBugSurfacesWalkAvoid() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(
                role: .user,
                content: "هسوني مشيت 45 دقيقة شبيكككك"
            ),
            CaptainConversationMessage(
                role: .assistant,
                content: "حقك علي يا محمد"
            ),
            CaptainConversationMessage(
                role: .user,
                content: "شنو نسوي اب كيفك؟"
            )
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertTrue(tags.familiesToAvoid.contains(.walking),
                      "Analyzer must extract walking from 'هسوني مشيت 45 دقيقة'")
    }

    func testEnglishCompletionClaim() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(
                role: .user,
                content: "I just walked 45 minutes, what should we do next?"
            )
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertTrue(tags.familiesToAvoid.contains(.walking))
    }

    func testStrengthCompletionClaim() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(
                role: .user,
                content: "خلصت تمارين قوة قبل شوي"
            )
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertTrue(tags.familiesToAvoid.contains(.strength))
    }

    // MARK: - Refusals

    func testTargetedRefusalBlocksFamily() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(
                role: .user,
                content: "ما أريد ركض اليوم"
            )
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertTrue(tags.familiesToAvoid.contains(.running))
    }

    func testGenericExhaustionFlagsRefusalWithoutFamily() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(
                role: .user,
                content: "ما عندي خلق أتمرن اليوم"
            )
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertEqual(tags.refusals.count, 1)
        XCTAssertNil(tags.refusals.first?.family,
                     "Generic refusal must not pin a single family")
    }

    // MARK: - Captain-directed frustration

    func testFrustrationAtCaptainTriggersFlag() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(
                role: .user,
                content: "ليش هيج؟ ما تفهم؟"
            )
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertTrue(tags.userIsFrustratedWithCaptain)
    }

    func testGeneralComplaintDoesNotFlagCaptainFrustration() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(
                role: .user,
                content: "تعبان اليوم كلش"
            )
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertFalse(tags.userIsFrustratedWithCaptain)
    }

    // MARK: - Latest-emotion only (older turns ignored)

    func testOnlyLatestEmotionIsCaptured() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(role: .user, content: "متحمس اليوم"),       // .motivated
            CaptainConversationMessage(role: .user, content: "تعبان جداً")        // .tired
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: nil)
        XCTAssertEqual(tags.latestEmotion, .tired,
                       "Latest emotion wins; earlier motivated turn must not bleed through")
    }

    // MARK: - Family de-duplication

    func testActivityFromSnapshotAndChatDoesNotDoubleCount() {
        let snapshot = RecentActivitySnapshot(
            title: "Walking",
            family: .walking,
            durationMinutes: 45,
            activeCalories: 261,
            distanceKm: 3.11,
            endedAt: Date().addingTimeInterval(-15 * 60),
            minutesSinceEnd: 15
        )
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(role: .user, content: "هسوني مشيت 45 دقيقة")
        ]
        let tags = analyzer.analyze(conversation: convo, recentActivity: snapshot)
        XCTAssertEqual(
            tags.familiesToAvoid.filter { $0 == .walking }.count, 1,
            "Walking must appear exactly once in the avoid-list, not duplicated"
        )
    }
}

// MARK: - RecentActivityFamily classification coverage

@MainActor
final class RecentActivityFamilyClassificationTests: XCTestCase {

    func testIraqiTitlesClassify() {
        XCTAssertEqual(RecentActivityFamily.classify(title: "مشي"),       .walking)
        XCTAssertEqual(RecentActivityFamily.classify(title: "ركض"),       .running)
        XCTAssertEqual(RecentActivityFamily.classify(title: "يوغا"),     .yoga)
        XCTAssertEqual(RecentActivityFamily.classify(title: "بيلاتس"),   .pilates)
        XCTAssertEqual(RecentActivityFamily.classify(title: "ملاكمة"),   .boxing)
        XCTAssertEqual(RecentActivityFamily.classify(title: "تمارين قوة"), .strength)
        XCTAssertEqual(RecentActivityFamily.classify(title: "جلسة امتنان"), .gratitude)
    }

    func testEnglishTitlesClassify() {
        XCTAssertEqual(RecentActivityFamily.classify(title: "Walking"),         .walking)
        XCTAssertEqual(RecentActivityFamily.classify(title: "Running"),         .running)
        XCTAssertEqual(RecentActivityFamily.classify(title: "Outdoor Cycling"), .cycling)
        XCTAssertEqual(RecentActivityFamily.classify(title: "Strength Training"), .strength)
        XCTAssertEqual(RecentActivityFamily.classify(title: "HIIT"),            .hiit)
        XCTAssertEqual(RecentActivityFamily.classify(title: "Cinematic Grind"), .cinematic)
    }

    func testUnknownTitleFallsToOther() {
        XCTAssertEqual(RecentActivityFamily.classify(title: "Underwater Basket Weaving"), .other)
    }
}
