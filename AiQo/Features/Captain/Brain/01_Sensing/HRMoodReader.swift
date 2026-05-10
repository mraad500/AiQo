// ===============================================
// File: HRMoodReader.swift
// Brain Refactor §49 — Physiological Mood Inference
//
// Text-based mood inference (hand-coded keywords + sentiment) is shallow:
// the user can say "بخير" while their heart rate is at 95bpm because they're
// stressed about the workout they're avoiding. World-class coaching reads
// the *body* alongside the words.
//
// This file infers the user's current mood from the gap between their live
// heart rate and their resting baseline, then *crosses* it with the recent
// activity context so a "high HR right after a workout" doesn't get
// misclassified as stress.
//
// Privacy: all reasoning happens on-device. The HR + resting HR values are
// never transmitted; only the *categorical mood* and a tone directive ride
// the prompt to the cloud.
//
// Pure local computation, runs in <0.5ms once HR data is in hand.
// ===============================================

import Foundation

// MARK: - Arousal + Mood

/// How activated the autonomic nervous system appears, derived from HR
/// elevation above resting. Five buckets — finer than three (the model
/// can't act on 7 distinct levels) and coarser than ten.
enum HRArousal: String, Sendable {
    /// HR within ±5 bpm of resting. Body is calm.
    case calm
    /// HR 5–15 bpm above resting. Mild engagement.
    case neutral
    /// HR 15–30 bpm above resting. Notable activation.
    case activated
    /// HR > 30 bpm above resting (and not from recent effort). High arousal.
    case highlyAroused
    /// No HR data, or sample too noisy to classify.
    case unknown
}

/// Best-guess mood the prompt narrates. Mood is *always* an inference —
/// the cross with `recentActivity` is what saves us from labelling every
/// post-workout state as "stressed."
enum HRInferredMood: String, Sendable {
    /// Calm + late hour, or calm + low effort context. Wind-down register.
    case relaxed
    /// Mid-range HR, no activity context. The default healthy state.
    case focused
    /// Activated + no recent workout — likely positive arousal.
    case excited
    /// Highly aroused + no recent workout. Stress signature.
    case stressed
    /// Activated/highly-aroused + fresh workout. Don't mistake for stress.
    case postEffort
    /// Calm + very late hour. Body is clearly winding down.
    case windingDown
    /// Insufficient data.
    case unknown
}

// MARK: - Reading

struct HRMoodReading: Sendable {
    let currentHR: Int?
    let restingHR: Int?
    /// `currentHR - restingHR`. Positive = elevation above baseline.
    /// `nil` when either value is missing.
    let elevationFromResting: Int?
    let arousal: HRArousal
    let mood: HRInferredMood
    /// 0–1; rises with sample completeness (HR + resting + activity context).
    let confidence: Double

    var hasSignal: Bool { mood != .unknown && arousal != .unknown }

    /// Iraqi-Arabic tone directive — what the prompt should tell the model
    /// about pacing, volume, and energy match.
    var toneDirectiveArabic: String {
        switch mood {
        case .relaxed:
            return "نبضه قريب من الراحة — تكلم بهدوء، جمل أطول قليلاً، نبرة دافئة"
        case .focused:
            return "نبضه طبيعي ومتزن — كلام دقيق ومباشر، بدون حشو"
        case .excited:
            return "نبضه مرفوع وطاقته إيجابية — جاريه بنفس الحماس، مختصر وسريع"
        case .stressed:
            return "نبضه مرفوع جداً والسياق يشير لتوتر — نبرة هادئة وداعمة، خطوة صغيرة وحدة، تجنب الضغط"
        case .postEffort:
            return "نبضه مرفوع لأنه توه خلّص جهد — اعترف بالتعب، اقترح ترطيب وراحة، لا تشد"
        case .windingDown:
            return "نبضه هابط ووقت متأخر — كلام مهدئ، اقتراحات للنوم"
        case .unknown:
            return "بيانات النبض غير كافية — استخدم الإشارات النصية فقط للنبرة"
        }
    }

    var toneDirectiveEnglish: String {
        switch mood {
        case .relaxed:
            return "HR near resting — speak calmly, slightly longer sentences, warm tone"
        case .focused:
            return "HR balanced — precise, direct, no filler"
        case .excited:
            return "HR elevated, positive arousal — match the energy, keep it brisk"
        case .stressed:
            return "HR elevated and context suggests stress — calm, supportive tone; one small step; avoid pressure"
        case .postEffort:
            return "HR elevated from a fresh session — acknowledge fatigue, suggest hydration + rest, don't push"
        case .windingDown:
            return "HR dropping and it's late — soothing tone, sleep-leaning suggestions"
        case .unknown:
            return "HR data insufficient — rely on text cues for tone"
        }
    }

