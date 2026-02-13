import SwiftUI

/// 🛡️ نظام إدارة المستويات والدروع (Gamification Logic)
enum LevelSystem {
    
    // أنواع الدروع
    enum ShieldTier: String {
        case wood     = "Wood"
        case bronze   = "Bronze"
        case silver   = "Silver"
        case gold     = "Gold"
        case platinum = "Platinum"
        case diamond  = "Diamond"
        case master   = "Master"
        
        // الألوان الخاصة بكل درع (للاستخدام في SwiftUI)
        var color: Color {
            switch self {
            case .wood:     return Color(red: 0.6, green: 0.4, blue: 0.2)
            case .bronze:   return Color(red: 0.8, green: 0.5, blue: 0.2)
            case .silver:   return Color.gray
            case .gold:     return Color.yellow
            case .platinum: return Color(red: 0.85, green: 0.95, blue: 1.0)
            case .diamond:  return Color.cyan
            case .master:   return Color.purple
            }
        }
    }

    /// تحديد نوع الدرع بناءً على المستوى (كل 5 مستويات يتغير)
    static func getShield(for level: Int) -> ShieldTier {
        switch level {
        case 1...4:   return .wood
        case 5...9:   return .bronze
        case 10...14: return .silver
        case 15...19: return .gold
        case 20...24: return .platinum
        case 25...29: return .diamond
        default:      return .master
        }
    }
    
    /// إرجاع اسم الأيقونة (SF Symbol) المناسبة للدرع
    static func getShieldIconName(for level: Int) -> String {
        // يمكنك تغيير هذه الأسماء إذا كان لديك صور مخصصة في Assets
        switch getShield(for: level) {
        case .wood:     return "shield.fill"
        case .bronze:   return "shield.fill"
        case .silver:   return "shield.checkerboard"
        case .gold:     return "shield.righthalf.filled" // مثال لتنويع الأشكال
        case .platinum: return "star.shield.fill"
        case .diamond:  return "diamond.fill" // أو shield specific
        case .master:   return "crown.fill"
        }
    }
}
