import SwiftUI
import UIKit

enum ProfileEditField {
    case name
    case age
    case height
    case weight

    var title: String {
        switch self {
        case .name:
            return NSLocalizedString("screen.profile.editName.title", value: "Your Name", comment: "")
        case .age:
            return NSLocalizedString("screen.profile.editAge.title", value: "Update Age", comment: "")
        case .height:
            return NSLocalizedString("screen.profile.editHeight.title", value: "Update Height", comment: "")
        case .weight:
            return NSLocalizedString("screen.profile.editWeight.title", value: "Update Weight", comment: "")
        }
    }

    var message: String {
        switch self {
        case .name:
            return NSLocalizedString("screen.profile.editName.message", value: "Edit your display name", comment: "")
        case .age:
            return NSLocalizedString("screen.profile.editAge.message", value: "How old are you?", comment: "")
        case .height:
            return NSLocalizedString("screen.profile.editHeight.message", value: "Enter height in cm", comment: "")
        case .weight:
            return NSLocalizedString("screen.profile.editWeight.message", value: "Enter weight in kg", comment: "")
        }
    }

    var placeholder: String {
        switch self {
        case .name:
            return NSLocalizedString("screen.profile.editName.placeholder", value: "Name", comment: "")
        case .age:
            return NSLocalizedString("screen.profile.editAge.placeholder", value: "Years", comment: "")
        case .height:
            return NSLocalizedString("screen.profile.editHeight.placeholder", value: "CM", comment: "")
        case .weight:
            return NSLocalizedString("screen.profile.editWeight.placeholder", value: "KG", comment: "")
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .name:
            return .default
        case .age, .height, .weight:
            return .numberPad
        }
    }
}

struct BioMetricDetail: Identifiable {
    let id: String
    let title: String
    let value: String
    let unit: String
    let symbol: String
    let tone: ProfileSurfaceTone

