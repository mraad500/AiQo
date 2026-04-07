import Foundation
import SwiftData

/// نموذج المراجعة الأسبوعية لمشروع كسر الرقم القياسي
@Model
final class WeeklyLog {
    var id: UUID
    var weekNumber: Int
    var date: Date

    // بيانات المراجعة
    var currentWeight: Double?
    /// أفضل أداء هالأسبوع
    var performanceThisWeek: Double?
    /// رأي المستخدم (كتابة حرة)
    var userFeedback: String?
    /// ملاحظات الكابتن (من LLM)
    var captainNotes: String?
    /// تعديلات على الخطة
    var adjustments: String?

    // تقييم
    /// تقييم المستخدم للأسبوع 1-5
    var weekRating: Int?
    /// هل المستخدم ماشي صح
    var isOnTrack: Bool
    /// العوائق اللي واجهها المستخدم
    var obstacles: String?

    /// العلاقة مع المشروع
    var project: RecordProject?

    init(weekNumber: Int) {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.date = Date()
        self.isOnTrack = true
    }
}
