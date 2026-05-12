import SwiftUI

// MARK: - PlanPalette
//
// Single source of truth for the Plan feature's color palette. The Plan
// surface uses ONLY the four AiQo brand colors — mint, sand, lavender,
// lemon — and a small set of neutral grays. No saturated coral / blue /
// orange. The visual hierarchy comes from typography, spacing, and
// material layering — not color noise.

enum PlanPalette {
    // MARK: Brand colors (the only colors used on this surface)

    /// Primary brand mint — calm, trustworthy. Used for CTAs, primary
    /// actions, completion states, and the dominant active surface.
    static let mint = Color(red: 0.77, green: 0.94, blue: 0.86)

    /// Secondary brand sand/beige — warm, grounded. Used for the
    /// "you're working" surfaces (active plan card, runner background)
    /// and as a secondary accent on cards.
    static let sand = Color(red: 0.97, green: 0.86, blue: 0.66)

    /// Tertiary brand lavender — premium, focused. Used for movement /
    /// progression accents (legs, glutes, equipment-machine) and for
    /// the rest-timer gradient where blue-purple felt out of brand.
    static let lavender = Color(red: 0.84, green: 0.74, blue: 0.96)

    /// Highlight brand lemon — energy, attention. Used very sparingly:
    /// streak flames, energy templates, the "quick cue" callout. Never
    /// as a base fill on a large surface.
    static let lemon = Color(red: 0.99, green: 0.91, blue: 0.62)

    // MARK: Deeper variants for stronger contrast (used on text and icons
    // sitting on the same-family pastel — e.g. mint icon on mint surface).

    static let mintDeep = Color(red: 0.32, green: 0.62, blue: 0.52)
    static let sandDeep = Color(red: 0.68, green: 0.50, blue: 0.22)
    static let lavenderDeep = Color(red: 0.55, green: 0.42, blue: 0.72)
    static let lemonDeep = Color(red: 0.62, green: 0.52, blue: 0.18)

    // MARK: Neutral grays — kept neutral, brand-warm undertone

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let hairline = Color.primary.opacity(0.08)
    static let surfaceTint = Color.primary.opacity(0.04)

    // MARK: Brand families — a (pastel, deep) pair carrying both fill and ink

    enum Family: CaseIterable {
        case mint, sand, lavender, lemon

        var pastel: Color {
            switch self {
            case .mint: PlanPalette.mint
            case .sand: PlanPalette.sand
            case .lavender: PlanPalette.lavender
            case .lemon: PlanPalette.lemon
            }
        }

        var ink: Color {
            switch self {
            case .mint: PlanPalette.mintDeep
            case .sand: PlanPalette.sandDeep
            case .lavender: PlanPalette.lavenderDeep
            case .lemon: PlanPalette.lemonDeep
            }
        }
    }
}
