import Foundation
import SwiftUI
internal import Combine

/// Single chat bubble model used by the Captain conversation UI.
struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String
    let isUser: Bool
    let timestamp: Date
    var isAnimating: Bool

    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.isAnimating = isAnimating
    }

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false
    ) {
        self.init(
            id: id,
            text: content,
            isUser: isUser,
            timestamp: timestamp,
            isAnimating: isAnimating
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
    @Published var inputText: String = ""
    @Published var coachState: CoachCognitiveState = .idle
    @Published var showCustomization: Bool = false
    @Published var showProfile: Bool = false
    @Published var customization: CaptainCustomization = .default
    @Published var feedbackTrigger: Int = 0

    var isSending: Bool { isLoading }
    var isTyping: Bool { isLoading }

    private let userDefaults = UserDefaults.standard
    private let service: CaptainService
    private let contextBuilder: CaptainContextBuilder
    private let minimumLoadingStateDuration: TimeInterval = 0.8

    private var responseTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    private enum Keys {
        static let name = "captain_user_name"
        static let age = "captain_user_age"
        static let height = "captain_user_height"
        static let weight = "captain_user_weight"
        static let calling = "captain_calling"
        static let tone = "captain_tone"
    }

    init(
        service: CaptainService? = nil,
        contextBuilder: CaptainContextBuilder? = nil
    ) {
        self.service = service ?? CaptainService()
        self.contextBuilder = contextBuilder ?? .shared
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
        sendMessage(inputText)
    }

    func sendMessage(_ rawText: String) {
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

        responseTask = Task { [weak self] in
            guard let self else { return }
            await self.processMessage(requestID: requestID)
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

    private func addWelcomeMessage() {
        messages.append(
            ChatMessage(
                text: "هلا! أنا كابتن حمّودي. شنو هدفك اليوم؟",
                isUser: false
            )
        )
    }

    private func processMessage(requestID: UUID) async {
        defer {
            if activeRequestID == requestID {
                isLoading = false
                coachState = .idle
            }
        }

        let conversation = buildConversationHistory()
        let promptContext = await buildPromptContext()

        do {
            let startedAt = Date()
            let responseTask = Task<CaptainServiceReply, Error> { [service] in
                try await service.generateReply(
                    conversation: conversation,
                    context: promptContext
                )
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
            print("CaptainViewModel network error:", error)
            messages.append(
                ChatMessage(
                    text: prependUserNameIfNeeded(to: fallbackMessage(for: error)),
                    isUser: false
                )
            )
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

    private func buildPromptContext() async -> CaptainPromptContext {
        let runtime = await contextBuilder.buildSystemContext()

        return CaptainPromptContext(
            runtime: runtime,
            userProfileSummary: buildUserProfileSummary()
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
        if error is CaptainSecretsError {
            return "ثبت OPENAI_API_KEY بخطة التشغيل حتى يشتغل الكابتن مباشرة."
        }

        if let serviceError = error as? CaptainServiceError {
            switch serviceError {
            case .missingAPIKey:
                return "ثبت OPENAI_API_KEY بخطة التشغيل حتى يشتغل الكابتن مباشرة."
            case .invalidStructuredResponse:
                return "رد الكابتن وصل بصيغة غير متوقعة. جرّب مرة ثانية وبعدها أرتبها إلك."
            case .httpError:
                return "خادم الكابتن ما رد بشكل صحيح هسه. جرّب بعد شوي."
            default:
                break
            }
        }

        return "صار خلل بالشبكة يا بطل. جرّب مرة ثانية."
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
}
