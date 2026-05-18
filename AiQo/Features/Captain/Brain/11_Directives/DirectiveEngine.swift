import Foundation

/// Executes user-taught standing directives when their trigger fires.
///
/// This is the "remember + execute, never forget" half of the layer. It is
/// deliberately deterministic and offline: the after-workout analysis +
/// comparison is composed on-device so it always runs instantly, for free,
/// even when the workout ends in the background with no network — exactly the
/// reliability a "do this after EVERY workout" promise demands.
///
/// The chat Captain still gives deeper, model-written analysis when the user
/// opens the app and asks; this engine guarantees the standing promise is kept
/// every single time regardless.
actor DirectiveEngine {
    static let shared = DirectiveEngine()

    private let store: DirectiveStore

    init(store: DirectiveStore = .shared) {
        self.store = store
    }

    // MARK: - Workout completion

    /// Called by `AIWorkoutSummaryService.handleWorkoutEnded` after every
    /// workout. Returns the notification body to send if an active
    /// `.afterWorkout` directive matched (so the caller sends *this* instead of
    /// its generic static line), or `nil` to let the caller fall back.
    func handleWorkoutCompleted(_ snapshot: DirectiveWorkoutSnapshot) async -> String? {
        let gateAllowed = await MainActor.run {
            DevOverride.unlockAllFeatures || TierGate.shared.canAccess(.captainDirectives)
        }
        guard gateAllowed else {
            await logInfo("DirectiveEngine workout skipped — TierGate(.captainDirectives)")
            return nil
        }

        await BrainBus.shared.publish(.workoutCompleted)

        let directives = await store.directives(trigger: .afterWorkout, enabledOnly: true)
        guard let directive = directives.first else { return nil }

        let previous = await previousWorkout(before: snapshot.endedAt)

        let body: String
        switch directive.action {
        case .analyzeAndCompareWorkout:
            body = WorkoutComparisonComposer.compose(
                current: snapshot,
                previous: previous,
                fireCount: directive.fireCount,
                localeCode: directive.localeCode
            )
        case .notify:
            let custom = directive.params["text"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            body = (custom?.isEmpty == false)
                ? custom!
                : WorkoutComparisonComposer.compose(
                    current: snapshot,
                    previous: previous,
                    fireCount: directive.fireCount,
                    localeCode: directive.localeCode
                )
        }

        await store.recordFired(id: directive.id)
        await BrainBus.shared.publish(.directiveFired(directive.id))
        await logInfo("DirectiveEngine fired afterWorkout directive id=\(directive.id) action=\(directive.action.rawValue)")

        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    /// The most recent recorded workout that ended meaningfully before this one
    /// (guards against comparing the just-finished workout to itself when the
    /// in-app `WorkoutHistoryStore` already recorded the same session).
    private func previousWorkout(before endedAt: Date) async -> WorkoutHistoryEntry? {
        let entries = await MainActor.run { WorkoutHistoryStore.shared.recentEntries() }
        return entries.first { endedAt.timeIntervalSince($0.date) > 120 }
    }

    private func logInfo(_ message: String) async {
        await MainActor.run { diag.info(message) }
    }
}

// MARK: - Comparison composer

/// Builds the Iraqi/English "analyze this workout and compare it to the
/// previous one" notification body. Pure, deterministic, testable.
enum WorkoutComparisonComposer {

    nonisolated static func compose(
        current: DirectiveWorkoutSnapshot,
        previous: WorkoutHistoryEntry?,
        fireCount: Int,
        localeCode: String
    ) -> String {
        localeCode == "en"
            ? composeEnglish(current: current, previous: previous, fireCount: fireCount)
            : composeArabic(current: current, previous: previous, fireCount: fireCount)
    }

    // MARK: Arabic (Iraqi dialect)

    nonisolated private static func composeArabic(
        current: DirectiveWorkoutSnapshot,
        previous: WorkoutHistoryEntry?,
        fireCount: Int
    ) -> String {
        let minutes = max(1, Int((Double(current.durationSeconds) / 60).rounded()))
        let cals = Int(current.activeCalories.rounded())

        var todayParts: [String] = ["تمرين \(current.workoutType) \(minutes) دقيقة"]
        if cals > 0 { todayParts.append("\(cals) سعرة") }
        if current.zone2Percent >= 55 {
            todayParts.append("توازن زون تو ممتاز")
        } else if current.peakPercent >= 35 {
            todayParts.append("شدّة عالية")
        }
        let today = "بطل، \(todayParts.joined(separator: "، "))."

        guard let previous else {
            return "\(today) هذا أول تمرين أسجله إلك، من الحصة الجاية أبدي أقارنلك التقدم تمرين بتمرين."
        }

        let prevMinutes = max(1, previous.durationSeconds / 60)
        var deltas: [String] = []
        deltas.append("المدة " + arabicDelta(Double(minutes - prevMinutes), unit: "دقيقة", unitPlural: "دقايق"))
        if previous.activeCalories > 0 {
            deltas.append("السعرات " + arabicDelta(current.activeCalories - previous.activeCalories, unit: "سعرة", unitPlural: "سعرة"))
        }
        if let prevHR = previous.heartRate, prevHR > 0, current.averageHeartRate > 0 {
            let diff = Int((current.averageHeartRate - prevHR).rounded())
            if abs(diff) >= 3 {
                deltas.append(diff < 0 ? "ونبضك المعدل أهدأ بـ \(abs(diff))" : "ونبضك المعدل أعلى بـ \(diff)")
            }
        }
        if previous.distanceMeters >= 100, current.distanceKm >= 0.1 {
            let prevKm = previous.distanceMeters / 1000
            let kmDiff = current.distanceKm - prevKm
            if abs(kmDiff) >= 0.3 {
                deltas.append("والمسافة " + arabicDelta(kmDiff, unit: "كيلو", unitPlural: "كيلو", isDecimal: true))
            }
        }

        let comparison = "مقارنة بتمرينك السابق: " + deltas.joined(separator: "، ") + "."
        let close = motivationalCloseArabic(
            durationDelta: minutes - prevMinutes,
            caloriesDelta: current.activeCalories - previous.activeCalories
        )
        return "\(today) \(comparison) \(close)"
    }

    nonisolated private static func arabicDelta(
        _ value: Double,
        unit: String,
        unitPlural: String,
        isDecimal: Bool = false
    ) -> String {
        let magnitude = abs(value)
        guard magnitude >= (isDecimal ? 0.1 : 0.5) else { return "نفس المستوى تقريباً" }
        let amount = isDecimal
            ? String(format: "%.1f", magnitude)
            : "\(Int(magnitude.rounded()))"
        let word = (Int(magnitude.rounded()) >= 3 && !isDecimal) ? unitPlural : unit
        return value > 0 ? "زادت \(amount) \(word)" : "نقصت \(amount) \(word)"
    }

    nonisolated private static func motivationalCloseArabic(durationDelta: Int, caloriesDelta: Double) -> String {
        if durationDelta > 0 || caloriesDelta > 20 {
            return "تقدّم حقيقي يا بطل، ثبّت هالإيقاع وراح تطلع لقدام بسرعة."
        }
        if durationDelta < 0 && caloriesDelta < -20 {
            return "خفّيت شوي هالمرة، مو مشكلة، خل الحصة الجاية ترجع تشد بهدوء."
        }
        return "ثابت ومستمر، هذا اللي يبني النتيجة على المدى الطويل."
    }

    // MARK: English

    nonisolated private static func composeEnglish(
        current: DirectiveWorkoutSnapshot,
        previous: WorkoutHistoryEntry?,
        fireCount: Int
    ) -> String {
        let minutes = max(1, Int((Double(current.durationSeconds) / 60).rounded()))
        let cals = Int(current.activeCalories.rounded())

        var todayParts: [String] = ["\(current.workoutType) for \(minutes) min"]
        if cals > 0 { todayParts.append("\(cals) kcal") }
        if current.zone2Percent >= 55 {
            todayParts.append("excellent Zone 2 control")
        } else if current.peakPercent >= 35 {
            todayParts.append("high intensity")
        }
        let today = "Strong work — \(todayParts.joined(separator: ", "))."

        guard let previous else {
            return "\(today) This is the first workout I've logged for you — from the next one I'll compare your progress session by session."
        }

        let prevMinutes = max(1, previous.durationSeconds / 60)
        var deltas: [String] = []
        deltas.append("duration " + englishDelta(Double(minutes - prevMinutes), unit: "min"))
        if previous.activeCalories > 0 {
            deltas.append("calories " + englishDelta(current.activeCalories - previous.activeCalories, unit: "kcal"))
        }
        if let prevHR = previous.heartRate, prevHR > 0, current.averageHeartRate > 0 {
            let diff = Int((current.averageHeartRate - prevHR).rounded())
            if abs(diff) >= 3 {
                deltas.append(diff < 0 ? "avg HR \(abs(diff)) lower" : "avg HR \(diff) higher")
            }
        }
        if previous.distanceMeters >= 100, current.distanceKm >= 0.1 {
            let kmDiff = current.distanceKm - (previous.distanceMeters / 1000)
            if abs(kmDiff) >= 0.3 {
                deltas.append("distance " + englishDelta(kmDiff, unit: "km", isDecimal: true))
            }
        }

        let comparison = "Vs your previous workout: " + deltas.joined(separator: ", ") + "."
        let close = motivationalCloseEnglish(
            durationDelta: minutes - prevMinutes,
            caloriesDelta: current.activeCalories - previous.activeCalories
        )
        return "\(today) \(comparison) \(close)"
    }

    nonisolated private static func englishDelta(_ value: Double, unit: String, isDecimal: Bool = false) -> String {
        let magnitude = abs(value)
        guard magnitude >= (isDecimal ? 0.1 : 0.5) else { return "about the same" }
        let amount = isDecimal ? String(format: "%.1f", magnitude) : "\(Int(magnitude.rounded()))"
        return value > 0 ? "up \(amount) \(unit)" : "down \(amount) \(unit)"
    }

    nonisolated private static func motivationalCloseEnglish(durationDelta: Int, caloriesDelta: Double) -> String {
        if durationDelta > 0 || caloriesDelta > 20 {
            return "Real progress — lock this rhythm and you'll climb fast."
        }
        if durationDelta < 0 && caloriesDelta < -20 {
            return "Lighter this time, that's fine — let the next session build back up calmly."
        }
        return "Consistent and steady — that's what builds long-term results."
    }
}
