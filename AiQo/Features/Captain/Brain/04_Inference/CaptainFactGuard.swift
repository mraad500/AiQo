import Foundation
import os.log

/// Deterministic guard that stops the Captain from stating health numbers that
/// contradict the user's REAL HealthKit snapshot.
///
/// An LLM can confidently invent figures — "اليوم مشيت ١٢ ألف خطوة!" when the
/// device recorded 4,962. On a *health* product that is both a trust-killer and
/// a liability. This guard runs AFTER generation (cloud or on-device), scans the
/// reply for metric claims, and rewrites any number that diverges from the real
/// value beyond a rounding tolerance. It is pure string work — NO model, NO
/// network — so it can never hallucinate a correction.
///
/// Design choices that keep false-positives near zero:
/// - Only metrics that are actually known (> 0) are checked; a missing snapshot
///   never "corrects" a number to zero.
/// - A stated value within `relativeTolerance` of the truth is left alone, so
///   legitimate rounding ("5000" for 4,962) is never robotically rewritten.
/// - A match preceded by a past-time marker ("امبارح"، "yesterday"، "last week")
///   is skipped — the snapshot describes today, so historical references are
///   out of scope.
/// `nonisolated` so it can run inside any isolation domain — the cloud path
/// (MainActor) and the free on-device path (`CaptainOnDeviceChatEngine` actor)
/// both call it. It holds no mutable shared state (only a `let` tolerance + a
/// Sendable logger), so opting out of the module's default actor isolation is
/// safe and correct.
nonisolated struct CaptainFactGuard: Sendable {

    /// Real, current-day metrics. Any field left `nil` (or non-positive) is
    /// treated as "unknown" and never used to rewrite the reply.
    struct Facts: Sendable, Equatable {
        var steps: Int?
        var activeCalories: Int?
        var heartRate: Int?

        var hasAnything: Bool {
            (steps ?? 0) > 0 || (activeCalories ?? 0) > 0 || (heartRate ?? 0) > 0
        }
    }

    struct Result: Sendable {
        let message: String
        let correctionCount: Int
        var didCorrect: Bool { correctionCount > 0 }
    }

    /// A stated number within this fraction of the true value is accepted as
    /// rounding. 0.15 → "5000" passes for a real 4,962 (0.8% off) but "12000"
    /// is corrected (142% off).
    private let relativeTolerance: Double

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainFactGuard"
    )

    init(relativeTolerance: Double = 0.15) {
        self.relativeTolerance = relativeTolerance
    }

    // MARK: - Public API

    func corrected(_ message: String, facts: Facts) -> Result {
        guard facts.hasAnything,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Result(message: message, correctionCount: 0)
        }

        var working = message
        var corrections = 0

        if let steps = facts.steps, steps > 0 {
            corrections += correctMetric(in: &working, realValue: steps, unitPatterns: Self.stepUnits)
        }
        if let calories = facts.activeCalories, calories > 0 {
            corrections += correctMetric(in: &working, realValue: calories, unitPatterns: Self.calorieUnits)
        }
        if let heartRate = facts.heartRate, heartRate > 0 {
            corrections += correctMetric(in: &working, realValue: heartRate, unitPatterns: Self.heartRateUnits)
        }

        if corrections > 0 {
            logger.notice("fact_guard_corrected count=\(corrections)")
        }
        return Result(message: working, correctionCount: corrections)
    }

    // MARK: - Unit vocabularies (Arabic + English)

    private static let stepUnits = ["خطوة", "خطوات", "خطوه", "steps", "step"]
    private static let calorieUnits = [
        "سعرة", "سعرات", "سعره", "كالوري", "كالوريز",
        "calories", "calorie", "kcal", "cal"
    ]
    private static let heartRateUnits = ["نبضة", "نبضات", "نبضه", "bpm"]

    /// Past-time markers — if one appears just before a number, the claim is
    /// about another day and the current snapshot must not overwrite it.
    private static let pastMarkers = [
        "امبارح", "إمبارح", "البارحة", "بارح", "قبل", "الماضي", "الفائت", "سابق",
        "yesterday", "last", "ago", "previous", "earlier"
    ]

    // MARK: - Core matcher

    private func correctMetric(in text: inout String, realValue: Int, unitPatterns: [String]) -> Int {
        let unitGroup = unitPatterns
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        // <quantity><gap><unit> where quantity = digits (Western or Arabic-Indic)
        // with optional separators and an optional thousands word (ألف / k).
        // A letter-boundary lookahead stops "خطوة" matching inside a longer word.
        let pattern =
            "([\\d٠-٩][\\d٠-٩.,٬]*(?:\\s*(?:ألف|الف|آلاف|[kK]))?)(\\s*)(?:\(unitGroup))(?![\\p{L}])"

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }

        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return 0 }

        var corrections = 0
        // Replace right-to-left so earlier match ranges stay valid.
        for match in matches.reversed() {
            let quantityRange = match.range(at: 1)
            guard quantityRange.location != NSNotFound else { continue }
            let quantity = ns.substring(with: quantityRange)

            guard !isPrecededByPastMarker(in: ns, before: match.range.location) else { continue }
            guard let stated = parseQuantity(quantity) else { continue }

            let error = abs(stated - Double(realValue)) / Double(max(realValue, 1))
            guard error > relativeTolerance else { continue }

            let usesArabicDigits = quantity.unicodeScalars.contains { $0 >= "٠" && $0 <= "٩" }
            let replacement = format(realValue, arabicDigits: usesArabicDigits)
            text = (text as NSString).replacingCharacters(in: quantityRange, with: replacement)
            corrections += 1
        }
        return corrections
    }

    // MARK: - Helpers

    /// Parses a matched quantity ("١٢ ألف", "12,000", "78") into a number,
    /// applying the ×1000 thousands word and normalizing digit systems.
    private func parseQuantity(_ raw: String) -> Double? {
        var s = raw
        var multiplier = 1.0
        for word in ["ألف", "الف", "آلاف"] where s.contains(word) {
            multiplier = 1000
            s = s.replacingOccurrences(of: word, with: "")
        }
        if s.contains("k") || s.contains("K") {
            multiplier = 1000
            s = s.replacingOccurrences(of: "k", with: "").replacingOccurrences(of: "K", with: "")
        }

        // Arabic-Indic → Western digits.
        var western = ""
        for scalar in s.unicodeScalars {
            if scalar >= "٠" && scalar <= "٩" {
                western.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x0660 + 0x30)!)
            } else {
                western.unicodeScalars.append(scalar)
            }
        }

        // Strip grouping separators / spaces; keep one decimal point.
        let cleaned = western
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "٬", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned) else { return nil }
        return value * multiplier
    }

    private func format(_ value: Int, arabicDigits: Bool) -> String {
        let western = String(value)
        guard arabicDigits else { return western }
        var arabic = ""
        for scalar in western.unicodeScalars {
            if scalar >= "0" && scalar <= "9" {
                arabic.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x30 + 0x0660)!)
            } else {
                arabic.unicodeScalars.append(scalar)
            }
        }
        return arabic
    }

    /// True when a past-time marker sits in the ~24 chars immediately before the
    /// number — meaning the claim is about another day, not today's snapshot.
    private func isPrecededByPastMarker(in text: NSString, before location: Int) -> Bool {
        let windowStart = max(0, location - 24)
        let window = text.substring(with: NSRange(location: windowStart, length: location - windowStart))
            .lowercased()
        return Self.pastMarkers.contains { window.contains($0.lowercased()) }
    }
}