    var valueText: String {
        [value, unit]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct BioScanHighlight {
    let title: String
    let value: String
    let symbol: String
}

struct ProfileLevelSummary {
    let level: Int
    let progress: CGFloat
    let lineScore: Int

    var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    static func load() -> ProfileLevelSummary {
        let store = LevelStore.shared
        return ProfileLevelSummary(
            level: max(store.currentLevel, 1),
            progress: CGFloat(min(max(store.progress, 0), 1)),
            lineScore: max(store.totalXP, 0)
        )
    }
}

// Every token is `Color(light:dark:)` so the profile screen adapts to dark
// mode. Light values are byte-identical to the original palette — light mode
// is unchanged; only the dark side is new. Dark values follow the app's
// established glass aesthetic (deep background aligned with AiQoTheme,
// heavily-reduced white sheen so glossy edges don't glare).
enum ProfilePalette {
    static let backgroundTop = Color(light: .white, dark: Color(hex: "0B1016"))
    static let backgroundBottom = Color(light: .white, dark: Color(hex: "0E151D"))
    static let mint = Color(
        light: Color(red: 0.77, green: 0.94, blue: 0.86),
        dark: Color(hex: "5ECDB7")
    )
    static let sand = Color(
        light: Color(red: 0.97, green: 0.84, blue: 0.64),
        dark: Color(hex: "C9A86A")
    )
    static let pearl = Color(light: Color(hex: "FFF8EF"), dark: Color(hex: "1B2531"))
    static let textPrimary = Color(light: .black.opacity(0.84), dark: Color(hex: "F6F8FB"))
    static let textSecondary = Color(light: .black.opacity(0.58), dark: Color(hex: "AAB6C3"))
    static let textTertiary = Color(light: .black.opacity(0.38), dark: Color(hex: "7C8896"))
    static let whiteGlass = Color(
        light: Color(hex: "FFF8EF").opacity(0.92),
        dark: Color(hex: "232E3B")
    )
    static let whiteSoft = Color(
        light: Color(hex: "FFF8EF").opacity(0.72),
        dark: Color(hex: "1E2835")
    )
    static let stroke = Color(light: .white.opacity(0.66), dark: .white.opacity(0.10))
    static let shadow = Color(light: .black.opacity(0.04), dark: .black.opacity(0.32))
    static let innerGlow = Color(light: .white.opacity(0.72), dark: .white.opacity(0.06))
    static let innerShade = Color(light: .black.opacity(0.028), dark: .black.opacity(0.10))

    // Centralized glass tokens — replace the scattered Color.white/black
    // literals in ProfileScreenComponents so the glossy rim/sheen/shadow
    // softens in dark mode instead of glaring.
    static let rimBright = Color(light: .white.opacity(0.80), dark: .white.opacity(0.12))
    static let rimMedium = Color(light: .white.opacity(0.42), dark: .white.opacity(0.07))
    static let rimFaint = Color(light: .white.opacity(0.28), dark: .white.opacity(0.05))
    static let glassSheen = Color(light: .white.opacity(0.09), dark: .white.opacity(0.03))
    static let trackFill = Color(light: .white.opacity(0.36), dark: .white.opacity(0.08))
    static let thumbFill = Color(light: .white.opacity(0.94), dark: Color(hex: "E7ECF1"))
    static let hairline = Color(light: .black.opacity(0.06), dark: .white.opacity(0.12))
    static let shadowSoft = Color(light: .black.opacity(0.10), dark: .black.opacity(0.40))
    static let shadowFaint = Color(light: .black.opacity(0.02), dark: .black.opacity(0.22))
    static let backdropGlow = Color(
        light: .white.opacity(0.28),
        dark: Color(hex: "5ECDB7").opacity(0.05)
    )
}

enum ProfileSurfaceTone {
    case sand
    case mint
    case pearl

    var gradient: [Color] {
        switch self {
        case .sand:
            return [
                Color(light: Color(red: 0.97, green: 0.84, blue: 0.64), dark: Color(hex: "2C2317")),
                Color(light: Color(hex: "EDCB8E"), dark: Color(hex: "261D12")),
                Color(light: Color(hex: "F5DEBB"), dark: Color(hex: "1F170D"))
            ]
        case .mint:
            return [
                Color(light: Color(red: 0.77, green: 0.94, blue: 0.86), dark: Color(hex: "16312B")),
                Color(
                    light: Color(red: 0.77, green: 0.94, blue: 0.86).opacity(0.85),
                    dark: Color(hex: "132A24")
                ),
                Color(
                    light: Color(red: 0.77, green: 0.94, blue: 0.86).opacity(0.65),
                    dark: Color(hex: "0F211D")
                )
            ]
        case .pearl:
            return [
                Color(light: Color(hex: "FFF8EF"), dark: Color(hex: "1B2430")),
                Color(light: Color(hex: "F8EFE2"), dark: Color(hex: "171F29")),
                Color(light: Color(hex: "F0E5D5"), dark: Color(hex: "131A23"))
            ]
        }
    }

    var shadowTint: Color {
        switch self {
        case .sand:
            return Color(
                light: Color(red: 0.97, green: 0.84, blue: 0.64).opacity(0.32),
                dark: .black.opacity(0.42)
            )
        case .mint:
            return Color(
                light: Color(red: 0.77, green: 0.94, blue: 0.86).opacity(0.28),
                dark: .black.opacity(0.42)
            )
        case .pearl:
            return Color(light: Color(hex: "E2D7C6").opacity(0.38), dark: .black.opacity(0.40))
        }
    }

    var topSheen: Color {
        switch self {
        case .sand:
            return Color(light: .white.opacity(0.42), dark: .white.opacity(0.05))
        case .mint:
            return Color(light: .white.opacity(0.38), dark: .white.opacity(0.05))
        case .pearl:
            return Color(light: .white.opacity(0.46), dark: .white.opacity(0.06))
        }
    }

    var bottomTint: Color {
        switch self {
        case .sand:
            return Color(
                light: Color(red: 0.97, green: 0.84, blue: 0.64).opacity(0.12),
                dark: .black.opacity(0.12)
            )
        case .mint:
            return Color(
                light: Color(red: 0.77, green: 0.94, blue: 0.86).opacity(0.12),
                dark: .black.opacity(0.12)
            )
        case .pearl:
            return Color(light: Color(hex: "EEE5D8").opacity(0.26), dark: .black.opacity(0.12))
        }
    }

    var rimStart: Color {
        switch self {
        case .sand, .mint:
            return Color(light: .white.opacity(0.82), dark: .white.opacity(0.12))
        case .pearl:
            return Color(light: .white.opacity(0.88), dark: .white.opacity(0.12))
        }
    }

    var rimEnd: Color {
        switch self {
        case .sand, .mint:
            return Color(light: .white.opacity(0.26), dark: .white.opacity(0.04))
        case .pearl:
            return Color(light: .white.opacity(0.34), dark: .white.opacity(0.05))
        }
    }

    var materialOpacity: Double {
        switch self {
        case .sand, .mint:
            return 0.0
        case .pearl:
            return 0.10
        }
    }
}
