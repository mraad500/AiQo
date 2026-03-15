import Foundation
import SwiftUI

enum TribeDashboardTab: String, CaseIterable, Identifiable {
    case tribe
    case arena
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tribe:
            return "القبيلة"
        case .arena:
            return "الأرينا"
        case .global:
            return "العالمي"
        }
    }
}

enum TribeSectorColor: String, CaseIterable, Identifiable {
    case blue
    case green
    case yellow
    case red
    case purple

    static let memberDisplayOrder: [TribeSectorColor] = [.blue, .green, .yellow, .red, .purple]
    static let ringVisualOrder: [TribeSectorColor] = [.yellow, .purple, .blue, .green, .red]

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .blue:
            return "Blue.Tribe.Ring"
        case .green:
            return "Green.Tribe.Ring"
        case .yellow:
            return "Yellow.Tribe.Ring"
        case .red:
            return "Red.Tribe.Ring"
        case .purple:
            return "purple.Tribe.Ring"
        }
    }

    var accent: Color {
        switch self {
        case .blue:
            return Color(hex: "2A71EA")
        case .green:
            return Color(hex: "51E9D1")
        case .yellow:
            return Color(hex: "F8A967")
        case .red:
            return Color(hex: "DF3750")
        case .purple:
            return Color(hex: "9751F6")
        }
    }

    var glowColor: Color {
        accent.opacity(0.24)
    }

    var haloColor: Color {
        Color(light: Color.white.opacity(0.55), dark: Color.white.opacity(0.16))
    }

    var ambientOffset: CGSize {
        switch self {
        case .blue:
            return CGSize(width: 0.04, height: -0.18)
        case .green:
            return CGSize(width: 0.12, height: 0.03)
        case .yellow:
            return CGSize(width: 0.00, height: -0.24)
        case .red:
            return CGSize(width: 0.00, height: 0.26)
        case .purple:
            return CGSize(width: -0.12, height: 0.08)
        }
    }

    var segmentName: String {
        switch self {
        case .blue:
            return "الأزرق"
        case .green:
            return "الأخضر"
        case .yellow:
            return "الذهبي"
        case .red:
            return "القرمزي"
        case .purple:
            return "البنفسجي"
        }
    }

    var memberLabel: String {
        switch self {
        case .blue:
            return "القطاع الأزرق"
        case .green:
            return "القطاع الأخضر"
        case .yellow:
            return "القطاع الذهبي"
        case .red:
            return "القطاع القرمزي"
        case .purple:
            return "القطاع البنفسجي"
        }
    }
}

struct TribeSummary {
    var eyebrow: String
    var title: String
    var summary: String
    var memberBadge: String
    var progress: Double
    var progressValue: String
    var progressLabel: String
    var ringSegmentTarget: Int
}

struct TribeStatMiniCardModel: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let accent: Color
}

struct TribeRingMember: Identifiable {
    let id: String
    let memberId: String?
    let name: String
    let role: TribeMemberRole
    let energyToday: Int
    let level: Int
    let sectorColor: TribeSectorColor
    let isCurrentUser: Bool
    let isVacant: Bool

    init(member: TribeMember, sectorColor: TribeSectorColor, isCurrentUser: Bool) {
        self.id = member.id
        self.memberId = member.id
        self.name = isCurrentUser ? "tribe.mock.selfName".localized : member.visibleDisplayName
        self.role = member.role
        self.energyToday = member.energyToday
        self.level = member.level
        self.sectorColor = sectorColor
        self.isCurrentUser = isCurrentUser
        self.isVacant = false
    }

    init(slot: Int, sectorColor: TribeSectorColor) {
        self.id = "tribe-slot-\(slot)"
        self.memberId = nil
        self.name = "مقعد جديد"
        self.role = .member
        self.energyToday = 0
        self.level = 0
        self.sectorColor = sectorColor
        self.isCurrentUser = false
        self.isVacant = true
    }

    var displayName: String {
        name
    }

    var roleTitle: String {
        isVacant ? "مقعد مفتوح" : role.presentationTitle
    }

    var levelText: String {
        isVacant ? "بانتظار عضو" : "مستوى \(level)"
    }

    var contributionValue: String {
        isVacant ? "—" : energyToday.formatted(.number.grouping(.automatic))
    }

    var contributionLabel: String {
        isVacant ? "مقعد متاح" : "طاقة اليوم"
    }

    var segmentLabel: String {
        sectorColor.memberLabel
    }
}

struct TribeGlobalRankEntry: Identifiable {
    let id: String
    let memberId: String?
    let rank: Int
    let name: String
    let caption: String
    let score: Int
    let streakDays: Int
    let accent: Color
    let isCurrentUser: Bool
    let isTribeMember: Bool

    var formattedScore: String {
        score.formatted(.number.grouping(.automatic))
    }
}

