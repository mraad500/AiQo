import Foundation
import SwiftUI
import UIKit
import Combine

struct CaptainProcessingTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Captain processing exceeded the maximum allowed time."
    }
}

enum ChatMessageAccessory: Equatable, Sendable {
    case morningGratitude

    var buttonTitle: String {
        switch self {
        case .morningGratitude:
            return "ابدأ جلسة الامتنان ✨"
        }
    }
}

/// Single chat bubble model used by the Captain conversation UI.
struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String
    let isUser: Bool
    let timestamp: Date
    var isAnimating: Bool
    var isEphemeral: Bool
    var isRead: Bool
    var accessory: ChatMessageAccessory?
    var spotifyRecommendation: SpotifyRecommendation?
    /// A non-conversational, UI-only marker (e.g. the "earlier chat folded into
    /// memory" pill shown once when compaction kicks in). Never persisted and
    /// never sent to the model — the window/digest builders skip it.
    var isSystemNote: Bool

    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false,
        isEphemeral: Bool = false,
        isRead: Bool = true,
        accessory: ChatMessageAccessory? = nil,
        spotifyRecommendation: SpotifyRecommendation? = nil,
        isSystemNote: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.isAnimating = isAnimating
        self.isEphemeral = isEphemeral
        self.isRead = isRead
        self.accessory = accessory
        self.spotifyRecommendation = spotifyRecommendation
        self.isSystemNote = isSystemNote
    }

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false,
        isEphemeral: Bool = false,
        isRead: Bool = true,
        accessory: ChatMessageAccessory? = nil,
        spotifyRecommendation: SpotifyRecommendation? = nil
    ) {
        self.init(
            id: id,
            text: content,
            isUser: isUser,
            timestamp: timestamp,
            isAnimating: isAnimating,
            isEphemeral: isEphemeral,
            isRead: isRead,
            accessory: accessory,
            spotifyRecommendation: spotifyRecommendation
        )
    }

    var content: String {
        get { text }
        set { text = newValue }
    }
}