    func toneDirective(language: AppLanguage) -> String {
        language == .arabic ? toneDirectiveArabic : toneDirectiveEnglish
    }

    static let unknown = HRMoodReading(
        currentHR: nil,
        restingHR: nil,
        elevationFromResting: nil,
        arousal: .unknown,
        mood: .unknown,
        confidence: 0.0
    )
}

// MARK: - Reader

@MainActor
enum HRMoodReader {

    /// Default resting-HR fallback when HealthKit doesn't expose one. 65 bpm
    /// is the population median for adults. We surface lower confidence
    /// when we fall back to it.
    ///
    /// §50 Round 6 Fix ξ — when a `UserProfileLens` is available the
    /// fallback scales with age bracket (younger users have lower resting
    /// baselines on average). Without a lens we still use the
    /// population median.
    static let defaultRestingHR: Int = 65

    /// Age-aware fallback. Conservative — these are population midpoints
    /// for the adult range; individual variance is large but the gap
    /// between "youth" and "senior" is clinically meaningful.
    static func restingHRBaseline(for ageBracket: AgeBracket?) -> Int {
        switch ageBracket {
        case .youth:        return 60   // 18–24, often more athletic
        case .prime:        return 62   // 25–39, peak fitness window
        case .established:  return 66   // 40–54
        case .senior:       return 70   // 55+
        case .none:         return defaultRestingHR
        }
    }

    /// Elevation thresholds (bpm above resting) for arousal classification.
    static let mildBand: Int = 5
    static let activatedBand: Int = 15
    static let highBand: Int = 30

    /// Pure synthesis. Caller is expected to have already fetched both
    /// values; the reader does no IO. `recentActivity` lets us cross-rule
    /// out post-workout elevation from "stress" mis-classification.
    ///
    /// §50 Round 6 — `profileLens` is consulted when `restingHR` is missing
    /// so the fallback baseline reflects the user's age bracket.
    static func read(
        currentHR: Int?,
        restingHR: Int?,
        recentActivity: RecentActivitySnapshot?,
        hour: Int,
        profileLens: UserProfileLens? = nil
    ) -> HRMoodReading {
        guard let current = currentHR, current > 0 else {
            return .unknown
        }

        let resting = (restingHR ?? Self.restingHRBaseline(for: profileLens?.ageBracket))
        let elevation = current - resting
        let arousal = classifyArousal(elevation: elevation)
        let isPostEffort = recentActivity?.freshness == .veryFresh
            && (recentActivity?.minutesSinceEnd ?? 999) <= 30
        let mood = classifyMood(
            arousal: arousal,
            elevation: elevation,
            isPostEffort: isPostEffort,
            hour: hour
        )

        // Confidence: full when we had a real resting baseline; partial
        // when we used the 65-bpm fallback. Activity cross-context adds
        // certainty when post-effort.
        var confidence = 0.6
        if restingHR != nil { confidence += 0.25 }
        if isPostEffort { confidence += 0.15 }
        confidence = min(1.0, confidence)

        return HRMoodReading(
            currentHR: current,
            restingHR: resting,
            elevationFromResting: elevation,
            arousal: arousal,
            mood: mood,
            confidence: confidence
        )
    }

    private static func classifyArousal(elevation: Int) -> HRArousal {
        switch elevation {
        case ..<(-mildBand):           return .calm
        case (-mildBand)...mildBand:   return .calm
        case (mildBand + 1)..<activatedBand:    return .neutral
        case activatedBand..<highBand: return .activated
        default:                       return .highlyAroused
        }
    }

    private static func classifyMood(
        arousal: HRArousal,
        elevation: Int,
        isPostEffort: Bool,
        hour: Int
    ) -> HRInferredMood {
        let isLate = hour >= 21 || hour < 5

        // Post-effort short-circuits everything — high HR is expected and
        // *not* stress.
        if isPostEffort, arousal == .activated || arousal == .highlyAroused {
            return .postEffort
        }

        switch arousal {
        case .calm:
            return isLate ? .windingDown : .relaxed
        case .neutral:
            return .focused
        case .activated:
            return .excited
        case .highlyAroused:
            // High HR + no fresh workout = likely stress / anxiety signal.
            return .stressed
        case .unknown:
            return .unknown
        }
    }
}
