import Foundation
import SwiftData

// 1. الكيان الأول: السجل اليومي للمستخدم (The Daily Aura)
@Model
final class AiQoDailyRecord {
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
        // تحويل التاريخ لنص كمعرف فريد لليوم
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.id = formatter.string(from: date)
        
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

// 2. الكيان الثاني: مهام التمارين (The Grind Nodes)
@Model
final class WorkoutTask {
    var id: UUID
    var title: String // مثل: "تمارين الضغط (3 مجاميع)"
    var isCompleted: Bool
    
    // العلاقة العكسية للرجوع لليوم
    var dailyRecord: AiQoDailyRecord?
    
    init(title: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
    }
}
