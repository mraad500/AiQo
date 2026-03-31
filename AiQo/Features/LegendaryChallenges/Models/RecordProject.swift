import Foundation
import SwiftData

/// نموذج مشروع كسر الرقم القياسي — SwiftData
@Model
final class RecordProject {
    var id: UUID
    /// ID الرقم القياسي من قائمة الأرقام
    var recordID: String
    /// "أكثر ضغط بدقيقة"
    var recordTitle: String
    /// "قوة", "كارديو", "تحمّل", "صفاء"
    var recordCategory: String
    /// الرقم المطلوب كسره
    var targetValue: Double
    /// "مرة", "ساعة", "كم", "دقيقة"
    var unit: String
    /// صاحب الرقم الحالي
    var currentRecordHolder: String
    /// علم الدولة
    var holderCountryFlag: String

    // بيانات المستخدم عند البدء (snapshot)
    var userWeightAtStart: Double?
    var userFitnessLevelAtStart: String?
    /// أفضل أداء للمستخدم عند بدء المشروع
    var userBestAtStart: Double

    // الخطة
    /// مدة الخطة بالأسابيع
    var totalWeeks: Int
    /// الأسبوع الحالي (يبدأ من 1)
    var currentWeek: Int
    /// الخطة الأسبوعية كاملة كـ JSON
    var planJSON: String
    /// "أسطوري", "صعب", "متوسط"
    var difficulty: String

    // التقدم
    /// أفضل أداء وصله المستخدم خلال المشروع
    var bestPerformance: Double
    /// سجل المراجعات الأسبوعية
    @Relationship(deleteRule: .cascade) var weeklyLogs: [WeeklyLog]

    // الحالة
    /// "active", "completed", "abandoned"
    var status: String
    var startDate: Date
    var endDate: Date?
    var lastReviewDate: Date?
    var lastReviewNotes: String?

    /// هل الخطة مثبتة في تبويب "الخطة"
    var isPinnedToPlan: Bool

    /// حالة إنجاز المهام اليومية للـ legacy ProjectView — مخزنة كـ JSON array من Task IDs
    /// الصيغة: ["w1d1", "w1d3", "w2d2"] — week:day deterministic keys
    var completedTaskIDsJSON: String

    // NEW: HRR Assessment Data
    /// أعلى نبض خلال اختبار الجهد
    var hrrPeakHR: Double?
    /// نبض القلب بعد دقيقة استرداد
    var hrrRecoveryHR: Double?
    /// مستوى الاسترداد: "excellent", "good", "needsWork"
    var hrrLevel: String?

    init(
        recordID: String,
        recordTitle: String,
        recordCategory: String,
        targetValue: Double,
        unit: String,
        currentRecordHolder: String,
        holderCountryFlag: String,
        userWeightAtStart: Double? = nil,
        userFitnessLevelAtStart: String? = nil,
        userBestAtStart: Double,
        totalWeeks: Int,
        planJSON: String,
        difficulty: String
    ) {
        self.id = UUID()
        self.recordID = recordID
        self.recordTitle = recordTitle
        self.recordCategory = recordCategory
        self.targetValue = targetValue
        self.unit = unit
        self.currentRecordHolder = currentRecordHolder
        self.holderCountryFlag = holderCountryFlag
        self.userWeightAtStart = userWeightAtStart
        self.userFitnessLevelAtStart = userFitnessLevelAtStart
        self.userBestAtStart = userBestAtStart
        self.totalWeeks = totalWeeks
        self.currentWeek = 1
        self.planJSON = planJSON
        self.difficulty = difficulty
        self.bestPerformance = userBestAtStart
        self.weeklyLogs = []
        self.status = "active"
        self.startDate = Date()
        self.isPinnedToPlan = true
        self.completedTaskIDsJSON = "[]"
    }

    /// نسبة التقدم (0...1)
    var progressFraction: Double {
        guard totalWeeks > 0 else { return 0 }
        return Double(currentWeek) / Double(totalWeeks)
    }
}
