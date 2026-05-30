import Foundation

/// Privacy wrapper over HybridBrainService.
///
/// Before any data reaches the Gemini API, this service:
/// 1. Fetches cloud-safe memories (no PII — only goals/preferences)
/// 2. Sanitizes conversation (truncates to last 4 messages)
/// 3. Redacts all PII (emails, phones, UUIDs, IPs)
/// 4. Normalizes user names to "User"
/// 5. Buckets health data (steps by 50, calories by 10)
struct CloudBrainService: Sendable {
    private let transport: HybridBrainService
    private let sanitizer: PrivacySanitizer
    private let activeTierProvider: @Sendable () async -> SubscriptionTier

    init(
        transport: HybridBrainService = HybridBrainService(),
        sanitizer: PrivacySanitizer = PrivacySanitizer(),
        activeTierProvider: @escaping @Sendable () async -> SubscriptionTier = {
            await MainActor.run { AccessManager.shared.activeTier }
        }
    ) {
        self.transport = transport
        self.sanitizer = sanitizer
        self.activeTierProvider = activeTierProvider
    }

    /// **Fix (2026-04-08):** Collapsed two sequential `MainActor.run` hops into a single hop.
    /// Before: two separate `await MainActor.run` calls serialized behind the MainActor queue,
    /// each waiting for SwiftUI's render cycle to yield. If the UI was busy (scroll, animation),
    /// this could block for 100ms+ per hop. Now both values are fetched in one MainActor round-trip.
    ///
    /// The subsequent sanitization (`sanitizeForCloud`) runs on the caller's cooperative pool
    /// thread — never on MainActor — so regex processing cannot block the UI.
    func generateReply(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        if !DevOverride.unlockAllFeatures {
            guard TierGate.shared.canAccess(.captainChat) else {
                diag.info("CloudBrainService.generateReply blocked by TierGate(.captainChat)")
                throw BrainError.tierRequired(TierGate.shared.requiredTier(for: .captainChat))
            }
        }
        let startedAt = Date()
        let latestUserMessage = request.conversation.last(where: { $0.role == .user })?.content ?? ""

        // App-knowledge grounding: static, PII-free, deterministic on-device
        // lexical retrieval — pure/sync, computed off-MainActor. Lets Captain
        // answer "شنو Peaks؟ / شلون أستخدم المطبخ؟ / فرق الاشتراكات؟"
        // accurately instead of hallucinating. nil on unrelated turns → no
        // prompt bloat.
        let appKnowledgeBlock = AppKnowledge.relevantBlock(
            for: latestUserMessage,
            screenHint: String(describing: request.screenContext).lowercased()
        )

        // Single MainActor hop — tier, memories, consent, and coaching profile
        // in one round-trip.
        let (activeTier, cloudSafeMemories, consentGranted, cloudSafeProfile) = await MainActor.run {
            let tier = AccessManager.shared.activeTier
            let budget = tier.effectiveAccessTier == .pro ? 700 : 400
            let memories = MemoryStore.shared.buildCloudSafeRelevantContext(
                for: latestUserMessage,
                screenContext: request.screenContext,
                maxTokens: budget
            )
            let consent = AIDataConsentManager.shared.hasUserConsented
            let profile = Self.makeCloudSafeProfile(userName: userName)
            return (tier, memories, consent, profile)
        }

        guard consentGranted else {
            await AuditLogger.shared.record(AuditLogger.Entry(
                id: UUID(),
                timestamp: startedAt,
                destination: "none",
                tier: activeTier.auditLabel,
                promptBytes: 0,
                responseBytes: 0,
                latencyMs: 0,
                consentGranted: false,
                sanitizationApplied: false,
                purpose: request.purpose.rawValue,
                outcome: .consentDenied
            ))
            throw AIDataConsentError.consentRequired
        }

        // All sanitization runs off-MainActor (on the cooperative thread pool).
        // This is where the regex-heavy PII redaction happens — it must never block the UI.
        let sanitizedRequest = sanitizer.sanitizeForCloud(
            request,
            knownUserName: userName,
            cloudSafeProfile: cloudSafeProfile,
            cloudSafeMemories: cloudSafeMemories,
            cloudSafeAppKnowledge: appKnowledgeBlock ?? ""
        )

        // Model is gated by `GEMINI_3_PREVIEW_ENABLED`: when the flag is OFF,
        // `GeminiModelPolicy.reasoning == .fast`, so every tier uses the stable
        // `gemini-2.5-flash` and no preview call is ever made.
        let aiModel = activeTier.effectiveAccessTier == .pro
            ? GeminiModelPolicy.reasoning
            : GeminiModelPolicy.fast
        let promptBytes = Self.estimatedPromptBytes(of: sanitizedRequest)

        // Audits a successful call and runs the silent workout-plan recovery, so
        // the primary path and the fallback path get identical treatment.
        func finalize(_ reply: HybridBrainServiceReply, model: String, callStartedAt: Date) async -> HybridBrainServiceReply {
            await AuditLogger.shared.record(AuditLogger.Entry(
                id: UUID(),
                timestamp: callStartedAt,
                destination: model,
                tier: activeTier.auditLabel,
                promptBytes: promptBytes,
                responseBytes: reply.message.utf8.count,
                latencyMs: Int(Date().timeIntervalSince(callStartedAt) * 1000),
                consentGranted: true,
                sanitizationApplied: true,
                purpose: request.purpose.rawValue,
                outcome: .success
            ))

            // Reliability guarantee: when the user clearly asked for a workout
            // plan (gym screen + plan-request phrasing) but the model replied
            // with prose only and `workoutPlan == nil`, the user otherwise has
            // to manually re-ask ("دز الخطة"). Do that one retry silently here
            // so the failed first pass is never surfaced, then merge the rich
            // first message with the recovered structured plan.
            if reply.workoutPlan == nil, Self.looksLikePlanRequest(sanitizedRequest) {
                let retryStartedAt = Date()
                if let recovered = try? await Self.retryForWorkoutPlan(
                    base: sanitizedRequest,
                    firstReply: reply,
                    transport: transport,
                    model: model
                ) {
                    await AuditLogger.shared.record(AuditLogger.Entry(
                        id: UUID(),
                        timestamp: retryStartedAt,
                        destination: model,
                        tier: activeTier.auditLabel,
                        promptBytes: promptBytes,
                        responseBytes: recovered.message.utf8.count,
                        latencyMs: Int(Date().timeIntervalSince(retryStartedAt) * 1000),
                        consentGranted: true,
                        sanitizationApplied: true,
                        purpose: request.purpose.rawValue,
                        outcome: recovered.workoutPlan == nil ? .failure : .success
                    ))
                    if recovered.workoutPlan != nil {
                        return recovered
                    }
                }
            }

            return reply
        }

        // Audits a failed call (metadata only — never content).
        func auditFailure(model: String, callStartedAt: Date) async {
            await AuditLogger.shared.record(AuditLogger.Entry(
                id: UUID(),
                timestamp: callStartedAt,
                destination: model,
                tier: activeTier.auditLabel,
                promptBytes: promptBytes,
                responseBytes: 0,
                latencyMs: Int(Date().timeIntervalSince(callStartedAt) * 1000),
                consentGranted: true,
                sanitizationApplied: true,
                purpose: request.purpose.rawValue,
                outcome: .failure
            ))
        }

        do {
            let reply = try await transport.generateReply(request: sanitizedRequest, model: aiModel)
            return await finalize(reply, model: aiModel, callStartedAt: startedAt)
        } catch {
            await auditFailure(model: aiModel, callStartedAt: startedAt)

            // Automatic fallback: a preview-model failure/timeout retries once on
            // the stable `gemini-2.5-flash` so the user never feels it. Only fires
            // when the failed call actually used a non-fast (preview) model.
            guard aiModel != GeminiModelPolicy.fast else { throw error }
            diag.info("CloudBrainService: \(aiModel) failed (\(error.localizedDescription)); falling back to \(GeminiModelPolicy.fast)")
            let fallbackStartedAt = Date()
            do {
                let fallbackReply = try await transport.generateReply(request: sanitizedRequest, model: GeminiModelPolicy.fast)
                return await finalize(fallbackReply, model: GeminiModelPolicy.fast, callStartedAt: fallbackStartedAt)
            } catch {
                await auditFailure(model: GeminiModelPolicy.fast, callStartedAt: fallbackStartedAt)
                throw error
            }
        }
    }

