import Foundation

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

        // FeatureFlags statics are MainActor-isolated under Swift 6 strict concurrency.
        // One short MainActor hop to read the Info.plist-backed bool — cheaper than
        // marking the whole FeatureFlags enum `nonisolated` (which would diverge from
        // the existing codebase pattern).
        let onDeviceEnabled = await MainActor.run { FeatureFlags.learningVerificationOnDeviceEnabled }
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

            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: payload)
                if let verdict = Self.parseVerdict(from: response.content) {
                    return verdict
                }
                return fallbackVerdict(reason: "reasoner_parse_failed")
            } catch {
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

    // MARK: - Prompt

    /// Honest compliant fallback copy (on-device model unavailable). No promise of
    /// server-side manual review — the image never leaves the device.
    static let iosUnavailableMessage = "حبيبي جهازك الحالي ما يدعم التحقق الذكي. الشهادة محفوظة عندك، جرب من جهاز أحدث أو استنى تحديث iOS جاي."

    /// Used when the reasoner ran but couldn't decide cleanly.
    static let genericUnclearMessage = "شكلها زينة بس خل أتأكد شوية، ارفعها مرة ثانية أو خلي الصورة أوضح."

    /// The exact Arabic prompt provided in the spec. Captain Hamoudi's voice.
    /// Stored as a constant so any copy audit can diff it directly.
    static let promptTemplate: String = """
    أنت الكابتن حمودي، المدرب الذكي لتطبيق AiQo. مستخدمك للتو رفع شهادة إتمام كورس، ومهمتك تتحقق منها.

    حلل النص المستخرج من صورة الشهادة اللي راح يجيك من المستخدم، وحدد:

    1) هل اسم الكورس (عربي أو إنجليزي) موجود بالنص؟ اقبل المطابقة الضبابية (ترجمات، اختصارات).
    2) هل اسم المستخدم موجود بالنص؟ اقبل اختلافات إملائية (محمد/Mohammad/Mohammed/Muhammad).
    3) هل النص يحتوي على كلمات مثل "certificate"، "شهادة"، "completion"، "إتمام"، "awarded"، "presented to"؟
    4) هل النص قصير جداً أو غير مفهوم (يدل على صورة غير واضحة)؟

    ارجع JSON فقط بهذا الشكل الدقيق:
    {
      "status": "verified" | "needs_review" | "rejected",
      "confidence": 0.0 إلى 1.0,
      "detected_course_name": "...",
      "detected_user_name": "...",
      "reason": "... (إنجليزي، تقني، مختصر)",
      "hamoudi_message_ar": "... (رسالة دافئة باللهجة العراقية، 1-2 جملة)"
    }

    قواعد القرار:
    - الاثنين (الكورس + الاسم) واضحين → verified (confidence ≥ 0.85)
    - واحد واضح والثاني غامض → needs_review (confidence 0.5–0.84)
    - لا الاثنين واضحين أو نص غير مفهوم → rejected (confidence < 0.5)

    أمثلة صوت حمودي:
    - verified: "فديتك والله، شهادتك وصلت وكلشي تمام! فخور بيك، +XP إلك."
    - needs_review: "شكلها زينة بس خل أتأكد شوية، راح أرجعلك قريب."
    - rejected (غير واضحة): "حبيبي الصورة مو واضحة، صورها مرة ثانية بإضاءة أحسن."
    - rejected (ما تطابق): "هاي الشهادة ما تخص الكورس اللي اخترته، تأكد من رفع الشهادة الصحيحة."

    مو مسموح تطلع من شخصية حمودي. مو مسموح ترد بالإنجليزي. لازم ترجع واحد من الثلاثة statuses.
    """

    private static func makeUserPayload(
        extractedText: String,
        course: LearningCourse,
        userFirstName: String
    ) -> String {
        let platform = course.platform.canonicalName
        let displayFirstName = userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameLine = displayFirstName.isEmpty ? "(غير متوفر)" : displayFirstName
        return """
        اسم الكورس بالعربية: \(course.titleAr)
        اسم الكورس بالإنجليزية: \(course.titleEn)
        المنصة: \(platform)
        الاسم الأول للمستخدم: \(nameLine)

        النص اللي استخرجناه من صورة الشهادة:
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
        let hamoudi_message_ar: String?
    }

    /// Robust JSON extraction — the model may wrap the JSON in ``` fences or add
    /// trailing commentary even when told not to. Mirrors the defensive behavior in
    /// `LLMJSONParser`.
    fileprivate static func parseVerdict(from raw: String) -> Verdict? {
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

        guard let raw = try? JSONDecoder().decode(RawVerdict.self, from: data) else {
            return nil
        }

        let status: Status
        switch raw.status?.lowercased() {
        case "verified": status = .verified
        case "needs_review", "needsreview": status = .needsReview
        case "rejected": status = .rejected
        default: return nil
        }

        let confidence = max(0, min(1, raw.confidence ?? 0))

        guard let message = raw.hamoudi_message_ar?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return nil
        }

        return Verdict(
            status: status,
            confidence: confidence,
            detectedCourseName: raw.detected_course_name,
            detectedUserName: raw.detected_user_name,
            reason: raw.reason ?? "unspecified",
            hamoudiMessageAr: message
        )
    }
}
