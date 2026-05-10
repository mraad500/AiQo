// ===============================================
// File: UserProfileLens.swift
// Brain Refactor §39 — Demographic-Aware Calibration
//
// Translates the user's stable profile (age, weight, primary goal, level) into
// reasoning-grade modifiers: appropriate intensity ceilings, what counts as a
// "personal best" for *this* user, and a one-sentence coaching directive that
// the prompt prepends to the reasoning brief.
//
// Without this lens, the reasoner uses the same thresholds for a 25-year-old
// marathoner and a 55-year-old beginner — "celebrate 8,000 steps" lands very
// differently for each. With it, the brief speaks to the actual person.
// ===============================================

import Foundation

// MARK: - Profile Lens

enum AgeBracket: String, Sendable {
    /// Under 25 — high recovery capacity, prone to over-doing it.
    case youth
    /// 25–39 — peak athletic window, good intensity tolerance.
    case prime
    /// 40–54 — recovery slows, still highly capable, joint care matters.
    case established
    /// 55+ — bias mobility/walking, careful with high-impact suggestions.
    case senior

    static func from(age: Int) -> AgeBracket {
        switch age {
        case ..<25:    return .youth
        case 25..<40:  return .prime
        case 40..<55:  return .established
        default:       return .senior
        }
    }
}

enum ExperienceLevel: String, Sendable {
    case novice
    case intermediate
    case advanced

    /// Inferred from the AiQo level + the volume of recorded workouts. Levels
    /// 1–10 + few sessions = novice. Levels ≥ 25 with consistent activity =
    /// advanced. Everything in between = intermediate.
    static func infer(level: Int, workoutCount: Int) -> ExperienceLevel {
        if level >= 25 && workoutCount >= 5 { return .advanced }
        if level <= 8 || workoutCount <= 2  { return .novice }
        return .intermediate
    }
}

/// Bundles everything the reasoner needs to *calibrate* its angle decisions
/// and the prompt needs to *narrate* tone for this specific user.
struct UserProfileLens: Sendable {
    let age: Int?
    let ageBracket: AgeBracket?
    let weightKg: Double?
    let primaryGoal: CaptainPrimaryGoal?
    let experience: ExperienceLevel
    let level: Int

    // MARK: Threshold modifiers

    /// What counts as a "notable" daily steps total for this user. Used by
    /// the reasoner to decide whether to fire a `stepsPersonalBest` pattern.
    /// Younger / advanced users have higher floors so the Captain doesn't
    /// celebrate trivial wins.
    var stepsPersonalBestFloor: Int {
        switch (ageBracket, experience) {
        case (.senior, _):              return 4_000
        case (.established, .novice):   return 5_000
        case (_, .advanced):            return 9_000
        case (.youth, _):               return 8_000
        case (.prime, _):               return 7_000
        default:                        return 6_000
        }
    }

    /// Hours of sleep below which the reasoner treats it as "low" *for this
    /// user*. Older users feel deficits earlier — the threshold is generous.
    var lowSleepThresholdHours: Double {
        switch ageBracket {
        case .senior, .established: return 6.5
        default:                    return 6.0
        }
    }

    /// One-sentence directive the prompt renders so the model adapts language
    /// + intensity suggestions. Iraqi-Arabic; English mirror also produced.
    var coachingDirectiveArabic: String {
        var pieces: [String] = []

        switch ageBracket {
        case .senior:
            pieces.append("المستخدم 55+ — انحاز للمشي والإطالة، وتجنب اقتراحات عالية الشدة")
        case .established:
            pieces.append("المستخدم 40-54 — اهتم بالاستشفاء وصحة المفاصل، الشدة المعتدلة كافية")
        case .prime:
            pieces.append("المستخدم 25-39 — قابل للشدة العالية، شجّع التطوّر")
        case .youth:
            pieces.append("المستخدم تحت 25 — طاقة عالية بس عرضة للإفراط، حذّر من overtraining لمّا يلزم")
        case .none:
            break
        }

        switch experience {
        case .novice:
            pieces.append("مبتدئ — اقترح خطوات صغيرة، تجنب المصطلحات التقنية، احتفل بالأساسيات")
        case .intermediate:
            pieces.append("متوسط — تكدر تستخدم مصطلحات أوسع، تدرّج محسوب")
        case .advanced:
            pieces.append("متقدم — تحدث بدقة، اقترح تطورات قابلة للقياس")
        }

        if let goal = primaryGoal {
            pieces.append(goalDirectiveArabic(goal))
        }

        return pieces.joined(separator: " · ")
    }