    /// True when the latest user message is asking for a workout — in the gym
    /// screen OR the main Captain chat. The recovery retry only fires when the
    /// first reply already came back with `workoutPlan == nil` (see call site),
    /// so a correct first reply never pays the extra round-trip. Phrasings are
    /// deliberately broad (conversational asks like "اكتبلي تمرين"، not just
    /// "ابني خطة") because a paid user must never get a teaser instead of a
    /// real workout.
    private static func looksLikePlanRequest(_ request: HybridBrainRequest) -> Bool {
        guard request.screenContext == .gym || request.screenContext == .mainChat else { return false }
        guard let last = request.conversation
            .last(where: { $0.role == .user })?
            .content
            .lowercased()
        else { return false }

        let needles = [
            "أبني خطة", "ابني خطة", "خطة تمرين", "خطة تدريب",
            "اعطني خطة", "اعطيني خطة", "سويلي خطة", "سو لي خطة",
            "اكتبلي تمرين", "اكتب لي تمرين", "عطني تمرين", "عطيني تمرين",
            "سويلي تمرين", "سو لي تمرين", "تمرين اليوم", "تمرين قوي",
            "بدي اتمرن", "بدّي أتمرّن", "ريد تمرين", "أريد تمرين", "اريد اتمرن",
            "build me a", "workout plan", "training plan", "personalized",
            "write me a workout", "give me a workout", "workout for"
        ]
        return needles.contains { last.contains($0.lowercased()) }
    }

