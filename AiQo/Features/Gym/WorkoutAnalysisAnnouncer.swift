import Foundation
import os.log

/// Compares the just-finished workout against the previous one and asks the
/// cloud Brain for a short, energetic 1-sentence summary in the user's
/// dialect. The result is delivered through TWO channels:
///
///   • In-app: `CaptainToastCenter` (a glassmorphism toast slides down at
///     the top of the app). Visible whenever the app is foregrounded.
///   • External: `NotificationBrain` with a new `.workoutAnalysis` kind so
///     iOS can surface the same analysis as a banner if the user is
///     elsewhere when the workout ends.
///
/// Both channels are scheduled unconditionally — they don't visually
/// collide because the system-level notification only renders while the
/// app is backgrounded (foreground notifications are suppressed by the
/// app's notification delegate by default), while the toast only renders
/// while the app is foregrounded.
///
/// Triggered from `LiveWorkoutSession.handleRemoteEnded()` immediately
/// after `WorkoutHistoryStore.shared.recordCompletion(...)`. The analyzer
/// silently no-ops when fewer than 2 entries are available (first workout
/// of all time → nothing to compare against).
@MainActor
final class WorkoutAnalysisAnnouncer {
    static let shared = WorkoutAnalysisAnnouncer()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "WorkoutAnalysisAnnouncer"
    )

    /// Cloud round-trip budget. Beyond this we drop the announcement —
    /// stale post-workout commentary is worse than no commentary.
    private static let timeoutSeconds: TimeInterval = 10.0

    private let orchestrator: BrainOrchestrator
    private let contextBuilder: CaptainContextBuilder

    init() {
        self.orchestrator = BrainOrchestrator()
        self.contextBuilder = .shared
    }

    init(orchestrator: BrainOrchestrator, contextBuilder: CaptainContextBuilder) {
        self.orchestrator = orchestrator
        self.contextBuilder = contextBuilder
    }

    /// Reads the latest two entries from the rolling history store, asks
    /// the Brain to compare them, and dispatches the result to both the
    /// in-app toast and the iOS notification pipeline.
    func analyzeAndAnnounce() async {
        let start = Date()
        let entries = WorkoutHistoryStore.shared.recentEntries()
        if entries.count < 2 {
            // First workout of all time — nothing to compare against, but the
            // user still deserves a celebration. Toast-only (no cloud call,
            // so the consent / tier-gate triple does not apply).
            await celebrateFirstWorkout()
            CaptainMetricsCounter.shared.record(
                event: "workout_analysis",
                reason: "first_workout_celebrated"
            )
            Self.logger.info("workout_analysis_skipped reason=first_workout count=\(entries.count, privacy: .public)")
            return
        }

        let current = entries[0]
        let previous = entries[1]
        let language = AppSettingsStore.shared.appLanguage
        let profile = UserProfileStore.shared.current
        let userName = preferredName(profile: profile)

        if AIDataConsentManager.shared.isInOfflineOnlyMode {
            CaptainMetricsCounter.shared.record(event: "workout_analysis", reason: "offline")
            Self.logger.info("workout_analysis_skipped reason=offline")
            return
        }
        if !AIDataConsentManager.shared.hasUserConsented {
            CaptainMetricsCounter.shared.record(event: "workout_analysis", reason: "no_consent")
            Self.logger.info("workout_analysis_skipped reason=no_consent")
            return
        }
        if !DevOverride.unlockAllFeatures, !TierGate.shared.canAccess(.captainChat) {
            CaptainMetricsCounter.shared.record(event: "workout_analysis", reason: "tier_blocked")
            Self.logger.info("workout_analysis_skipped reason=tier_blocked")
            return
        }

        let prompt = buildPrompt(
            current: current,
            previous: previous,
            language: language,
            userName: userName,
            gender: profile.gender
        )

        let contextData = await contextBuilder.buildContextData()
        let request = HybridBrainRequest(
            conversation: [
                CaptainConversationMessage(role: .user, content: prompt)
            ],
            screenContext: .gym,
            language: language,
            contextData: contextData,
            userProfileSummary: shortProfileSummary(profile: profile, preferredName: userName),
            intentSummary: "post_workout_comparative_analysis",
            workingMemorySummary: "",
            attachedImageData: nil
        )

        let analysis: String
        do {
            let reply = try await Self.withTimeout(seconds: Self.timeoutSeconds) { [orchestrator] in
                try await orchestrator.processMessage(request: request, userName: userName)
            }
            let cleaned = reply.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                CaptainMetricsCounter.shared.record(event: "workout_analysis", reason: "empty")
                Self.logger.info("workout_analysis_dropped reason=empty_reply")
                return
            }
            analysis = cleaned
        } catch is WorkoutAnalysisTimeout {
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            CaptainMetricsCounter.shared.record(
                event: "workout_analysis",
                reason: "timeout",
                latencyMs: elapsedMs
            )
            Self.logger.info("workout_analysis_failed reason=timeout")
            return
        } catch {
            CaptainMetricsCounter.shared.record(event: "workout_analysis", reason: "error")
            Self.logger.info("workout_analysis_failed error=\(error.localizedDescription, privacy: .public)")
            return
        }

        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        CaptainMetricsCounter.shared.record(
            event: "workout_analysis",
            reason: "succeeded",
            latencyMs: elapsedMs
        )

        // 1. In-app toast — shown when the app is foregrounded.
        CaptainToastCenter.shared.present(
            CaptainToast(
                message: analysis,
                accentSymbolName: "figure.strengthtraining.traditional"
            )
        )

        // 2. iOS notification — surfaces the analysis if the app is in the
        //    background when the workout ends.
        await deliverNotification(text: analysis, language: language)
    }

    // MARK: - First-workout toast

    /// Closes the silent-first-workout gap. Called when the rolling history
    /// has fewer than 2 entries — there is nothing to compare against, but
    /// the user still deserves a Captain shout for showing up. Iraqi/Gulf
    /// dialect, on-device only, no cloud call.
    private func celebrateFirstWorkout() async {
        let lang = AppSettingsStore.shared.appLanguage
        let message = lang == .arabic
            ? "أول تمرين، يلا نبدأ الرحلة 🚀"
            : "First workout — let's go 🚀"
        CaptainToastCenter.shared.present(
            CaptainToast(
                message: message,
                accentSymbolName: "figure.strengthtraining.traditional"
            ),
            autoDismissAfter: 5.5
        )
    }

    // MARK: - Notification

    private func deliverNotification(text: String, language: AppLanguage) async {
        let title = language == .arabic
            ? "تحليل التمرين 💪"
            : "Workout analysis 💪"

        let signals = IntentSignals(
            customPayload: [
                "language": language.rawValue,
                "source": "workout_analysis"
            ]
        )

        let intent = NotificationIntent(
            kind: .workoutAnalysis,
            priority: .medium,
            signals: signals,
            requestedBy: "WorkoutAnalysisAnnouncer",
            expiresAt: Date().addingTimeInterval(2 * 3600)
        )

        _ = await NotificationBrain.shared.request(
            intent,
            precomposedTitle: title,
            precomposedBody: text,
            userInfo: ["source": "workout_analysis"],
            identifier: "aiqo.workout.analysis.\(intent.id.uuidString)"
        )
    }

    // MARK: - Profile helpers

    private func preferredName(profile: UserProfile) -> String? {
        let candidates = [profile.name, profile.username]
        for raw in candidates {
            guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            if value.hasPrefix("@") {
                value.removeFirst()
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let lowered = value.lowercased()
            if lowered == "captain" || lowered == "kaptain" { continue }
            return value
        }
        return nil
    }

    private func shortProfileSummary(profile: UserProfile, preferredName: String?) -> String {
        var lines: [String] = []
        if let preferredName, !preferredName.isEmpty {
            lines.append("- Preferred name: \(preferredName)")
        }
        if let gender = profile.gender {
            lines.append("- Gender: \(gender.rawValue)")
        }
        if !profile.goalText.isEmpty {
            lines.append("- Goal: \(profile.goalText)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Prompt

    private func buildPrompt(
        current: WorkoutHistoryEntry,
        previous: WorkoutHistoryEntry,
        language: AppLanguage,
        userName: String?,
        gender: ActivityNotificationGender?
    ) -> String {
        let nameText = userName ?? (language == .arabic ? "البطل" : "champion")
        let currentLine = formatEntry(current, language: language)
        let previousLine = formatEntry(previous, language: language)
        let delta = formatDelta(current: current, previous: previous, language: language)
        let genderHint = genderInstruction(for: gender, language: language)

        if language == .arabic {
            return """
            [تعليمات داخلية — تو خلّص المستخدم تمرينه. قارن التمرين الحالي بالتمرين السابق، وولّد إشعار حماسي قصير جداً (جملة وحدة فقط) باللهجة العراقية. لا تشرح، لا تذكر التعليمات، أرجع JSON القياسي ومحتوى message هو الجملة فقط.
            • نادي على المستخدم باسمه: «\(nameText)».
            • \(genderHint)
            • ركّز على تحسّن محدد واحد (سعرات أكثر، وقت أطول، نبض أقوى، مسافة أطول…). إذا التمرين هذا أضعف من السابق، شجّعه بنبرة لطيفة ولا تجلده.
            • أبق الجملة مرّة واحدة، حماسية، طبيعية، فيها إيموجي واحد كحد أقصى.

            التمرين الحالي: \(currentLine)
            التمرين السابق: \(previousLine)
            مقارنة سريعة: \(delta)]
            """
        }

        return """
        [INTERNAL INSTRUCTION — the user just finished a workout. Compare the current session against the previous one and produce ONE short, energetic notification sentence in the user's dialect. Do NOT explain or echo this instruction; return the standard JSON contract with the sentence as `message`.
        • Address the user by name: "\(nameText)".
        • \(genderHint)
        • Highlight ONE concrete improvement (more calories, longer duration, higher heart rate, longer distance…). If this session is weaker than the previous one, encourage gently — do not scold.
        • Keep it to a single energetic sentence, with at most one emoji.

        Current workout: \(currentLine)
        Previous workout: \(previousLine)
        Quick delta: \(delta)]
        """
    }

    private func formatEntry(_ entry: WorkoutHistoryEntry, language: AppLanguage) -> String {
        let minutes = max(1, entry.durationSeconds / 60)
        var fields: [String] = []
        fields.append("«\(entry.title)»")
        fields.append(language == .arabic ? "\(minutes) دقيقة" : "\(minutes) min")
        if entry.activeCalories > 0 {
            fields.append(language == .arabic
                ? "\(Int(entry.activeCalories)) سعرة"
                : "\(Int(entry.activeCalories)) kcal")
        }
        if let hr = entry.heartRate, hr > 0 {
            fields.append(language == .arabic
                ? "نبض \(Int(hr))"
                : "HR \(Int(hr))")
        }
        if entry.distanceMeters >= 100 {
            let km = entry.distanceMeters / 1000
            fields.append(String(format: language == .arabic ? "%.2f كم" : "%.2f km", km))
        }
        return fields.joined(separator: language == .arabic ? "، " : ", ")
    }

    private func formatDelta(
        current: WorkoutHistoryEntry,
        previous: WorkoutHistoryEntry,
        language: AppLanguage
    ) -> String {
        let calorieDelta = current.activeCalories - previous.activeCalories
        let durationDelta = current.durationSeconds - previous.durationSeconds
        let distanceDelta = current.distanceMeters - previous.distanceMeters
        let heartDelta: Double? = {
            guard let cur = current.heartRate, let prev = previous.heartRate, cur > 0, prev > 0 else {
                return nil
            }
            return cur - prev
        }()

        var parts: [String] = []

        if abs(calorieDelta) >= 1 {
            let prefix = calorieDelta > 0 ? "+" : ""
            parts.append(language == .arabic
                ? "السعرات \(prefix)\(Int(calorieDelta))"
                : "calories \(prefix)\(Int(calorieDelta)) kcal")
        }

        if abs(durationDelta) >= 30 {
            let minutes = durationDelta / 60
            let prefix = minutes > 0 ? "+" : ""
            parts.append(language == .arabic
                ? "المدة \(prefix)\(minutes) دقيقة"
                : "duration \(prefix)\(minutes) min")
        }

        if abs(distanceDelta) >= 100 {
            let km = distanceDelta / 1000
            let prefix = km > 0 ? "+" : ""
            let formatted = String(format: "%@%.2f", prefix, km)
            parts.append(language == .arabic
                ? "المسافة \(formatted) كم"
                : "distance \(formatted) km")
        }

        if let heartDelta, abs(heartDelta) >= 1 {
            let prefix = heartDelta > 0 ? "+" : ""
            parts.append(language == .arabic
                ? "النبض \(prefix)\(Int(heartDelta))"
                : "HR \(prefix)\(Int(heartDelta)) bpm")
        }

        if parts.isEmpty {
            return language == .arabic
                ? "أداء قريب جداً من التمرين السابق"
                : "performance nearly identical to the previous session"
        }

        return parts.joined(separator: language == .arabic ? "، " : ", ")
    }

    private func genderInstruction(
        for gender: ActivityNotificationGender?,
        language: AppLanguage
    ) -> String {
        guard let gender else {
            return language == .arabic
                ? "خلّ الصياغة محايدة بين المذكر والمؤنث."
                : "Keep grammar gender-neutral."
        }
        if language == .arabic {
            switch gender {
            case .male:
                return "المستخدم ذكر — استخدم الصياغة المذكّرة."
            case .female:
                return "المستخدمة أنثى — استخدم الصياغة المؤنّثة."
            }
        }
        switch gender {
        case .male:   return "User is male — phrase masculine where the language allows."
        case .female: return "User is female — phrase feminine where the language allows."
        }
    }

    // MARK: - Timeout

    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw WorkoutAnalysisTimeout()
            }
            guard let result = try await group.next() else {
                throw WorkoutAnalysisTimeout()
            }
            group.cancelAll()
            return result
        }
    }
}

private struct WorkoutAnalysisTimeout: LocalizedError {
    var errorDescription: String? { "Workout analysis generation timed out." }
}
