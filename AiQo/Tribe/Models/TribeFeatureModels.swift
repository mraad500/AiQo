import Foundation

struct TribeFeatureFlags {
    private static func flag(named key: String, default defaultValue: Bool) -> Bool {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key)

        if let boolValue = rawValue as? Bool {
            return boolValue
        }

        if let stringValue = rawValue as? String {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                break
            }
        }

        return defaultValue
    }

    /// Read from Info.plist so backend can be enabled via a new build without code changes
    static var backendEnabled: Bool {
        flag(named: "TRIBE_BACKEND_ENABLED", default: false)
    }
    /// Read from Info.plist — when true, Tribe requires active subscription
    static var subscriptionGateEnabled: Bool {
        flag(named: "TRIBE_SUBSCRIPTION_GATE_ENABLED", default: false)
    }
    /// Whether the Tribe tab is visible at all — hide if not ready for launch
    static var featureVisible: Bool {
        flag(named: "TRIBE_FEATURE_VISIBLE", default: true)
    }
}

enum TribeScreenTab: String, CaseIterable, Identifiable, Hashable, Codable {
    case hub
    case arena
    case log
    case galaxy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hub:
            return "tribe.tab.hub".localized
        case .arena:
            return "tribe.tab.arena".localized
        case .log:
            return "tribe.tab.log".localized
        case .galaxy:
            return "tribe.tab.galaxy".localized
        }
    }
}

enum GalaxyLayoutStyle: String, CaseIterable, Identifiable, Hashable, Codable {
    case network
    case spokes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network:
            return "tribe.galaxy.layout.network".localized
        case .spokes:
            return "tribe.galaxy.layout.spokes".localized
        }
    }
}

enum GalaxyCardMode: String, CaseIterable, Identifiable, Codable {
    case network
    case arena

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network:
            return "tribe.galaxy.mode.network".localized
        case .arena:
            return "tribe.galaxy.mode.arena".localized
        }
    }
}

enum ChallengeScope: String, CaseIterable, Identifiable, Hashable, Codable {
    case personal
    case tribe
    case galaxy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal:
            return "tribe.challenge.scope.personal".localized
        case .tribe:
            return "tribe.challenge.scope.tribe".localized
        case .galaxy:
            return "tribe.challenge.scope.galaxy".localized
        }
    }
}

enum ChallengeCadence: String, CaseIterable, Identifiable, Hashable, Codable {
    case daily
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "tribe.challenge.cadence.daily".localized
        case .monthly:
            return "tribe.challenge.cadence.monthly".localized
        }
    }

    var sectionTitle: String {
        switch self {
        case .daily:
            return "tribe.challenge.section.daily".localized
        case .monthly:
            return "tribe.challenge.section.monthly".localized
        }
    }
}

enum TribeChallengeMetricType: String, CaseIterable, Identifiable, Hashable, Codable {
    case steps
    case water
    case sleep
    case minutes
    case custom
    case sugarFree
    case calmMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps:
            return "tribe.metric.steps".localized
        case .water:
            return "tribe.metric.water".localized
        case .sleep:
            return "tribe.metric.sleep".localized
        case .minutes:
            return "tribe.metric.minutes".localized
        case .custom:
            return "tribe.metric.custom".localized
        case .sugarFree:
            return "tribe.metric.sugarFree".localized
        case .calmMinutes:
            return "tribe.metric.calmMinutes".localized
        }
    }

    var unitLabel: String {
        switch self {
        case .steps:
            return "tribe.unit.steps".localized
        case .water:
            return "tribe.unit.water".localized
        case .sleep:
            return "tribe.unit.sleep".localized
        case .minutes:
            return "tribe.unit.minutes".localized
        case .custom:
            return "tribe.unit.custom".localized
        case .sugarFree:
            return "tribe.unit.sugarFree".localized
        case .calmMinutes:
            return "tribe.unit.minutes".localized
        }
    }

    var iconName: String {
        switch self {
        case .steps:
            return "figure.walk"
        case .water:
            return "drop.fill"
        case .sleep:
            return "moon.zzz.fill"
        case .minutes, .calmMinutes:
            return "timelapse"
        case .custom:
            return "sparkles"
        case .sugarFree:
            return "leaf.fill"
        }
    }

    var accentHue: Double {
        switch self {
        case .steps:
            return 0.58
        case .water:
            return 0.52
        case .sleep:
            return 0.64
        case .minutes:
            return 0.70
        case .custom:
            return 0.74
        case .sugarFree:
            return 0.38
        case .calmMinutes:
            return 0.66
        }
    }

    var defaultIncrement: Int {
        switch self {
        case .steps:
            return 2_500
        case .water:
            return 2
        case .sleep:
            return 2
        case .minutes:
            return 10
        case .custom:
            return 1
        case .sugarFree:
            return 1
        case .calmMinutes:
            return 10
        }
    }
}

