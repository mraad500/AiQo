import Foundation
import UIKit
import os.log

/// Public entry point for on-device certificate verification.
///
/// Orchestrates a 2-stage pipeline:
/// 1. **Stage A — `CertificateOCR`:** Vision text extraction (Arabic + English).
/// 2. **Stage B — `HamoudiVerificationReasoner`:** Foundation Models reasoning over the
///    extracted text against the expected course metadata.
///
/// The image never leaves the device. Every attempt records a metadata-only entry
/// into `AuditLogger` — no image, no extracted text, no PII.
actor CertificateVerifier {
    static let shared = CertificateVerifier()

    enum Result: Sendable {
        case verified(confidence: Double, message: String)
        case needsReview(reason: String, message: String)
        case rejected(reason: String, message: String)
    }

    private let reasoner = HamoudiVerificationReasoner()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CertificateVerifier"
    )

    func verify(
        image: UIImage,
        course: LearningCourse,
        userFirstName: String,
        questId: String
    ) async -> Result {
        let startedAt = Date()

        // ══════════════════════════════════════════════════════════════════════
        //  TEMPORARY DEBUG — REMOVE AFTER DIAGNOSIS (2026-04-20).
        //  Logs the inputs Hamoudi is reasoning over so we can see why a
        //  legitimate certificate is landing at .needsReview / .rejected.
        //  All logs stay on-device (os.log → Console.app). Image bytes are
        //  NEVER logged — only size metadata + extracted text snippet.
        //  See architectural commitment in AiQoFeatureFlags.swift line 81.
        // ══════════════════════════════════════════════════════════════════════
        logger.notice("""
        debug_verify_input \
        course_id=\(course.id, privacy: .public) \
        expected_ar=\(course.titleAr, privacy: .public) \
        expected_en=\(course.titleEn, privacy: .public) \
        platform=\(course.platform.canonicalName, privacy: .public) \
        user_first_name=\(userFirstName, privacy: .public) \
        quest_id=\(questId, privacy: .public) \
        image_size=\(Int(image.size.width), privacy: .public)x\(Int(image.size.height), privacy: .public) \
        image_scale=\(image.scale, privacy: .public)
        """)

        // Rate limit — 3 attempts per hour. Guards the Foundation Models session from
        // abuse and protects the user's battery.
        //
        // DEBUG builds skip the rate limiter entirely so developers can iterate on
        // certificate verification during diagnosis. Release builds (production) still
        // enforce the cap strictly. This block's `#if DEBUG` branch also clears any
        // stored attempt history so re-running on a DEBUG build doesn't carry
        // rate-limit state from a previous session.
        #if DEBUG
        VerificationRateLimiter.reset()
        logger.notice("debug_rate_limiter_bypassed reason=debug_build")
        #else
        guard VerificationRateLimiter.canAttempt(now: startedAt) else {
            let minutesRemaining = Int((VerificationRateLimiter.retryAfterSeconds(now: startedAt) / 60).rounded(.up))
            let message = "جربت 3 مرات بالساعة، خل نستريح شوية. جرب بعد \(max(minutesRemaining, 1)) دقيقة أو تواصل معانا لو عندك مشكلة."
            logger.notice("debug_rate_limited retry_after_min=\(minutesRemaining, privacy: .public)")
            await recordAudit(
                startedAt: startedAt,
                outcome: .rateLimit,
                consentGranted: OnDeviceVerificationConsent.hasConsented,
                questId: questId
            )
            return .rejected(reason: "rate_limit", message: message)
        }
        VerificationRateLimiter.recordAttempt(now: startedAt)
        #endif

        // Stage A — on-device OCR.
        let ocrResult: CertificateOCR.Result
        do {
            ocrResult = try await CertificateOCR.extractText(from: image)
        } catch {
            logger.error("ocr_failed error=\(error.localizedDescription, privacy: .public)")
            let message = "حبيبي الصورة مو واضحة، صورها مرة ثانية بإضاءة أحسن."
            await recordAudit(
                startedAt: startedAt,
                outcome: .ocrFailed,
                consentGranted: OnDeviceVerificationConsent.hasConsented,
                questId: questId
            )
            return .rejected(reason: "ocr_failed", message: message)
        }

        // TEMPORARY DEBUG — see ocr output to diagnose match failures.
        logger.notice("""
        debug_ocr_result \
        char_count=\(ocrResult.extractedText.count, privacy: .public) \
        text=\(ocrResult.extractedText, privacy: .public)
        """)

        // Stage B — on-device reasoning.
        let verdict = await reasoner.reason(
            extractedText: ocrResult.extractedText,
            course: course,
            userFirstName: userFirstName
        )

        // TEMPORARY DEBUG — see Hamoudi's verdict before mapping to user-visible result.
        logger.notice("""
        debug_hamoudi_verdict \
        status=\(verdict.status.rawValue, privacy: .public) \
        confidence=\(verdict.confidence, privacy: .public) \
        reason=\(verdict.reason, privacy: .public) \
        detected_course=\(verdict.detectedCourseName ?? "nil", privacy: .public) \
        detected_user=\(verdict.detectedUserName ?? "nil", privacy: .public)
        """)

        let result = Self.mapVerdictToResult(verdict)
        let outcome = Self.mapResultToAudit(result)

        await recordAudit(
            startedAt: startedAt,
            outcome: outcome,
            consentGranted: OnDeviceVerificationConsent.hasConsented,
            questId: questId
        )

        return result
    }

    // MARK: - Mapping

    private static func mapVerdictToResult(_ verdict: HamoudiVerificationReasoner.Verdict) -> Result {
        switch verdict.status {
        case .verified:
            return .verified(confidence: verdict.confidence, message: verdict.hamoudiMessageAr)
        case .needsReview:
            return .needsReview(reason: verdict.reason, message: verdict.hamoudiMessageAr)
        case .rejected:
            return .rejected(reason: verdict.reason, message: verdict.hamoudiMessageAr)
        }
    }

    private static func mapResultToAudit(_ result: Result) -> AuditLogger.Entry.Outcome {
        switch result {
        case .verified: return .verified
        case .needsReview: return .needsReview
        case .rejected: return .rejected
        }
    }

    // MARK: - Audit (metadata only; no image, no extracted text)

    private func recordAudit(
        startedAt: Date,
        outcome: AuditLogger.Entry.Outcome,
        consentGranted: Bool,
        questId: String
    ) async {
        let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        let tier = await MainActor.run { AccessManager.shared.activeTier.auditLabel }
        // Segment the audit purpose by stage so Stage 1 vs Stage 2 completion funnels
        // can be analyzed later without schema changes. "learningSpark.stage1" or
        // "learningSpark.stage2" — resolved via LearningChallengeRegistry.
        let stage = await MainActor.run { LearningChallengeRegistry.stage(for: questId) }
        let entry = AuditLogger.Entry(
            id: UUID(),
            timestamp: startedAt,
            destination: "on_device_verification",
            tier: tier,
            promptBytes: 0,
            responseBytes: 0,
            latencyMs: latencyMs,
            consentGranted: consentGranted,
            sanitizationApplied: false,
            purpose: "learningSpark.stage\(stage)",
            outcome: outcome
        )
        await AuditLogger.shared.record(entry)
    }
}
