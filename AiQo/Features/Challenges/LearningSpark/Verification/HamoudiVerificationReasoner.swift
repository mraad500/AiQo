import Foundation
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Stage B of the on-device certificate-verification pipeline.
///
/// Feeds the OCR-extracted text into Captain Hamoudi's on-device Language Model
/// (Foundation Models, iOS 26+) with a structured reasoning prompt. Returns a typed
/// `Verdict` — no cloud call is ever made from this actor.
///
/// Falls back to `.needsReview` with a warm Iraqi Arabic message when:
/// - `LEARNING_VERIFICATION_ON_DEVICE_ENABLED` feature flag is off
/// - Running on iOS < 26
/// - `SystemLanguageModel.default.availability != .available`
/// - The model throws any generation error
/// - The model's response is not valid JSON
///
/// Mirrors the `FactExtractor` pattern ([FactExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/FactExtractor.swift))
/// for Foundation Models gating, so the two entry points stay behaviourally consistent.
actor HamoudiVerificationReasoner {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HamoudiVerificationReasoner"
    )

    enum Status: String, Codable, Sendable {
        case verified
        case needsReview = "needs_review"
        case rejected
    }

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
        // marking the whole enums nonisolated (which would diverge from the existing
        // codebase pattern). Gender feeds the gender-aware Hamoudi copy downstream.
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

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                return Verdict(
                    status: .needsReview,
                    confidence: 0,
                    detectedCourseName: nil,
                    detectedUserName: nil,
                    reason: "apple_intelligence_unavailable",
                    hamoudiMessageAr: Self.iosUnavailableMessage
                )
            }

            let instructions = Self.promptTemplate
            let payload = Self.makeUserPayload(
                extractedText: extractedText,
                course: course,
                userFirstName: userFirstName
            )

            // TEMPORARY DEBUG (2026-04-20) — log the exact payload Hamoudi sees so we can
            // diagnose why legitimate certificates land at needsReview. Stays on-device.
            logger.notice("debug_hamoudi_payload\n\(payload, privacy: .public)")

            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: payload)
                // TEMPORARY DEBUG — raw LM response before JSON extraction/parsing.
                logger.notice("debug_hamoudi_raw_response\n\(response.content, privacy: .public)")
                if let verdict = Self.parseVerdict(from: response.content, gender: gender) {
                    return verdict
                }
                logger.notice("debug_hamoudi_parse_failed raw_content_unparseable")
                return fallbackVerdict(reason: "reasoner_parse_failed")
            } catch {
                logger.error("debug_hamoudi_generation_failed error=\(error.localizedDescription, privacy: .public)")
                return fallbackVerdict(reason: "reasoner_generation_failed")
            }
        }
        #endif

        return Verdict(
            status: .needsReview,
            confidence: 0,
            detectedCourseName: nil,
            detectedUserName: nil,
            reason: "ios_unavailable",
            hamoudiMessageAr: Self.iosUnavailableMessage
        )
    }

    private func fallbackVerdict(reason: String) -> Verdict {
        Verdict(
            status: .needsReview,
            confidence: 0,
            detectedCourseName: nil,
            detectedUserName: nil,
            reason: reason,
            hamoudiMessageAr: Self.genericUnclearMessage
        )
    }

    // MARK: - Hamoudi Copy (Arabic, Swift-side)
    //
    // Apple's Foundation Models (iOS 26.x in AR locales) throws "Unsupported
    // language" when the prompt is in Arabic. We keep the instructions in
    // English (which the LM supports) and map the model's reason code to a
    // fixed Iraqi-Arabic Hamoudi message here in Swift. This makes the UX
    // copy versioned, deterministic, and audit-friendly, and it sidesteps the
    // locale limitation without leaving the device.

    /// Shown when the on-device model isn't available at all.
    static let iosUnavailableMessage = "حبيبي جهازك الحالي ما يدعم التحقق الذكي. الشهادة محفوظة عندك، جرب من جهاز أحدث أو استنى تحديث iOS جاي."

    /// Fallback when the reasoner ran but produced nothing parseable.
    static let genericUnclearMessage = "شكلها زينة بس خل أتأكد شوية، ارفعها مرة ثانية أو خلي الصورة أوضح."

    /// Maps a model-emitted reason code to the warm Iraqi-Arabic message the
    /// user actually sees. Unknown codes fall back to `genericUnclearMessage`.
    ///
    /// For the `.verified` outcome the message is gender-aware: if the user
    /// set their gender in the profile, Hamoudi addresses them with the
    /// matching pronoun (بيك / بيج). If gender is unset, a warm neutral line
    /// is used so the copy doesn't feel broken for users who skipped that field.
    fileprivate static func hamoudiMessage(
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

    /// Gender-aware "verified" celebration copy. Warm friend-tone — "حجي" is a
    /// casual Iraqi vocative; "فخورين بيك/بيج" ("we're proud of you") conveys
    /// the sense that AiQo stood beside the user through the course.
    private static func verifiedMessage(for gender: ActivityNotificationGender?) -> String {
        switch gender {
        case .male:
            return "حجي الف مبروك! الشهادة وصلت وكلشي تمام، فخورين بيك."
        case .female:
            return "حجي الف مبروك! الشهادة وصلت وكلشي تمام، فخورين بيج."
        case .none:
            return "حجي الف مبروك! الشهادة وصلت وكلشي تمام، إنجاز يستاهل الاحتفال."
        }
    }

    // MARK: - Prompt

    /// English-language instructions for the classifier. Arabic course titles /
    /// OCR text are embedded as content tokens in the user payload — the model
    /// matches them as Unicode patterns, not as a language it has to reason in.
    /// The model is NOT asked to generate Arabic — the Hamoudi copy is set in
    /// Swift based on the returned `reason` code.
    static let promptTemplate: String = """
    You are a certificate verification classifier. Your job: decide whether a user-uploaded course completion certificate matches the expected course.

    The OCR text may contain Arabic, English, or both. Accept fuzzy matching — translations, abbreviations, and minor wording differences are OK.

    For each attempt you will receive:
    - The expected course title in Arabic and English
    - The expected platform name
    - The user's first name (may be in Arabic or English)
    - The extracted OCR text from the certificate image

    Return ONLY valid JSON in this exact shape. No markdown fences, no commentary, no extra keys, no trailing text:

    {
      "status": "verified" | "needs_review" | "rejected",
      "confidence": 0.0,
      "detected_course_name": "...",
      "detected_user_name": "...",
      "reason": "one of these exact codes: verified | course_ambiguous | user_ambiguous | both_ambiguous | wrong_course | image_unclear | no_certificate_text"
    }

    Decision rules (pick the single most specific):
    - Both expected course AND user first name clearly present → status=verified, confidence ≥ 0.85, reason=verified
    - Course clear, name missing or ambiguous → status=needs_review, confidence 0.5-0.84, reason=user_ambiguous
    - Name clear, course missing or ambiguous → status=needs_review, confidence 0.5-0.84, reason=course_ambiguous
    - Both partial, neither clear → status=needs_review, confidence 0.5-0.84, reason=both_ambiguous
    - Text clearly references a different course → status=rejected, confidence < 0.5, reason=wrong_course
    - Text is too short, garbled, or unreadable → status=rejected, confidence < 0.5, reason=image_unclear
    - No certificate keywords found at all → status=rejected, confidence < 0.5, reason=no_certificate_text

    Certificate keywords (any one is enough evidence this IS a certificate):
    "certificate", "certification", "completion", "awarded", "presented to", "has successfully completed", "شهادة", "إتمام", "تمنح"

    Name matching rules:
    - Arabic ↔ English transliterations are the same name: محمد = Mohammad = Mohammed = Muhammad
    - First-name match is sufficient even if the certificate shows a full name ("محمد رعد" satisfies user first name "محمد")

    Course title matching rules:
    - Accept exact matches, translations, and minor wording differences
    - "Planning a Career Path" matches "Planning a Successful Career Path"
    - "التخطيط لبناء مسار مهني" matches "التخطيط لبناء مسار مهني ناجح"

    Output ONLY the JSON object. No explanation.
    """

    private static func makeUserPayload(
        extractedText: String,
        course: LearningCourse,
        userFirstName: String
    ) -> String {
        let platform = course.platform.canonicalName
        let displayFirstName = userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameLine = displayFirstName.isEmpty ? "(unknown)" : displayFirstName
        // English labels, Arabic values — the model matches the Arabic values as
        // Unicode content, not as a language it needs to "understand".
        return """
        Expected course (Arabic): \(course.titleAr)
        Expected course (English): \(course.titleEn)
        Expected platform: \(platform)
        User first name: \(nameLine)

        Extracted OCR text from certificate:
        \"\"\"
        \(extractedText)
        \"\"\"
        """
    }

    // MARK: - Parsing

    private struct RawVerdict: Decodable {
        let status: String?
        let confidence: Double?
        let detected_course_name: String?
        let detected_user_name: String?
        let reason: String?
    }

    /// Robust JSON extraction — the model may wrap the JSON in ``` fences or add
    /// trailing commentary even when told not to. Mirrors the defensive behavior in
    /// `LLMJSONParser`. `gender` feeds the gender-aware verified message.
    fileprivate static func parseVerdict(
        from raw: String,
        gender: ActivityNotificationGender?
    ) -> Verdict? {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let firstBrace = cleaned.firstIndex(of: "{"),
            let lastBrace = cleaned.lastIndex(of: "}"),
            firstBrace < lastBrace
        else { return nil }

        let slice = String(cleaned[firstBrace...lastBrace])
        guard let data = slice.data(using: .utf8) else { return nil }

        guard let rawVerdict = try? JSONDecoder().decode(RawVerdict.self, from: data) else {
            return nil
        }

        let status: Status
        switch rawVerdict.status?.lowercased() {
        case "verified": status = .verified
        case "needs_review", "needsreview": status = .needsReview
        case "rejected": status = .rejected
        default: return nil
        }

        let confidence = max(0, min(1, rawVerdict.confidence ?? 0))
        let reason = rawVerdict.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "unspecified"

        return Verdict(
            status: status,
            confidence: confidence,
            detectedCourseName: rawVerdict.detected_course_name,
            detectedUserName: rawVerdict.detected_user_name,
            reason: reason,
            // The user-visible Arabic copy is deterministic in Swift, keyed on
            // the reason code — we never trust the LM to emit Arabic (it may
            // not support AR locale on the user's device).
            hamoudiMessageAr: hamoudiMessage(forReason: reason, gender: gender)
        )
    }
}
