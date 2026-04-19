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
        userFirstName: String
    ) async -> Result {
        let startedAt = Date()

        // Rate limit — 3 attempts per hour. Guards the Foundation Models session from
        // abuse and protects the user's battery.
        guard VerificationRateLimiter.canAttempt(now: startedAt) else {
            let minutesRemaining = Int((VerificationRateLimiter.retryAfterSeconds(now: startedAt) / 60).rounded(.up))
            let message = "جربت 3 مرات بالساعة، خل نستريح شوية. جرب بعد \(max(minutesRemaining, 1)) دقيقة أو تواصل معانا لو عندك مشكلة."
            await recordAudit(
                startedAt: startedAt,
                outcome: .rateLimit,
                consentGranted: OnDeviceVerificationConsent.hasConsented
            )
            return .rejected(reason: "rate_limit", message: message)
        }
        VerificationRateLimiter.recordAttempt(now: startedAt)

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
                consentGranted: OnDeviceVerificationConsent.hasConsented
            )
            return .rejected(reason: "ocr_failed", message: message)
        }

        // Stage B — on-device reasoning.
        let verdict = await reasoner.reason(
            extractedText: ocrResult.extractedText,
            course: course,
            userFirstName: userFirstName
        )

        let result = Self.mapVerdictToResult(verdict)
        let outcome = Self.mapResultToAudit(result)

        await recordAudit(
            startedAt: startedAt,
            outcome: outcome,
            consentGranted: OnDeviceVerificationConsent.hasConsented
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
        consentGranted: Bool
    ) async {
        let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        let tier = await MainActor.run { AccessManager.shared.activeTier.auditLabel }
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
            purpose: "learningSpark",
            outcome: outcome
        )
        await AuditLogger.shared.record(entry)
    }
}
