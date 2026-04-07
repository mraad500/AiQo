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

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "The on-device sleep agent returned an empty response."
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        }
    }
}

struct AppleIntelligenceSleepAgent: Sendable {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "AppleIntelligenceSleepAgent"
    )

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
                maximumResponseTokens: 160
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

        let hasStageData = session.deepMinutes > 0 || session.remMinutes > 0

        var stageBlock: String
        if hasStageData {
            stageBlock = """
            نوم عميق: \(session.deepMinutes) دقيقة (\(formattedPercentage(session.deepPercentage))) — \(deepRating). المفروض 15-25%.
            REM: \(session.remMinutes) دقيقة (\(formattedPercentage(session.remPercentage))) — \(remRating). المفروض 20-25%.
            """
        } else {
            stageBlock = "ما عدنه بيانات مراحل النوم. لا تحچي عن النوم العميق ولا REM."
        }

        return """
        أنت حمّودي، مدرب رياضي عراقي بتطبيق AiQo.
        لهجتك: عراقي صرف. تستخدم: هسه، شلون، يا بطل، عوف، چا، شوكت، هواية، ماكو، أكو، خوش.
        لا تستخدم فصحى أبداً.

        نوم المستخدم:
        الكل: \(totalHours) ساعة و \(totalRemainingMin) دقيقة — \(totalRating). المفروض 7-9 ساعات.
        \(stageBlock)
        صحى بالليل: \(session.awakeMinutes) دقيقة.

        اكتب 3 جمل بس بالعراقي:
        1. شلون نومه بشكل عام (كون صريح).
        2. \(hasStageData ? "أهم شي لاحظته على المراحل وشنو تأثيره على جسمه." : "نصيحة يزيد بيها ساعات نومه.")
        3. نصيحة وحدة سهلة يسويها الليلة.

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
        let hasStages = session.deepMinutes > 0 || session.remMinutes > 0

        var parts = ["إجمالي النوم: \(totalHours) ساعة و\(totalMin) دقيقة (\(rating)). المفروض 7-9 ساعات."]

        if hasStages {
            let deepR = stageRating(percentage: session.deepPercentage, ideal: 15...25)
            let remR = stageRating(percentage: session.remPercentage, ideal: 20...25)
            parts.append("نوم عميق: \(session.deepMinutes) دقيقة (\(formattedPercentage(session.deepPercentage))) — \(deepR). المفروض 15-25%.")
            parts.append("REM: \(session.remMinutes) دقيقة (\(formattedPercentage(session.remPercentage))) — \(remR). المفروض 20-25%.")
            parts.append("نوم أساسي: \(session.coreMinutes) دقيقة.")
        }

        if session.awakeMinutes > 0 {
            parts.append("استيقاظ بالليل: \(session.awakeMinutes) دقيقة.")
        }

        return parts.joined(separator: "\n")
    }

    /// تحليل نوم محسوب بالكامل on-device بـ Swift — يُستخدم لمّا Apple Intelligence والـ cloud مو متاحين
    func availabilityFallback(
        for session: SleepSession,
        reasonDescription: String
    ) -> String {
        let totalHours = session.totalMinutes / 60
        let totalMin = session.totalMinutes % 60
        let rating = sleepDurationRating(minutes: session.totalMinutes)
        let hasStages = session.deepMinutes > 0 || session.remMinutes > 0

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

            if session.deepPercentage < 15 {
                lines.append("النوم العميق عندك \(session.deepMinutes) دقيقة (\(deepRating)) — هذا يأثر على تعافي العضلات وهرمون النمو.")
            } else {
                lines.append("النوم العميق \(session.deepMinutes) دقيقة — \(deepRating)، خوش للعضلات.")
            }

            if session.remPercentage < 20 {
                lines.append("REM عندك \(session.remMinutes) دقيقة (\(remRating)) — يعني التركيز والذاكرة ممكن يتأثرون.")
            } else {
                lines.append("REM \(session.remMinutes) دقيقة — \(remRating)، ذاكرتك بخير.")
            }
        }

        // نصيحة
        if session.totalMinutes < 420 {
            lines.append("الليلة حاول تنام أبچر بنص ساعة على الأقل.")
        } else if hasStages && session.deepPercentage < 15 {
            lines.append("الليلة وقف الكافيين بعد الساعة 2 الظهر عشان ترفع النوم العميق.")
        } else if session.awakeMinutes > 15 {
            lines.append("صحيت \(session.awakeMinutes) دقيقة بالليل — خلي الغرفة بردانة ومظلمة.")
        } else {
            lines.append("كمّل على هالروتين، نومك تمام.")
        }

        return lines.joined(separator: "\n")
    }
}
