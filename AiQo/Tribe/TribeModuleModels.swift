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
            return "الارينا"
        case .global:
            return "العالمي"
        }
    }
}

enum TribeRingSegmentToken: String, CaseIterable, Identifiable {
    case blue
    case skyBlue
    case yellow
    case red
    case purple

    static let ringOrder: [TribeRingSegmentToken] = [.blue, .skyBlue, .yellow, .red, .purple]
    static let revealOrder: [TribeRingSegmentToken] = [.blue, .skyBlue, .yellow, .red, .purple]

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .blue:
            return "Blue.Tribe.Ring"
        case .skyBlue:
            return "sky.blue.Tribe.Ring"
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
            return Color(hex: "3551FF")
        case .skyBlue:
            return Color(hex: "5EDCFF")
        case .yellow:
            return Color(hex: "E8BF55")
        case .red:
            return Color(hex: "FF6D6B")
        case .purple:
            return Color(hex: "A56CFF")
        }
    }

    var glowColor: Color {
        accent.opacity(0.24)
    }

    var ambientOffset: CGSize {
        switch self {
        case .blue:
            return CGSize(width: -0.18, height: -0.22)
        case .skyBlue:
            return CGSize(width: 0.19, height: -0.20)
        case .yellow:
            return CGSize(width: 0.24, height: 0.06)
        case .red:
            return CGSize(width: 0.00, height: 0.25)
        case .purple:
            return CGSize(width: -0.22, height: 0.10)
        }
    }

    var revealStartAngle: Double {
        switch self {
        case .blue:
            return 314
        case .skyBlue:
            return 19
        case .yellow:
            return 86
        case .red:
            return 160
        case .purple:
            return 244
        }
    }

    var revealSweep: Double {
        switch self {
        case .blue:
            return 62
        case .skyBlue:
            return 63
        case .yellow:
            return 66
        case .red:
            return 76
        case .purple:
            return 66
        }
    }

    var memberLabel: String {
        switch self {
        case .blue:
            return "القطاع الأزرق"
        case .skyBlue:
            return "القطاع السماوي"
        case .yellow:
            return "القطاع الذهبي"
        case .red:
            return "القطاع القرمزي"
        case .purple:
            return "القطاع البنفسجي"
        }
    }
}

struct TribeHeroSummary {
    var title: String
    var subtitle: String
    var progress: Double
    var centerValue: String
    var centerLabel: String
}

struct TribeStatCardModel: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let accent: Color
}

struct TribeFeaturedMember: Identifiable {
    let slot: Int
    let segment: TribeRingSegmentToken
    let member: TribeMember?
    let isCurrentUser: Bool

    var id: String {
        member?.id ?? "tribe-slot-\(slot)"
    }

    var isVacant: Bool {
        member == nil
    }

    var displayName: String {
        member?.visibleDisplayName ?? "مقعد جديد"
    }

    var initials: String {
        member?.resolvedInitials ?? "+"
    }

    var roleTitle: String {
        guard let member else { return "مقعد مفتوح" }
        if isCurrentUser {
            return "أنت"
        }
        return member.role.presentationTitle
    }

    var levelText: String {
        guard let member else { return "بانتظار عضو" }
        return "مستوى \(member.level)"
    }

    var energyText: String {
        guard let member else { return "جاهز للانضمام" }
        return "\(member.energyToday.formatted(.number.grouping(.automatic))) طاقة"
    }

    var contributionValue: String {
        guard let member else { return "—" }
        return member.energyToday.formatted(.number.grouping(.automatic))
    }

    var contributionLabel: String {
        member == nil ? "مقعد متاح" : "طاقة اليوم"
    }

    var summary: String {
        guard let member else {
            return "هذا القطاع جاهز لعضو جديد داخل الحلقة."
        }

        if isCurrentUser {
            return "قطاعك يرفع نبض القبيلة اليوم بـ \(member.energyToday.formatted(.number.grouping(.automatic))) نقطة."
        }

        return "يحافظ على حضور ثابت اليوم ويساهم بـ \(member.energyToday.formatted(.number.grouping(.automatic))) نقطة."
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

enum TribePremiumTokens {
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 14
    static let cardRadius: CGFloat = 32
    static let cardPadding: CGFloat = 20
}

enum TribeModernPalette {
    static let backgroundTop = Color(light: Color(hex: "FBF8F1"), dark: Color(hex: "0B1216"))
    static let backgroundMiddle = Color(light: Color(hex: "F4F7F0"), dark: Color(hex: "101A1F"))
    static let backgroundBottom = Color(light: Color(hex: "EEF3EC"), dark: Color(hex: "121C22"))
    static let backgroundMintGlow = Color(light: Color(hex: "CFEFE3"), dark: Color(hex: "1F3B37"))
    static let backgroundSandGlow = Color(light: Color(hex: "F4DFC0"), dark: Color(hex: "3A2E21"))
    static let backgroundWhiteGlow = Color.white.opacity(0.66)
    static let surfaceTop = Color(light: Color.white.opacity(0.96), dark: Color(hex: "162028").opacity(0.96))
    static let surfaceBottom = Color(light: Color(hex: "F8F6F2").opacity(0.96), dark: Color(hex: "1A252F").opacity(0.96))
    static let surfaceHighlight = Color(light: Color.white.opacity(0.78), dark: Color.white.opacity(0.06))
    static let border = Color(light: Color(hex: "D8E4DA").opacity(0.92), dark: Color.white.opacity(0.08))
    static let borderStrong = Color(light: Color.white.opacity(0.88), dark: Color.white.opacity(0.12))
    static let textPrimary = Color(light: Color(hex: "162027"), dark: Color(hex: "F5F7FA"))
    static let textSecondary = Color(light: Color(hex: "62707A"), dark: Color(hex: "A8B2BA"))
    static let textTertiary = Color(light: Color(hex: "88949D"), dark: Color(hex: "7D8A95"))
    static let shadow = Color.black.opacity(0.10)
    static let mint = Color(light: Color(hex: "A7E3D5"), dark: Color(hex: "7FD3C4"))
    static let mintDeep = Color(light: Color(hex: "69C9B6"), dark: Color(hex: "8EDCCC"))
    static let sky = Color(light: Color(hex: "B7DDF4"), dark: Color(hex: "6DA8CC"))
    static let sand = Color(light: Color(hex: "EBD3AE"), dark: Color(hex: "B89B6E"))
    static let sandSoft = Color(light: Color(hex: "F5E7D1"), dark: Color(hex: "4B4030"))
    static let warm = Color(light: Color(hex: "E8C587"), dark: Color(hex: "C49A5E"))
    static let cardTint = Color(light: Color(hex: "EEF7F3"), dark: Color(hex: "18242B"))
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
