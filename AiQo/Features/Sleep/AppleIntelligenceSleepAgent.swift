import Foundation
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SleepSession: Sendable {
    let totalSleep: TimeInterval
    let deepSleep: TimeInterval
    let remSleep: TimeInterval
    let coreSleep: TimeInterval
    let awake: TimeInterval

    var totalMinutes: Int {
        roundedMinutes(for: totalSleep)
    }

    var deepMinutes: Int {
        roundedMinutes(for: deepSleep)
    }

    var remMinutes: Int {
        roundedMinutes(for: remSleep)
    }

    var coreMinutes: Int {
        roundedMinutes(for: coreSleep)
    }

    var awakeMinutes: Int {
        roundedMinutes(for: awake)
    }

    var deepPercentage: Double {
        percentage(for: deepSleep)
    }

    var remPercentage: Double {
        percentage(for: remSleep)
    }

    var corePercentage: Double {
        percentage(for: coreSleep)
    }

    private func percentage(for duration: TimeInterval) -> Double {
        guard totalSleep > 0 else { return 0 }
        return (duration / totalSleep) * 100
    }

    private func roundedMinutes(for duration: TimeInterval) -> Int {
        max(Int((duration / 60).rounded()), 0)
    }
}

enum AppleIntelligenceSleepAgentError: LocalizedError {
    case emptyResponse(session: SleepSession)
    /// Apple Intelligence مو متاح — يصعد للـ orchestrator عشان يحوّله للـ cloud
    case modelUnavailable(sleepSummary: String, session: SleepSession)
    case lowQualityResponse(sleepSummary: String, session: SleepSession, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "The on-device sleep agent returned an empty response."
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        case .lowQualityResponse:
            return "The on-device sleep agent returned a low-quality sleep analysis."
        }
    }
}

struct AppleIntelligenceSleepAgent: Sendable {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "AppleIntelligenceSleepAgent"
    )
    private let qualityEvaluator = SleepAnalysisQualityEvaluator()

    func analyze(session sleepSession: SleepSession) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default

            switch model.availability {
            case .available:
                break
            case .unavailable(let reason):
                logger.notice("sleep_agent_unavailable reason=\(String(describing: reason), privacy: .public)")
                throw AppleIntelligenceSleepAgentError.modelUnavailable(
                    sleepSummary: buildArabicSummary(for: sleepSession),
                    session: sleepSession
                )
            }

            let instructions = buildSystemPrompt(for: sleepSession)
            let options = GenerationOptions(
                sampling: nil,
                temperature: 0.5,
                maximumResponseTokens: 200
            )

            do {
                let modelSession = LanguageModelSession(
                    model: model,
                    instructions: instructions
                )
                let response = try await modelSession.respond(
                    to: generationTriggerPrompt,
                    options: options
                )
                let generated = sanitize(response.content)

                guard !generated.isEmpty else {
                    throw AppleIntelligenceSleepAgentError.emptyResponse(session: sleepSession)
                }

                guard qualityEvaluator.isUseful(message: generated, session: sleepSession) else {
                    logger.notice("sleep_agent_low_quality_response")
                    throw AppleIntelligenceSleepAgentError.lowQualityResponse(
                        sleepSummary: buildArabicSummary(for: sleepSession),
                        session: sleepSession,
                        message: generated
                    )
                }

                logger.notice("sleep_agent_succeeded")
                return generated
            } catch let generationError as LanguageModelSession.GenerationError {
                if case .unsupportedLanguageOrLocale = generationError {
                    logger.notice("sleep_agent_unsupported_locale")
                    throw AppleIntelligenceSleepAgentError.modelUnavailable(
                        sleepSummary: buildArabicSummary(for: sleepSession),
                        session: sleepSession
                    )
                }

                logger.error(
                    "sleep_agent_generation_failed error=\(generationError.localizedDescription, privacy: .public)"
                )
                throw generationError
            } catch {
                logger.error("sleep_agent_failed error=\(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
#endif

        throw AppleIntelligenceSleepAgentError.modelUnavailable(
            sleepSummary: buildArabicSummary(for: sleepSession),
            session: sleepSession
        )
    }
}

