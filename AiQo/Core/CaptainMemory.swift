import Foundation
import SwiftData

/// نموذج ذاكرة الكابتن حمّودي — يحفظ المعلومات اللي يتذكرها عبر الجلسات
@Model
final class CaptainMemory {
    var id: UUID
    /// تصنيف الذاكرة: identity, goal, body, preference, mood, injury, nutrition, workout_history, sleep, insight, active_record_project
    var category: String
    /// مفتاح فريد للذاكرة
    @Attribute(.unique) var key: String
    /// القيمة المحفوظة
    var value: String
    /// مدى الثقة بالمعلومة (0.0 - 1.0)
    var confidence: Double
    /// مصدر المعلومة: user_explicit, extracted, healthkit, inferred, llm_extracted
    var source: String
    var createdAt: Date
    var updatedAt: Date
    /// عدد مرات الاستخدام بالـ prompt
    var accessCount: Int

    init(
        key: String,
        value: String,
        category: String,
        source: String,
        confidence: Double = 0.7
    ) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.category = category
        self.source = source
        self.confidence = confidence
        self.createdAt = Date()
        self.updatedAt = Date()
        self.accessCount = 0
    }
}