typealias ChallengeGoalType = TribeChallengeMetricType

enum TribeChallengeStatus: String, Codable, CaseIterable, Equatable {
    case active
    case ended
}

struct TribeChallengeProgressSummary: Codable, Equatable {
    var valueText: String
    var percentComplete: Double
}

struct TribeChallenge: Identifiable, Codable, Equatable {
    let id: String
    var scope: ChallengeScope
    var cadence: ChallengeCadence
    var title: String
    var subtitle: String
    var metricType: TribeChallengeMetricType
    var targetValue: Int
    var progressValue: Int
    var startAt: Date
    var endAt: Date
    var createdByUserId: String?
    var isCuratedGlobal: Bool
    var status: TribeChallengeStatus
    var participantsCount: Int
    var unitOverride: String?

    init(
        id: String,
        scope: ChallengeScope,
        cadence: ChallengeCadence,
        title: String,
        subtitle: String = "",
        metricType: TribeChallengeMetricType,
        targetValue: Int,
        progressValue: Int = 0,
        startAt: Date = .now,
        endAt: Date,
        createdByUserId: String? = nil,
        isCuratedGlobal: Bool = false,
        status: TribeChallengeStatus = .active,
        participantsCount: Int = 0,
        unitOverride: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.cadence = cadence
        self.title = title
        self.subtitle = subtitle
        self.metricType = metricType
        self.targetValue = targetValue
        self.progressValue = progressValue
        self.startAt = startAt
        self.endAt = endAt
        self.createdByUserId = createdByUserId
        self.isCuratedGlobal = isCuratedGlobal
        self.status = status
        self.participantsCount = participantsCount
        self.unitOverride = unitOverride
    }

    var goalType: ChallengeGoalType {
        get { metricType }
        set { metricType = newValue }
    }

    var createdBy: String {
        get { createdByUserId ?? "system" }
        set { createdByUserId = newValue }
    }

    var endsAt: Date {
        get { endAt }
        set { endAt = newValue }
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(max(Double(progressValue) / Double(targetValue), 0), 1)
    }

    var remainingValue: Int {
        max(targetValue - progressValue, 0)
    }

    var unitLabel: String {
        unitOverride ?? metricType.unitLabel
    }

    var progressSummary: TribeChallengeProgressSummary {
        TribeChallengeProgressSummary(
            valueText: "\(progressValue.formatted(.number.grouping(.automatic)))/\(targetValue.formatted(.number.grouping(.automatic)))",
            percentComplete: progress
        )
    }

    var remainingText: String {
        String(
            format: "tribe.challenge.remaining".localized,
            locale: Locale.current,
            remainingValue.formatted(.number.grouping(.automatic)),
            unitLabel
        )
    }

    func timeRemainingText(reference: Date = .now) -> String {
        let seconds = max(Int(endAt.timeIntervalSince(reference)), 0)

        if cadence == .monthly {
            let days = max(1, Int(ceil(Double(seconds) / 86_400)))
            return String(
                format: "tribe.challenge.timeRemaining.days".localized,
                locale: Locale.current,
                days
            )
        }

        let hours = max(1, Int(ceil(Double(seconds) / 3_600)))
        return String(
            format: "tribe.challenge.timeRemaining.hours".localized,
            locale: Locale.current,
            hours
        )
    }
}

struct ChallengeContribution: Identifiable, Equatable {
    let nodeId: String
    let challengeId: String
    let value: Int

    var id: String { "\(nodeId)-\(challengeId)" }
}

enum ChallengeSuggestionStatus: String, Codable, CaseIterable, Equatable {
    case pendingSuggestion
    case approved
    case rejected
}

struct GalaxyChallengeSuggestion: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var metricType: TribeChallengeMetricType
    var cadence: ChallengeCadence
    var proposedByUserId: String
    var status: ChallengeSuggestionStatus
    var createdAt: Date
}
