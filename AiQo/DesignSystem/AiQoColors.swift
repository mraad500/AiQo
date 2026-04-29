import SwiftUI

enum AiQoColors {
    static let mint = Color(hex: "CDF4E4")
    static let beige = Color(hex: "F5D5A6")

    // Softer accents — AiQo brand spec. One step deeper than `mint`/`beige`
    // so progress rings and wellness surfaces hold their weight against
    // `.ultraThinMaterial` without washing out. Used in the Water hero; safe
    // to adopt in future brand-consistent surfaces. Additive: do not replace
    // `mint`/`beige`.
    static let mintSoft = Color(hex: "B7E5D2")
    static let sandSoft = Color(hex: "EBCF97")
}
