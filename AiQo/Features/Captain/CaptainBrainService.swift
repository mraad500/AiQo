import Foundation

final class CaptainBrainService {
    static let shared = CaptainBrainService()

    private init() {}

    func generateSmartPrompt(for record: AiQoDailyRecord) -> String {
        let totalWorkouts = record.workouts.count
        let completedWorkouts = record.workouts.filter(\.isCompleted)
        let pendingWorkouts = record.workouts.filter { !$0.isCompleted }

        let completedCount = completedWorkouts.count
        let pendingCount = pendingWorkouts.count

        let stepsProgress = progressPercentage(current: record.currentSteps, target: record.targetSteps)
        let caloriesProgress = progressPercentage(current: record.burnedCalories, target: record.targetCalories)
        let waterProgress = progressPercentage(current: record.waterCups, target: record.targetWaterCups)

        let didCompletePushupWorkout = completedWorkouts.contains { workout in
            let normalizedTitle = workout.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return normalizedTitle.contains("ضغط") || normalizedTitle.contains("push")
        }

        let workoutStatusBlock: String = {
            guard !record.workouts.isEmpty else {
                return "- لا توجد تمارين مسجلة اليوم."
            }

            return record.workouts.enumerated().map { index, workout in
                let state = workout.isCompleted ? "مكتمل" : "غير مكتمل"
                return "- \(index + 1). \(workout.title): \(state)"
            }.joined(separator: "\n")
        }()

        let nextPendingWorkout = pendingWorkouts.first?.title ?? "لا يوجد، كل التمارين مكتملة."

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ar_IQ")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: record.date)

        return """
        [SYSTEM PROMPT - CAPTAIN BRAIN]
        الشخصية:
        أنت الكابتن حمّودي، مدرب شخصي عراقي صارم ولكن حنون ومحفز. تتحدث باللهجة العراقية الطبيعية (مثل: هلا بطل، عاشت إيدك، شد حيلك، هسه، دير بالك).

        بيانات اليوم الحقيقية:
        - التاريخ: \(dateString)
        - الخطوات: \(record.currentSteps) من أصل \(record.targetSteps) (\(stepsProgress)%)
        - السعرات المحروقة: \(record.burnedCalories) من أصل \(record.targetCalories) (\(caloriesProgress)%)
        - أكواب الماء: \(record.waterCups) من أصل \(record.targetWaterCups) (\(waterProgress)%)
        - التمارين المكتملة: \(completedCount) من أصل \(totalWorkouts)
        - التمارين غير المكتملة: \(pendingCount)
        - أقرب تمرين غير مكتمل: \(nextPendingWorkout)
        - تم إكمال تمرين الضغط اليوم: \(didCompletePushupWorkout ? "نعم" : "لا")
        - اقتراح اليوم المسجل: \(record.captainDailySuggestion)
        - حالة كل التمارين:
        \(workoutStatusBlock)

        التوجيه الديناميكي للرد:
        - علّق على هذه البيانات نفسها، ولا تعطِ نصائح عامة بعيدة عن الأرقام.
        - إذا كان المستخدم متأخرًا في شرب الماء، ذكّره بأسلوب حازم.
        - إذا كان "تم إكمال تمرين الضغط اليوم: نعم" امدحه بوضوح.
        - إذا توجد تمارين غير مكتملة، وجّه المستخدم يبدأ مباشرة بالتمرين غير المكتمل الأقرب.
        - إذا مؤشرات الإنجاز عالية، ثبّت الدافع وادفعه للاستمرار بنفس النسق.
        - الرد يجب أن يكون سينمائيًا، قصيرًا جدًا، وبحد أقصى 3 جمل فقط، ليكون مناسبًا للتحويل الصوتي السريع عبر ElevenLabs.
        - لا تستخدم تعداد نقطي في الرد النهائي، ولا أي شرح تقني أو ميتا.
        """
    }

    private func progressPercentage(current: Int, target: Int) -> Int {
        guard target > 0 else { return 0 }
        let ratio = Double(max(0, current)) / Double(target)
        let percentage = Int((ratio * 100).rounded())
        return min(max(percentage, 0), 999)
    }
}
