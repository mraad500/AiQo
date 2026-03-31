import Foundation

enum SmartWakeMode: String, CaseIterable, Identifiable, Sendable {
    case fromBedtime
    case fromWakeTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fromBedtime:
            return "من وقت النوم"
        case .fromWakeTime:
            return "من وقت الاستيقاظ"
        }
    }
}

enum SmartWakeWindow: Int, CaseIterable, Identifiable, Sendable {
    case ten = 10
    case twenty = 20
    case thirty = 30

    var id: Int { rawValue }

    var duration: TimeInterval {
        Double(rawValue) * 60
    }

    var title: String {
        "\(rawValue) د"
    }
}

struct SmartWakeRecommendation: Identifiable, Equatable, Sendable {
    let id: String
    let wakeDate: Date
    let cycleCount: Int
    let estimatedSleepDuration: TimeInterval
    let confidenceScore: Double
    let badge: String
    let isBest: Bool
    let explanation: String
    let isWithinSmartWindow: Bool

    var confidenceLabel: String {
        switch confidenceScore {
        case 0.9...:
            return "ثقة عالية"
        case 0.75...:
            return "ثقة جيدة"
        case 0.55...:
            return "ثقة متوسطة"
        default:
            return "ثقة محدودة"
        }
    }
}

struct SmartWakeEngine: Sendable {
    struct Configuration: Sendable {
        let cycleLength: TimeInterval
        let sleepOnsetDelay: TimeInterval
        let priorityCycles: [Int]
        let supportedCycles: [Int]

        static let `default` = Configuration(
            cycleLength: 90 * 60,
            sleepOnsetDelay: 14 * 60,
            priorityCycles: [6, 5, 4],
            supportedCycles: [3, 4, 5, 6]
        )

        var cycleMinutes: Int {
            Int(cycleLength / 60)
        }

        var sleepOnsetMinutes: Int {
            Int(sleepOnsetDelay / 60)
        }
    }

    private let calendar: Calendar
    private let configuration: Configuration

    init(
        calendar: Calendar = .current,
        configuration: Configuration = .default
    ) {
        self.calendar = calendar
        self.configuration = configuration
    }

    func defaultLatestWakeTime(from bedtime: Date) -> Date {
        dateByAdding(
            minutes: configuration.sleepOnsetMinutes + (5 * configuration.cycleMinutes),
            to: bedtime
        ) ?? bedtime.addingTimeInterval(configuration.sleepOnsetDelay + (5 * configuration.cycleLength))
    }

    func recommendations(fromBedtime bedtime: Date) -> [SmartWakeRecommendation] {
        let recommendations = configuration.supportedCycles
            .sorted(by: >)
            .map { cycleCount in
                let wakeDate = cycleWakeDate(from: bedtime, cycleCount: cycleCount)
                let sleepDuration = estimatedSleepDuration(for: cycleCount)

                return SmartWakeRecommendation(
                    id: recommendationID(for: wakeDate, cycleCount: cycleCount, suffix: "bedtime"),
                    wakeDate: wakeDate,
                    cycleCount: cycleCount,
                    estimatedSleepDuration: sleepDuration,
                    confidenceScore: confidenceScore(
                        cycleCount: cycleCount,
                        sleepDuration: sleepDuration,
                        isWithinSmartWindow: false,
                        isFallback: false
                    ),
                    badge: badge(for: cycleCount, isBest: false),
                    isBest: false,
                    explanation: bedtimeExplanation(for: cycleCount),
                    isWithinSmartWindow: false
                )
            }

        let bestID = recommendations.max(by: bedtimeRanking)?.id
        return markedBestRecommendation(in: recommendations, bestID: bestID)
    }

