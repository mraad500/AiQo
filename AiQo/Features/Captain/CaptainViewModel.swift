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

    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false,
        isEphemeral: Bool = false,
        isRead: Bool = true,
        accessory: ChatMessageAccessory? = nil,
        spotifyRecommendation: SpotifyRecommendation? = nil
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
    @Published var showCustomization: Bool = false
    @Published var showChatHistory: Bool = false
    @Published var showProfile: Bool = false
    @Published var showGratitudeSession: Bool = false
    @Published var customization: CaptainCustomization = .default
    @Published var feedbackTrigger: Int = 0
    @Published var activeModule: ScreenContext = .mainChat
    @Published var quickReplies: [String] = []

    var isSending: Bool { isLoading }
    var isTyping: Bool { isLoading }

    private let userDefaults = UserDefaults.standard
    private let orchestrator: BrainOrchestrator
    private let contextBuilder: CaptainContextBuilder
    private let cognitivePipeline: CaptainCognitivePipeline
    private let morningHabitOrchestrator: MorningHabitOrchestrator
    private let replyJSONParser = LLMJSONParser()
    private let minimumLoadingStateDuration: TimeInterval = 0.8
    private let globalProcessingTimeout: TimeInterval = 15
    /// Sleep analysis runs entirely on-device (HealthKit + Foundation Models) and needs more time.
    private let sleepProcessingTimeout: TimeInterval = 25

    /// حد أقصى للرسائل بالذاكرة — الباقي محفوظ بـ SwiftData
    private static let maxInMemoryMessages = 80

    private var responseTask: Task<Void, Never>?
    private var activeRequestID: UUID?
    private var messageCount = 0
    /// كل فتحة تطبيق = جلسة جديدة
    private(set) var currentSessionID = UUID()

    private enum Keys {
        static let name = "captain_user_name"
        static let age = "captain_user_age"
        static let height = "captain_user_height"
        static let weight = "captain_user_weight"
        static let calling = "captain_calling"
        static let tone = "captain_tone"
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
        let hasStopped = messageSteps >= stopSteps

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
            chatScrollEnabled: hasStopped
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
        guard !trimmedText.isEmpty else { return }
        guard !isLoading else { return }

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

        let requestID = UUID()
        activeRequestID = requestID
        let attachedImageData = Self.preparedImageData(from: image)

        // Capture everything needed BEFORE leaving the MainActor.
        // The heavy lifting (prompt building, sanitization, network call) runs on the
        // cooperative thread pool via Task.detached — never blocking the UI.
        let conversation = buildConversationHistory()
        let userName = captainReplyUserName()
        let language = AppSettingsStore.shared.appLanguage
        let promptContext = cognitivePipeline.buildPromptContext(
            userMessage: trimmedText,
            screenContext: context,
            customization: customization,
            preferredName: userName
        )

        responseTask = Task { [weak self] in
            guard let self else { return }
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

    func saveCustomization() {
        userDefaults.set(customization.name, forKey: Keys.name)
        userDefaults.set(customization.age, forKey: Keys.age)
        userDefaults.set(customization.height, forKey: Keys.height)
        userDefaults.set(customization.weight, forKey: Keys.weight)
        userDefaults.set(customization.calling, forKey: Keys.calling)
        userDefaults.set(customization.tone.rawValue, forKey: Keys.tone)
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

    /// يبدأ محادثة جديدة — sessionID جديد ورسالة ترحيبية
    func startNewChat() {
        currentSessionID = UUID()
        messages.removeAll()
        messageCount = 0
        currentWorkoutPlan = nil
        currentMealPlan = nil
        quickReplies = []

        let welcome = ChatMessage(
            text: NSLocalizedString("captain.welcome", value: "هلا! أنا كابتن حمّودي. شنو هدفك اليوم؟", comment: "Captain first message"),
            isUser: false
        )
        messages.append(welcome)
        // Don't persist the welcome message — the session is only persisted once the user sends their first message.
        // This prevents stale single-message sessions accumulating in SwiftData on every cold launch.
    }

    /// يحمّل جلسة قديمة — يستبدل الرسائل الحالية برسائل الجلسة المختارة
    func loadSession(_ session: ChatSession) {
        currentSessionID = session.id
        let stored = MemoryStore.shared.fetchMessages(for: session.id)
        messages = stored
        messageCount = stored.count
        currentWorkoutPlan = nil
        currentMealPlan = nil
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

        do {
            // Build HealthKit context (async but lightweight — just reads cached values)
            let contextData = await contextBuilder.buildContextData()

            let promptRequest = HybridBrainRequest(
                conversation: prebuiltConversation,
                screenContext: screenContext,
                language: prebuiltLanguage,
                contextData: contextData,
                userProfileSummary: prebuiltPromptContext.profileSummary,
                intentSummary: prebuiltPromptContext.intentSummary,
                workingMemorySummary: prebuiltPromptContext.workingMemorySummary,
                attachedImageData: attachedImageData
            )

            let startedAt = Date()
            let capturedOrchestrator = orchestrator
            // Sleep analysis runs entirely on-device (HealthKit + Foundation Models) — give it more time.
            // The orchestrator may reroute .mainChat → .sleepAnalysis internally if the message is sleep-related.
            let latestUserText = prebuiltConversation.last(where: { $0.role == .user })?.content ?? ""
            let needsSleepTimeout = screenContext == .sleepAnalysis
                || looksLikeSleepRequest(latestUserText)
            let orchestratorTimeout = needsSleepTimeout
                ? sleepProcessingTimeout
                : globalProcessingTimeout
            let reply = try await withGlobalTimeout(seconds: orchestratorTimeout) {
                try await capturedOrchestrator.processMessage(
                    request: promptRequest,
                    userName: prebuiltUserName
                )
            }

            try await runCognitiveTimeline(requestID: requestID)

            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minimumLoadingStateDuration {
                let remaining = minimumLoadingStateDuration - elapsed
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            try await transitionCoachState(to: .typing, hold: 0.18, requestID: requestID)
            try ensureActiveRequest(requestID)

            // Validate and clean the reply before displaying:
            // 1. Remove duplicate sentences
            // 2. Trigger fallback if English ratio is too high in Arabic mode
            let cleanedReplyMessage = cleanAssistantReplyMessage(reply.message)
            let validated = validateResponse(
                CaptainStructuredResponse(
                    message: cleanedReplyMessage,
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
            let assistantReply = validated.message

            let replyMessage = ChatMessage(
                text: assistantReply,
                isUser: false,
                spotifyRecommendation: validated.spotifyRecommendation
            )

            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                messages.append(replyMessage)
            }

            persistChatMessage(replyMessage)
            trimInMemoryMessagesIfNeeded()

            let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            AnalyticsService.shared.track(.captainResponseReceived(latencyMs: latencyMs))

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
        messages.removeFirst(excess)
    }

    /// آخر 20 رسالة فقط — كافية للسياق بدون تضخم الـ payload
    private static let maxConversationWindow = 20

    private func buildConversationHistory() -> [CaptainConversationMessage] {
        messages.suffix(Self.maxConversationWindow).compactMap { message in
            let trimmedText = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            return CaptainConversationMessage(
                role: message.isUser ? .user : .assistant,
                content: trimmedText
            )
        }
    }

    private func persistChatMessage(_ message: ChatMessage) {
        let sessionID = currentSessionID
        MemoryStore.shared.persistMessageAsync(message, sessionID: sessionID)
    }

    private func runCognitiveTimeline(requestID: UUID) async throws {
        try await transitionCoachState(to: .readingMessage, hold: 0.18, requestID: requestID)
        try await transitionCoachState(to: .thinkingOnDevice, hold: 0.24, requestID: requestID)
        try await transitionCoachState(to: .shapingReply, hold: 0.22, requestID: requestID)
        try ensureActiveRequest(requestID)
        coachState = .typing
    }

    private func transitionCoachState(
        to state: CoachCognitiveState,
        hold: TimeInterval,
        requestID: UUID
    ) async throws {
        try ensureActiveRequest(requestID)
        coachState = state

        let nanoseconds = UInt64(max(0, hold) * 1_000_000_000)
        if nanoseconds > 0 {
            try await Task.sleep(nanoseconds: nanoseconds)
        }

        try ensureActiveRequest(requestID)
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

        return replyJSONParser.cleanDisplayText(from: rawReply, fallback: fallback)
    }

    private func prependUserNameIfNeeded(to reply: String) -> String {
        guard let userName = captainReplyUserName() else { return reply }
        guard containsArabicCharacters(in: userName) else { return reply }
        guard !hasUserNamePrefix(reply, userName: userName) else { return reply }
        return "\(userName)، \(reply)"
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
