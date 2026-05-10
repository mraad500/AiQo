// ===============================================
// File: RecentActivitySnapshot.swift
// Brain Refactor §33 — Recent-Activity Awareness
//
// Surfaces the most recent completed workout as a *structured fact* so the
// Captain prompt can encode hard "do not suggest the same activity" rules.
// Without this, the model only sees raw `steps_today` and a 50-char chat-log
// truncation — which is why Hamoudi recommended a walk to a user who had just
// finished a 45-minute walk (real bug, screenshot 2026-05-09).
// ===============================================

import Foundation

// MARK: - Snapshot

/// Freshness window for the most recent workout. The Captain prompt uses this
/// to decide whether the activity is "still active context" (anti-repeat rules
/// kick in) or merely historical reference.
enum RecentActivityFreshness: String, Sendable {
    /// Ended within the last hour. The user is *still in the workout's wake* —
    /// recovery cues, hydration, stretching are appropriate; repeating the
    /// activity is a hard failure.
    case veryFresh
    /// Ended 1–6 hours ago. The activity is still load-bearing context for
    /// today's coaching but the user may be ready for a *different* low-impact
    /// session.
    case fresh
    /// Ended 6–24 hours ago. Reference only — no anti-repeat rule.
    case stale
}

/// Canonical activity family used for anti-repeat matching. The raw workout
/// title can vary (`"مشي"`, `"Walking"`, `"Outdoor Walk"`) but the family is
/// stable — that's what we feed to the prompt as "do not suggest X".
enum RecentActivityFamily: String, Sendable {
    case walking
    case running
    case cycling
    case strength
    case hiit
    case yoga
    case swimming
    case calisthenics
    case pilates
    case gratitude
    case boxing
    case martialArts
    case sport          // football, basketball, padel, tennis
    case jumpRope
    case stairs
    case elliptical
    case equestrian
    case cinematic      // Cinematic Grind / Cardio with Captain
    case other

    /// Arabic label used in the prompt — keeps Hamoudi's voice consistent
    /// instead of leaking English category names.
    var arabicLabel: String {
        switch self {
        case .walking:      return "مشي"
        case .running:      return "ركض"
        case .cycling:      return "دراجة"
        case .strength:     return "تمارين قوة"
        case .hiit:         return "HIIT"
        case .yoga:         return "يوغا"
        case .swimming:     return "سباحة"
        case .calisthenics: return "تمارين وزن الجسم"
        case .pilates:      return "بيلاتس"
        case .gratitude:    return "جلسة امتنان"
        case .boxing:       return "ملاكمة"
        case .martialArts:  return "فنون قتالية"
        case .sport:        return "رياضة جماعية"
        case .jumpRope:     return "نط حبل"
        case .stairs:       return "صعود درج"
        case .elliptical:   return "إليبتكال"
        case .equestrian:   return "فروسية"
        case .cinematic:    return "كارديو ويا الكابتن"
        case .other:        return "تمرين"
        }
    }

    var englishLabel: String {
        switch self {
        case .walking:      return "walking"
        case .running:      return "running"
        case .cycling:      return "cycling"
        case .strength:     return "strength training"
        case .hiit:         return "HIIT"
        case .yoga:         return "yoga"
        case .swimming:     return "swimming"
        case .calisthenics: return "calisthenics"
        case .pilates:      return "pilates"
        case .gratitude:    return "gratitude session"
        case .boxing:       return "boxing"
        case .martialArts:  return "martial arts"
        case .sport:        return "team sport"
        case .jumpRope:     return "jump rope"
        case .stairs:       return "stair climbing"
        case .elliptical:   return "elliptical"
        case .equestrian:   return "equestrian"
        case .cinematic:    return "cardio with Captain"
        case .other:        return "workout"
        }
    }