extension AppleIntelligenceSleepAgent {
    var generationTriggerPrompt: String {
        "شلون نوم المستخدم؟ حلله هسه بالعراقي."
    }

    func buildSystemPrompt(for session: SleepSession) -> String {
        let totalHours = session.totalMinutes / 60
        let totalRemainingMin = session.totalMinutes % 60

        let totalRating = sleepDurationRating(minutes: session.totalMinutes)
        let deepRating = stageRating(percentage: session.deepPercentage, ideal: 15...25)
        let remRating = stageRating(percentage: session.remPercentage, ideal: 20...25)
        let coreRating = coreStageRating(percentage: session.corePercentage)

        let hasStageData = session.deepMinutes > 0 || session.remMinutes > 0 || session.coreMinutes > 0

        var stageBlock: String
        if hasStageData {
            stageBlock = """
            نوم عميق: \(session.deepMinutes) دقيقة (\(formattedPercentage(session.deepPercentage))) — \(deepRating). المفروض 15-25%.
            نوم أساسي: \(session.coreMinutes) دقيقة (\(formattedPercentage(session.corePercentage))) — \(coreRating). غالباً يكون تقريباً 45-55%.
            REM: \(session.remMinutes) دقيقة (\(formattedPercentage(session.remPercentage))) — \(remRating). المفروض 20-25%.
            """
        } else {
            stageBlock = "ما عدنه بيانات مراحل النوم. لا تحچي عن النوم العميق ولا REM ولا النوم الأساسي."
        }

        return """
        أنت حمّودي، مدرب رياضي عراقي بتطبيق AiQo.
        لهجتك: عراقي صرف. تستخدم: هسه، شلون، يا بطل، عوف، چا، شوكت، هواية، ماكو، أكو، خوش.
        لا تستخدم فصحى أبداً.

        نوم المستخدم:
        الكل: \(totalHours) ساعة و \(totalRemainingMin) دقيقة — \(totalRating). المفروض 7-9 ساعات.
        \(stageBlock)
        صحى بالليل: \(session.awakeMinutes) دقيقة.

        اكتب 4 جمل بس بالعراقي:
        1. شلون نومه بشكل عام (كون صريح).
        2. \(hasStageData ? "اشرح نسبة النوم العميق ونسبة النوم الأساسي وشنو تعني على التعافي الجسدي." : "كول بصراحة إن بيانات المراحل مو متوفرة.")
        3. \(hasStageData ? "اشرح نسبة REM وشنو تعني على التركيز والذاكرة، واذكر الاستيقاظ إذا كان مؤثر." : "أعطِ ملاحظة قصيرة عن الاستيقاظ أو مدة النوم فقط إذا موجودة." )
        4. اختم بنصيحة وحدة واضحة مخصوصة لتحسين جودة مراحل النوم الليلة، مو مجرد زيادة ساعات النوم فقط.

        ممنوع: أرقام مو موجودة بالبيانات، نقاط، عناوين، إيموجي، كلام فصيح.
        """
    }

    func sleepDurationRating(minutes: Int) -> String {
        let hours = Double(minutes) / 60.0
        if hours < 5.0 { return "قليل هواية" }
        if hours < 6.0 { return "قليل" }
        if hours < 7.0 { return "يمشي بس مو مثالي" }
        if hours <= 9.0 { return "خوش نوم" }
        return "هواية نوم"
    }

    func stageRating(percentage: Double, ideal: ClosedRange<Double>) -> String {
        if percentage <= 0 { return "ما متوفر" }
        if percentage < ideal.lowerBound - 5 { return "ناقص هواية" }
        if percentage < ideal.lowerBound { return "عالحد" }
        if percentage <= ideal.upperBound { return "تمام" }
        return "زايد شوية"
    }