    func recommendations(
        latestWakeTime: Date,
        window: SmartWakeWindow,
        referenceBedtime: Date
    ) -> [SmartWakeRecommendation] {
        let alignedReferenceBedtime = alignedBedtime(referenceBedtime, for: latestWakeTime)
        let alignedLatestWakeTime = alignedWakeTime(latestWakeTime, after: alignedReferenceBedtime)
        let windowStart = dateByAdding(minutes: -window.rawValue, to: alignedLatestWakeTime)
            ?? alignedLatestWakeTime.addingTimeInterval(-window.duration)

        let cycleRecommendations = configuration.supportedCycles
            .sorted(by: >)
            .map { cycleCount in
                let wakeDate = cycleWakeDate(from: alignedReferenceBedtime, cycleCount: cycleCount)
                let sleepDuration = estimatedSleepDuration(for: cycleCount)
                let isWithinWindow = wakeDate >= windowStart && wakeDate <= alignedLatestWakeTime

                return SmartWakeRecommendation(
                    id: recommendationID(for: wakeDate, cycleCount: cycleCount, suffix: "wake"),
                    wakeDate: wakeDate,
                    cycleCount: cycleCount,
                    estimatedSleepDuration: sleepDuration,
                    confidenceScore: confidenceScore(
                        cycleCount: cycleCount,
                        sleepDuration: sleepDuration,
                        isWithinSmartWindow: isWithinWindow,
                        isFallback: false
                    ),
                    badge: badge(for: cycleCount, isBest: false),
                    isBest: false,
                    explanation: wakeTimeExplanation(for: cycleCount, withinWindow: isWithinWindow),
                    isWithinSmartWindow: isWithinWindow
                )
            }

        let featuredRecommendation: SmartWakeRecommendation

        if let bestInsideWindow = cycleRecommendations
            .filter(\.isWithinSmartWindow)
            .sorted(by: wakeRecommendationSort(latestWakeTime: alignedLatestWakeTime))
            .first {
            featuredRecommendation = bestInsideWindow
        } else {
            let fallbackCycle = inferredCycleCount(
                wakeDate: alignedLatestWakeTime,
                referenceBedtime: alignedReferenceBedtime
            )
            let fallbackSleepDuration = max(
                0,
                alignedLatestWakeTime.timeIntervalSince(alignedReferenceBedtime) - configuration.sleepOnsetDelay
            )

            featuredRecommendation = SmartWakeRecommendation(
                id: recommendationID(for: alignedLatestWakeTime, cycleCount: fallbackCycle, suffix: "fallback"),
                wakeDate: alignedLatestWakeTime,
                cycleCount: fallbackCycle,
                estimatedSleepDuration: fallbackSleepDuration,
                confidenceScore: confidenceScore(
                    cycleCount: fallbackCycle,
                    sleepDuration: fallbackSleepDuration,
                    isWithinSmartWindow: true,
                    isFallback: true
                ),
                badge: "متوازن",
                isBest: false,
                explanation: "ما لقينا نهاية دورة مناسبة داخل النافذة المحددة، لذلك اعتمدنا آخر وقت مسموح.",
                isWithinSmartWindow: true
            )
        }

        let alternates = cycleRecommendations
            .filter { $0.id != featuredRecommendation.id }
            .sorted(by: wakeRecommendationSort(latestWakeTime: alignedLatestWakeTime))
            .prefix(3)

        return markedBestRecommendation(
            in: [featuredRecommendation] + Array(alternates),
            bestID: featuredRecommendation.id
        )
    }

    private func estimatedSleepDuration(for cycleCount: Int) -> TimeInterval {
        Double(cycleCount) * configuration.cycleLength
    }

    private func cycleWakeDate(from bedtime: Date, cycleCount: Int) -> Date {
        let totalMinutes = configuration.sleepOnsetMinutes + (cycleCount * configuration.cycleMinutes)
        return dateByAdding(minutes: totalMinutes, to: bedtime)
            ?? bedtime.addingTimeInterval(configuration.sleepOnsetDelay + (Double(cycleCount) * configuration.cycleLength))
    }

    private func bedtimeRanking(
        _ lhs: SmartWakeRecommendation,
        _ rhs: SmartWakeRecommendation
    ) -> Bool {
        if lhs.confidenceScore == rhs.confidenceScore {
            return lhs.cycleCount < rhs.cycleCount
        }

        return lhs.confidenceScore < rhs.confidenceScore
    }

    private func confidenceScore(
        cycleCount: Int,
        sleepDuration: TimeInterval,
        isWithinSmartWindow: Bool,
        isFallback: Bool
    ) -> Double {
        let baseScore: Double

        switch cycleCount {
        case 6:
            baseScore = 0.96
        case 5:
            baseScore = 0.87
        case 4:
            baseScore = 0.72
        default:
            baseScore = 0.46
        }

        var score = baseScore

        if sleepDuration < 6 * 3600 {
            score -= 0.12
        } else if sleepDuration > 9.5 * 3600 {
            score -= 0.06
        }

        if cycleCount < 4 {
            score -= 0.08
        }

        if isWithinSmartWindow {
            score += 0.04
        }

        if isFallback {
            score -= 0.18
        }

        return min(max(score, 0.18), 0.99)
    }

