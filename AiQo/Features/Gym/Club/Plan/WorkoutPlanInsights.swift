import Foundation
import SwiftUI

// MARK: - Vocabulary

enum WorkoutMuscleGroup: String, CaseIterable {
    case chest, back, legs, glutes, shoulders, arms, core, fullBody, cardio, mobility

    var icon: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .legs: "figure.run"
        case .glutes: "figure.cooldown"
        case .shoulders: "figure.boxing"
        case .arms: "dumbbell.fill"
        case .core: "figure.core.training"
        case .fullBody: "figure.mixed.cardio"
        case .cardio: "heart.fill"
        case .mobility: "figure.flexibility"
        }
    }

    var arabicLabel: String {
        switch self {
        case .chest: "صدر"
        case .back: "ظهر"
        case .legs: "أرجل"
        case .glutes: "أرداف"
        case .shoulders: "أكتاف"
        case .arms: "ذراع"
        case .core: "كور"
        case .fullBody: "جسم كامل"
        case .cardio: "كارديو"
        case .mobility: "تمدد"
        }
    }

    var englishLabel: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .legs: "Legs"
        case .glutes: "Glutes"
        case .shoulders: "Shoulders"
        case .arms: "Arms"
        case .core: "Core"
        case .fullBody: "Full Body"
        case .cardio: "Cardio"
        case .mobility: "Mobility"
        }
    }

    /// Brand family for the muscle group. Mapped onto the four AiQo
    /// brand colors only — no saturated coral / blue / orange. The
    /// distribution groups muscles by training intent so the plan card
    /// reads as a calm, branded surface rather than a noisy rainbow.
    var family: PlanPalette.Family {
        switch self {
        // Strength / warm presses → sand
        case .chest, .back, .shoulders: .sand
        // Movement / lower body → lavender
        case .legs, .glutes: .lavender
        // Control / sculpting → mint
        case .arms, .core, .mobility: .mint
        // Energy → lemon
        case .cardio, .fullBody: .lemon
        }
    }

    var accent: Color { family.pastel }
    var ink: Color { family.ink }
}

enum WorkoutEquipment: String, CaseIterable {
    case bodyweight, dumbbell, barbell, machine, band, kettlebell, cable

    var icon: String {
        switch self {
        case .bodyweight: "figure.stand"
        case .dumbbell: "dumbbell.fill"
        case .barbell: "scalemass.fill"
        case .machine: "gearshape.2.fill"
        case .band: "infinity.circle.fill"
        case .kettlebell: "circle.grid.cross.fill"
        case .cable: "cable.connector"
        }
    }

    var arabicLabel: String {
        switch self {
        case .bodyweight: "وزن جسم"
        case .dumbbell: "دامبل"
        case .barbell: "بار"
        case .machine: "ماكينة"
        case .band: "مطاط"
        case .kettlebell: "كتل بيل"
        case .cable: "كيبل"
        }
    }

    var englishLabel: String {
        switch self {
        case .bodyweight: "Bodyweight"
        case .dumbbell: "Dumbbell"
        case .barbell: "Barbell"
        case .machine: "Machine"
        case .band: "Band"
        case .kettlebell: "Kettlebell"
        case .cable: "Cable"
        }
    }
}

enum WorkoutDifficulty {
    case beginner, intermediate, advanced

    var arabicLabel: String {
        switch self {
        case .beginner: "مبتدئ"
        case .intermediate: "متوسط"
        case .advanced: "متقدم"
        }
    }

    var englishLabel: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var family: PlanPalette.Family {
        switch self {
        case .beginner: .mint
        case .intermediate: .sand
        case .advanced: .lavender
        }
    }

    var accent: Color { family.pastel }
    var ink: Color { family.ink }
}

// MARK: - Per-exercise insights

struct ExerciseInsights {
    let muscleGroup: WorkoutMuscleGroup
    let equipment: WorkoutEquipment
    let estimatedSeconds: Int       // total time (sets × set time + rest)
    let restSeconds: Int
    let formCues: [String]
    let alternatives: [String]
}

extension Exercise {
    func insights(language: AppLanguage) -> ExerciseInsights {
        let normalized = name.lowercased()
        let muscle = ExerciseClassifier.muscleGroup(for: normalized)
        let equipment = ExerciseClassifier.equipment(for: normalized)
        let perSet = ExerciseClassifier.estimatedSetSeconds(for: repsOrDuration, muscle: muscle)
        let rest = ExerciseClassifier.restSeconds(for: muscle, equipment: equipment)
        let totalSeconds = max(60, sets * (perSet + rest) - rest)
        let cues = ExerciseClassifier.formCues(for: normalized, language: language)
        let alts = ExerciseClassifier.alternatives(for: normalized, language: language)
        return ExerciseInsights(
            muscleGroup: muscle,
            equipment: equipment,
            estimatedSeconds: totalSeconds,
            restSeconds: rest,
            formCues: cues,
            alternatives: alts
        )
    }
}