    /// One silent re-request that forces the structured `workoutPlan`. The
    /// body image is intentionally NOT resent (the visual feedback is already
    /// captured in `firstReply.message`; resending wastes bandwidth and a
    /// vision round-trip). On success the rich first message is preserved and
    /// the recovered plan is attached.
    private static func retryForWorkoutPlan(
        base: HybridBrainRequest,
        firstReply: HybridBrainServiceReply,
        transport: HybridBrainService,
        model: String
    ) async throws -> HybridBrainServiceReply {
        let force = base.language == .arabic
            ? "ضروري الحين ترجع نفس الخطة داخل حقل workoutPlan منظّم: title و durationWeeks و days[] (كل يوم: name و focus و exercises مع sets و repsOrDuration). خلّي message قصيرة وحط الخطة كاملة بـ workoutPlan. لا ترد نص فقط."
            : "You MUST now return the same plan inside a structured workoutPlan object: title, durationWeeks, days[] (each day: name, focus, exercises with sets and repsOrDuration). Keep message short and put the full plan in workoutPlan. Do not reply with prose only."

        var convo = base.conversation
        convo.append(CaptainConversationMessage(role: .assistant, content: firstReply.message))
        convo.append(CaptainConversationMessage(role: .user, content: force))

        let retryRequest = HybridBrainRequest(
            conversation: convo,
            screenContext: base.screenContext,
            language: base.language,
            contextData: base.contextData,
            userProfileSummary: base.userProfileSummary,
            intentSummary: base.intentSummary,
            workingMemorySummary: base.workingMemorySummary,
            attachedImageData: nil,
            purpose: base.purpose
        )

        let retry = try await transport.generateReply(request: retryRequest, model: model)

        guard let plan = retry.workoutPlan else { return firstReply }

        return HybridBrainServiceReply(
            message: firstReply.message,
            quickReplies: retry.quickReplies ?? firstReply.quickReplies,
            workoutPlan: plan,
            mealPlan: firstReply.mealPlan,
            spotifyRecommendation: firstReply.spotifyRecommendation,
            rawText: retry.rawText,
            truncatedAtMaxTokens: retry.truncatedAtMaxTokens
        )
    }

    private static func estimatedPromptBytes(of request: HybridBrainRequest) -> Int {
        var total = 0
        for msg in request.conversation {
            total += msg.content.utf8.count
        }
        total += request.intentSummary.utf8.count
        total += request.workingMemorySummary.utf8.count
        total += request.userProfileSummary.utf8.count
        return total
    }

    /// Builds the coaching-safe profile snapshot passed to the cloud. Runs on
    /// MainActor because `UserProfileStore.shared.current` reads from
    /// `UserDefaults` and the observable store is main-isolated.
    @MainActor
    private static func makeCloudSafeProfile(userName: String?) -> CloudSafeProfile {
        let profile = UserProfileStore.shared.current

        let resolvedFirstName: String? = {
            if let name = userName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return name.components(separatedBy: .whitespaces).first
            }
            let profileName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if profileName.isEmpty || profileName.lowercased() == "captain" { return nil }
            return profileName.components(separatedBy: .whitespaces).first
        }()

