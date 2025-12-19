import Foundation
internal import Combine

// تعريف اسم الإشعار حتى نستخدمه بالواجهة
extension Notification.Name {
    static let levelStoreDidChange = Notification.Name("AiQoLevelStoreDidChange")
}

final class LevelStore {
    
    // Singleton: نسخة واحدة مشتركة لكل التطبيق
    static let shared = LevelStore()
    
    private let defaults = UserDefaults.standard
    private let xpKey = "aiqo_user_xp_current"
    private let levelKey = "aiqo_user_level_index"
    
    // المتغيرات للقراءة فقط من الخارج
    private(set) var currentXP: Int
    private(set) var level: Int
    
    init() {
        // استرجاع البيانات المحفوظة أو البدء من الصفر
        self.currentXP = defaults.integer(forKey: xpKey)
        let savedLevel = defaults.integer(forKey: levelKey)
        self.level = savedLevel == 0 ? 1 : savedLevel // نبدأ من المستوى 1
    }
    
    // MARK: - Game Logic
    
    // معادلة الصعوبة: كل مستوى أصعب بـ 20% من القبله
    // المستوى 1: 500 نقطة
    // المستوى 2: 600 نقطة ... وهكذا
    func xpRequired(for level: Int) -> Int {
        let base = 500.0
        let multiplier = 1.2
        // المعادلة: 500 * (1.2 ^ (المستوى - 1))
        let result = base * pow(multiplier, Double(level - 1))
        return Int(result)
    }
    
    // حساب نسبة التقدم (من 0.0 إلى 1.0) للبروجرس بار
    var progress: Float {
        let required = xpRequired(for: level)
        if required == 0 { return 0 }
        return Float(currentXP) / Float(required)
    }
    
    // دالة إضافة النقاط (استخدمها لما يخلص تمرين)
    func addXP(amount: Int) {
        currentXP += amount
        var didLevelUp = false
        
        // التحقق من الصعود للمستوى التالي
        var required = xpRequired(for: level)
        
        // حلقة تكرار (لو حصل نقاط هواية وصعد مستويين مرة وحدة)
        while currentXP >= required {
            currentXP -= required // نصفر النقاط للمستوى الجديد (أو نبقي الباقي)
            level += 1
            didLevelUp = true
            required = xpRequired(for: level) // تحديث المطلوب للمستوى الجديد
        }
        
        save()
        notifyUI(didLevelUp: didLevelUp)
    }
    
    // MARK: - Helpers
    
    private func save() {
        defaults.set(currentXP, forKey: xpKey)
        defaults.set(level, forKey: levelKey)
    }
    
    private func notifyUI(didLevelUp: Bool) {
        NotificationCenter.default.post(
            name: .levelStoreDidChange,
            object: nil,
            userInfo: ["didLevelUp": didLevelUp]
        )
    }
    
    // دالة للتجربة (إعادة تعيين)
    func resetProgress() {
        currentXP = 0
        level = 1
        save()
        notifyUI(didLevelUp: false)
    }
}