// MARK: - Plan-level insights

struct WorkoutPlanInsights {
    let totalEstimatedSeconds: Int
    let primaryMuscleGroups: [WorkoutMuscleGroup]
    let equipmentNeeded: [WorkoutEquipment]
    let difficulty: WorkoutDifficulty
    let totalSets: Int

    var prettyDuration: String {
        let minutes = max(5, Int((Double(totalEstimatedSeconds) / 60).rounded()))
        return "\(minutes)"
    }
}

extension WorkoutPlan {
    func insights(language: AppLanguage) -> WorkoutPlanInsights {
        var totalSeconds = 0
        var muscleCounts: [WorkoutMuscleGroup: Int] = [:]
        var equipmentSet: [WorkoutEquipment: Int] = [:]
        var totalSets = 0
        var maxSetsSeen = 0

        for exercise in exercises {
            let info = exercise.insights(language: language)
            totalSeconds += info.estimatedSeconds
            muscleCounts[info.muscleGroup, default: 0] += 1
            equipmentSet[info.equipment, default: 0] += 1
            totalSets += exercise.sets
            maxSetsSeen = max(maxSetsSeen, exercise.sets)
        }

        let primary = muscleCounts
            .sorted { $0.value > $1.value }
            .map(\.key)

        let equipment = equipmentSet
            .sorted { $0.value > $1.value }
            .map(\.key)

        let difficulty: WorkoutDifficulty
        switch (totalSets, maxSetsSeen, exercises.count) {
        case let (sets, _, _) where sets >= 16:
            difficulty = .advanced
        case let (sets, peak, _) where sets >= 10 || peak >= 4:
            difficulty = .intermediate
        default:
            difficulty = .beginner
        }

        return WorkoutPlanInsights(
            totalEstimatedSeconds: totalSeconds,
            primaryMuscleGroups: Array(primary.prefix(3)),
            equipmentNeeded: Array(equipment.prefix(3)),
            difficulty: difficulty,
            totalSets: totalSets
        )
    }
}

// MARK: - Classifier (heuristic)

enum ExerciseClassifier {
    static func muscleGroup(for normalizedName: String) -> WorkoutMuscleGroup {
        let n = normalizedName

        if matches(n, ["push-up", "push up", "pushup", "ضغط", "بنش", "bench", "press", "chest"]) {
            return .chest
        }
        if matches(n, ["pull", "row", "rowing", "deadlift", "ديدليفت", "سحب", "رو", "ظهر", "back"]) {
            return .back
        }
        if matches(n, ["squat", "lunge", "سكوات", "لانجز", "leg", "calf", "أرجل", "رجل", "step-up"]) {
            return .legs
        }
        if matches(n, ["hip thrust", "glute", "أرداف", "كيك", "hip bridge", "جسر"]) {
            return .glutes
        }
        if matches(n, ["overhead", "shoulder", "lateral raise", "أكتاف", "كتف", "press out"]) {
            return .shoulders
        }
        if matches(n, ["curl", "بايسبس", "تراي", "tricep", "bicep", "ذراع", "arm"]) {
            return .arms
        }
        if matches(n, ["plank", "بلانك", "crunch", "كرنش", "core", "كور", "russian twist", "sit-up", "mountain climber"]) {
            return .core
        }
        if matches(n, ["run", "jog", "ركض", "هرولة", "burpee", "jump rope", "هايت", "كارديو", "cardio", "rowing erg"]) {
            return .cardio
        }
        if matches(n, ["stretch", "تمدد", "تنفّس", "تنفس", "breath", "mobility", "yoga", "يوغا", "فتح", "flow"]) {
            return .mobility
        }
        if matches(n, ["farmer", "carry", "كاري"]) {
            return .fullBody
        }
        return .fullBody
    }

    static func equipment(for normalizedName: String) -> WorkoutEquipment {
        let n = normalizedName

        if matches(n, ["dumbbell", "دامبل", "db "]) { return .dumbbell }
        if matches(n, ["barbell", "بار ", "bar ", "deadlift", "ديدليفت", "back squat", "front squat"]) { return .barbell }
        if matches(n, ["band", "مطاط"]) { return .band }
        if matches(n, ["kettlebell", "كتل بيل", "كتل بل"]) { return .kettlebell }
        if matches(n, ["cable", "كيبل", "كابل"]) { return .cable }
        if matches(n, ["machine", "ماكينة", "ماكنة", "smith"]) { return .machine }
        return .bodyweight
    }