enum ArenaScopeFilter: String, CaseIterable, Identifiable {
    case tribes
    case everyone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tribes:
            return "القبائل"
        case .everyone:
            return "الجميع"
        }
    }
}

enum GlobalTimeFilter: String, CaseIterable, Identifiable {
    case today
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "اليوم"
        case .sevenDays:
            return "7 أيام"
        case .thirtyDays:
            return "30 يوم"
        }
    }
}

struct ArenaHeroSummary {
    let title: String
    let subtitle: String
    let activeCountText: String
}

enum ArenaChallengeStatus: String {
    case active = "نشط"
    case join = "انضم"

    var title: String { rawValue }
    var isCallToAction: Bool { self == .join }
}

struct ArenaFeaturedMatchup: Identifiable {
    let id: String
    let leftTitle: String
    let rightTitle: String
    let leftProgress: Double
    let rightProgress: Double
    let remainingText: String
    let badgeText: String
    let badgeTint: Color
}

struct ArenaCompactChallenge: Identifiable {
    let id: String
    let title: String
    let category: String
    let status: ArenaChallengeStatus
    let progressCurrent: Int
    let progressTotal: Int
    let participantLabel: String
    let timeLeftLabel: String
    let accentColor: Color
    let scope: ArenaScopeFilter

    var progress: Double {
        guard progressTotal > 0 else { return 0 }
        return min(max(Double(progressCurrent) / Double(progressTotal), 0), 1)
    }

    var progressText: String {
        "\(progressCurrent.arenaFormatted) / \(progressTotal.arenaFormatted)"
    }

    static let mockData: [ArenaCompactChallenge] = [
        ArenaCompactChallenge(
            id: "arena-steps-50k",
            title: "سباق 50K خطوة",
            category: "خطوات",
            status: .active,
            progressCurrent: 37_600,
            progressTotal: 50_000,
            participantLabel: "3 قبائل",
            timeLeftLabel: "باقي 11 ساعة",
            accentColor: TribeModernPalette.mintDeep,
            scope: .tribes
        ),
        ArenaCompactChallenge(
            id: "arena-zone2-war",
            title: "حرب Zone 2",
            category: "Zone 2",
            status: .join,
            progressCurrent: 34,
            progressTotal: 60,
            participantLabel: "121 لاعب",
            timeLeftLabel: "باقي 7 ساعة",
            accentColor: TribeModernPalette.sky,
            scope: .everyone
        ),
        ArenaCompactChallenge(
            id: "arena-water-series",
            title: "3 أيام ماء",
            category: "ماء",
            status: .active,
            progressCurrent: 28,
            progressTotal: 40,
            participantLabel: "3 قبائل",
            timeLeftLabel: "باقي 8 ساعة",
            accentColor: TribeModernPalette.sand,
            scope: .tribes
        ),
        ArenaCompactChallenge(
            id: "arena-sleep-streak",
            title: "سلسلة النوم",
            category: "نوم",
            status: .join,
            progressCurrent: 26,
            progressTotal: 40,
            participantLabel: "2 قبائل",
            timeLeftLabel: "باقي 18 يوم",
            accentColor: TribeModernPalette.lavender,
            scope: .tribes
        )
    ]
}

struct ArenaRecentWinner: Identifiable {
    let id: String
    let name: String
    let achievement: String
    let accent: Color
}

enum GlobalRankingTrend {
    case up
    case down
    case stable

    var symbolName: String {
        switch self {
        case .up:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .stable:
            return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up:
            return TribeModernPalette.mintDeep
        case .down:
            return Color(light: Color(hex: "E6938E"), dark: Color(hex: "D88486"))
        case .stable:
            return TribeModernPalette.textTertiary
        }
    }
}

struct GlobalRankingRowItem: Identifiable {
    let id: String
    let rank: Int
    let name: String
    let caption: String
    let scoreText: String
    let accent: Color
    let trend: GlobalRankingTrend
    let isCurrentUser: Bool
}

struct GlobalSelfRankSummary {
    let title: String
    let percentileText: String
    let scoreText: String
}

enum TribePremiumTokens {
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let cardSpacing: CGFloat = 14
    static let cardRadius: CGFloat = 32
    static let cardPadding: CGFloat = 20
}