    /// Maps a free-form workout title (often localized, sometimes raw HK type)
    /// to the canonical family. Match on substring of the *normalized* title —
    /// case + diacritic insensitive.
    static func classify(title: String) -> RecentActivityFamily {
        let normalized = title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        // Order matters: longer / more specific patterns first.
        if normalized.contains("hiit")          { return .hiit }
        if normalized.contains("cinematic") || normalized.contains("سينماتك") || normalized.contains("ويا الكابتن") {
            return .cinematic
        }
        if normalized.contains("ركض") || normalized.contains("جري") || normalized.contains("run") {
            return .running
        }
        if normalized.contains("مشي") || normalized.contains("walk") {
            return .walking
        }
        if normalized.contains("دراج") || normalized.contains("cycl") || normalized.contains("bike") {
            return .cycling
        }
        if normalized.contains("سباح") || normalized.contains("swim") {
            return .swimming
        }
        if normalized.contains("يوغا") || normalized.contains("yoga") {
            return .yoga
        }
        if normalized.contains("بيلاتس") || normalized.contains("pilates") {
            return .pilates
        }
        if normalized.contains("ملاكم") || normalized.contains("box") {
            return .boxing
        }
        if normalized.contains("فنون قتال") || normalized.contains("martial") {
            return .martialArts
        }
        if normalized.contains("امتنان") || normalized.contains("gratitude") {
            return .gratitude
        }
        if normalized.contains("نط") || normalized.contains("jump rope") || normalized.contains("rope") {
            return .jumpRope
        }
        if normalized.contains("درج") || normalized.contains("stair") {
            return .stairs
        }
        if normalized.contains("إليبتكال") || normalized.contains("elliptical") {
            return .elliptical
        }
        if normalized.contains("فروسي") || normalized.contains("equest") {
            return .equestrian
        }
        if normalized.contains("وزن الجسم") || normalized.contains("calisthen") {
            return .calisthenics
        }
        if normalized.contains("قوة") || normalized.contains("strength") || normalized.contains("resist") || normalized.contains("حديد") {
            return .strength
        }
        if normalized.contains("كرة") || normalized.contains("football") || normalized.contains("basket") || normalized.contains("padel") || normalized.contains("tennis") {
            return .sport
        }
        return .other
    }
}

/// Structured snapshot of the user's most recent workout, plus everything the
/// prompt layer needs to reason about it: how long ago it ended, how fresh
/// the load is, and the canonical family for anti-repeat enforcement.
struct RecentActivitySnapshot: Sendable {
    let title: String                 // raw user-facing title ("مشي", "Walking")
    let family: RecentActivityFamily  // canonical for anti-repeat
    let durationMinutes: Int
    let activeCalories: Int
    let distanceKm: Double?           // nil when not a distance workout
    let endedAt: Date
    let minutesSinceEnd: Int

    var freshness: RecentActivityFreshness {
        switch minutesSinceEnd {
        case ..<60:        return .veryFresh
        case 60..<360:     return .fresh
        default:           return .stale
        }
    }

    /// Localized "ended N minutes/hours ago" phrase. Iraqi-friendly.
    func endedAgoPhrase(language: AppLanguage) -> String {
        let isArabic = language == .arabic
        if minutesSinceEnd < 60 {
            return isArabic
                ? "خلصه قبل \(minutesSinceEnd) دقيقة"
                : "ended \(minutesSinceEnd) min ago"
        }
        let hours = minutesSinceEnd / 60
        let remainder = minutesSinceEnd % 60
        if remainder == 0 {
            return isArabic
                ? "خلصه قبل \(hours) ساعة"
                : "ended \(hours)h ago"
        }
        return isArabic
            ? "خلصه قبل \(hours) ساعة و\(remainder) دقيقة"
            : "ended \(hours)h \(remainder)m ago"
    }
}

// MARK: - Provider

/// Reads the most recent entry from `WorkoutHistoryStore` and converts it into
/// a `RecentActivitySnapshot`. Pure adapter — no network, no HealthKit, no
/// SwiftData. Safe to call from any synchronous context on the main actor.
@MainActor
enum RecentActivityProvider {

    /// Look-back window — anything older than this is considered "stale enough
    /// not to constrain the next reply." Mirrors the freshness ladder.
    static let lookbackHours: Int = 24

    /// Returns the most recent workout if it ended within `lookbackHours`,
    /// otherwise `nil`. The 60-second floor matches `WorkoutHistoryStore`'s
    /// own minimum-duration filter — no need to re-validate here.
    static func mostRecent(now: Date = Date()) -> RecentActivitySnapshot? {
        guard let entry = WorkoutHistoryStore.shared.recentEntries().first else {
            return nil
        }

        let secondsSinceEnd = now.timeIntervalSince(entry.date)
        guard secondsSinceEnd >= 0 else { return nil }   // clock skew guard
        let minutesSinceEnd = Int(secondsSinceEnd / 60)
        guard minutesSinceEnd < lookbackHours * 60 else { return nil }

        let distanceKm: Double? = entry.distanceMeters >= 100
            ? entry.distanceMeters / 1000
            : nil

        return RecentActivitySnapshot(
            title: entry.title,
            family: RecentActivityFamily.classify(title: entry.title),
            durationMinutes: max(1, entry.durationSeconds / 60),
            activeCalories: Int(entry.activeCalories.rounded()),
            distanceKm: distanceKm,
            endedAt: entry.date,
            minutesSinceEnd: minutesSinceEnd
        )
    }
}
