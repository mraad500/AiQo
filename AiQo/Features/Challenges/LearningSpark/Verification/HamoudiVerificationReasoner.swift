import Foundation
import os.log

/// Top-level verification status shared across the certificate-verification
/// pipeline. Lives outside the `HamoudiVerificationReasoner` actor so
/// non-actor consumers (e.g. `CertificateTextMatcher`) can reference it
/// without inheriting actor isolation.
enum HamoudiVerificationStatus: String, Codable, Sendable {
    case verified
    case needsReview = "needs_review"
    case rejected
}

/// Stage B of the on-device certificate-verification pipeline.
///
/// Calls `CertificateTextMatcher` for the verification decision, then maps the
/// emitted reason code to a warm Iraqi-Arabic Hamoudi message. No cloud call is
/// made here — the whole flow stays on device.
///
/// ## Why no Foundation Models LM
///
/// Apple Intelligence on iOS 26.x AR locales throws
/// `An unsupported language or locale was used` whenever the prompt contains
/// Arabic — including Arabic values in the user payload (course title, OCR text).
/// That makes `LanguageModelSession` unusable for bilingual certificates on
/// Arabic-region devices. We replaced the LM classifier with a rule-based
/// matcher that does the same job deterministically on-device (see
/// `CertificateTextMatcher.swift`). The zero-cloud-verification commitment is
/// preserved — image + OCR text never leave the device.
///
/// A Phase-2 enhancement may optionally personalize the verified message via the
/// Captain API cloud LLM (consent-gated, verdict-only payload, Swift fallback).
/// That lives in a separate service so this actor stays on-device-only.
actor HamoudiVerificationReasoner {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HamoudiVerificationReasoner"
    )

    /// Alias kept for call-site compatibility. The canonical enum is the
    /// top-level `HamoudiVerificationStatus` above.
    typealias Status = HamoudiVerificationStatus

    struct Verdict: Sendable {
        let status: Status
        let confidence: Double
        let detectedCourseName: String?
        let detectedUserName: String?
        /// Short English technical reason. Never shown to the user — used in audit trail
        /// and for rejection-card copy.
        let reason: String
        /// Warm Iraqi-Arabic message shown to the user via the Captain message card.
        let hamoudiMessageAr: String
    }

    func reason(
        extractedText: String,
        course: LearningCourse,
        userFirstName: String
    ) async -> Verdict {

        // FeatureFlags + UserProfileStore statics are MainActor-isolated under Swift 6
        // strict concurrency. One short MainActor hop reads both — cheaper than
        // marking the whole enums nonisolated. Gender feeds the gender-aware Hamoudi
        // copy downstream.
        let (onDeviceEnabled, gender) = await MainActor.run {
            (FeatureFlags.learningVerificationOnDeviceEnabled,
             UserProfileStore.shared.current.gender)
        }
        if !onDeviceEnabled {
            return Verdict(
                status: .needsReview,
                confidence: 0,
                detectedCourseName: nil,
                detectedUserName: nil,
                reason: "on_device_flag_disabled",
                hamoudiMessageAr: Self.iosUnavailableMessage
            )
        }

        // On-device rule-based classification (deterministic, fast, Arabic-aware).
        let match = CertificateTextMatcher.classify(
            extractedText: extractedText,
            course: course,
            userFirstName: userFirstName
        )

        logger.notice("""
        debug_matcher_result \
        status=\(match.status.rawValue, privacy: .public) \
        reason=\(match.reason.rawValue, privacy: .public) \
        confidence=\(match.confidence, privacy: .public) \
        detected_course=\(match.detectedCourseName ?? "nil", privacy: .public) \
        detected_user=\(match.detectedUserName ?? "nil", privacy: .public)
        """)

        return Verdict(
            status: match.status,
            confidence: match.confidence,
            detectedCourseName: match.detectedCourseName,
            detectedUserName: match.detectedUserName,
            reason: match.reason.rawValue,
            hamoudiMessageAr: Self.hamoudiMessage(
                forReason: match.reason.rawValue,
                gender: gender
            )
        )
    }

    // MARK: - Hamoudi Copy (Swift-side, Arabic)

    /// Shown when the on-device verification flag is disabled (manual kill-switch).
    static let iosUnavailableMessage = "حبيبي جهازك الحالي ما يدعم التحقق الذكي. الشهادة محفوظة عندك، جرب من جهاز أحدث أو استنى تحديث iOS جاي."

    /// Fallback for unknown reason codes.
    static let genericUnclearMessage = "شكلها زينة بس خل أتأكد شوية، ارفعها مرة ثانية أو خلي الصورة أوضح."

    /// Maps a matcher reason code to the warm Iraqi-Arabic message the user
    /// sees. For the `.verified` outcome the message is gender-aware; other
    /// outcomes use neutral copy.
    ///
    /// Exposed `static func` so the forthcoming `CertificateResponseService`
    /// (Phase 2 — Captain cloud API) can fall back to this deterministic copy
    /// when the cloud is unavailable, consent is not granted, or the tier gate
    /// blocks the call.
    static func hamoudiMessage(
        forReason reason: String,
        gender: ActivityNotificationGender?
    ) -> String {
        switch reason.lowercased() {
        case "verified":
            return verifiedMessage(for: gender)
        case "course_ambiguous", "user_ambiguous", "both_ambiguous":
            return "شكلها زينة بس خل أتأكد شوية، ارفعها مرة ثانية أو خلي الصورة أوضح."
        case "wrong_course":
            return "هاي الشهادة ما تخص الكورس اللي اخترته، تأكد من رفع الشهادة الصحيحة."
        case "image_unclear", "no_certificate_text":
            return "حبيبي الصورة مو واضحة، صورها مرة ثانية بإضاءة أحسن."
        default:
            return genericUnclearMessage
        }
    }

    /// Gender-aware "verified" copy. Male keeps the casual Iraqi "حجي" vocative;
    /// female and gender-unset drop it (it's male-addressing in Iraqi dialect).
    private static func verifiedMessage(for gender: ActivityNotificationGender?) -> String {
        switch gender {
        case .male:
            return "حجي الف مبروك! الشهادة وصلت وكلشي تمام، فخورين بيك."
        case .female:
            return "الف مبروك! الشهادة وصلت وكلشي تمام، فخورين بيج."
        case .none:
            return "الف مبروك! الشهادة وصلت وكلشي تمام، إنجاز يستاهل الاحتفال."
        }
    }
}
