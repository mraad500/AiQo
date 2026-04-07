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

enum ProfilePalette {
    static let backgroundTop = Color.white
    static let backgroundBottom = Color.white
    static let mint = Color(red: 0.77, green: 0.94, blue: 0.86)
    static let sand = Color(red: 0.97, green: 0.84, blue: 0.64)
    static let pearl = Color(hex: "FFF8EF")
    static let textPrimary = Color.black.opacity(0.84)
    static let textSecondary = Color.black.opacity(0.58)
    static let textTertiary = Color.black.opacity(0.38)
    static let whiteGlass = ProfilePalette.pearl.opacity(0.92)
    static let whiteSoft = ProfilePalette.pearl.opacity(0.72)
    static let stroke = Color.white.opacity(0.66)
    static let shadow = Color.black.opacity(0.04)
    static let innerGlow = Color.white.opacity(0.72)
    static let innerShade = Color.black.opacity(0.028)
}

enum ProfileSurfaceTone {
    case sand
    case mint
    case pearl

    var gradient: [Color] {
        switch self {
        case .sand:
            return [
                ProfilePalette.sand,
                Color(hex: "EDCB8E"),
                Color(hex: "F5DEBB")
            ]
        case .mint:
            return [
                ProfilePalette.mint,
                ProfilePalette.mint.opacity(0.85),
                ProfilePalette.mint.opacity(0.65)
            ]
        case .pearl:
            return [
                Color(hex: "FFF8EF"),
                Color(hex: "F8EFE2"),
                Color(hex: "F0E5D5")
            ]
        }
    }

    var shadowTint: Color {
        switch self {
        case .sand:
            return ProfilePalette.sand.opacity(0.32)
        case .mint:
            return ProfilePalette.mint.opacity(0.28)
        case .pearl:
            return Color(hex: "E2D7C6").opacity(0.38)
        }
    }

    var topSheen: Color {
        switch self {
        case .sand:
            return Color.white.opacity(0.42)
        case .mint:
            return Color.white.opacity(0.38)
        case .pearl:
            return Color.white.opacity(0.46)
        }
    }

    var bottomTint: Color {
        switch self {
        case .sand:
            return ProfilePalette.sand.opacity(0.12)
        case .mint:
            return ProfilePalette.mint.opacity(0.12)
        case .pearl:
            return Color(hex: "EEE5D8").opacity(0.26)
        }
    }

    var rimStart: Color {
        switch self {
        case .sand, .mint:
            return Color.white.opacity(0.82)
        case .pearl:
            return Color.white.opacity(0.88)
        }
    }

    var rimEnd: Color {
        switch self {
        case .sand, .mint:
            return Color.white.opacity(0.26)
        case .pearl:
            return Color.white.opacity(0.34)
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