    private func badge(for cycleCount: Int, isBest: Bool) -> String {
        if isBest {
            return "الأفضل"
        }

        switch cycleCount {
        case 5, 6:
            return "متوازن"
        default:
            return "أخف"
        }
    }

    private func bedtimeExplanation(for cycleCount: Int) -> String {
        switch cycleCount {
        case 6:
            return "هذا الوقت أقرب لنهاية دورة نوم متوقعة ويمنحك مدة نوم مريحة."
        case 5:
            return "هذا الخيار يوازن بين مدة النوم والالتزام بموعد صباحي عملي."
        case 4:
            return "خيار مقبول إذا كنت تحتاج الاستيقاظ أبكر من المعتاد."
        default:
            return "مدة أقصر من المثالي، لذلك يفضّل استخدامه عند الضرورة فقط."
        }
    }

    private func wakeTimeExplanation(
        for cycleCount: Int,
        withinWindow: Bool
    ) -> String {
        if withinWindow {
            return "ضمن نافذة الاستيقاظ الذكي واعتمادًا على دورات النوم التقديرية."
        }

        if cycleCount < 4 {
            return "خيار أخف زمنيًا لكنه أقل مثالية من ناحية التعافي."
        }

        return "نهاية دورة متوقعة لكنها تقع خارج نافذة الاستيقاظ الحالية."
    }

    private func alignedWakeTime(_ latestWakeTime: Date, after bedtime: Date) -> Date {
        if latestWakeTime > bedtime {
            return latestWakeTime
        }

        return calendar.date(byAdding: .day, value: 1, to: latestWakeTime)
            ?? latestWakeTime.addingTimeInterval(86_400)
    }

    private func alignedBedtime(_ bedtime: Date, for latestWakeTime: Date) -> Date {
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: bedtime)
        var candidate = calendar.date(
            bySettingHour: bedtimeComponents.hour ?? 23,
            minute: bedtimeComponents.minute ?? 0,
            second: 0,
            of: latestWakeTime
        ) ?? bedtime

        if candidate >= latestWakeTime {
            candidate = calendar.date(byAdding: .day, value: -1, to: candidate)
                ?? candidate.addingTimeInterval(-86_400)
        }

        return candidate
    }

    private func inferredCycleCount(
        wakeDate: Date,
        referenceBedtime: Date
    ) -> Int {
        let effectiveSleepDuration = max(
            0,
            wakeDate.timeIntervalSince(referenceBedtime) - configuration.sleepOnsetDelay
        )
        let rawCycleCount = Int((effectiveSleepDuration / configuration.cycleLength).rounded())
        return min(
            max(rawCycleCount, configuration.supportedCycles.min() ?? 3),
            configuration.supportedCycles.max() ?? 6
        )
    }

    private func wakeRecommendationSort(
        latestWakeTime: Date
    ) -> (SmartWakeRecommendation, SmartWakeRecommendation) -> Bool {
        { lhs, rhs in
            if lhs.isWithinSmartWindow != rhs.isWithinSmartWindow {
                return lhs.isWithinSmartWindow && !rhs.isWithinSmartWindow
            }

            let lhsDistance = abs(latestWakeTime.timeIntervalSince(lhs.wakeDate))
            let rhsDistance = abs(latestWakeTime.timeIntervalSince(rhs.wakeDate))

            if lhsDistance == rhsDistance {
                return lhs.confidenceScore > rhs.confidenceScore
            }

            return lhsDistance < rhsDistance
        }
    }

    private func markedBestRecommendation(
        in recommendations: [SmartWakeRecommendation],
        bestID: String?
    ) -> [SmartWakeRecommendation] {
        recommendations.map { recommendation in
            let isBest = recommendation.id == bestID

            return SmartWakeRecommendation(
                id: recommendation.id,
                wakeDate: recommendation.wakeDate,
                cycleCount: recommendation.cycleCount,
                estimatedSleepDuration: recommendation.estimatedSleepDuration,
                confidenceScore: recommendation.confidenceScore,
                badge: badge(for: recommendation.cycleCount, isBest: isBest),
                isBest: isBest,
                explanation: recommendation.explanation,
                isWithinSmartWindow: recommendation.isWithinSmartWindow
            )
        }
    }

    private func dateByAdding(minutes: Int, to date: Date) -> Date? {
        calendar.date(byAdding: DateComponents(minute: minutes), to: date)
    }

    private func recommendationID(
        for wakeDate: Date,
        cycleCount: Int,
        suffix: String
    ) -> String {
        "\(suffix)-\(cycleCount)-\(Int(wakeDate.timeIntervalSince1970))"
    }
}
