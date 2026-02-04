import UIKit

enum Colors {
    static let bg   = UIColor.systemBackground
    static let card = UIColor.secondarySystemBackground
    static let subtext = UIColor.secondaryLabel

    static let background = UIColor.systemBackground
    static let text = UIColor.label

    static let mint  = UIColor(red: 0.77, green: 0.94, blue: 0.86, alpha: 1)
    static let sand  = UIColor(red: 0.97, green: 0.84, blue: 0.64, alpha: 1)
    static let accent = UIColor(red: 1.00, green: 0.90, blue: 0.55, alpha: 1)
    static let aiqoBeige = UIColor(red: 0.98, green: 0.87, blue: 0.70, alpha: 1)
    // ✅ Add these
    static let lemon = UIColor(red: 1.00, green: 0.93, blue: 0.72, alpha: 1)
    static let lav   = UIColor(red: 0.96, green: 0.88, blue: 1.00, alpha: 1)
}

import SwiftUI
extension Color {
    static let brandMint = Color(red: 0.77, green: 0.94, blue: 0.86)
    static let brandSand = Color(red: 0.97, green: 0.84, blue: 0.64)
    static let aiqoBeige = Color(red: 0.98, green: 0.87, blue: 0.70)
}
import SwiftUI

extension Color {

    static let aiqoText   = Color(Colors.text)
    static let aiqoSub    = Color(Colors.subtext)

    static let aiqoMint   = Color(Colors.mint)
    static let aiqoSand   = Color(Colors.sand)
    static let aiqoAccent = Color(Colors.accent)

    static let aiqoLemon  = Color(Colors.lemon)
    static let aiqoLav    = Color(Colors.lav)
}