    func coreStageRating(percentage: Double) -> String {
        if percentage <= 0 { return "ما متوفر" }
        if percentage < 40 { return "واطي" }
        if percentage <= 60 { return "ضمن الطبيعي" }
        return "عالي شوية"
    }

    func sanitize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }

    func formattedPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    /// ملخص أرقام النوم بالعربي — يُرسل للـ cloud API لمّا المحلي مو متاح (أرقام مجمّعة فقط، بدون بيانات خام)
    func buildArabicSummary(for session: SleepSession) -> String {
        let totalHours = session.totalMinutes / 60
        let totalMin = session.totalMinutes % 60
        let rating = sleepDurationRating(minutes: session.totalMinutes)
        let hasStages = session.deepMinutes > 0 || session.remMinutes > 0 || session.coreMinutes > 0

        var parts = ["إجمالي النوم: \(totalHours) ساعة و\(totalMin) دقيقة (\(rating)). المفروض 7-9 ساعات."]

        if hasStages {
            let deepR = stageRating(percentage: session.deepPercentage, ideal: 15...25)
            let remR = stageRating(percentage: session.remPercentage, ideal: 20...25)
            let coreR = coreStageRating(percentage: session.corePercentage)
            parts.append("نوم عميق: \(session.deepMinutes) دقيقة (\(formattedPercentage(session.deepPercentage))) — \(deepR). المفروض 15-25%.")
            parts.append("نوم أساسي: \(session.coreMinutes) دقيقة (\(formattedPercentage(session.corePercentage))) — \(coreR). الطبيعي تقريباً 45-55%.")
            parts.append("REM: \(session.remMinutes) دقيقة (\(formattedPercentage(session.remPercentage))) — \(remR). المفروض 20-25%.")
        }

        if session.awakeMinutes > 0 {
            parts.append("استيقاظ بالليل: \(session.awakeMinutes) دقيقة.")
        }

        return parts.joined(separator: "\n")
    }

    /// تحليل نوم محسوب بالكامل on-device بـ Swift — يُستخدم لمّا Apple Intelligence والـ cloud مو متاحين
    func availabilityFallback(
        for session: SleepSession,
        reasonDescription: String,
        language: AppLanguage = .arabic
    ) -> String {
        if language == .english {
            return englishAvailabilityFallback(for: session)
        }

        return arabicAvailabilityFallback(for: session)
    }

    private func arabicAvailabilityFallback(for session: SleepSession) -> String {
        let totalHours = session.totalMinutes / 60
        let totalMin = session.totalMinutes % 60
        let rating = sleepDurationRating(minutes: session.totalMinutes)
        let hasStages = session.deepMinutes > 0 || session.remMinutes > 0 || session.coreMinutes > 0

        var lines: [String] = []

        // تقييم عام
        if session.totalMinutes < 300 {
            lines.append("يا بطل، \(totalHours) ساعات و\(totalMin) دقيقة نوم — هذا قليل هواية على جسمك.")
        } else if session.totalMinutes < 420 {
            lines.append("نومك \(totalHours) ساعات و\(totalMin) دقيقة — \(rating)، بس جسمك يحتاج أكثر.")
        } else {
            lines.append("خوش، نومك \(totalHours) ساعات و\(totalMin) دقيقة — \(rating).")
        }

        // تحليل المراحل
        if hasStages {
            let deepRating = stageRating(percentage: session.deepPercentage, ideal: 15...25)
            let remRating = stageRating(percentage: session.remPercentage, ideal: 20...25)
            let coreRating = coreStageRating(percentage: session.corePercentage)
            lines.append("العميق عندك \(formattedPercentage(session.deepPercentage)) من النوم (\(session.deepMinutes) دقيقة) وياه الأساسي \(formattedPercentage(session.corePercentage)) (\(session.coreMinutes) دقيقة)، وهذا يخلي تعافيك \(session.deepPercentage < 15 ? "أضعف من المطلوب" : "أقرب للاستقرار") والأساسي \(coreRating).")
            lines.append("REM عندك \(formattedPercentage(session.remPercentage)) (\(session.remMinutes) دقيقة) — \(remRating)، ومع استيقاظ \(session.awakeMinutes) دقيقة بالليل فتركيزك ومودك يتأثرون حسب هالقطع.")
        }

        // نصيحة
        if hasStages && session.deepPercentage < 15 {
            lines.append("حتى ترفع جودة المراحل الليلة، وقف الكافيين بعد الظهر وخلي آخر ساعة قبل النوم هدوء وظلمة وشاشة أقل.")
        } else if hasStages && session.remPercentage < 20 {
            lines.append("حتى تتحسن جودة REM الليلة، ثبّت وقت نومك وابعد الموبايل والإجهاد الذهني بآخر ساعة.")
        } else if session.awakeMinutes > 15 {
            lines.append("حتى تتحسن جودة المراحل الليلة، برّد الغرفة، خفف السوائل متأخر، وخلي نومك على وقت ثابت.")
        } else if session.totalMinutes < 420 {
            lines.append("حتى ترتفع جودة المراحل الليلة، نام أبچر بنص ساعة على الأقل حتى تعطي العميق وREM وقت كافي.")
        } else {
            lines.append("حتى تبقي جودة المراحل زينة، كمّل على نفس وقت النوم وخلي آخر ساعة هادئة وثابتة.")
        }

        return lines.joined(separator: "\n")
    }

    private func englishAvailabilityFallback(for session: SleepSession) -> String {
        let totalHours = session.totalMinutes / 60
        let totalMin = session.totalMinutes % 60
        let hasStages = session.deepMinutes > 0 || session.remMinutes > 0 || session.coreMinutes > 0

        var lines: [String] = []

        if session.totalMinutes < 300 {
            lines.append("You only got \(totalHours)h \(totalMin)m of sleep, and that is clearly too low for solid recovery.")
        } else if session.totalMinutes < 420 {
            lines.append("You slept \(totalHours)h \(totalMin)m, which is still below the 7-9 hour target.")
        } else {
            lines.append("You slept \(totalHours)h \(totalMin)m, which is in a workable range overall.")
        }

        if hasStages {
            lines.append("Deep sleep was \(formattedPercentage(session.deepPercentage)) (\(session.deepMinutes) minutes) and core sleep was \(formattedPercentage(session.corePercentage)) (\(session.coreMinutes) minutes), so your physical recovery looks \(session.deepPercentage < 15 ? "lighter than ideal" : "fairly supported").")
            lines.append("REM sleep was \(formattedPercentage(session.remPercentage)) (\(session.remMinutes) minutes), and with \(session.awakeMinutes) awake minutes overnight your focus and mental sharpness may shift with that.")
        }

        if hasStages && session.deepPercentage < 15 {
            lines.append("To improve sleep-stage quality tonight, cut caffeine after early afternoon and keep the last hour before bed darker and calmer.")
        } else if hasStages && session.remPercentage < 20 {
            lines.append("To improve sleep-stage quality tonight, keep a fixed bedtime and reduce screens and mental stimulation in the final hour.")
        } else if session.awakeMinutes > 15 {
            lines.append("To improve sleep-stage quality tonight, cool the room, ease late fluids, and keep your sleep window steady.")
        } else if session.totalMinutes < 420 {
            lines.append("To improve sleep-stage quality tonight, get to bed at least 30 minutes earlier so deep and REM sleep have more room.")
        } else {
            lines.append("To keep your sleep stages strong, stay with the same bedtime and keep the last hour quiet and consistent.")
        }

        return lines.joined(separator: "\n")
    }
}
