import Foundation
import SwiftUI
import Combine

// MARK: - Notification Name
extension Notification.Name {
    static let levelStoreDidChange = Notification.Name("AiQoLevelStoreDidChange")
    static let levelDidLevelUp = Notification.Name("AiQoLevelDidLevelUp")
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
    
    var currentLevel: Int {
        level
    }
    
    private enum StorageKeys {
        static let currentLevel = "aiqo.user.level"
        static let currentXP = "aiqo.user.currentXP"
        static let totalXP = "aiqo.user.totalXP"
        static let legacyCurrentLevel = "aiqo.currentLevel"
        static let legacyCurrentXP = "aiqo.currentXP"
        static let legacyUserXP = "aiqo.user.xp"
        static let legacyCurrentLevelProgress = "aiqo.currentLevelProgress"
        static let legacyTotalXP = "aiqo.legacyTotalPoints"
        static let migrationDone = "aiqo.levelMigrationDone"
    }
    
    private init() {
        migrateLegacyStorageIfNeeded()
        load()
    }
    
    // MARK: - Core Logic
    
    /// XP المطلوب للوصول للمستوى التالي (range size of current level).
    var xpForNextLevel: Int {
        AiQoLeveling.xpForNextLevel(at: level)
    }

    var progress: Double {
        let needed = AiQoLeveling.xpForNextLevel(at: level)
        guard needed > 0 else { return 1.0 }
        return min(Double(currentXP) / Double(needed), 1.0)
    }

    /// إضافة نقاط خبرة. Level + currentXP are derived from `totalXP` via the
    /// shared threshold table so we always agree with the onboarding result.
    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        let oldLevel = level
        totalXP += amount
        recomputeLevelAndCurrentXP()

        let didLevelUp = level > oldLevel
        if didLevelUp {
            notifyUI(didLevelUp: true)
        }

        save()

        NotificationCenter.default.post(
            name: .aiqoXPGranted,
            object: self,
            userInfo: [
                "amount": amount,
                "totalXP": totalXP,
                "level": level,
                "didLevelUp": didLevelUp
            ]
        )

        let syncXP = totalXP
        let syncLevel = level
        Task { @MainActor in
            await SupabaseArenaService.shared.syncUserStats(totalPoints: syncXP, level: syncLevel)
        }
    }

    private func recomputeLevelAndCurrentXP() {
        level = max(AiQoLeveling.level(forTotalXP: totalXP), 1)
        currentXP = AiQoLeveling.currentXP(forTotalXP: totalXP, atLevel: level)
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
        UserDefaults.standard.set(level, forKey: StorageKeys.currentLevel)
        UserDefaults.standard.set(currentXP, forKey: StorageKeys.currentXP)
        UserDefaults.standard.set(totalXP, forKey: StorageKeys.totalXP)

        Task { @MainActor in
            QuestPersistenceController.shared.syncPlayerStats(
                level: self.level,
                currentLevelXP: self.currentXP,
                totalXP: self.totalXP
            )
        }
        
        NotificationCenter.default.post(name: .levelStoreDidChange, object: nil)
    }
    
    private func load() {
        totalXP = UserDefaults.standard.integer(forKey: StorageKeys.totalXP)

        // Re-derive level + currentXP from totalXP so we self-heal any drift
        // from older builds that used the exponential formula. Without this,
        // existing users who onboarded under the old code keep their wrong
        // stored level forever.
        recomputeLevelAndCurrentXP()

        UserDefaults.standard.set(level, forKey: StorageKeys.currentLevel)
        UserDefaults.standard.set(currentXP, forKey: StorageKeys.currentXP)
    }
    
    private func migrateLegacyStorageIfNeeded() {
        let defaults = UserDefaults.standard
        
        guard !defaults.bool(forKey: StorageKeys.migrationDone) else { return }
        
        let modernLevel = defaults.integer(forKey: StorageKeys.currentLevel)
        let legacyLevel = defaults.integer(forKey: StorageKeys.legacyCurrentLevel)
        if legacyLevel != 0 && modernLevel == 0 {
            defaults.set(legacyLevel, forKey: StorageKeys.currentLevel)
        }
        defaults.removeObject(forKey: StorageKeys.legacyCurrentLevel)
        
        let resolvedLevel = max(defaults.integer(forKey: StorageKeys.currentLevel), 1)
        
        let modernCurrentXP = defaults.integer(forKey: StorageKeys.currentXP)
        let legacyCurrentXP = defaults.integer(forKey: StorageKeys.legacyCurrentXP)
        if legacyCurrentXP != 0 && modernCurrentXP == 0 {
            defaults.set(legacyCurrentXP, forKey: StorageKeys.currentXP)
        }
        defaults.removeObject(forKey: StorageKeys.legacyCurrentXP)
        
        let currentXPAfterLegacyMigration = defaults.integer(forKey: StorageKeys.currentXP)
        let legacyUserXP = defaults.integer(forKey: StorageKeys.legacyUserXP)
        if legacyUserXP != 0 && currentXPAfterLegacyMigration == 0 {
            defaults.set(legacyUserXP, forKey: StorageKeys.currentXP)
        }
        defaults.removeObject(forKey: StorageKeys.legacyUserXP)
        
        let currentXPAfterUserXPMigration = defaults.integer(forKey: StorageKeys.currentXP)
        let legacyProgress = defaults.double(forKey: StorageKeys.legacyCurrentLevelProgress)
        if legacyProgress != 0 && currentXPAfterUserXPMigration == 0 {
            let migratedXP = Int((legacyProgress * Double(xpRequired(for: resolvedLevel))).rounded())
            if migratedXP != 0 {
                defaults.set(migratedXP, forKey: StorageKeys.currentXP)
            }
        }
        defaults.removeObject(forKey: StorageKeys.legacyCurrentLevelProgress)
        
        let modernTotalXP = defaults.integer(forKey: StorageKeys.totalXP)
        let legacyTotalXP = defaults.integer(forKey: StorageKeys.legacyTotalXP)
        if legacyTotalXP != 0 && modernTotalXP == 0 {
            defaults.set(legacyTotalXP, forKey: StorageKeys.totalXP)
        }
        defaults.removeObject(forKey: StorageKeys.legacyTotalXP)
        
        defaults.set(true, forKey: StorageKeys.migrationDone)
    }
    
    private func xpRequired(for level: Int) -> Int {
        AiQoLeveling.xpForNextLevel(at: level)
    }
    
    private func notifyUI(didLevelUp: Bool) {
        if didLevelUp {
            // تشغيل Haptics عند رفع المستوى
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            NotificationCenter.default.post(
                name: .levelDidLevelUp,
                object: nil,
                userInfo: ["newLevel": level]
            )
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
