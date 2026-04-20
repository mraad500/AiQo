import Foundation

enum WeeklyReviewTemplateGenerator {
    static func generate(
        project: RecordProject,
        currentWeight: Double?,
        bestPerformance: Double?,
        feedback: String,
        weekRating: Int,
        selectedObstacle: String
    ) -> ReviewResult {
        let isArabic = AppSettingsStore.shared.appLanguage != .english
        let normalizedObstacle = selectedObstacle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        let improvedPerformance = bestPerformance.map { $0 > project.bestPerformance } ?? false
        let isOnTrack = weekRating >= 4 || improvedPerformance

        let captainMessage: String
        if improvedPerformance {
            captainMessage = isArabic
                ? "واضح أنك كسرت رقمك السابق هالأسبوع. هذا تقدم حقيقي، كمّل على نفس النفس."
                : "You beat your previous performance this week. That is real progress, so keep the same rhythm."
        } else if weekRating >= 4 {
            captainMessage = isArabic
                ? "أسبوعك كان ثابت وحلو. خلّ نفس الزخم مستمر وادخل الأسبوع الجاي وأنت جاهز."
                : "Your week looked steady and strong. Keep the momentum and roll into next week ready."
        } else if !normalizedFeedback.isEmpty {
            captainMessage = isArabic
                ? "سمعت ملاحظاتك، والأسبوع هذا يحتاج ضبط بسيط مو إعادة من الصفر."
                : "I heard your feedback, and this week needs a small adjustment, not a full reset."
        } else {
            captainMessage = isArabic
                ? "خلّينا نرتب الأسبوع الجاي بشكل أذكى حتى ترجع تمسك الإيقاع بسرعة."
                : "Let’s shape next week a bit smarter so you can get back into rhythm quickly."
        }

        var adjustmentParts: [String] = []
        if weekRating > 0 && weekRating <= 2 {
            adjustmentParts.append(
                isArabic
                    ? "خفف الشدة يومين وخلك على جلسات أقصر لكن ثابتة."
                    : "Lower the intensity for two days and keep the sessions shorter but consistent."
            )
        }
        if !normalizedObstacle.isEmpty {
            adjustmentParts.append(
                isArabic
                    ? "راقب العائق الرئيسي هذا الأسبوع: \(normalizedObstacle)."
                    : "Keep an eye on the main obstacle this week: \(normalizedObstacle)."
            )
        }
        if currentWeight == nil && bestPerformance == nil {
            adjustmentParts.append(
                isArabic
                    ? "سجّل وزن أو أداء واحد على الأقل حتى يكون التقييم الجاي أدق."
                    : "Log at least one weight or performance number so the next review is sharper."
            )
        }

        let warning: String?
        if normalizedObstacle.contains("injury") || normalizedObstacle.contains("إصابة") {
            warning = isArabic
                ? "إذا الألم مستمر، خفف الحمل وخلّ التعافي أول أولوية."
                : "If pain is still there, reduce the load and make recovery your first priority."
        } else {
            warning = nil
        }

        return ReviewResult(
            isOnTrack: isOnTrack,
            captainMessage: captainMessage,
            adjustments: adjustmentParts.isEmpty ? nil : adjustmentParts.joined(separator: " "),
            nextWeekPlanJSON: nil,
            updatedTotalWeeks: nil,
            warningIfAny: warning
        )
    }
}
