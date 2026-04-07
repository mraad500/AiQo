import UIKit

// MARK: - AiQo Colors
enum Colors {
    // Base colors
    static let bg = UIColor.systemBackground
    static let card = UIColor.secondarySystemBackground
    static let subtext = UIColor.secondaryLabel
    static let background = UIColor.systemBackground
    static let text = UIColor.label
    
    // Brand colors - Soft pastels
    static let mint = UIColor(red: 0.77, green: 0.94, blue: 0.86, alpha: 1)      // #C4F0DB
    static let sand = UIColor(red: 0.97, green: 0.84, blue: 0.64, alpha: 1)      // #F8D6A3
    static let accent = UIColor(red: 1.00, green: 0.90, blue: 0.55, alpha: 1)    // #FFE68C
    static let aiqoBeige = UIColor(red: 0.98, green: 0.87, blue: 0.70, alpha: 1) // #FADEB3
    static let lemon = UIColor(red: 1.00, green: 0.93, blue: 0.72, alpha: 1)     // #FFECB8
    static let lav = UIColor(red: 0.96, green: 0.88, blue: 1.00, alpha: 1)       // #F5E0FF
    
    // Semantic colors
    static let currentUserHighlight = mint
    static let defaultRowBackground = UIColor.white
    static let levelBadgeBackground = sand
}

// MARK: - SwiftUI Color Extensions
import SwiftUI

extension Color {
    static let brandMint = Color(red: 0.77, green: 0.94, blue: 0.86)
    static let brandSand = Color(red: 0.97, green: 0.84, blue: 0.64)
    static let aiqoBeige = Color(red: 0.98, green: 0.87, blue: 0.70)
    
    static let aiqoText = Color(Colors.text)
    static let aiqoSub = Color(Colors.subtext)
    static let aiqoMint = Color(Colors.mint)
    static let aiqoSand = Color(Colors.sand)
    static let aiqoAccent = Color(Colors.accent)
    static let aiqoLemon = Color(Colors.lemon)
    static let aiqoLav = Color(Colors.lav)
    static let kitchenMint = Color(Colors.mint)

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