enum TribeModernPalette {
    static let backgroundBase = Color(light: .white, dark: Color(hex: "0B1016"))
    static let backgroundTop = Color(light: Color(hex: "FBF8F1"), dark: Color(hex: "0B1216"))
    static let backgroundMiddle = Color(light: Color(hex: "F4F7F0"), dark: Color(hex: "101A1F"))
    static let backgroundBottom = Color(light: Color(hex: "EEF3EC"), dark: Color(hex: "121C22"))
    static let backgroundMintGlow = Color(light: Color(hex: "CFEFE3"), dark: Color(hex: "1F3B37"))
    static let backgroundSandGlow = Color(light: Color(hex: "F4DFC0"), dark: Color(hex: "3A2E21"))
    static let backgroundWhiteGlow = Color(light: Color.white.opacity(0.66), dark: Color.white.opacity(0.04))
    static let surfaceTop = Color(light: Color.white.opacity(0.96), dark: Color(hex: "162028").opacity(0.96))
    static let surfaceBottom = Color(light: Color(hex: "F8F6F2").opacity(0.96), dark: Color(hex: "1A252F").opacity(0.96))
    static let surfaceHighlight = Color(light: Color.white.opacity(0.78), dark: Color.white.opacity(0.06))
    static let surfaceOverlay = Color(light: Color.white.opacity(0.98), dark: Color(hex: "1A2330").opacity(0.96))
    static let accentFlash = Color(light: Color.white.opacity(0.05), dark: Color.white.opacity(0.02))
    static let border = Color(light: Color(hex: "D8E4DA").opacity(0.92), dark: Color.white.opacity(0.08))
    static let borderStrong = Color(light: Color.white.opacity(0.88), dark: Color.white.opacity(0.12))
    static let textPrimary = Color(light: Color(hex: "162027"), dark: Color(hex: "F5F7FA"))
    static let textSecondary = Color(light: Color(hex: "62707A"), dark: Color(hex: "A8B2BA"))
    static let textTertiary = Color(light: Color(hex: "88949D"), dark: Color(hex: "7D8A95"))
    static let shadow = Color(light: Color.black.opacity(0.10), dark: Color.black.opacity(0.34))
    static let mint = Color(light: Color(hex: "A7E3D5"), dark: Color(hex: "7FD3C4"))
    static let mintDeep = Color(light: Color(hex: "69C9B6"), dark: Color(hex: "8EDCCC"))
    static let sky = Color(light: Color(hex: "B7DDF4"), dark: Color(hex: "6DA8CC"))
    static let sand = Color(light: Color(hex: "EBD3AE"), dark: Color(hex: "B89B6E"))
    static let sandSoft = Color(light: Color(hex: "F5E7D1"), dark: Color(hex: "4B4030"))
    static let warm = Color(light: Color(hex: "E8C587"), dark: Color(hex: "C49A5E"))
    static let cardTint = Color(light: Color(hex: "EEF7F3"), dark: Color(hex: "18242B"))
    static let lavender = Color(light: Color(hex: "C9B8F5"), dark: Color(hex: "7C69B7"))
    static let controlFill = Color(light: Color(hex: "F7F8F7"), dark: Color(hex: "151D26"))
    static let controlSelectedFill = Color(light: Color.white.opacity(0.94), dark: Color(hex: "202A35").opacity(0.96))
    static let subtleSurface = Color(light: Color(hex: "F8F9F9"), dark: Color(hex: "141C25"))
    static let chipBackground = Color(light: Color(hex: "F2F5F7"), dark: Color(hex: "1A2430"))
    static let progressTrack = Color(light: Color(hex: "EEF1F1"), dark: Color(hex: "1C2530"))
    static let ringCenterTop = Color(light: Color.white.opacity(0.94), dark: Color(hex: "24303A").opacity(0.98))
    static let ringCenterBottom = Color(light: Color(hex: "F5E7D1").opacity(0.50), dark: Color(hex: "182127").opacity(0.98))
    static let crownSurface = Color(light: Color.white, dark: Color(hex: "111922"))
}

extension TribeMemberRole {
    var presentationTitle: String {
        switch self {
        case .owner:
            return "القائد"
        case .admin:
            return "منسق"
        case .member:
            return "عضو"
        }
    }
}

extension TribeChallengeMetricType {
    var premiumAccent: Color {
        Color(hue: accentHue, saturation: 0.64, brightness: 0.92)
    }
}

extension TribeChallenge {
    var presentationStateLabel: String {
        if status == .ended {
            return "مغلق"
        }

        if progress >= 0.85 {
            return "قريب"
        }

        if isCuratedGlobal {
            return "مختار"
        }

        return "نشط"
    }
}

extension TribeChallengeMetricType {
    var arenaCategoryLabel: String {
        switch self {
        case .steps:
            return "خطوات"
        case .water:
            return "ماء"
        case .sleep:
            return "نوم"
        case .minutes:
            return "Zone 2"
        case .custom:
            return "تمرين"
        case .sugarFree:
            return "استمرار"
        case .calmMinutes:
            return "هدوء"
        }
    }
}

extension String {
    var tribeDisplayInitials: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "A" }

        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            let first = words[0].prefix(1)
            let second = words[1].prefix(1)
            return String(first + second)
        }

        return String(trimmed.prefix(2))
    }
}

private enum ArenaNumberFormatter {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

private extension Int {
    var arenaFormatted: String {
        ArenaNumberFormatter.formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
