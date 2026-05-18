import Foundation
import SwiftData

// 1. الكيان الأول: السجل اليومي للمستخدم (The Daily Aura)
@Model
final class AiQoDailyRecord {
    #Index<AiQoDailyRecord>([\.date])

    /// المصدر الوحيد لصيغة معرّف اليوم. مقفول على `en_US_POSIX` + تقويم ميلادي
    /// حتى يطلع ثابت بأرقام لاتينية مهما كانت لغة/تقويم الجهاز. أي كود يدور
    /// عن سجل يوم لازم يستعمل نفس هذا الـ formatter (مو formatter محلي).
    static let dayIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @Attribute(.unique) var id: String // نخليه بصيغة (yyyy-MM-dd) حتى ما يتكرر اليوم
    var date: Date

    // الأهداف والمؤشرات الحيوية (مثل ما موجودة بشاشة "خطة اليوم")
    var currentSteps: Int
    var targetSteps: Int
    var burnedCalories: Int
    var targetCalories: Int
    var waterCups: Int
    var targetWaterCups: Int

    // الذكاء الاصطناعي: اقتراح الكابتن لليوم (مثل: جرّب يوغا 20 دقيقة اليوم)
    var captainDailySuggestion: String

    // العلاقة: كل يوم يحتوي على قائمة تمارين (خلايا عصبية متصلة)
    @Relationship(deleteRule: .cascade)
    var workouts: [WorkoutTask]

    init(date: Date = Date(), currentSteps: Int = 0, targetSteps: Int = 10000, burnedCalories: Int = 0, targetCalories: Int = 600, waterCups: Int = 0, targetWaterCups: Int = 8, captainDailySuggestion: String = "استعد ليوم مليء بالطاقة يا بطل!") {
        // تحويل التاريخ لنص كمعرف فريد لليوم.
        // لازم نقفل locale + calendar حتى الـ id يطلع ثابت "yyyy-MM-dd"
        // بأرقام لاتينية وتقويم ميلادي مهما كانت إعدادات الجهاز (عربي/هجري).
        // بدون هالقفل: جهاز عربي ينتج "٢٠٢٦-٠٥-١٢" أو تاريخ هجري، فما يتطابق
        // مع الـ formatter اللي يدور عن السجل لاحقاً → الخطة المثبتة تختفي
        // بعد إعادة فتح التطبيق.
        self.id = AiQoDailyRecord.dayIDFormatter.string(from: date)

        self.date = date
        self.currentSteps = currentSteps
        self.targetSteps = targetSteps
        self.burnedCalories = burnedCalories
        self.targetCalories = targetCalories
        self.waterCups = waterCups
        self.targetWaterCups = targetWaterCups
        self.captainDailySuggestion = captainDailySuggestion
        self.workouts = []
    }
}
