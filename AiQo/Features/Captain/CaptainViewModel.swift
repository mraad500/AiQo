import Foundation
import SwiftUI
import UIKit
internal import Combine

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
    var accessory: ChatMessageAccessory?

    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false,
        isEphemeral: Bool = false,
        accessory: ChatMessageAccessory? = nil
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.isAnimating = isAnimating
        self.isEphemeral = isEphemeral
        self.accessory = accessory
    }

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false,
        isEphemeral: Bool = false,
        accessory: ChatMessageAccessory? = nil
    ) {
        self.init(
            id: id,
            text: content,
            isUser: isUser,
            timestamp: timestamp,
            isAnimating: isAnimating,
            isEphemeral: isEphemeral,
            accessory: accessory
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
    @Published var showProfile: Bool = false
    @Published var customization: CaptainCustomization = .default
    @Published var feedbackTrigger: Int = 0

    var isSending: Bool { isLoading }
    var isTyping: Bool { isLoading }

    private let userDefaults = UserDefaults.standard
    private let service: LocalBrainService
    private let contextBuilder: CaptainContextBuilder
    private let morningRoutineManager: MorningRoutineManager
    private let healthManager = HealthKitManager.shared
    private let minimumLoadingStateDuration: TimeInterval = 0.8

    private var responseTask: Task<Void, Never>?
    private var activeRequestID: UUID?
    private var isGeneratingMorningAnalysis = false

    private enum Keys {
        static let name = "captain_user_name"
        static let age = "captain_user_age"
        static let height = "captain_user_height"
        static let weight = "captain_user_weight"
        static let calling = "captain_calling"
        static let tone = "captain_tone"
    }

    init(
        service: LocalBrainService? = nil,
        contextBuilder: CaptainContextBuilder? = nil,
        morningRoutineManager: MorningRoutineManager? = nil
    ) {
        self.service = service ?? LocalBrainService()
        self.contextBuilder = contextBuilder ?? .shared
        self.morningRoutineManager = morningRoutineManager ?? .shared
        loadCustomization()
        addWelcomeMessage()
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

    func sendMessage(_ rawText: String, context: ScreenContext = .mainChat) {
        sendMessage(text: rawText, context: context)
    }

    func sendMessage(
        text rawText: String,
        image: UIImage? = nil,
        context: ScreenContext = .mainChat
    ) {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        responseTask?.cancel()
        feedbackTrigger += 1
        inputText = ""
        messages.append(ChatMessage(text: trimmedText, isUser: true))
        isLoading = true
        coachState = .readingMessage

        let requestID = UUID()
        activeRequestID = requestID
        let hasAttachedImage = image != nil

        responseTask = Task { [weak self] in
            guard let self else { return }
            await self.processMessage(
                requestID: requestID,
                screenContext: context,
                hasAttachedImage: hasAttachedImage
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

        messages.append(ChatMessage(text: summary, isUser: false))
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
        guard !isGeneratingMorningAnalysis else { return }
        guard !messages.contains(where: { $0.isEphemeral }) else { return }
        guard morningRoutineManager.prepareMorningAnalysisIfNeeded() != nil else { return }

        responseTask?.cancel()
        isGeneratingMorningAnalysis = true
        isLoading = true
        coachState = .readingMessage
        feedbackTrigger += 1

        let requestID = UUID()
        activeRequestID = requestID

        responseTask = Task { [weak self] in
            guard let self else { return }
            await self.processMorningSleepAnalysis(requestID: requestID)
        }
    }

    func removeEphemeralMessages() {
        messages.removeAll { $0.isEphemeral }
    }

    func startMorningGratitudeSession() {
        feedbackTrigger += 1
    }

    private func addWelcomeMessage() {
        messages.append(
            ChatMessage(
                text: "هلا! أنا كابتن حمّودي. شنو هدفك اليوم؟",
                isUser: false
            )
        )
    }

    private func processMessage(
        requestID: UUID,
        screenContext: ScreenContext,
        hasAttachedImage: Bool
    ) async {
        defer {
            if activeRequestID == requestID {
                isLoading = false
                coachState = .idle
            }
        }

        let conversation = buildConversationHistory()
        let promptRequest = await buildPromptRequest(
            conversation: conversation,
            screenContext: screenContext,
            hasAttachedImage: hasAttachedImage
        )

        do {
            let startedAt = Date()
            let responseTask = Task<LocalBrainServiceReply, Error> { [service] in
                try await service.generateReply(request: promptRequest)
            }

            try await runCognitiveTimeline(requestID: requestID)
            let reply = try await responseTask.value

            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minimumLoadingStateDuration {
                let remaining = minimumLoadingStateDuration - elapsed
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            try await transitionCoachState(to: .typing, hold: 0.18, requestID: requestID)
            try ensureActiveRequest(requestID)

            currentWorkoutPlan = reply.workoutPlan
            currentMealPlan = reply.mealPlan
            messages.append(
                ChatMessage(
                    text: prependUserNameIfNeeded(to: reply.message),
                    isUser: false
                )
            )
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestID == requestID else { return }
            print("CaptainViewModel local brain error:", error)
            messages.append(
                ChatMessage(
                    text: prependUserNameIfNeeded(to: fallbackMessage(for: error)),
                    isUser: false
                )
            )
        }
    }

    private func processMorningSleepAnalysis(requestID: UUID) async {
        defer {
            if activeRequestID == requestID {
                isLoading = false
                coachState = .idle
            }
            isGeneratingMorningAnalysis = false
        }

        do {
            let promptRequest = try await buildMorningSleepRequest()
            let startedAt = Date()
            let localReplyTask = Task<LocalBrainServiceReply, Error> { [service] in
                try await service.generateReply(request: promptRequest)
            }

            try await runCognitiveTimeline(requestID: requestID)
            let reply = try await localReplyTask.value

            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minimumLoadingStateDuration {
                let remaining = minimumLoadingStateDuration - elapsed
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            try await transitionCoachState(to: .typing, hold: 0.18, requestID: requestID)
            try ensureActiveRequest(requestID)

            currentWorkoutPlan = reply.workoutPlan
            currentMealPlan = reply.mealPlan
            messages.removeAll { $0.isEphemeral }
            messages.append(
                ChatMessage(
                    text: prependUserNameIfNeeded(to: reply.message),
                    isUser: false,
                    isEphemeral: true,
                    accessory: .morningGratitude
                )
            )
            morningRoutineManager.markMorningMessageRead()
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestID == requestID else { return }
            print("CaptainViewModel morning sleep analysis error:", error)

            currentWorkoutPlan = nil
            currentMealPlan = nil
            messages.removeAll { $0.isEphemeral }
            messages.append(
                ChatMessage(
                    text: morningSleepFallbackMessage(),
                    isUser: false,
                    isEphemeral: true,
                    accessory: .morningGratitude
                )
            )
            morningRoutineManager.markMorningMessageRead()
        }
    }

    private func buildConversationHistory() -> [CaptainConversationMessage] {
        messages.compactMap { message in
            let trimmedText = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            return CaptainConversationMessage(
                role: message.isUser ? .user : .assistant,
                content: trimmedText
            )
        }
    }

    private func buildPromptRequest(
        conversation: [CaptainConversationMessage],
        screenContext: ScreenContext,
        hasAttachedImage: Bool
    ) async -> LocalBrainRequest {
        let contextData = await contextBuilder.buildContextData()
        let language = AppSettingsStore.shared.appLanguage
        let profileSummary = buildUserProfileSummary()
        let router = PromptRouter(language: language)
        let systemPrompt = router.generateSystemPrompt(for: screenContext, data: contextData)

        return LocalBrainRequest(
            conversation: conversation,
            screenContext: screenContext,
            language: language,
            systemPrompt: systemPrompt,
            contextData: contextData,
            userProfileSummary: profileSummary,
            hasAttachedImage: hasAttachedImage
        )
    }

    private func buildMorningSleepRequest() async throws -> LocalBrainRequest {
        let contextData = await contextBuilder.buildContextData()
        let language = AppSettingsStore.shared.appLanguage
        let router = PromptRouter(language: language)
        let systemPrompt = router.generateSystemPrompt(for: .sleepAnalysis, data: contextData)
        let summaryPrompt = try await buildMorningSleepSummaryPrompt(language: language)

        return LocalBrainRequest(
            conversation: [
                CaptainConversationMessage(role: .user, content: summaryPrompt)
            ],
            screenContext: .sleepAnalysis,
            language: language,
            systemPrompt: systemPrompt,
            contextData: contextData,
            userProfileSummary: buildUserProfileSummary(),
            hasAttachedImage: false
        )
    }

    private func buildUserProfileSummary() -> String {
        let profile = UserProfileStore.shared.current
        let preferredName = captainReplyUserName() ?? "not provided"

        return """
        - Preferred name: \(preferredName)
        - Profile name: \(summaryValue(profile.name))
        - Username: \(summaryValue(profile.username))
        - Age: \(summaryValue(customization.age))
        - Height cm: \(summaryValue(customization.height))
        - Weight kg: \(summaryValue(customization.weight))
        - Preferred tone: \(customization.tone.rawValue)
        """
    }

    private func summaryValue(_ value: String?) -> String {
        guard let value else { return "not provided" }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "not provided" : trimmed
    }

    private func buildMorningSleepSummaryPrompt(language: AppLanguage) async throws -> String {
        let authorized = try await healthManager.requestSleepAuthorizationIfNeeded()
        guard authorized else {
            throw SleepStageFetchError.authorizationDenied
        }

        let stages = try await healthManager.fetchSleepStagesForLastNight()
        guard let sleepStart = stages.first?.startDate,
              let sleepEnd = stages.last?.endDate,
              !stages.isEmpty else {
            throw MorningSleepAnalysisError.noSleepData
        }

        let totalSleep = stages
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
        let deepSleep = totalDuration(for: .deep, in: stages)
        let remSleep = totalDuration(for: .rem, in: stages)
        let coreSleep = totalDuration(for: .core, in: stages)
        let awakeTime = totalDuration(for: .awake, in: stages)

        return """
        MORNING_SLEEP_ANALYSIS
        SleepStart: \(formattedClockTime(sleepStart))
        SleepEnd: \(formattedClockTime(sleepEnd))
        TotalSleepHours: \(formattedHours(totalSleep))
        DeepSleepHours: \(formattedHours(deepSleep))
        REMSleepHours: \(formattedHours(remSleep))
        CoreSleepHours: \(formattedHours(coreSleep))
        AwakeMinutes: \(Int((awakeTime / 60).rounded()))
        OutputLanguage: \(language == .english ? "English" : "Arabic (Iraqi dialect)")
        Instruction: Give one brief, friendly morning sleep analysis and one gentle suggestion.
        """
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

    private func fallbackMessage(for error: Error) -> String {
        if let serviceError = error as? LocalBrainServiceError {
            switch serviceError {
            case .invalidStructuredResponse:
                return localizedFallbackMessage(
                    arabic: "الرد المحلي طلع بصيغة غير متوقعة. جرّب مرة ثانية.",
                    english: "The on-device reply came back in an unexpected format. Try again."
                )
            case .missingUserMessage, .emptyConversation:
                return localizedFallbackMessage(
                    arabic: "أرسللي رسالة أوضح حتى أرتبلك الرد صح.",
                    english: "Send a clearer message so I can shape the local reply correctly."
                )
            }
        }

        return localizedFallbackMessage(
            arabic: "صار خلل بسيط بالمخ المحلي يا بطل. جرّب مرة ثانية.",
            english: "Captain's local brain hit a small issue. Try again."
        )
    }

    private func localizedFallbackMessage(arabic: String, english: String) -> String {
        AppSettingsStore.shared.appLanguage == .english ? english : arabic
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

    private func totalDuration(
        for stage: SleepStageData.Stage,
        in stages: [SleepStageData]
    ) -> TimeInterval {
        stages
            .filter { $0.stage == stage }
            .reduce(0) { $0 + $1.duration }
    }

    private func formattedHours(_ duration: TimeInterval) -> String {
        String(format: "%.1f", duration / 3_600)
    }

    private func formattedClockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func morningSleepFallbackMessage() -> String {
        localizedFallbackMessage(
            arabic: "صباح الخير. ما قدرت أقرأ تفاصيل نوم البارحة بالكامل، بس خذ بداية هادئة اليوم: مي، ضوء طبيعي، ومشي خفيف.",
            english: "Good morning. I could not fully read last night's sleep details, so start gently today with water, natural light, and an easy walk."
        )
    }

}

private enum MorningSleepAnalysisError: LocalizedError {
    case noSleepData

    var errorDescription: String? {
        switch self {
        case .noSleepData:
            return "No sleep data was available for the previous night."
        }
    }
}