    var coachingDirectiveEnglish: String {
        var pieces: [String] = []

        switch ageBracket {
        case .senior:
            pieces.append("User is 55+ — bias toward walking and mobility, avoid high-impact suggestions")
        case .established:
            pieces.append("User is 40–54 — prioritise recovery and joint care, moderate intensity is enough")
        case .prime:
            pieces.append("User is 25–39 — high-intensity capable, encourage progression")
        case .youth:
            pieces.append("User is under 25 — high energy but overtraining risk, flag it when relevant")
        case .none:
            break
        }

        switch experience {
        case .novice:
            pieces.append("Novice — small steps, avoid jargon, celebrate fundamentals")
        case .intermediate:
            pieces.append("Intermediate — broader vocabulary OK, progressive loading")
        case .advanced:
            pieces.append("Advanced — precise language, measurable progressions")
        }

        if let goal = primaryGoal {
            pieces.append(goalDirectiveEnglish(goal))
        }

        return pieces.joined(separator: " · ")
    }

    private func goalDirectiveArabic(_ goal: CaptainPrimaryGoal) -> String {
        switch goal {
        case .loseWeight:     return "هدفه نزول وزن — اربط النصائح بحرق دهون مستدام، لا تشدد على القيود السعرية القاسية"
        case .gainWeight:     return "هدفه زيادة وزن — اربط بفائض السعرات الذكي والبروتين"
        case .cutFat:         return "هدفه نشف دهون — اربط بالـ Zone 2 والبروتين العالي"
        case .buildMuscle:    return "هدفه بناء عضلات — اربط بالحمل المتدرج والاستشفاء"
        case .improveFitness: return "هدفه لياقة عامة — اربط بالاستمرارية مو الشدة"
        }
    }

    private func goalDirectiveEnglish(_ goal: CaptainPrimaryGoal) -> String {
        switch goal {
        case .loseWeight:     return "Goal: weight loss — anchor on sustainable fat burn, avoid harsh calorie restriction"
        case .gainWeight:     return "Goal: weight gain — anchor on smart calorie surplus + protein"
        case .cutFat:         return "Goal: cut fat — anchor on Zone 2 + high protein"
        case .buildMuscle:    return "Goal: muscle build — anchor on progressive overload + recovery"
        case .improveFitness: return "Goal: general fitness — anchor on consistency over intensity"
        }
    }
}

// MARK: - Shared UserDefaults Keys (Brain §50 Round 6 Fix λ)

/// Single source of truth for the customization-screen UserDefaults keys.
/// Both `CaptainViewModel.Keys` and `UserProfileLensBuilder` reference this
/// enum so a future rename can't silently break the lens read path.
enum CaptainCustomizationKeys {
    static let name = "captain_user_name"
    static let age = "captain_user_age"
    static let height = "captain_user_height"
    static let weight = "captain_user_weight"
    static let calling = "captain_calling"
    static let tone = "captain_tone"
}

// MARK: - Builder

@MainActor
enum UserProfileLensBuilder {

    /// Reads from `CaptainPersonalizationStore` (primary goal) and the existing
    /// customization fields (age, weight) to build the lens. Returns `nil`
    /// only when *no* personalization is available — most fields are
    /// optional individually.
    static func build(
        ageString: String?,
        weightString: String?,
        level: Int,
        recentWorkoutCount: Int,
        primaryGoal: CaptainPrimaryGoal?
    ) -> UserProfileLens {
        let age = ageString.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let weight = weightString.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let bracket = age.map(AgeBracket.from(age:))
        let experience = ExperienceLevel.infer(
            level: level,
            workoutCount: recentWorkoutCount
        )

        return UserProfileLens(
            age: age,
            ageBracket: bracket,
            weightKg: weight,
            primaryGoal: primaryGoal,
            experience: experience,
            level: level
        )
    }
}