/// Drives the unified Captain chat screen and keeps the latest structured workout plan in sync with the UI.
@MainActor
final class CaptainViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var currentWorkoutPlan: WorkoutPlan?
    @Published var currentMealPlan: MealPlan?
    @Published var inputText: String = ""
    @Published var coachState: CoachCognitiveState = .idle
    /// Live progressive-reveal state. While `streamingMessageID != nil` the
    /// chat shows ONE live bubble bound to `streamingText` instead of the
    /// finalized row — the `messages` array is published exactly once (on
    /// completion), so a long conversation never re-diffs the whole list
    /// per character. Kept tiny and isolated on purpose.
    @Published private(set) var streamingMessageID: UUID?
    @Published private(set) var streamingText: String = ""
    @Published var showCustomization: Bool = false
    @Published var showChatHistory: Bool = false
    @Published var showProfile: Bool = false
    @Published var showGratitudeSession: Bool = false
    @Published var showPaywall: Bool = false
    @Published var customization: CaptainCustomization = .default
    @Published var feedbackTrigger: Int = 0
    @Published var activeModule: ScreenContext = .mainChat
    @Published var quickReplies: [String] = []

    /// Mirrors `TierGate.shared.currentTier`. Views bind to this for
    /// reactive "Pro-only" badges, trial banners, etc.
    @Published private(set) var effectiveTier: SubscriptionTier = .none

    var isSending: Bool { isLoading }
    var isTyping: Bool { isLoading }

    private let userDefaults = UserDefaults.standard
    private let orchestrator: BrainOrchestrator
    /// Free-tier Captain runs fully on-device via Apple Intelligence — pure
    /// dynamic generation, no cloud, no memory, no templates.
    private let onDeviceEngine = CaptainOnDeviceChatEngine()
    private let contextBuilder: CaptainContextBuilder
    private let cognitivePipeline: CaptainCognitivePipeline
    /// Bridges the embedding-RAG `MemoryRetriever` into the live chat prompt.
    /// Stateless; runs off-MainActor and is parallelized with the HealthKit
    /// context read, so it adds no perceptible latency.
    private let chatMemoryEnricher = ChatMemoryEnricher()
    private let morningHabitOrchestrator: MorningHabitOrchestrator
    private let replyJSONParser = LLMJSONParser()
    private let minimumLoadingStateDuration: TimeInterval = 0.8
    /// Cloud Gemini calls with the full 7-layer prompt + Arabic tokenization
    /// commonly land in the 12–22s range; 15s was firing on healthy P95 calls
    /// and showing a "try again" error to users while the request was still
    /// in-flight. URLSession deadline is 35s so 30s leaves buffer for the
    /// underlying transport to surface a real failure if the network is gone.
    private let globalProcessingTimeout: TimeInterval = 30
    /// Sleep analysis runs entirely on-device (HealthKit + Foundation Models) and needs more time.
    private let sleepProcessingTimeout: TimeInterval = 25

    /// حد أقصى للرسائل بالذاكرة — الباقي محفوظ بـ SwiftData
    private static let maxInMemoryMessages = 80

    private var responseTask: Task<Void, Never>?
    private var activeRequestID: UUID?
    private var messageCount = 0
    /// كل فتحة تطبيق = جلسة جديدة
    private(set) var currentSessionID = UUID()

    /// Rolling, faithful compaction of the part of the CURRENT session that has
    /// already been EVICTED from `messages` (the 80-message in-RAM cap). The
    /// per-turn prompt digest merges this with the in-RAM pre-window head, so the
    /// Captain never loses the conversation's head — even past the RAM cap — and
    /// therefore never fabricates to fill a forgotten gap. Reset per session.
    /// See [[ConversationCompactor]] / `ConversationDigest`.
    private var sessionDigest: ConversationDigest = .empty
    /// True once we've crossed into compaction at least once this session — used
    /// only for a one-time diagnostics breadcrumb, not behavior.
    private var didLogCompaction = false
    /// True once the subtle "earlier chat folded into memory" pill has been
    /// shown this session — it appears exactly once, at the seam.
    private var didInsertCompactionNote = false

    private enum Keys {
        static let name = "captain_user_name"
        static let age = "captain_user_age"
        static let height = "captain_user_height"
        static let weight = "captain_user_weight"
        static let calling = "captain_calling"
        static let tone = "captain_tone"
        static let customStyle = "captain_custom_style"
    }

    init(
        orchestrator: BrainOrchestrator? = nil,
        contextBuilder: CaptainContextBuilder? = nil,
        cognitivePipeline: CaptainCognitivePipeline? = nil,
        morningHabitOrchestrator: MorningHabitOrchestrator? = nil
    ) {
        self.orchestrator = orchestrator ?? BrainOrchestrator()
        self.contextBuilder = contextBuilder ?? .shared
        self.cognitivePipeline = cognitivePipeline ?? .shared
        self.morningHabitOrchestrator = morningHabitOrchestrator ?? .shared
        loadCustomization()
        loadPersistedHistory()
        bindTierGate()
    }

    private func bindTierGate() {
        // Seed with the current tier. HEAD's TierGate exposes currentTier
        // as a computed property (reads UserDefaults live), so a one-shot
        // read is enough; downstream views re-query on render.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.effectiveTier = TierGate.shared.currentTier
        }
    }

    deinit {
        responseTask?.cancel()
    }

    struct CaptainLayoutMetrics {
        let chatHeight: CGFloat
        let chatOffset: CGFloat
        let avatarHeight: CGFloat
        let avatarOffset: CGFloat
        let chatScrollEnabled: Bool
    }

    func layout(for availableHeight: CGFloat) -> CaptainLayoutMetrics {
        let messageSteps = CGFloat(max(messages.count - 1, 0))

        let avatarHeight = availableHeight * 0.62
        let perMessageDrop = availableHeight * 0.11
        let bellyAnchor: CGFloat = 0.58
        let avatarBaseTop = availableHeight - avatarHeight
        let bellyYAtBase = avatarBaseTop + (avatarHeight * bellyAnchor)
        let maxAvatarOffset = max(0, availableHeight - 8 - bellyYAtBase)
        let avatarOffset = min(perMessageDrop * messageSteps, maxAvatarOffset)

        let stopSteps = perMessageDrop > 0 ? ceil(maxAvatarOffset / perMessageDrop) : 0
        let effectiveSteps = min(messageSteps, stopSteps)

        let chatHeight = min(availableHeight * 0.62, availableHeight * (0.27 + (0.085 * effectiveSteps)))
        let chatStartOffset = -availableHeight * 0.02
        let perMessageChatDrop = availableHeight * 0.11
        let proposedChatOffset = chatStartOffset + (perMessageChatDrop * effectiveSteps)

        let desiredGap: CGFloat = 24
        let avatarTopWithOffset = avatarBaseTop + avatarOffset
        let maxChatBottom = avatarTopWithOffset - desiredGap
        let maxAllowedOffset = maxChatBottom - chatHeight
        let chatOffset = min(proposedChatOffset, maxAllowedOffset)

        return CaptainLayoutMetrics(
            chatHeight: chatHeight,
            chatOffset: chatOffset,
            avatarHeight: avatarHeight,
            avatarOffset: avatarOffset,
            chatScrollEnabled: true
        )
    }

    func openProfile() {
        showProfile = true
    }

    func sendMessage() {
        sendMessage(text: inputText)
    }

    func sendMessage(_ rawText: String, context: ScreenContext? = nil) {
        sendMessage(text: rawText, context: context)
    }

    func sendMessage(
        text rawText: String,
        image: UIImage? = nil,
        context: ScreenContext? = nil
    ) {
        let context = context ?? activeModule
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmergencyBypass = IntentClassifier.classify(trimmedText).primary == .crisis
        guard !trimmedText.isEmpty else { return }
        guard !isLoading else { return }

        // Free tier → Captain runs ON-DEVICE (Apple Intelligence): dynamic,
        // private, uncapped, zero templates. Paid (Max+) continues to the cloud
        // brain + durable-memory path below. Crisis messages always use the
        // full pipeline regardless of tier.
        if !DevOverride.unlockAllFeatures && !isEmergencyBypass && !TierGate.shared.canAccess(.captainChat) {
            sendOnDeviceReply(text: trimmedText)
            return
        }

        let requiresCloudConsent = context != .sleepAnalysis && !isEmergencyBypass
        if requiresCloudConsent, AIDataConsentManager.shared.isInOfflineOnlyMode {
            return
        }
        guard !requiresCloudConsent || AIDataConsentManager.shared.ensureConsent(presentIfPossible: true) else {
            return
        }

        HapticEngine.light()
        AnalyticsService.shared.track(.captainMessageSent(length: trimmedText.count))

        responseTask?.cancel()
        feedbackTrigger += 1
        inputText = ""

        // Persist the welcome message on first user interaction so the session is complete in SwiftData
        if messageCount == 0, let welcomeMessage = messages.first, !welcomeMessage.isUser {
            persistChatMessage(welcomeMessage)
        }

        let userMessage = ChatMessage(text: trimmedText, isUser: true)
        messages.append(userMessage)
        isLoading = true
        coachState = .readingMessage
        persistChatMessage(userMessage)

        // Once the session grows past the verbatim window, drop a single soft
        // marker at the seam so the continuity is visible (not a silent gap) —
        // the Captain keeps the whole thread via the digest, this just shows it.
        maybeInsertCompactionNote()

        let requestID = UUID()
        activeRequestID = requestID
        let attachedImageData = Self.preparedImageData(from: image)

        // Only the lightweight captures happen here. The heavy SwiftData fetches
        // (memory retrieval, thread log save) are deferred into the Task so the
        // typing bubble can render before MainActor gets busy again.
        let language = AppSettingsStore.shared.appLanguage

        responseTask = Task { [weak self] in
            guard let self else { return }

            // One frame for SwiftUI to render isLoading = true + typing bubble
            // before any blocking MainActor work (SwiftData fetches, HealthKit).
            await Task.yield()

            ConversationThreadManager.shared.logUserMessage(content: trimmedText)

            // 11_Directives — if the user just taught a standing instruction
            // ("after every workout, analyze it and compare it to the previous
            // one and notify me"), save it durably + mirror it into recallable
            // memory now, so the Captain confirms it in THIS reply and never
            // forgets it. The post-workout execution runs independently via
            // DirectiveEngine regardless of this chat.
            if let directiveDraft = DirectiveLearner.detect(from: trimmedText) {
                await DirectiveCoordinator.shared.learn(draft: directiveDraft)
            }

            let conversation = self.buildConversationHistory()
            let userName = self.captainReplyUserName()
            let promptContext = self.cognitivePipeline.buildPromptContext(
                userMessage: trimmedText,
                screenContext: context,
                customization: self.customization,
                preferredName: userName
            )

            await self.processMessage(
                requestID: requestID,
                screenContext: context,
                attachedImageData: attachedImageData,
                prebuiltConversation: conversation,
                prebuiltUserName: userName,
                prebuiltLanguage: language,
                prebuiltPromptContext: promptContext
            )
        }
    }

    // MARK: - Free tier — on-device Captain

    /// FREE-tier Captain: one fully dynamic reply generated ON-DEVICE via Apple
    /// Intelligence (`CaptainOnDeviceChatEngine`). No cloud, no memory, no
    /// templates — every reply is generated fresh so it never feels canned.
    /// Paid tiers use the cloud brain + memory path in `processMessage`.
    private func sendOnDeviceReply(text trimmedText: String) {
        HapticEngine.light()
        AnalyticsService.shared.track(.captainMessageSent(length: trimmedText.count))

        responseTask?.cancel()
        feedbackTrigger += 1
        inputText = ""

        // Persona (name + tone) for this turn. Conversation memory is kept
        // natively inside the engine's live session — no transcript is passed.
        let persona = onDevicePersona()

        let userMessage = ChatMessage(text: trimmedText, isUser: true)
        messages.append(userMessage)
        isLoading = true
        coachState = .readingMessage

        let requestID = UUID()
        activeRequestID = requestID
        let engine = onDeviceEngine

        responseTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeRequestID == requestID {
                    self.isLoading = false
                    self.coachState = .idle
                }
            }

            await Task.yield()
            self.coachState = .thinkingOnDevice

            do {
                let reply = try await engine.respondInConversation(
                    to: trimmedText,
                    persona: persona
                )
                try self.ensureActiveRequest(requestID)
                let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedReply.isEmpty else {
                    self.appendOnDeviceFallback(requestID: requestID)
                    return
                }
                self.coachState = .typing
                await self.revealReply(
                    ChatMessage(text: trimmedReply, isUser: false),
                    requestID: requestID
                )
            } catch is CancellationError {
                // Superseded by a newer message — drop silently.
            } catch {
                diag.info("CaptainViewModel.sendOnDeviceReply failed: \(error.localizedDescription)")
                self.appendOnDeviceFallback(requestID: requestID)
            }
        }
    }

    /// Soft, warm retry line for the rare case the on-device model is busy or
    /// unavailable. Shown only on hard failure — never as a routine reply.
    private func appendOnDeviceFallback(requestID: UUID) {
        guard activeRequestID == requestID else { return }
        let text = AppSettingsStore.shared.appLanguage == .english
            ? "Give me one sec and try that again."
            : "عطني ثانية وجرّبها مرة لخ."
        appendFinal(ChatMessage(text: text, isUser: false), requestID: requestID)
    }

    func saveCustomization() {
        userDefaults.set(customization.name, forKey: Keys.name)
        userDefaults.set(customization.age, forKey: Keys.age)
        userDefaults.set(customization.height, forKey: Keys.height)
        userDefaults.set(customization.weight, forKey: Keys.weight)
        userDefaults.set(customization.calling, forKey: Keys.calling)
        userDefaults.set(customization.tone.rawValue, forKey: Keys.tone)
        userDefaults.set(customization.customStyle, forKey: Keys.customStyle)
        feedbackTrigger += 1

        let nickname = customization.calling.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = nickname.isEmpty ? "✅ تمام تم الحفظ" : "✅ تمام تم الحفظ - راح أناديك \(nickname)"

        let confirmMessage = ChatMessage(text: summary, isUser: false)
        messages.append(confirmMessage)
        persistChatMessage(confirmMessage)
        showCustomization = false
    }

    func loadCustomization() {
        customization.name = userDefaults.string(forKey: Keys.name) ?? ""
        customization.age = userDefaults.string(forKey: Keys.age) ?? ""
        customization.height = userDefaults.string(forKey: Keys.height) ?? ""
        customization.weight = userDefaults.string(forKey: Keys.weight) ?? ""
        customization.calling = userDefaults.string(forKey: Keys.calling) ?? ""

        if let toneString = userDefaults.string(forKey: Keys.tone),
           let tone = CaptainTone(rawValue: toneString) {
            customization.tone = tone
        }
        customization.customStyle = userDefaults.string(forKey: Keys.customStyle) ?? ""
    }

    func consumePendingCaptainNotificationIfAny() {
        let handler = CaptainNotificationHandler.shared
        guard let pending = handler.pendingNotificationMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pending.isEmpty else { return }

        messages.append(ChatMessage(text: pending, isUser: false))
        handler.clearPendingMessage()
    }

    func generateMorningSleepAnalysis() {
        Task { @MainActor [weak self] in
            await self?.consumeMorningHabitInsightIfNeeded()
        }
    }

    func removeEphemeralMessages() {
        messages.removeAll { $0.isEphemeral }
    }

    func removeReadEphemeralMessages() {
        messages.removeAll { $0.isEphemeral && $0.isRead }
        morningHabitOrchestrator.deleteReadEphemeralInsightIfNeeded()
    }

    func markEphemeralMessageRead(messageID: UUID? = nil) {
        var didUpdateMessage = false

        for index in messages.indices {
            guard messages[index].isEphemeral, !messages[index].isRead else { continue }
            if let messageID, messages[index].id != messageID { continue }

            messages[index].isRead = true
            didUpdateMessage = true
        }

        if didUpdateMessage {
            morningHabitOrchestrator.markEphemeralInsightRead()
        }
    }

    func handleScenePhaseTransition(_ phase: ScenePhase) {
        guard phase == .background else { return }
        removeReadEphemeralMessages()
    }

    func startMorningGratitudeSession() {
        feedbackTrigger += 1
        showGratitudeSession = true
    }

    /// كل فتحة تطبيق تبدأ بمحادثة جديدة — المحادثات القديمة متاحة عبر زر التاريخ
    private func loadPersistedHistory() {
        startNewChat()
    }

    /// يبدأ محادثة جديدة — sessionID جديد ورسالة ترحيبية متغيّرة كل فتحة
    func startNewChat() {
        currentSessionID = UUID()
        messages.removeAll()
        messageCount = 0
        currentWorkoutPlan = nil
        currentMealPlan = nil
        quickReplies = []
        sessionDigest = .empty
        didLogCompaction = false
        didInsertCompactionNote = false

        responseTask?.cancel()
        activeRequestID = nil

        AnalyticsService.shared.track(.captainChatOpened)

        isLoading = true
        coachState = .typing

        let sessionID = currentSessionID
        let capturedOrchestrator = orchestrator
        let isFreeCaptain = !DevOverride.unlockAllFeatures && !TierGate.shared.canAccess(.captainChat)
        let engine = onDeviceEngine
        let persona = onDevicePersona()
        responseTask = Task { [weak self] in
            var dynamic: String?
            if isFreeCaptain {
                // Free welcome is generated on-device — live + data-aware
                // (name + today's steps + tone), never a canned line.
                dynamic = try? await engine.welcome(persona: persona)
            } else {
                dynamic = await DynamicWelcomeComposer.compose(orchestrator: capturedOrchestrator)
                // Cloud welcome failed (offline / timeout / consent) — fall back to
                // the on-device welcome so paid users still get a personalized
                // greeting, never the flat canned line.
                if dynamic == nil {
                    dynamic = try? await engine.welcome(persona: persona)
                }
            }
            self?.applyWelcomeMessage(dynamic, for: sessionID)
        }
    }

    /// Inserts the welcome bubble after the dynamic generator settles, or
    /// drops in the static fallback if generation returned nil. Bails out
    /// silently if the user has already started another session in the
    /// meantime (e.g., tapped a chat-history entry).
    private func applyWelcomeMessage(_ dynamic: String?, for sessionID: UUID) {
        guard currentSessionID == sessionID else { return }

        let trimmed = dynamic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text: String
        if !trimmed.isEmpty {
            text = trimmed
        } else {
            // Absolute last resort (both cloud + on-device unavailable) — keep it
            // personalized with the user's name, not a flat canned line.
            let name = captainReplyUserName()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if AppSettingsStore.shared.appLanguage == .english {
                text = name.isEmpty ? "Hey! What's your goal today?" : "Hey \(name)! What's your goal today?"
            } else {
                text = name.isEmpty ? "هلا بيك! شنو هدفك اليوم؟" : "هلا \(name)! شنو هدفك اليوم؟"
            }
        }

        let welcome = ChatMessage(text: text, isUser: false)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            messages.append(welcome)
        }
        isLoading = false
        coachState = .idle
        // Don't persist the welcome — the session is only persisted on first
        // user reply, so we never leave stale single-message sessions in
        // SwiftData on every cold launch.
    }

    /// يحمّل جلسة قديمة — يستبدل الرسائل الحالية برسائل الجلسة المختارة
    func loadSession(_ session: ChatSession) {
        currentSessionID = session.id
        let stored = MemoryStore.shared.fetchMessages(for: session.id)
        messages = stored
        messageCount = stored.count
        currentWorkoutPlan = nil
        currentMealPlan = nil
        // Full transcript is back in RAM, so per-turn compaction rebuilds the
        // digest from scratch — reset the evicted-head accumulator.
        sessionDigest = .empty
        didLogCompaction = false
        didInsertCompactionNote = false
        showChatHistory = false
    }

    /// **Fix (2026-04-08):** Accepts pre-built conversation and profile data so the heavy
    /// string processing (conversation history, profile summary, memory context) happens
    /// on the MainActor *before* the Task launches — but only the lightweight capture,
    /// not the orchestrator call. The orchestrator + sanitizer + network call all run on
    /// the cooperative thread pool, never blocking the UI.
    private func processMessage(
        requestID: UUID,
        screenContext: ScreenContext,
        attachedImageData: Data?,
        prebuiltConversation: [CaptainConversationMessage],
        prebuiltUserName: String?,
        prebuiltLanguage: AppLanguage,
        prebuiltPromptContext: CaptainPromptContext
    ) async {
        defer {
            if activeRequestID == requestID {
                isLoading = false
                coachState = .idle
            }
        }

        // Give SwiftUI a frame to render the typing indicator before any
        // MainActor-isolated work (HealthKit reads, prompt assembly) starts.
        await Task.yield()

        do {
            let latestUserText = prebuiltConversation.last(where: { $0.role == .user })?.content ?? ""
            // Continuity past the verbatim window: a FAITHFUL, structured digest
            // of the earlier part of this session — opening goal, points the
            // user made, the Captain's OWN commitments, corrections, and the
            // last exchange. Built by `ConversationCompactor` from real messages
            // only, so it can never invent a fact (an LLM summary could). It is
            // carried as the request's dedicated `conversationState`, NOT folded
            // into `workingMemorySummary` (which the cloud path rebuilds from
            // durable memories and would silently drop), so the head of a long
            // chat actually reaches the model and the Captain stops "forgetting"
            // and then hallucinating to fill the gap. nil for short chats.
            let conversationDigest = buildConversationDigest()
            let conversationStateBlock = conversationDigest.renderedBlock(language: prebuiltLanguage)
            if conversationStateBlock != nil, !didLogCompaction {
                didLogCompaction = true
                diag.info("CaptainViewModel: conversation compaction active (covered≈\(conversationDigest.coveredMessageCount) msgs)")
            }

            // Run the embedding-RAG semantic recall CONCURRENTLY with the
            // HealthKit context read. `enrich` is off-MainActor and hops onto
            // the MemoryRetriever actor while `buildContextData` awaits
            // HealthKit, so the semantic lookup adds ~no wall-clock latency.
            // On free tier `MemoryRetriever` returns an empty bundle and
            // `enrich` returns the lexical base unchanged — no regression.
            // Session continuity is no longer threaded here — it now flows
            // through the reliable `conversationState` channel above.
            async let contextDataTask = contextBuilder.buildContextData()
            async let enrichedMemoryTask = chatMemoryEnricher.enrich(
                baseSummary: prebuiltPromptContext.workingMemorySummary,
                userMessage: latestUserText,
                screenContext: screenContext
            )

            var contextData = await contextDataTask
            let workingMemorySummary = await enrichedMemoryTask

            // Brain V2: Detect sentiment from user's message
            if CaptainContextBuilder.isBrainV2Enabled, !latestUserText.isEmpty {
                contextData.messageSentiment = SentimentDetector.shared.detect(message: latestUserText)
            }

            let promptRequest = HybridBrainRequest(
                conversation: prebuiltConversation,
                screenContext: screenContext,
                language: prebuiltLanguage,
                contextData: contextData,
                userProfileSummary: prebuiltPromptContext.profileSummary,
                intentSummary: prebuiltPromptContext.intentSummary,
                workingMemorySummary: workingMemorySummary,
                attachedImageData: attachedImageData,
                conversationState: conversationStateBlock
            )

            let startedAt = Date()
            let capturedOrchestrator = orchestrator
            // Sleep analysis runs entirely on-device (HealthKit + Foundation Models) — give it more time.
            // The orchestrator may reroute .mainChat → .sleepAnalysis internally if the message is sleep-related.
            let needsSleepTimeout = screenContext == .sleepAnalysis
                || looksLikeSleepRequest(latestUserText)
            let orchestratorTimeout = needsSleepTimeout
                ? sleepProcessingTimeout
                : globalProcessingTimeout

            // Real token streaming. When enabled, the orchestrator's CLOUD path
            // streams live `message` previews through `onPreview` into a bound
            // bubble — first text shows in ~1s instead of after the full
            // generation. `streamID` lets us detect afterward whether streaming
            // actually drove the UI (it only fires on the cloud route, never on
            // the on-device sleep route or on error) so we can skip the
            // client-side fake reveal in that case. OFF → unchanged behavior.
            let useStreaming = FeatureFlags.captainRealStreaming
            let streamID = UUID()
            let onPreview: (@Sendable (String) async -> Void)?
            if useStreaming {
                onPreview = { [weak self] preview in
                    await self?.applyStreamingPreview(preview, streamID: streamID, requestID: requestID)
                }
            } else {
                onPreview = nil
            }

            let reply = try await withGlobalTimeout(seconds: orchestratorTimeout) {
                try await capturedOrchestrator.processMessage(
                    request: promptRequest,
                    userName: prebuiltUserName,
                    onMessagePreview: onPreview
                )
            }

            // The reply is already computed. The old `runCognitiveTimeline`
            // added ~0.64s of pure Task.sleep here, plus a 0.18s typing hold —
            // ~0.82s of dead time the user feels as lag AFTER the AI already
            // answered. Go straight to the reveal. The sub-`minimumLoadingState`
            // floor is kept only so an instant cached/offline reply still shows
            // a brief typing flash instead of flickering.
            try ensureActiveRequest(requestID)

            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minimumLoadingStateDuration {
                let remaining = minimumLoadingStateDuration - elapsed
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            try ensureActiveRequest(requestID)
            coachState = .typing

            // Silent-Captain fallback. The model is asked (hybrid contract)
            // to return BOTH a short warm message AND the structured plan.
            // In practice Gemini sometimes (a) returns an empty `message`
            // when it judges the card sufficient, (b) returns a one-word
            // ack ("تدلل!") that collapses to a tiny bubble, or (c) emits
            // the parser-fallback "connection error" string when the JSON
            // round-trip glitches. In all three cases the Captain looks
            // mute beside its own plan card.
            //
            // We hard-coerce a warm intro when the model gave us a card
            // but failed to give us a real message. 60 grapheme clusters
            // is the bar — that's roughly "a sentence + a pointer". Any
            // shorter and the bubble doesn't carry the Captain's voice
            // properly. We also reject the known parser-fallback strings
            // even when they exceed the length threshold, because they
            // are coaching-content-free.
            let warmFallback: String? = {
                guard reply.workoutPlan != nil || reply.mealPlan != nil else { return nil }
                let trimmed = reply.message
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let isTooShort = trimmed.count < 60
                let isParserFallback = trimmed.hasPrefix("عذراً، صار خلل")
                    || trimmed.hasPrefix("Sorry, something went wrong")
                    || trimmed.hasPrefix("صار خلل بسيط")
                    || trimmed.hasPrefix("Captain hit a small issue")
                guard isTooShort || isParserFallback else { return nil }
                if reply.workoutPlan != nil {
                    return AppSettingsStore.shared.appLanguage == .english
                        ? "Locked in, champ — your plan is ready in the card below. Open it and let's go, knee-safe and dialed in."
                        : "تدلل يا بطل، رتبتلك خطة قوية ومراعية لركبتك بالكرت تحت. افتحها وابدأ، صوّب على الأداء الصحيح ولا تشد على الركبة."
                }
                return AppSettingsStore.shared.appLanguage == .english
                    ? "Done — your meal plan is in the card below. Tap it for the full breakdown and timing."
                    : "جاهز — خطة الأكل بالكرت تحت. افتحها وشوف الوجبات والتوقيت كامل."
            }()

            // Validate and clean the reply before displaying:
            // 1. Remove duplicate sentences
            // 2. Trigger fallback if English ratio is too high in Arabic mode
            let baseMessage = warmFallback ?? cleanAssistantReplyMessage(reply.message)
            let validated = validateResponse(
                CaptainStructuredResponse(
                    message: baseMessage,
                    quickReplies: reply.quickReplies,
                    workoutPlan: reply.workoutPlan,
                    mealPlan: reply.mealPlan,
                    spotifyRecommendation: reply.spotifyRecommendation
                ),
                screenContext: screenContext
            )

            currentWorkoutPlan = validated.workoutPlan
            currentMealPlan = validated.mealPlan
            quickReplies = screenContext == .sleepAnalysis ? [] : (validated.quickReplies ?? [])

            let userText = messages.last(where: { $0.isUser })?.text ?? ""

            // Fact-guard: never let the Captain state a health number that
            // contradicts today's real HealthKit snapshot. Pure, deterministic,
            // conservative — only grossly-wrong figures are rewritten; rounding
            // and other-day references are left untouched. `contextData` carries
            // the same live metrics injected into the prompt's bio-state layer.
            let guardedReply = CaptainFactGuard().corrected(
                validated.message,
                facts: CaptainFactGuard.Facts(
                    steps: contextData.steps,
                    activeCalories: contextData.calories,
                    heartRate: contextData.heartRate
                )
            ).message

            let assistantReply = Self.markIfTruncated(
                assistantReply: guardedReply,
                truncatedAtMaxTokens: reply.truncatedAtMaxTokens
            )

            let replyMessage = ChatMessage(
                text: assistantReply,
                isUser: false,
                spotifyRecommendation: validated.spotifyRecommendation
            )

            if useStreaming, streamingMessageID == streamID {
                // Live tokens already revealed the reply in real time. Swap the
                // raw streamed preview for the validated final text and commit
                // in one mutation — no second client-side reveal.
                streamingText = replyMessage.text
                appendFinal(replyMessage, requestID: requestID)
            } else {
                await revealReply(replyMessage, requestID: requestID)
            }

            persistChatMessage(replyMessage)
            ConversationThreadManager.shared.logCaptainResponse(content: assistantReply)
            trimInMemoryMessagesIfNeeded()

            // Turn the model's explicit "remember this" / "remind me at X"
            // intents into real, visible side effects (Saved Memories row +
            // a scheduled local notification). Without this the Captain only
            // *claims* it saved/scheduled — the bug behind this feature.
            if reply.savedMemory != nil || reply.reminder != nil {
                await CaptainMemoryActionHandler.apply(
                    savedMemory: reply.savedMemory,
                    reminder: reply.reminder,
                    language: prebuiltLanguage
                )
            }

            let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            AnalyticsService.shared.track(.captainResponseReceived(latencyMs: latencyMs))
            if reply.truncatedAtMaxTokens {
                AnalyticsService.shared.track(.captainResponseTruncated(screen: screenContext.rawValue))
            }

            // استخراج الذكريات بالخلفية
            messageCount += 1
            let count = messageCount
            Task.detached(priority: .utility) {
                await MemoryExtractor.extract(
                    userMessage: userText,
                    assistantReply: assistantReply,
                    store: MemoryStore.shared,
                    messageCount: count
                )
            }
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestID == requestID else { return }
            AnalyticsService.shared.track(.captainResponseFailed(error: String(describing: error)))
            #if DEBUG
            print("CaptainViewModel hybrid brain error:", error)
            #endif
            let errorMessage = ChatMessage(
                text: fallbackMessage(for: error, screenContext: screenContext),
                isUser: false,
                spotifyRecommendation: fallbackSpotifyRecommendation(for: screenContext)
            )
            messages.append(errorMessage)
            persistChatMessage(errorMessage)
        }
    }

    /// Races `operation` against a strict deadline. Throws `CaptainProcessingTimeoutError` if the deadline is exceeded.
    private func withGlobalTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CaptainProcessingTimeoutError()
            }

            guard let result = try await group.next() else {
                throw CaptainProcessingTimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    private func consumeMorningHabitInsightIfNeeded() async {
        guard let insight = await morningHabitOrchestrator.consumeEphemeralInsightIfNeeded() else { return }
        appendMorningHabitInsightIfNeeded(insight)
    }

    private func appendMorningHabitInsightIfNeeded(_ insight: MorningHabitOrchestrator.MorningInsight) {
        if let index = messages.firstIndex(where: { $0.isEphemeral }) {
            messages[index].text = prependUserNameIfNeeded(to: insight.message)
            messages[index].isRead = insight.isRead
            messages[index].accessory = .morningGratitude
            return
        }

        messages.append(
            ChatMessage(
                text: prependUserNameIfNeeded(to: insight.message),
                isUser: false,
                isEphemeral: true,
                isRead: insight.isRead,
                accessory: .morningGratitude
            )
        )
    }

    /// حذف الرسائل القديمة من الذاكرة إذا تجاوزنا الحد — SwiftData يحفظ الكل
    private func trimInMemoryMessagesIfNeeded() {
        guard messages.count > Self.maxInMemoryMessages else { return }
        let excess = messages.count - Self.maxInMemoryMessages
        // Fold the about-to-be-evicted head into the rolling digest FIRST, so
        // nothing is lost when it leaves RAM — the Captain keeps the whole
        // session's context (as faithful compacted state) even past the
        // in-memory cap. SwiftData still holds the full verbatim transcript.
        let evicted = Array(messages.prefix(excess))
        sessionDigest = ConversationCompactor.compact(droppedMessages: evicted, priorDigest: sessionDigest)
        messages.removeFirst(excess)
    }

    /// Verbatim window: at most `maxConversationWindow` messages, AND bounded by
    /// a character budget so a few very long turns can't blow past the model's
    /// context. Stays comfortably above the PrivacySanitizer cloud cap of 16
    /// messages by design — see PrivacySanitizer.maxConversationMessages.
    /// Everything OLDER than this window is preserved by `ConversationDigest`.
    private static let maxConversationWindow = 24
    /// Never compact below this many recent messages, even if they're long —
    /// the immediate thread must always be verbatim.
    private static let minLiveWindow = 8
    /// Char budget for the verbatim window (~3–4k Arabic tokens). The digest
    /// carries the rest losslessly, so trimming here costs no continuity.
    private static let liveWindowCharBudget = 9000

    /// Index in `messages` where the verbatim window begins. Walks newest →
    /// oldest, keeping turns until the message-count cap or (past the floor) the
    /// char budget would be exceeded. `messages[start...]` is the live window;
    /// `messages[0..<start]` is the head that gets compacted into the digest.
    private func liveWindowStartIndex() -> Int {
        guard !messages.isEmpty else { return 0 }
        var count = 0
        var chars = 0
        var startIndex = messages.count
        for i in stride(from: messages.count - 1, through: 0, by: -1) {
            // UI-only system notes are not turns — never count toward the window.
            if messages[i].isSystemNote { continue }
            let nextCount = count + 1
            let nextChars = chars + messages[i].text.count
            if nextCount > Self.maxConversationWindow { break }
            if nextCount > Self.minLiveWindow && nextChars > Self.liveWindowCharBudget { break }
            count = nextCount
            chars = nextChars
            startIndex = i
        }
        return startIndex
    }

    private func buildConversationHistory() -> [CaptainConversationMessage] {
        let start = liveWindowStartIndex()
        guard start < messages.count else { return [] }
        return messages[start...].compactMap { message in
            guard !message.isSystemNote else { return nil }
            let trimmedText = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            return CaptainConversationMessage(
                role: message.isUser ? .user : .assistant,
                content: trimmedText
            )
        }
    }

    /// Faithful, structured digest of the conversation OUTSIDE the verbatim
    /// window. Merges `sessionDigest` (the part already evicted from RAM by the
    /// 80-message cap) with the in-RAM pre-window head, so coverage is complete
    /// with zero loss no matter how long the session runs. Deterministic and
    /// extractive — see [[ConversationCompactor]] — so it can't introduce a
    /// fact the user/Captain never said. `.empty` (renders nil) for short chats.
    private func buildConversationDigest() -> ConversationDigest {
        let start = liveWindowStartIndex()
        let head = start > 0 ? Array(messages[0..<start]) : []
        guard !head.isEmpty || !sessionDigest.isEmpty else { return .empty }
        return ConversationCompactor.compact(droppedMessages: head, priorDigest: sessionDigest)
    }

    /// Inserts a single, soft "earlier chat folded into memory" marker at the
    /// seam the first time the session grows past the verbatim window. Purely
    /// cosmetic continuity reassurance — never persisted, never sent to the
    /// model (the window/digest builders skip `isSystemNote`). Placed right
    /// before the message the user just sent so it reads as a gentle divider.
    private func maybeInsertCompactionNote() {
        guard !didInsertCompactionNote, liveWindowStartIndex() > 0 else { return }
        didInsertCompactionNote = true

        let text = AppSettingsStore.shared.appLanguage == .english
            ? "Earlier chat folded into memory"
            : "طويت بداية محادثتنا بذاكرتي حتى أبقى متذكّر كل شي"
        let note = ChatMessage(text: text, isUser: false, isSystemNote: true)

        let insertAt = max(0, messages.count - 1)
        withAnimation(.easeOut(duration: 0.35)) {
            messages.insert(note, at: insertAt)
        }
    }

    /// Progressively reveals the reply (WhatsApp/ChatGPT-style) instead of
    /// dumping a wall of text after a long blank wait. Only `streamingText`
    /// publishes per tick — `messages` is appended exactly once at the end so
    /// the list never re-diffs mid-reveal. Bounded so even a very long reply
    /// finishes within ~0.65s (snappy, not a slow crawl). Honors Reduce Motion.
    private func revealReply(_ message: ChatMessage, requestID: UUID) async {
        let full = message.text
        guard !UIAccessibility.isReduceMotionEnabled, full.count > 12 else {
            appendFinal(message, requestID: requestID)
            return
        }

        streamingMessageID = message.id
        streamingText = ""

        let total = full.count
        let steps = min(max(total, 1), 40)
        let chunk = max(1, Int((Double(total) / Double(steps)).rounded(.up)))

        var idx = full.startIndex
        while idx < full.endIndex {
            do {
                try ensureActiveRequest(requestID)
            } catch {
                // A newer request now owns the screen — drop the half-revealed
                // bubble and bail without committing it to `messages`.
                streamingMessageID = nil
                streamingText = ""
                return
            }
            let end = full.index(idx, offsetBy: chunk, limitedBy: full.endIndex) ?? full.endIndex
            streamingText.append(contentsOf: full[idx..<end])
            idx = end
            try? await Task.sleep(nanoseconds: 16_000_000)
        }

        appendFinal(message, requestID: requestID)
    }

    /// Commits the finalized row and clears the live bubble in ONE synchronous
    /// mutation so SwiftUI coalesces them into a single render — the real row
    /// appears exactly as the streaming bubble is removed (same text, same
    /// position) → seamless, no flicker.
    private func appendFinal(_ message: ChatMessage, requestID: UUID) {
        guard activeRequestID == requestID else {
            streamingMessageID = nil
            streamingText = ""
            return
        }
        messages.append(message)
        streamingMessageID = nil
        streamingText = ""
        HapticEngine.light()
    }

    /// Applies one live streaming-preview frame to the bound bubble. The cloud
    /// streaming path calls this (via a `@Sendable` closure) for each token
    /// batch; it hops onto the VM's MainActor isolation here. The first frame
    /// binds the bubble identity and flips the coach to `.typing`; stale frames
    /// from a superseded request are dropped.
    private func applyStreamingPreview(_ preview: String, streamID: UUID, requestID: UUID) {
        guard activeRequestID == requestID else { return }
        if streamingMessageID != streamID {
            streamingMessageID = streamID
            coachState = .typing
        }
        streamingText = preview
    }

    private func persistChatMessage(_ message: ChatMessage) {
        let sessionID = currentSessionID
        MemoryStore.shared.persistMessageAsync(message, sessionID: sessionID)
    }

    private func ensureActiveRequest(_ requestID: UUID) throws {
        try Task.checkCancellation()
        guard activeRequestID == requestID else {
            throw CancellationError()
        }
    }

    private func fallbackMessage(
        for error: Error,
        screenContext: ScreenContext
    ) -> String {
        if let brainError = error as? BrainError,
           case .tierRequired(let tier) = brainError {
            return localizedFallbackMessage(
                arabic: "هاي الميزة تحتاج \(tier.displayName).",
                english: "This feature requires \(tier.displayName)."
            )
        }

        // Handle AiQoError rate-limit and server errors
        if let aiqoError = error as? AiQoError {
            switch aiqoError {
            case .captainRateLimited, .serverError(statusCode: 429):
                return localizedFallbackMessage(
                    arabic: NSLocalizedString("captain.error.rateLimited", value: "الكابتن مشغول شوي، جرّب بعد ثواني", comment: "Rate limit 429 error"),
                    english: "Captain is a bit busy, try again in a few seconds."
                )
            case .serverError(statusCode: 503):
                return localizedFallbackMessage(
                    arabic: NSLocalizedString("captain.error.serviceUnavailable", value: "السيرفر يحتاج استراحة، جرّب بعد شوي", comment: "Service unavailable 503 error"),
                    english: "The server needs a break, try again shortly."
                )
            default:
                break
            }
        }

        if error is CaptainProcessingTimeoutError {
            if screenContext == .myVibe {
                return localizedFallbackMessage(
                    arabic: "الرد أخذ وقت أطول من المتوقع، فحطيتلك فايب احتياطي حتى ما ينقطع المود.",
                    english: "The reply took longer than expected, so I queued a fallback vibe to keep the mood going."
                )
            }
            return localizedFallbackMessage(
                arabic: "الرد أخذ وقت أطول من المتوقع. جرّب مرة ثانية.",
                english: "The reply took longer than expected. Try again."
            )
        }

        if let consentError = error as? AIDataConsentError,
           case .consentRequired = consentError {
            return localizedFallbackMessage(
                arabic: NSLocalizedString(
                    "ai.consent.blocked.message",
                    value: "يلزمك توافق على مشاركة بيانات الذكاء الاصطناعي حتى تستخدم الميزات السحابية داخل AiQo.",
                    comment: "AI consent required fallback"
                ),
                english: "You need to agree to AiQo's AI data use disclosure before cloud AI features can run."
            )
        }

        if let serviceError = error as? LocalBrainServiceError {
            switch serviceError {
            case .invalidStructuredResponse:
                if screenContext == .myVibe {
                    return localizedFallbackMessage(
                        arabic: "الرد المحلي طلع بصيغة مو مستقرة، فحطيتلك فايب احتياطي تقدر تفتحه مباشرة.",
                        english: "The on-device reply came back unstable, so I dropped in a fallback vibe you can open right now."
                    )
                }
                return localizedFallbackMessage(
                    arabic: "الرد المحلي طلع بصيغة غير متوقعة. جرّب مرة ثانية.",
                    english: "The on-device reply came back in an unexpected format. Try again."
                )
            case .onDeviceTimeout:
                return localizedFallbackMessage(
                    arabic: "المحرك المحلي أخذ وقت أطول من المتوقع. جرّب مرة ثانية.",
                    english: "The on-device model took longer than expected. Try again."
                )
            case .missingUserMessage, .emptyConversation:
                return localizedFallbackMessage(
                    arabic: "أرسللي رسالة أوضح حتى أرتبلك الرد صح.",
                    english: "Send a clearer message so I can shape the local reply correctly."
                )
            }
        }

        if let hybridError = error as? HybridBrainServiceError {
            switch hybridError {
            case .invalidStructuredResponse:
                if screenContext == .myVibe {
                    return localizedFallbackMessage(
                        arabic: "رد السحابة رجع بصيغة مو صالحة، ففعّلتلك بلايليست احتياطية حتى ما ينقطع المود.",
                        english: "The cloud reply came back malformed, so I activated a fallback playlist to keep the vibe moving."
                    )
                }
                return localizedFallbackMessage(
                    arabic: "رد السحابة رجع بصيغة غير صالحة للواجهة. جرّب مرة ثانية.",
                    english: "The cloud reply came back in an invalid format. Try again."
                )
            case .networkUnavailable, .requestFailed:
                if screenContext == .myVibe {
                    return localizedFallbackMessage(
                        arabic: "الاتصال بالسحابة مو ثابت هسه، فرتبتلك فايب احتياطي من سبوتفاي لحد ما يرجع الاتصال.",
                        english: "The cloud connection is unstable right now, so I queued a Spotify fallback vibe until the network settles."
                    )
                }
                return localizedFallbackMessage(
                    arabic: "الاتصال بالسحابة مو ثابت هسه. جرّب مرة ثانية.",
                    english: "The cloud connection is unstable right now. Try again."
                )
            case .badStatusCode(429):
                return localizedFallbackMessage(
                    arabic: NSLocalizedString("captain.error.rateLimited", value: "الكابتن مشغول شوي، جرّب بعد ثواني", comment: "Rate limit 429 error"),
                    english: "Captain is a bit busy, try again in a few seconds."
                )
            case .badStatusCode(503):
                return localizedFallbackMessage(
                    arabic: NSLocalizedString("captain.error.serviceUnavailable", value: "السيرفر يحتاج استراحة، جرّب بعد شوي", comment: "Service unavailable 503 error"),
                    english: "The server needs a break, try again shortly."
                )
            case .badStatusCode, .invalidResponse, .emptyResponse, .emptyConversation,
                 .missingUserMessage, .missingAPIKey, .invalidEndpoint:
                break
            }
        }

        if let sleepStageError = error as? SleepStageFetchError {
            switch sleepStageError {
            case .authorizationDenied:
                return localizedFallbackMessage(
                    arabic: "حتى أطلعلك تحليل نوم محلي، فعّل صلاحية النوم من Health وبعدها جرّب مرة ثانية.",
                    english: "Enable sleep access in Health first, then try the local sleep analysis again."
                )
            case .healthDataUnavailable, .sleepAnalysisUnavailable:
                return morningSleepFallbackMessage()
            }
        }

        if screenContext == .myVibe {
            return localizedFallbackMessage(
                arabic: "صار خلل بسيط بمخ الدي جي، فحطيتلك فايب احتياطي يشتغل مباشرة.",
                english: "DJ Hamoudi hit a small issue, so I added a fallback vibe you can open immediately."
            )
        }

        return localizedFallbackMessage(
            arabic: "صار خلل بسيط بمخ الكابتن يا بطل. جرّب مرة ثانية.",
            english: "Captain hit a small issue. Try again."
        )
    }

    private func fallbackSpotifyRecommendation(for screenContext: ScreenContext) -> SpotifyRecommendation? {
        guard screenContext == .myVibe else { return nil }

        let latestUserMessage = messages.last(where: { $0.isUser })?.text ?? ""
        return SpotifyRecommendation.myVibeFallback(
            for: latestUserMessage,
            language: AppSettingsStore.shared.appLanguage
        )
    }

    private func localizedFallbackMessage(arabic: String, english: String) -> String {
        AppSettingsStore.shared.appLanguage == .english ? english : arabic
    }

    private func cleanAssistantReplyMessage(_ rawReply: String) -> String {
        let fallback = localizedFallbackMessage(
            arabic: "عذراً، صار خلل بالاتصال، تكدر تعيد كلامك؟",
            english: "Sorry, something went wrong with the connection. Could you say that again?"
        )

        let parsed = replyJSONParser.cleanDisplayText(from: rawReply, fallback: fallback)
        return Self.stripInlineMedicalDisclaimerTail(parsed)
    }

    /// v1.1 Apple rejection fix: the persistent `CaptainSafetyBanner` above
    /// the chat now carries the wellness/medical framing, so any trailing
    /// disclaimer sentence leaking into a bubble is redundant. Strip it here
    /// as a backstop in case an older cached prompt or remote config still
    /// instructs the LLM to emit it.
    nonisolated static func stripInlineMedicalDisclaimerTail(_ text: String) -> String {
        let patterns: [String] = [
            #"(?i)\n?⚕️?\s*This is educational info[^\n]*"#,
            #"(?i)\n?⚕️?\s*هذي معلومات تثقيفية[^\n]*"#,
            #"(?i)\n?⚕️?\s*استشر طبيب[^\n]*"#,
            #"(?i)\n?⚕️?\s*consult (your )?doctor[^\n]*"#
        ]
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Appends a single ellipsis to a reply that Gemini cut off at
    /// `MAX_TOKENS`, but only when the existing tail is not already a
    /// terminal-punctuation sequence. Keeps a quiet visual hint without
    /// double-punctuating well-formed (but coincidentally truncated) replies.
    /// The retry/continue UX is intentionally deferred — see fix prompt.
    nonisolated static func markIfTruncated(
        assistantReply: String,
        truncatedAtMaxTokens: Bool
    ) -> String {
        guard truncatedAtMaxTokens else { return assistantReply }
        let trimmed = assistantReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return assistantReply }
        let terminalSuffixes: [String] = [".", "؟", "!", "…", ".\""]
        if terminalSuffixes.contains(where: { trimmed.hasSuffix($0) }) {
            return trimmed
        }
        return "\(trimmed)…"
    }

    private func prependUserNameIfNeeded(to reply: String) -> String {
        guard let userName = captainReplyUserName() else { return reply }
        guard containsArabicCharacters(in: userName) else { return reply }
        guard !hasUserNamePrefix(reply, userName: userName) else { return reply }
        return "\(userName)، \(reply)"
    }

    /// True when the user is on the FREE, on-device Captain (no `captainChat`
    /// entitlement). Drives the UI upgrade nudge. Reading `effectiveTier` ties
    /// SwiftUI re-evaluation to entitlement changes (the nudge vanishes the
    /// instant the user subscribes).
    var isFreeCaptain: Bool {
        _ = effectiveTier
        return !DevOverride.unlockAllFeatures && !TierGate.shared.canAccess(.captainChat)
    }

    /// Paid Captain (Max or higher, or dev unlock) — may customize the
    /// Captain's personality preset.
    var isPaidCaptain: Bool { !isFreeCaptain }

    /// Pro Captain — additionally unlocks the free-text custom persona.
    var isProCaptain: Bool {
        _ = effectiveTier
        return DevOverride.unlockAllFeatures || effectiveTier == .pro
    }

    /// Persona snapshot for the free on-device Captain — name only. Free tier has
    /// NO style customization (that's a Max/Pro feature); the Captain just
    /// addresses the user warmly in one simple fixed voice.
    private func onDevicePersona() -> CaptainOnDeviceChatEngine.Persona {
        CaptainOnDeviceChatEngine.Persona(userName: captainReplyUserName())
    }

    private func captainReplyUserName() -> String? {
        let profile = UserProfileStore.shared.current
        let candidates = [
            customization.calling,
            customization.name,
            profile.name,
            profile.username
        ]

        for candidate in candidates {
            guard let rawCandidate = candidate else { continue }
            var normalized = rawCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.hasPrefix("@") {
                normalized.removeFirst()
                normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if normalized.isEmpty { continue }

            let lowered = normalized.lowercased()
            if lowered == "captain" || lowered == "kaptain" {
                continue
            }

            return normalized
        }

        return nil
    }

    private func hasUserNamePrefix(_ reply: String, userName: String) -> Bool {
        let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let loweredName = userName.lowercased()
        let prefixTokens = ["،", ",", ":", " "]

        for token in prefixTokens where trimmedReply.hasPrefix(loweredName + token) {
            return true
        }

        return false
    }

    private func containsArabicCharacters(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }

    private func morningSleepFallbackMessage() -> String {
        localizedFallbackMessage(
            arabic: "صباح الخير. ما قدرت أقرأ تفاصيل نوم البارحة بالكامل، بس خذ بداية هادئة اليوم: مي، ضوء طبيعي، ومشي خفيف.",
            english: "Good morning. I could not fully read last night's sleep details, so start gently today with water, natural light, and an easy walk."
        )
    }

}

private extension CaptainViewModel {
    static func preparedImageData(from image: UIImage?) -> Data? {
        guard let image else { return nil }
        return image.jpegData(compressionQuality: 0.74) ?? image.pngData()
    }

    /// Quick heuristic to detect sleep analysis requests so the global timeout can be extended.
    /// Mirrors BrainOrchestrator's sleep detection patterns without needing access to the private extension.
    func looksLikeSleepRequest(_ text: String) -> Bool {
        let lowered = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let sleepKeywords = [
            "حلل", "نوم", "نمت", "نومي",
            "sleep", "slept", "analyze sleep", "sleep analysis",
            "deep sleep", "rem"
        ]
        return sleepKeywords.contains { lowered.contains($0) }
    }

    /// Post-processes a structured response before it reaches the UI.
    /// 1. Removes duplicate sentences within the message.
    /// 2. Falls back to a generic Arabic reply if the English character ratio is too high in Arabic mode.
    func validateResponse(
        _ response: CaptainStructuredResponse,
        screenContext: ScreenContext
    ) -> CaptainStructuredResponse {
        var message = response.message

        // 1. Remove duplicate sentences (split on common Arabic/Latin sentence terminators)
        let separators = CharacterSet(charactersIn: ".،؟!\n")
        let sentences = message
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 3 } // ignore trivial fragments

        var seen = Set<String>()
        var unique: [String] = []
        for sentence in sentences {
            let normalized = sentence
                .lowercased()
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(normalized).inserted else { continue }
            unique.append(sentence)
        }

        // Rebuild only when we actually removed something
        if unique.count < sentences.count, !unique.isEmpty {
            message = unique.joined(separator: ".")
        }

        // 2. Language ratio guard — Arabic mode only
        if AppSettingsStore.shared.appLanguage == .arabic {
            let ratio = Self.englishCharRatio(in: message)
            if ratio > 0.4 {
                #if DEBUG
                print("⚠️ CaptainViewModel.validateResponse — English ratio \(String(format: "%.0f", ratio * 100))% in Arabic mode. Triggering generic fallback.")
                #endif
                if screenContext == .sleepAnalysis {
                    return CaptainStructuredResponse(
                        message: localizedFallbackMessage(
                            arabic: "ما طلع تحليل النوم مضبوط هالمرة. أعدها حتى أطلعلك حكم أوضح على نومك.",
                            english: "The sleep analysis did not come back cleanly this time. Try again and I will give you a clearer read."
                        ),
                        quickReplies: nil,
                        workoutPlan: nil,
                        mealPlan: nil,
                        spotifyRecommendation: nil
                    )
                }

                return CaptainStructuredResponse(
                    message: CaptainFallbackPolicy.genericArabicFallback(),
                    quickReplies: ["شنو هدفك اليوم؟", "حلل نومي", "سوّيلي وجبة"],
                    workoutPlan: nil,
                    mealPlan: nil,
                    // Preserve a Spotify card if present — it's structured data, not language content
                    spotifyRecommendation: response.spotifyRecommendation
                )
            }
        }

        // Return original if nothing changed
        if message == response.message {
            return response
        }

        return CaptainStructuredResponse(
            message: message,
            quickReplies: response.quickReplies,
            workoutPlan: response.workoutPlan,
            mealPlan: response.mealPlan,
            spotifyRecommendation: response.spotifyRecommendation
        )
    }

    /// Returns the fraction of non-whitespace characters that are ASCII Latin letters (a-z, A-Z).
    /// Used to detect English leakage in Arabic-mode responses.
    static func englishCharRatio(in text: String) -> Double {
        let nonWhitespace = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        let total = nonWhitespace.count
        guard total > 0 else { return 0 }
        let english = nonWhitespace.filter { $0.value >= 0x41 && $0.value <= 0x7A }.count
        return Double(english) / Double(total)
    }
}
