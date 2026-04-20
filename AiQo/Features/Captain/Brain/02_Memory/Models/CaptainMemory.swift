import Foundation
import SwiftData

/// نموذج ذاكرة الكابتن حمّودي — يحفظ المعلومات اللي يتذكرها عبر الجلسات
@Model
final class CaptainMemory {
    #Index<CaptainMemory>([\.category], [\.key])

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

struct CaptainMemorySnapshot: Equatable, Sendable, Identifiable {
    let id: UUID
    let key: String
    let value: String
    let category: String
    let confidence: Double
    let source: String
    let updatedAt: Date
    let accessCount: Int

    init(
        id: UUID,
        key: String,
        value: String,
        category: String,
        confidence: Double,
        source: String,
        updatedAt: Date,
        accessCount: Int
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.category = category
        self.confidence = confidence
        self.source = source
        self.updatedAt = updatedAt
        self.accessCount = accessCount
    }

    init(memory: CaptainMemory) {
        self.id = memory.id
        self.key = memory.key
        self.value = memory.value
        self.category = memory.category
        self.confidence = memory.confidence
        self.source = memory.source
        self.updatedAt = memory.updatedAt
        self.accessCount = memory.accessCount
    }

    init(fact: SemanticFact) {
        self.id = fact.id
        self.key = fact.storageKey
        self.value = fact.content
        self.category = fact.categoryRaw
        self.confidence = fact.confidence
        self.source = fact.sourceRaw
        self.updatedAt = fact.lastConfirmedAt
        self.accessCount = fact.referenceCount
    }
}
