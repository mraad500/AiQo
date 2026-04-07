// Supabase hook: keep this legacy preview view model in sync with the shared
// `TribeChallenge` model until the older Galaxy preview screens are removed.
internal import Combine
import SwiftUI
import UIKit

@MainActor
final class ArenaViewModel: ObservableObject {
    @Published var challenges: [TribeChallenge] = []
    @Published var activeChallengeId: String?
    @Published var createScope: ChallengeScope = .personal
    @Published var createCadence: ChallengeCadence = .daily
    @Published var createGoalType: ChallengeGoalType = .steps
    @Published var customTitle = ""
    @Published var message: String?

    init() {
        seedPreviewData()
    }

    var featuredChallenges: [TribeChallenge] {
        Array(challenges.prefix(4))
    }

    func challenges(for cadence: ChallengeCadence, scope: ChallengeScope) -> [TribeChallenge] {
        challenges.filter { $0.cadence == cadence && $0.scope == scope }
    }

    func select(_ challenge: TribeChallenge) {
        activeChallengeId = challenge.id
        impact(.light)
    }

    func contribute(to challenge: TribeChallenge) {
        guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        challenges[index].progressValue = min(
            challenges[index].targetValue,
            challenges[index].progressValue + challenge.goalType.defaultIncrement
        )
        activeChallengeId = challenge.id
        impact(.medium)
        showMessage("تمت المساهمة")
    }

    func createChallenge() {
        guard createScope != .galaxy else {
            showMessage("تحديات المجرة مختارة من AiQo.")
            impact(.rigid)
            return
        }

        let now = Date()
        let metricType = createGoalType
        let newChallenge = TribeChallenge(
            id: "legacy-\(UUID().uuidString)",
            scope: createScope,
            cadence: createCadence,
            title: resolvedChallengeTitle(),
            subtitle: "معاينة محلية من شاشة الأرينا القديمة.",
            metricType: metricType,
            targetValue: suggestedTarget(for: metricType, cadence: createCadence),
            progressValue: 0,
            startAt: now,
            endAt: createCadence == .daily ? now.addingTimeInterval(60 * 60 * 24) : now.addingTimeInterval(60 * 60 * 24 * 30),
            createdByUserId: "legacy-self",
            participantsCount: createScope == .tribe ? 4 : 1,
            unitOverride: metricType == .custom ? "وحدة" : nil
        )

        challenges.insert(newChallenge, at: 0)
        activeChallengeId = newChallenge.id
        customTitle = ""
        impact(.soft)
        showMessage("تم إنشاء التحدي")
    }

    private func seedPreviewData() {
        let now = Date()

        challenges = [
            TribeChallenge(
                id: "legacy-personal-calm",
                scope: .personal,
                cadence: .daily,
                title: "هدوء 20 دقيقة",
                subtitle: "معاينة سريعة.",
                metricType: .calmMinutes,
                targetValue: 20,
                progressValue: 8,
                startAt: now,
                endAt: now.addingTimeInterval(60 * 60 * 10),
                createdByUserId: "legacy-self",
                participantsCount: 1
            ),
            TribeChallenge(
                id: "legacy-tribe-steps",
                scope: .tribe,
                cadence: .daily,
                title: "50,000 خطوة اليوم",
                subtitle: "زخم قبلي سريع.",
                metricType: .steps,
                targetValue: 50_000,
                progressValue: 37_600,
                startAt: now,
                endAt: now.addingTimeInterval(60 * 60 * 9),
                createdByUserId: "legacy-tribe",
                participantsCount: 8
            ),
            TribeChallenge(
                id: "legacy-galaxy-water",
                scope: .galaxy,
                cadence: .daily,
                title: "ماء 40 كوب",
                subtitle: "تحدٍ مختار من AiQo.",
                metricType: .water,
                targetValue: 40,
                progressValue: 24,
                startAt: now,
                endAt: now.addingTimeInterval(60 * 60 * 8),
                participantsCount: 98
            ),
            TribeChallenge(
                id: "legacy-monthly-sleep",
                scope: .tribe,
                cadence: .monthly,
                title: "نوم 40 ساعة",
                subtitle: "تعافٍ جماعي.",
                metricType: .sleep,
                targetValue: 40,
                progressValue: 21,
                startAt: now,
                endAt: now.addingTimeInterval(60 * 60 * 24 * 20),
                createdByUserId: "legacy-tribe",
                participantsCount: 6
            )
        ]

        activeChallengeId = challenges.first?.id
    }

    private func resolvedChallengeTitle() -> String {
        let custom = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            return custom
        }

        switch createGoalType {
        case .steps:
            return createCadence == .daily ? "10,000 خطوة" : "120,000 خطوة"
        case .water:
            return createCadence == .daily ? "ماء 12 كوب" : "ماء 180 كوب"
        case .sleep:
            return createCadence == .daily ? "نوم 8 ساعات" : "نوم 40 ساعة"
        case .minutes, .calmMinutes:
            return createCadence == .daily ? "هدوء 20 دقيقة" : "هدوء 240 دقيقة"
        case .sugarFree:
            return createCadence == .daily ? "يوم بدون سكر" : "20 يوم بدون سكر"
        case .custom:
            return createCadence == .daily ? "تحدي يومي جديد" : "تحدي شهري جديد"
        }
    }

    private func suggestedTarget(for goalType: ChallengeGoalType, cadence: ChallengeCadence) -> Int {
        switch (goalType, cadence) {
        case (.steps, .daily):
            return 10_000
        case (.steps, .monthly):
            return 120_000
        case (.water, .daily):
            return 12
        case (.water, .monthly):
            return 180
        case (.sleep, .daily):
            return 8
        case (.sleep, .monthly):
            return 40
        case (.minutes, .daily), (.calmMinutes, .daily):
            return 20
        case (.minutes, .monthly), (.calmMinutes, .monthly):
            return 240
        case (.sugarFree, .daily):
            return 1
        case (.sugarFree, .monthly):
            return 20
        case (.custom, .daily):
            return 10
        case (.custom, .monthly):
            return 30
        }
    }

    private func showMessage(_ text: String) {
        message = text

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if self.message == text {
                self.message = nil
            }
        }
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