        let gender: String? = {
            guard let value = profile.gender else { return nil }
            return value.rawValue
        }()

        return CloudSafeProfile(
            firstName: resolvedFirstName,
            age: profile.age > 0 ? profile.age : nil,
            gender: gender,
            heightCm: profile.heightCm > 0 ? profile.heightCm : nil,
            weightKg: profile.weightKg > 0 ? profile.weightKg : nil
        )
    }
}

// MARK: - Kitchen Vision

extension CloudBrainService {
    /// Privacy-wrapped Gemini vision call for the Kitchen fridge scanner.
    ///
    /// Mirrors the sanitization + audit guarantees of `generateReply`:
    /// 1. Image data runs through `sanitizer.sanitizeKitchenImageData` (EXIF/GPS strip + resize)
    /// 2. Prompt runs through `sanitizer.sanitizePromptForCloud` (PII regex + numeric bucketing)
    /// 3. Outbound call is bracketed by `AuditLogger.Entry(purpose: .kitchen)` records
    /// 4. Tier-based model selection (Pro → reasoning, others → `gemini-2.5-flash`)
    ///
    /// Returns the raw model output text — the kitchen caller decodes the
    /// JSON array (`[{"name":…}]`) itself; the Captain structured-response
    /// parser is not used.
    func generateKitchenAnalysis(
        rawImageData: Data?,
        userName: String?
    ) async throws -> String {
        if !DevOverride.unlockAllFeatures {
            guard TierGate.shared.canAccess(.captainChat) else {
                throw BrainError.tierRequired(TierGate.shared.requiredTier(for: .captainChat))
            }
        }
        try await AICloudConsentGate.requireConsent()

        let startedAt = Date()
        let activeTier = await MainActor.run { AccessManager.shared.activeTier }
        let model = activeTier.effectiveAccessTier == .pro
            ? GeminiModelPolicy.reasoning
            : GeminiModelPolicy.fast

        guard let imageData = sanitizer.sanitizeKitchenImageData(rawImageData) else {
            throw HybridBrainServiceError.invalidResponse
        }

        let promptText = sanitizer.sanitizePromptForCloud(
            "Return JSON only. Visible food items only. Schema: [{\"name\": string, \"quantity\": number, \"unit\": string|null}]. Use generic food names.",
            knownUserName: userName
        )

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": promptText],
                        ["inlineData": [
                            "mimeType": "image/jpeg",
                            "data": imageData.base64EncodedString()
                        ]]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 220,
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]

        let urlRequest = try makeKitchenURLRequest(model: model, body: body)
        let promptBytes = promptText.utf8.count + imageData.count
        let tierLabel = activeTier.auditLabel

        func recordAudit(outcome: AuditLogger.Entry.Outcome, responseBytes: Int) async {
            await AuditLogger.shared.record(AuditLogger.Entry(
                id: UUID(),
                timestamp: startedAt,
                destination: model,
                tier: tierLabel,
                promptBytes: promptBytes,
                responseBytes: responseBytes,
                latencyMs: Int(Date().timeIntervalSince(startedAt) * 1000),
                consentGranted: true,
                sanitizationApplied: true,
                purpose: RequestPurpose.kitchen.rawValue,
                outcome: outcome
            ))
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                await recordAudit(outcome: .failure, responseBytes: 0)
                throw HybridBrainServiceError.badStatusCode(
                    (response as? HTTPURLResponse)?.statusCode ?? -1
                )
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let candidateContent = firstCandidate["content"] as? [String: Any],
                  let parts = candidateContent["parts"] as? [[String: Any]],
                  let content = parts.first?["text"] as? String else {
                await recordAudit(outcome: .failure, responseBytes: data.count)
                throw HybridBrainServiceError.invalidResponse
            }

            await recordAudit(outcome: .success, responseBytes: content.utf8.count)
            return content
        } catch {
            // Status-code and decode paths already audited before throwing.
            // Only record an extra failure entry for network-level errors
            // (URLSession threw before any HTTP response was available).
            if !(error is HybridBrainServiceError) {
                await recordAudit(outcome: .failure, responseBytes: 0)
            }
            throw error
        }
    }

    private func makeKitchenURLRequest(
        model: String,
        body: [String: Any]
    ) throws -> URLRequest {
        let apiKey = try GeminiConfig.resolvedAPIKey()
        var urlRequest = URLRequest(url: try GeminiConfig.endpointURL(for: model))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 15
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }
}