    static func estimatedSetSeconds(for repsOrDuration: String, muscle: WorkoutMuscleGroup) -> Int {
        let lower = repsOrDuration.lowercased()
        let digits = lower.compactMap { Character(extendedGraphemeClusterLiteral: $0).isASCII && $0.isNumber ? $0 : nil }
        let digitString = String(digits)
        let firstNumber = Int(digitString.prefix(3)) ?? 0

        if lower.contains("ثانية") || lower.contains("ثوان") || lower.contains("sec") || lower.contains("second") {
            return max(20, firstNumber)
        }
        if lower.contains("دقيقة") || lower.contains("دقائق") || lower.contains("min") || lower.contains("دقيق") {
            let minutes = max(1, firstNumber)
            return minutes * 60
        }
        // Otherwise treat number as reps and estimate ~3 seconds per rep, with light bias by muscle group
        let repsApprox = max(6, firstNumber)
        let secondsPerRep: Double
        switch muscle {
        case .legs, .back, .chest, .shoulders, .glutes:
            secondsPerRep = 3.5
        case .arms, .core:
            secondsPerRep = 2.8
        case .cardio, .fullBody:
            secondsPerRep = 2.4
        case .mobility:
            secondsPerRep = 4.0
        }
        return max(25, Int(Double(repsApprox) * secondsPerRep))
    }

    static func restSeconds(for muscle: WorkoutMuscleGroup, equipment: WorkoutEquipment) -> Int {
        switch (muscle, equipment) {
        case (.legs, .barbell), (.back, .barbell), (.chest, .barbell):
            return 90
        case (.legs, _), (.back, _), (.chest, _), (.shoulders, _):
            return 60
        case (.arms, _), (.glutes, _):
            return 50
        case (.core, _):
            return 40
        case (.cardio, _), (.fullBody, _):
            return 45
        case (.mobility, _):
            return 20
        }
    }

    static func formCues(for normalizedName: String, language: AppLanguage) -> [String] {
        let n = normalizedName

        // Arabic cues
        if language == .arabic {
            if matches(n, ["push", "ضغط", "بنش", "bench"]) {
                return [
                    "خلي الكتف ثابت ولا يطلع للأمام",
                    "نزّل بسيطرة لما الصدر يقرب الأرض/البار",
                    "تنفّس وانت نازل، فجّر وانت طالع"
                ]
            }
            if matches(n, ["squat", "سكوات", "لانجز", "lunge"]) {
                return [
                    "الكعب ضاغط الأرض، الركبة تتبع اتجاه القدم",
                    "نزّل لين الورك بمحاذاة الركبة على الأقل",
                    "الظهر مشدود ومنحنى الفقرات طبيعي"
                ]
            }
            if matches(n, ["row", "pull", "deadlift", "ديدليفت", "سحب", "رو"]) {
                return [
                    "اسحب الكوع للوراء مو من اليد",
                    "اعصر الكتف واخلي الصدر مفتوح",
                    "الظهر فلات، لا تقوس الفقرات"
                ]
            }
            if matches(n, ["plank", "بلانك"]) {
                return [
                    "الجسم خط واحد من الكتف للكعب",
                    "شد الكور والورك لتحت لا فوق",
                    "تنفّس بهدوء، لا تحبس النفس"
                ]
            }
            if matches(n, ["overhead", "shoulder", "press", "أكتاف", "كتف"]) {
                return [
                    "خلي العمود الفقري محايد، لا تقوّس",
                    "ادفع بشكل عمودي مع الجسم",
                    "اعصر الأرداف لتثبت الورك"
                ]
            }
            if matches(n, ["stretch", "تمدد", "yoga", "يوغا", "mobility", "فتح"]) {
                return [
                    "تنفّس عميق وانت بالموقف",
                    "لا تقفز بالحركة، ادخل تدريجي",
                    "وقفك يكون مريح مو موجع"
                ]
            }
            if matches(n, ["run", "jog", "burpee", "jump", "ركض", "هرولة", "كارديو"]) {
                return [
                    "ابدأ بإحماء قبل ما تعلّى الإيقاع",
                    "تنفّس بإيقاع 2 دخول 2 خروج",
                    "حافظ على وقفة مستقيمة، الكتف مفتوح"
                ]
            }
            return [
                "ركّز على الفورم قبل السرعة",
                "حركة كاملة وبسيطرة بكل عدّة",
                "تنفّس صح: زفير على الجهد"
            ]
        }

        // English cues
        if matches(n, ["push", "bench", "press", "chest"]) {
            return [
                "Keep shoulders pinned, don't shrug forward",
                "Lower with control until chest is just above the floor/bar",
                "Inhale on the way down, exhale on the press"
            ]
        }
        if matches(n, ["squat", "lunge"]) {
            return [
                "Drive through the heel; knees track over toes",
                "Hit at least parallel — hips below or level with knees",
                "Brace your core, neutral spine, chest tall"
            ]
        }
        if matches(n, ["row", "pull", "deadlift"]) {
            return [
                "Drive the elbows back, lats do the work — not the biceps",
                "Squeeze shoulder blades at the top",
                "Flat back; don't round the lower spine"
            ]
        }
        if matches(n, ["plank"]) {
            return [
                "Form a straight line from shoulder to heel",
                "Brace the core; don't let hips sag or pike",
                "Breathe slowly — never hold your breath"
            ]
        }
        if matches(n, ["overhead", "shoulder"]) {
            return [
                "Keep the spine neutral; don't over-arch the lower back",
                "Press straight up, in line with the torso",
                "Squeeze glutes for a stable base"
            ]
        }
        if matches(n, ["stretch", "yoga", "mobility", "flow"]) {
            return [
                "Breathe deeply throughout each hold",
                "Ease in gradually — never bounce into a stretch",
                "Tension should feel productive, never painful"
            ]
        }
        if matches(n, ["run", "jog", "burpee", "jump", "cardio"]) {
            return [
                "Start easy, ramp the pace once warm",
                "Pace your breathing: 2 in, 2 out",
                "Stay tall and relaxed — shoulders down"
            ]
        }
        return [
            "Master the form before you push speed",
            "Full range of motion, controlled tempo",
            "Exhale on the effort phase of every rep"
        ]
    }

