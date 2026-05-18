import Foundation
import SwiftData

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
