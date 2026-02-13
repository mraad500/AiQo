import Foundation
import SwiftUI
internal import Combine

// MARK: - Notification Name
extension Notification.Name {
    static let levelStoreDidChange = Notification.Name("AiQoLevelStoreDidChange")
}

// MARK: - Shield Tier Enum (أنواع الدروع)
enum ShieldTier: String, CaseIterable {
    case wood       = "shield_wood"      // Level 1-4
    case bronze     = "shield_bronze"    // Level 5-9
    case silver     = "shield_silver"    // Level 10-14
    case gold       = "shield_gold"      // Level 15-19
    case platinum   = "shield_platinum"  // Level 20-24
    case diamond    = "shield_diamond"   // Level 25-29
    case obsidian   = "shield_obsidian"  // Level 30-34
    case legendary  = "shield_legendary" // Level 35+
    
    var displayName: String {
        switch self {
        case .wood: return "Wood"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        case .obsidian: return "Obsidian"
        case .legendary: return "Legendary"
        }
    }
    
    // ألوان مميزة لكل درع
    var colorHex: String {
        switch self {
        case .wood: return "#8B4513"      // بني خشبي
        case .bronze: return "#CD7F32"    // برونزي
        case .silver: return "#C0C0C0"    // فضي
        case .gold: return "#FFD700"      // ذهبي
        case .platinum: return "#E5E4E2"  // بلاتيني
        case .diamond: return "#B9F2FF"   // سماوي فاتح
        case .obsidian: return "#3D3D3D"  // أسود غامق
        case .legendary: return "#FF6B6B" // أحمر أسطوري
        }
    }
}

// MARK: - Level Store (مخزن المستويات)
final class LevelStore: ObservableObject {
    
    static let shared = LevelStore()
    
    @Published var level: Int = 1
    @Published var currentXP: Int = 0
    @Published var totalXP: Int = 0
    
    // ثوابت الحسابات
    private let baseXP = 1000
    private let multiplier = 1.2
    
    private init() {
        load()
    }
    
    // MARK: - Core Logic
    
    /// XP المطلوب للوصول للمستوى التالي
    var xpForNextLevel: Int {
        let levelDouble = Double(level)
        return Int(Double(baseXP) * pow(multiplier, levelDouble - 1))
    }
    
    var progress: Double {
        guard xpForNextLevel > 0 else { return 0 }
        return Double(currentXP) / Double(xpForNextLevel)
    }
    
    /// إضافة نقاط خبرة
    func addXP(_ amount: Int) {
        currentXP += amount
        totalXP += amount
        checkForLevelUp()
        save()
    }
    
    private func checkForLevelUp() {
        while currentXP >= xpForNextLevel {
            currentXP -= xpForNextLevel
            level += 1
            notifyUI(didLevelUp: true)
        }
    }
    
    // MARK: - Shield Logic 🛡️
    
    /// إرجاع نوع الدرع بناءً على المستوى الحالي
    /// المعادلة: القسمة على 5 تحدد الـ Index
    /// 1-4 (Index 0: Wood)
    /// 5-9 (Index 1: Bronze)
    func getShieldTier(for levelToCheck: Int) -> ShieldTier {
        let tierIndex = levelToCheck / 5
        let allTiers = ShieldTier.allCases
        
        // التأكد من عدم الخروج عن مصفوفة الدروع
        if tierIndex < allTiers.count {
            return allTiers[tierIndex]
        } else {
            return .legendary
        }
    }
    
    /// دالة مساعدة لواجهة المستخدم
    func currentShieldTier() -> ShieldTier {
        return getShieldTier(for: self.level)
    }
    
    /// اسم أيقونة الدرع (للاستخدام في Image)
    func currentShieldIconName() -> String {
        return currentShieldTier().rawValue
    }
    
    // MARK: - Persistence
    
    private func save() {
        UserDefaults.standard.set(level, forKey: "aiqo.user.level")
        UserDefaults.standard.set(currentXP, forKey: "aiqo.user.currentXP")
        UserDefaults.standard.set(totalXP, forKey: "aiqo.user.totalXP")
        
        NotificationCenter.default.post(name: .levelStoreDidChange, object: nil)
    }
    
    private func load() {
        level = UserDefaults.standard.integer(forKey: "aiqo.user.level")
        if level == 0 { level = 1 }
        currentXP = UserDefaults.standard.integer(forKey: "aiqo.user.currentXP")
        totalXP = UserDefaults.standard.integer(forKey: "aiqo.user.totalXP")
    }
    
    private func notifyUI(didLevelUp: Bool) {
        if didLevelUp {
            // تشغيل Haptics عند رفع المستوى
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    // MARK: - Debug
    
    func resetProgress() {
        currentXP = 0
        totalXP = 0
        level = 1
        save()
    }
    
    #if DEBUG
    func debugSetLevel(_ newLevel: Int) {
        level = max(1, newLevel)
        currentXP = 0
        save()
    }
    #endif
}

// MARK: - Helper Extension for UI
// هذا الامتداد يساعدك تجيب لون الدرع مباشرة كـ Color
extension LevelStore {
    func shieldColor(for level: Int) -> Color {
        let hex = getShieldTier(for: level).colorHex
        return Color(hex: hex) // ✅ يعتمد على Colors.swift الآن
    }
}