    static func alternatives(for normalizedName: String, language: AppLanguage) -> [String] {
        let n = normalizedName
        let isArabic = language == .arabic

        if matches(n, ["push", "ضغط", "بنش"]) {
            return isArabic
                ? ["ضغط مائل بزاوية", "ضغط بالركب", "ضغط بمطاط"]
                : ["Incline push-up", "Knee push-up", "Band-assisted press"]
        }
        if matches(n, ["squat", "سكوات"]) {
            return isArabic
                ? ["سكوات بكرسي", "سكوات وزن جسم", "سكوات بدامبل"]
                : ["Box squat", "Bodyweight squat", "Goblet squat"]
        }
        if matches(n, ["lunge", "لانجز"]) {
            return isArabic
                ? ["ريفرس لانجز", "ستيب أب", "لانجز بكرسي"]
                : ["Reverse lunge", "Step-up", "Split squat"]
        }
        if matches(n, ["row", "سحب", "رو", "pull"]) {
            return isArabic
                ? ["رو بمطاط", "إنفرتد رو", "دامبل رو بيد وحدة"]
                : ["Band row", "Inverted row", "Single-arm DB row"]
        }
        if matches(n, ["plank", "بلانك"]) {
            return isArabic
                ? ["بلانك بالركب", "بلانك جانبي", "بلانك مع رفع رجل"]
                : ["Knee plank", "Side plank", "Plank with leg lift"]
        }
        if matches(n, ["overhead", "shoulder", "كتف"]) {
            return isArabic
                ? ["دامبل برس جالس", "Arnold press", "ضغط مطاط فوق الرأس"]
                : ["Seated DB press", "Arnold press", "Band overhead press"]
        }
        if matches(n, ["run", "jog", "ركض", "burpee", "كارديو"]) {
            return isArabic
                ? ["مشي سريع", "نط حبل", "Jumping jacks"]
                : ["Brisk walk", "Jump rope", "Jumping jacks"]
        }
        if matches(n, ["stretch", "تمدد", "yoga"]) {
            return isArabic
                ? ["تنفّس 4-6", "تمدد قطة-بقرة", "فتح الورك"]
                : ["4-6 breathing", "Cat-cow flow", "Hip opener"]
        }
        return isArabic
            ? ["نسخة بوزن أخف", "نسخة وزن جسم", "نسخة جالسة"]
            : ["Lighter-load variant", "Bodyweight variant", "Seated variant"]
    }

    private static func matches(_ haystack: String, _ needles: [String]) -> Bool {
        for needle in needles where haystack.contains(needle.lowercased()) { return true }
        return false
    }
}
