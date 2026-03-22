// Supabase hook: keep this legacy preview view model in sync with the shared
// `TribeChallenge` model until the older Galaxy preview screens are removed.
import Combine
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
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now.addingTimeInterval(60 * 60 * 10)
        let endOfMonth = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(60 * 60 * 24 * 30)

        challenges = [
            // ✅ تحديات شخصية يومية
            TribeChallenge(
                id: "personal-steps-daily",
                scope: .personal,
                cadence: .daily,
                title: "10,000 خطوة",
                subtitle: "حقق هدفك اليومي من الخطوات",
                metricType: .steps,
                targetValue: 10_000,
                progressValue: Int.random(in: 2000...7000),
                startAt: Calendar.current.startOfDay(for: now),
                endAt: endOfDay,
                createdByUserId: "self",
                participantsCount: 1
            ),
            TribeChallenge(
                id: "personal-calm-daily",
                scope: .personal,
                cadence: .daily,
                title: "هدوء 15 دقيقة",
                subtitle: "خذ وقتك للتأمل والراحة النفسية",
                metricType: .calmMinutes,
                targetValue: 15,
                progressValue: Int.random(in: 0...8),
                startAt: Calendar.current.startOfDay(for: now),
                endAt: endOfDay,
                createdByUserId: "self",
                participantsCount: 1
            ),
            TribeChallenge(
                id: "personal-water-daily",
                scope: .personal,
                cadence: .daily,
                title: "8 أكواب ماء",
                subtitle: "حافظ على ترطيب جسمك",
                metricType: .water,
                targetValue: 8,
                progressValue: Int.random(in: 1...4),
                startAt: Calendar.current.startOfDay(for: now),
                endAt: endOfDay,
                createdByUserId: "self",
                participantsCount: 1
            ),

            // 🏋️ تحديات القبيلة اليومية
            TribeChallenge(
                id: "tribe-steps-daily",
                scope: .tribe,
                cadence: .daily,
                title: "ماراثون القبيلة",
                subtitle: "50,000 خطوة جماعية اليوم!",
                metricType: .steps,
                targetValue: 50_000,
                progressValue: Int.random(in: 15000...38000),
                startAt: Calendar.current.startOfDay(for: now),
                endAt: endOfDay,
                createdByUserId: "tribe-leader",
                participantsCount: Int.random(in: 5...12)
            ),
            TribeChallenge(
                id: "tribe-sugarfree-daily",
                scope: .tribe,
                cadence: .daily,
                title: "يوم بدون سكر 🍬",
                subtitle: "تحدّوا أنفسكم كقبيلة!",
                metricType: .sugarFree,
                targetValue: 1,
                progressValue: 0,
                startAt: Calendar.current.startOfDay(for: now),
                endAt: endOfDay,
                createdByUserId: "tribe-leader",
                participantsCount: Int.random(in: 4...8)
            ),

            // 🌍 تحديات المجرة (عالمية)
            TribeChallenge(
                id: "galaxy-water-daily",
                scope: .galaxy,
                cadence: .daily,
                title: "موجة الترطيب 💧",
                subtitle: "تحدي AiQo العالمي — 500 كوب ماء!",
                metricType: .water,
                targetValue: 500,
                progressValue: Int.random(in: 180...380),
                startAt: Calendar.current.startOfDay(for: now),
                endAt: endOfDay,
                isCuratedGlobal: true,
                participantsCount: Int.random(in: 120...450)
            ),
            TribeChallenge(
                id: "galaxy-steps-daily",
                scope: .galaxy,
                cadence: .daily,
                title: "مليون خطوة 🏃",
                subtitle: "المجرة كلها تمشي! تحدي AiQo اليومي",
                metricType: .steps,
                targetValue: 1_000_000,
                progressValue: Int.random(in: 350000...720000),
                startAt: Calendar.current.startOfDay(for: now),
                endAt: endOfDay,
                isCuratedGlobal: true,
                participantsCount: Int.random(in: 200...800)
            ),

            // 📅 تحديات شهرية
            TribeChallenge(
                id: "personal-sleep-monthly",
                scope: .personal,
                cadence: .monthly,
                title: "نوم 200 ساعة",
                subtitle: "حافظ على نوم صحي هالشهر",
                metricType: .sleep,
                targetValue: 200,
                progressValue: Int.random(in: 40...120),
                startAt: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now,
                endAt: endOfMonth,
                createdByUserId: "self",
                participantsCount: 1
            ),
            TribeChallenge(
                id: "tribe-steps-monthly",
                scope: .tribe,
                cadence: .monthly,
                title: "500,000 خطوة شهرية",
                subtitle: "القبيلة تتحدى بعض!",
                metricType: .steps,
                targetValue: 500_000,
                progressValue: Int.random(in: 100000...320000),
                startAt: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now,
                endAt: endOfMonth,
                createdByUserId: "tribe-leader",
                participantsCount: Int.random(in: 6...15)
            ),
            TribeChallenge(
                id: "galaxy-calm-monthly",
                scope: .galaxy,
                cadence: .monthly,
                title: "10,000 دقيقة هدوء 🧘",
                subtitle: "المجرة تتأمل — تحدي AiQo الشهري",
                metricType: .calmMinutes,
                targetValue: 10_000,
                progressValue: Int.random(in: 2500...6800),
                startAt: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now,
                endAt: endOfMonth,
                isCuratedGlobal: true,
                participantsCount: Int.random(in: 150...600)
            ),
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
