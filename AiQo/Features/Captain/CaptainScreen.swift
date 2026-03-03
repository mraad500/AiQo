//
//  CaptainScreen.swift
//  AiQo - Captain Hamoudi Screen
//
//  SwiftUI Implementation + On-Device Captain Intelligence
//

import SwiftUI
internal import Combine

// MARK: - Message Model

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date
    var isAnimating: Bool

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isAnimating: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isAnimating = isAnimating
    }
}

// MARK: - User Customization Model

struct CaptainCustomization: Codable {
    var name: String
    var age: String
    var height: String
    var weight: String
    var calling: String
    var tone: CaptainTone

    static let `default` = CaptainCustomization(
        name: "",
        age: "",
        height: "",
        weight: "",
        calling: "",
        tone: .practical
    )
}

enum CaptainTone: String, Codable, CaseIterable {
    case practical = "عملي"
    case caring = "حنون"
    case strict = "صارم"

    var displayName: String {
        switch self {
        case .practical:
            return NSLocalizedString("captain.tone.practical", value: "Practical", comment: "")
        case .caring:
            return NSLocalizedString("captain.tone.caring", value: "Caring", comment: "")
        case .strict:
            return NSLocalizedString("captain.tone.strict", value: "Strict", comment: "")
        }
    }
}

enum CoachCognitiveState: Equatable {
    case idle
    case readingEnergy
    case analyzingBiometrics
    case translatingThoughts
    case typing

    var statusText: String? {
        switch self {
        case .idle:
            return nil
        case .readingEnergy:
            return "الكابتن يقرأ طاقتك"
        case .analyzingBiometrics:
            return "الكابتن يحلل المؤشرات الحيوية"
        case .translatingThoughts:
            return "الكابتن يرتب أفكاره ويترجمها"
        case .typing:
            return "الكابتن يكتب الرد"
        }
    }

    var detailText: String {
        switch self {
        case .idle:
            return "Captain ready"
        case .readingEnergy:
            return "يفهم نبرة الرسالة والطاقة"
        case .analyzingBiometrics:
            return "يراجع النوم، الحركة، والنبض"
        case .translatingThoughts:
            return "يحافظ على وعي واحد ويرتب الرد"
        case .typing:
            return "يصوغ الرد النهائي بصوت حمّودي"
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "sparkles"
        case .readingEnergy:
            return "eye.fill"
        case .analyzingBiometrics:
            return "waveform.path.ecg"
        case .translatingThoughts:
            return "character.bubble.fill"
        case .typing:
            return "ellipsis.bubble.fill"
        }
    }

    var accentColors: [Color] {
        switch self {
        case .idle:
            return [Color.white.opacity(0.18), Color.white.opacity(0.08)]
        case .readingEnergy:
            return [Color(red: 0.68, green: 0.91, blue: 0.84), Color(red: 0.43, green: 0.80, blue: 0.72)]
        case .analyzingBiometrics:
            return [Color(red: 1.00, green: 0.82, blue: 0.42), Color(red: 0.97, green: 0.62, blue: 0.35)]
        case .translatingThoughts:
            return [Color(red: 0.72, green: 0.67, blue: 0.98), Color(red: 0.53, green: 0.59, blue: 0.97)]
        case .typing:
            return [Color(red: 0.88, green: 0.77, blue: 0.53), Color(red: 0.95, green: 0.89, blue: 0.73)]
        }
    }

    var pulseScale: CGFloat {
        switch self {
        case .idle:
            return 1
        case .readingEnergy:
            return 1.24
        case .analyzingBiometrics:
            return 1.38
        case .translatingThoughts:
            return 1.5
        case .typing:
            return 1.18
        }
    }

    var rotationDuration: Double {
        switch self {
        case .idle:
            return 1
        case .readingEnergy:
            return 5.4
        case .analyzingBiometrics:
            return 4.2
        case .translatingThoughts:
            return 3.4
        case .typing:
            return 2.6
        }
    }
}

// MARK: - Theme (Light/Dark)

struct CaptainTheme {
    let colorScheme: ColorScheme

    var background: Color { Color(UIColor.systemBackground) }
    var card: Color { Color(UIColor.secondarySystemBackground) }
    var text: Color { Color.primary }
    var subtext: Color { Color(UIColor.secondaryLabel) }

    var border: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var shadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08)
    }

    var accent: Color { Color(hex: "FFD700") }

    var captainBubble: Color {
        let base = Color(hex: "F4CD8F")
        return colorScheme == .dark ? base.opacity(0.85) : base.opacity(0.95)
    }

    var userBubble: Color {
        let base = Color(hex: "A8E6CF")
        return colorScheme == .dark ? base.opacity(0.75) : base.opacity(0.95)
    }

    var inputBackground: Color { card }
    var fieldBackground: Color { colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }
    var icon: Color { subtext }
}

// MARK: - Main Captain Screen

struct CaptainScreen: View {
    @StateObject private var viewModel = CaptainViewModel()
    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            CaptainBackgroundView()

            VStack(spacing: 0) {
                CaptainHeaderView(
                    onProfileTap: { viewModel.openProfile() },
                    onCustomizeTap: { viewModel.showCustomization = true }
                )

                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        let layout = viewModel.layout(for: geometry.size.height)

                        VStack {
                            Spacer()

                            CaptainAvatarView()
                                .frame(height: layout.avatarHeight)
                                .offset(y: layout.avatarOffset)
                                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: layout.avatarOffset)
                                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: layout.avatarHeight)
                        }

                        VStack {
                            ChatContainerView(
                                messages: viewModel.messages,
                                isTyping: viewModel.isTyping,
                                coachState: viewModel.coachState,
                                scrollEnabled: layout.chatScrollEnabled
                            )
                            .frame(height: layout.chatHeight)
                            .offset(y: layout.chatOffset)
                            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: layout.chatHeight)
                            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: layout.chatOffset)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.messages.count)

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                }

                CaptainInputView(
                    text: $viewModel.inputText,
                    isSending: viewModel.isSending,
                    onSend: viewModel.sendMessage
                )
                .padding(.bottom, 16)
            }
        }
        .fontDesign(.rounded)
        .onTapGesture { hideKeyboard() }
        .gesture(DragGesture().onChanged { _ in hideKeyboard() })
        .sheet(isPresented: $viewModel.showCustomization) {
            CustomizationSheetView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $viewModel.showProfile) {
            NavigationStack {
                ProfileScreen()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .onAppear {
            viewModel.consumePendingCaptainNotificationIfAny()
        }
        .onReceive(CaptainNotificationHandler.shared.$pendingNotificationMessage) { _ in
            viewModel.consumePendingCaptainNotificationIfAny()
        }
        .sensoryFeedback(.selection, trigger: viewModel.feedbackTrigger)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Captain ViewModel (ON-DEVICE)

@MainActor
final class CaptainViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var isTyping: Bool = false
    @Published var coachState: CoachCognitiveState = .idle
    @Published var showCustomization: Bool = false
    @Published var showProfile: Bool = false
    @Published var customization: CaptainCustomization = .default
    @Published var feedbackTrigger: Int = 0

    private let userDefaults = UserDefaults.standard
    private let intelligenceManager = CaptainIntelligenceManager.shared
    private let brainMiddleware: CoachBrainMiddleware
    private let minimumCognitiveDelay: TimeInterval = 5.6

    private enum Keys {
        static let name = "captain_user_name"
        static let age = "captain_user_age"
        static let height = "captain_user_height"
        static let weight = "captain_user_weight"
        static let calling = "captain_calling"
        static let tone = "captain_tone"
    }

    private enum ReplyLanguage {
        case arabic
        case english
    }

    init(brainMiddleware: CoachBrainMiddleware? = nil) {
        self.brainMiddleware = brainMiddleware ?? CoachBrainMiddleware()
        loadCustomization()
        addWelcomeMessage()
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

        // Fast, per-message downward movement for captain.
        let avatarHeight = availableHeight * 0.62
        let perMessageDrop = availableHeight * 0.11

        // Stop when input bar reaches captain belly level.
        let bellyAnchor: CGFloat = 0.58
        let avatarBaseTop = availableHeight - avatarHeight
        let bellyYAtBase = avatarBaseTop + (avatarHeight * bellyAnchor)
        let maxAvatarOffset = max(0, availableHeight - 8 - bellyYAtBase)
        let avatarOffset = min(perMessageDrop * messageSteps, maxAvatarOffset)

        // Freeze layout after stop; after that only internal chat scrolling continues.
        let stopSteps = perMessageDrop > 0 ? ceil(maxAvatarOffset / perMessageDrop) : 0
        let effectiveSteps = min(messageSteps, stopSteps)
        let hasStopped = messageSteps >= stopSteps

        // Chat starts a bit higher, then moves down clearly with each message.
        let chatHeight = min(availableHeight * 0.62, availableHeight * (0.27 + (0.085 * effectiveSteps)))
        let chatStartOffset = -availableHeight * 0.08
        let perMessageChatDrop = availableHeight * 0.11
        let proposedChatOffset = chatStartOffset + (perMessageChatDrop * effectiveSteps)

        // Keep fixed spacing between chat card and captain.
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

    func openProfile() { showProfile = true }

    private func addWelcomeMessage() {
        let welcome = ChatMessage(
            content: "هلا! أنا كابتن حمّودي. شنو هدفك اليوم؟ 💪",
            isUser: false
        )
        messages.append(welcome)
    }

    func consumePendingCaptainNotificationIfAny() {
        let handler = CaptainNotificationHandler.shared
        guard let pending = handler.pendingNotificationMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pending.isEmpty else { return }

        // خلّي الاشعار يطلع كأول رسالة من الكابتن داخل الشاشة
        Task { [weak self] in
            guard let self else { return }
            await self.addAnimatedMessage(pending)
            handler.clearPendingMessage()
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        feedbackTrigger += 1

        let userMessage = ChatMessage(content: text, isUser: true)
        messages.append(userMessage)
        inputText = ""

        isSending = true
        isTyping = true

        Task { await processMessage(text) }
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
        let summary = nickname.isEmpty ? "✅ تمام تم الحفظ" : "✅ تمام تم الحفظ — راح أناديك \(nickname)"

        Task { await addAnimatedMessage(summary) }
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

    private func processMessage(_ text: String) async {
        do {
            let preferredLanguage = detectReplyLanguage(from: text)
            let startedAt = Date()
            let replyTask = Task<String, Error> { [brainMiddleware, intelligenceManager] in
                switch preferredLanguage {
                case .arabic:
                    return await brainMiddleware.processArabicMessage(text)
                case .english:
                    return try await intelligenceManager.generateCaptainResponse(
                        for: text,
                        forcedRoute: .onDevice
                    )
                }
            }

            await runCognitiveTimeline()
            let reply = try await replyTask.value

            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minimumCognitiveDelay {
                let remaining = minimumCognitiveDelay - elapsed
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            await transitionCoachState(to: .typing, hold: 0.35)

            isTyping = false
            let normalized = normalizeReplyForDisplay(reply)
            let finalReply = enforceReplyLanguageIfNeeded(
                reply: normalized,
                preferredLanguage: preferredLanguage
            )
            let displayReply = prependUserNameIfNeeded(
                to: finalReply,
                preferredLanguage: preferredLanguage
            )
            await addAnimatedMessage(displayReply)
            coachState = .idle
            isSending = false
        } catch is CancellationError {
            coachState = .idle
            isTyping = false
            isSending = false
        } catch {
            coachState = .idle
            isTyping = false
            await addAnimatedMessage("صار خلل محلي بسيط. خلينا نعيد المحاولة بعد ثواني.")
            isSending = false
        }
    }

    private func runCognitiveTimeline() async {
        await transitionCoachState(to: .readingEnergy, hold: 1.15)
        await transitionCoachState(to: .analyzingBiometrics, hold: 1.45)
        await transitionCoachState(to: .translatingThoughts, hold: 1.25)
        coachState = .typing
    }

    private func transitionCoachState(to state: CoachCognitiveState, hold: TimeInterval) async {
        coachState = state
        let nanoseconds = UInt64(max(0, hold) * 1_000_000_000)
        if nanoseconds > 0 {
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    private func detectReplyLanguage(from text: String) -> ReplyLanguage {
        let hasArabic = text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF,
                 0x0750...0x077F,
                 0x0870...0x089F,
                 0x08A0...0x08FF,
                 0xFB50...0xFDFF,
                 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
        return hasArabic ? .arabic : .english
    }

    private func response(_ text: String, matches language: ReplyLanguage) -> Bool {
        let hasArabic = text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF,
                 0x0750...0x077F,
                 0x0870...0x089F,
                 0x08A0...0x08FF,
                 0xFB50...0xFDFF,
                 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }

        switch language {
        case .arabic:
            return hasArabic
        case .english:
            return !hasArabic
        }
    }

    private func normalizeReplyForDisplay(_ text: String) -> String {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        while normalized.hasPrefix("=") || normalized.hasPrefix("-") || normalized.hasPrefix("•") {
            normalized.removeFirst()
            normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return normalized
    }

    private func enforceReplyLanguageIfNeeded(
        reply: String,
        preferredLanguage: ReplyLanguage
    ) -> String {
        guard !response(reply, matches: preferredLanguage) else {
            return reply
        }

        switch preferredLanguage {
        case .arabic:
            return "حبيبي، فهمت عليك. هسه أجاوبك بالعربي. شنو أول خطوة تريد نبدأ بيها اليوم؟"
        case .english:
            return "Got it. I will reply in English. What is the first step you want to start with today?"
        }
    }

    private func prependUserNameIfNeeded(
        to reply: String,
        preferredLanguage: ReplyLanguage
    ) -> String {
        guard preferredLanguage == .arabic else { return reply }
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

        for token in prefixTokens {
            if trimmedReply.hasPrefix(loweredName + token) {
                return true
            }
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

    private func addAnimatedMessage(_ content: String) async {
        let message = ChatMessage(content: "", isUser: false, isAnimating: true)
        messages.append(message)

        let messageIndex = messages.count - 1
        for char in content {
            try? await Task.sleep(nanoseconds: 25_000_000)
            messages[messageIndex].content.append(char)
        }
        messages[messageIndex].isAnimating = false
    }
}

// MARK: - Background View

struct CaptainBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(hex: "A8E6CF").opacity(colorScheme == .dark ? 0.10 : 0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.3)
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Header View

struct CaptainHeaderView: View {
    var onProfileTap: () -> Void
    var onCustomizeTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack(alignment: .top) {
            Text(NSLocalizedString("screen.captain.title", value: "Captain Hamoudi", comment: ""))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(theme.text)

            Spacer()

            VStack(spacing: 12) {
                FloatingProfileButton(size: 48) { onProfileTap() }

                Button(action: onCustomizeTap) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.text)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(theme.card)
                                .shadow(color: theme.shadow, radius: 10, x: 0, y: 6)
                        )
                        .overlay(Circle().stroke(theme.border, lineWidth: 0.8))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

// MARK: - Chat Container View

struct ChatContainerView: View {
    let messages: [ChatMessage]
    var isTyping: Bool = false
    var coachState: CoachCognitiveState = .idle
    var scrollEnabled: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, containerWidth: geo.size.width)
                                .id(message.id)
                        }

                        if isTyping {
                            HStack {
                                if coachState != .idle {
                                    ModernCognitiveIndicatorView(
                                        state: coachState
                                    )
                                } else {
                                    TypingIndicatorView()
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 6)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
                .scrollDisabled(!scrollEnabled)
                .onChange(of: messages.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: messages.last?.content) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.card)
                .shadow(color: theme.shadow, radius: 14, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.border, lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let containerWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    @State private var appeared = false

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 44) }

            Text(message.content)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(
                    maxWidth: containerWidth * 0.74,
                    alignment: message.isUser ? .trailing : .leading
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(message.isUser ? theme.userBubble : theme.captainBubble)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.border.opacity(0.9), lineWidth: 0.7)
                )
                .padding(message.isUser ? .leading : .trailing, 8)

            if !message.isUser { Spacer(minLength: 44) }
        }
        .padding(.horizontal, 6)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(theme.subtext.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == index ? 1.25 : 0.85)
                    .animation(.easeInOut(duration: 0.25), value: phase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.captainBubble)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.border.opacity(0.9), lineWidth: 0.7)
        )
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// MARK: - Cognitive Indicator

private struct CoachGlassCardModifier: ViewModifier {
    let theme: CaptainTheme
    let accentColors: [Color]
    let cornerRadius: CGFloat

    private var accent: Color {
        accentColors.last ?? Color.white.opacity(0.18)
    }

    private var glow: Color {
        accentColors.first ?? Color.white.opacity(0.12)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        glow.opacity(theme.colorScheme == .dark ? 0.14 : 0.22),
                                        Color.white.opacity(theme.colorScheme == .dark ? 0.02 : 0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(theme.colorScheme == .dark ? 0.18 : 0.42),
                                accent.opacity(0.36),
                                Color.white.opacity(theme.colorScheme == .dark ? 0.08 : 0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(
                color: accent.opacity(theme.colorScheme == .dark ? 0.18 : 0.10),
                radius: 16,
                x: 0,
                y: 10
            )
    }
}

private struct BreathingGlassRingModifier: ViewModifier {
    let state: CoachCognitiveState
    let pulseScale: CGFloat
    let rotationDegrees: Double
    let highlightDrift: CGFloat

    private var accent: Color {
        state.accentColors.last ?? Color.white.opacity(0.16)
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulseScale)
            .rotationEffect(.degrees(rotationDegrees))
            .shadow(color: accent.opacity(0.28), radius: 12, x: 0, y: 4)
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.48), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 6)
                    .scaleEffect(0.7)
                    .offset(x: highlightDrift, y: -highlightDrift * 0.35)
                    .blendMode(.screen)
            )
    }
}

private struct CoachSignalBarsView: View {
    let state: CoachCognitiveState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    let speed = max(1.1, state.rotationDuration * 0.55) + (Double(index) * 0.12)
                    let wave = (sin((time / speed) + Double(index)) + 1) * 0.5
                    let height = 9 + (wave * (12 + Double(index * 2)))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    state.accentColors.first?.opacity(0.9) ?? Color.white.opacity(0.7),
                                    state.accentColors.last?.opacity(0.55) ?? Color.white.opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: height)
                }
            }
            .frame(width: 28, height: 24)
        }
    }
}

private struct CoachOrbitingGlassOrbView: View {
    let state: CoachCognitiveState

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let progress = time / max(1.8, state.rotationDuration)
            let primaryAngle = progress * Double.pi * 2
            let secondaryAngle = progress * Double.pi * -2.7
            let pulse = CGFloat(
                0.92 + (((sin(primaryAngle) + 1) * 0.5) * Double(state.pulseScale - 0.92))
            )
            let haloScale = CGFloat(
                1.04 + (((cos(primaryAngle * 0.8) + 1) * 0.5) * 0.18)
            )
            let leadingColor = state.accentColors.first ?? Color.white.opacity(0.25)
            let trailingColor = state.accentColors.last ?? Color.white.opacity(0.18)

            ZStack {
                orbCore()
                orbGlow(color: leadingColor, size: 20, blur: 8, angle: primaryAngle, radius: 10)
                orbGlow(color: trailingColor, size: 30, blur: 12, angle: primaryAngle + 1.4, radius: 14)
                orbRings(
                    progress: progress,
                    leadingColor: leadingColor,
                    trailingColor: trailingColor,
                    haloScale: haloScale
                )
                orbParticle(size: 4, opacity: 0.72, angle: secondaryAngle, radius: 16)
                orbParticle(size: 5, opacity: 0.56, angle: secondaryAngle + 2.1, radius: 19)
                orbParticle(size: 6, opacity: 0.42, angle: secondaryAngle + 4.2, radius: 22)
                orbSymbol(leadingColor: leadingColor)
            }
            .scaleEffect(pulse)
            .frame(width: 54, height: 54)
            .drawingGroup(opaque: false)
        }
    }

    private func orbCore() -> some View {
        Circle()
            .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.34))
            .frame(width: 46, height: 46)
    }

    private func orbGlow(
        color: Color,
        size: CGFloat,
        blur: CGFloat,
        angle: Double,
        radius: CGFloat
    ) -> some View {
        Circle()
            .fill(color.opacity(colorScheme == .dark ? 0.24 : 0.30))
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
    }

    private func orbRings(
        progress: Double,
        leadingColor: Color,
        trailingColor: Color,
        haloScale: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .stroke(theme.border.opacity(0.65), lineWidth: 1)
                .frame(width: 46, height: 46)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [leadingColor, trailingColor, leadingColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3.6, lineCap: .round)
                )
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(progress * 360))

            Circle()
                .trim(from: 0.16, to: 0.58)
                .stroke(
                    Color.white.opacity(colorScheme == .dark ? 0.35 : 0.62),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(progress * -420))

            Circle()
                .stroke(trailingColor.opacity(0.24), lineWidth: 9)
                .blur(radius: 10)
                .frame(width: 46, height: 46)
                .scaleEffect(haloScale)
        }
    }

    private func orbParticle(
        size: CGFloat,
        opacity: Double,
        angle: Double,
        radius: CGFloat
    ) -> some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .offset(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
    }

    private func orbSymbol(leadingColor: Color) -> some View {
        Image(systemName: state.symbolName)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        leadingColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .symbolEffect(.pulse, options: .repeating.speed(0.8), value: state)
    }
}

private extension View {
    func coachGlassCard(
        theme: CaptainTheme,
        accentColors: [Color],
        cornerRadius: CGFloat = 22
    ) -> some View {
        modifier(
            CoachGlassCardModifier(
                theme: theme,
                accentColors: accentColors,
                cornerRadius: cornerRadius
            )
        )
    }

    func breathingGlassRing(
        state: CoachCognitiveState,
        pulseScale: CGFloat,
        rotationDegrees: Double,
        highlightDrift: CGFloat
    ) -> some View {
        modifier(
            BreathingGlassRingModifier(
                state: state,
                pulseScale: pulseScale,
                rotationDegrees: rotationDegrees,
                highlightDrift: highlightDrift
            )
        )
    }
}

struct BreathingRingIndicatorView: View {
    let state: CoachCognitiveState

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 14) {
            CoachOrbitingGlassOrbView(state: state)

            VStack(alignment: .leading, spacing: 4) {
                Text("Captain Consciousness")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.subtext.opacity(0.8))

                Text(state.statusText ?? "الكابتن حاضر")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(theme.text)

                Text(state.detailText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.subtext)
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)

            CoachSignalBarsView(state: state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .coachGlassCard(
            theme: theme,
            accentColors: state.accentColors
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.42),
                            state.accentColors.first?.opacity(0.34) ?? Color.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 112, height: 1.2)
                .padding(.top, 8)
                .padding(.leading, 14)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            state.accentColors.last?.opacity(0.18) ?? Color.white.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 30
                    )
                )
                .frame(width: 44, height: 44)
                .offset(x: 8, y: 10)
        }
        .contentTransition(.opacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: state)
    }
}

// MARK: - Avatar View

struct CaptainAvatarView: View {
    @State private var breathingOffset: CGFloat = 0

    var body: some View {
        Image("Hammoudi5")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .offset(y: breathingOffset)
            .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathingOffset = -8
                }
            }
    }
}

// MARK: - Input View

struct CaptainInputView: View {
    @Binding var text: String
    var isSending: Bool
    var onSend: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $text,
                prompt: Text(NSLocalizedString("captain.input.prompt", value: "شنو هدفك اليوم؟", comment: ""))
                    .foregroundColor(theme.subtext.opacity(0.75)),
                axis: .vertical
            )
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundColor(theme.text)
            .lineLimit(1...4)
            .padding(.leading, 18)
            .padding(.vertical, 14)

            Button(action: {}) {
                Image(systemName: "mic")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.icon)
            }

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(canSend ? .black : theme.subtext.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(canSend ? theme.accent : theme.fieldBackground))
                    .rotationEffect(.degrees(isSending ? 360 : 0))
                    .animation(
                        isSending ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: isSending
                    )
            }
            .disabled(!canSend)
            .padding(.trailing, 8)
        }
        .frame(minHeight: 52)
        .background(
            Capsule()
                .fill(theme.inputBackground)
                .shadow(color: theme.shadow, radius: 14, x: 0, y: 8)
        )
        .overlay(Capsule().stroke(theme.border, lineWidth: 0.8))
        .padding(.horizontal, 22)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
}

// MARK: - Customization Sheet

struct CustomizationSheetView: View {
    @ObservedObject var viewModel: CaptainViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text(NSLocalizedString("captain.customize.title", value: "Customize Captain", comment: ""))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(theme.text)

                            Text(NSLocalizedString("captain.customize.subtitle", value: "Add your info to personalize the captain.", comment: ""))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(theme.subtext)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        VStack(spacing: 12) {
                            CustomInputField(placeholder: NSLocalizedString("captain.customize.name", value: "Name", comment: ""), text: $viewModel.customization.name)
                            CustomInputField(placeholder: NSLocalizedString("captain.customize.age", value: "Age", comment: ""), text: $viewModel.customization.age, keyboard: .numberPad)
                            CustomInputField(placeholder: NSLocalizedString("captain.customize.height", value: "Height (cm)", comment: ""), text: $viewModel.customization.height, keyboard: .numberPad)
                            CustomInputField(placeholder: NSLocalizedString("captain.customize.weight", value: "Weight (kg)", comment: ""), text: $viewModel.customization.weight, keyboard: .decimalPad)
                            CustomInputField(placeholder: NSLocalizedString("captain.customize.calling", value: "How should the captain call you?", comment: ""), text: $viewModel.customization.calling)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("captain.customize.tone", value: "Captain tone", comment: ""))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.subtext)

                            Picker("", selection: $viewModel.customization.tone) {
                                ForEach(CaptainTone.allCases, id: \.self) { tone in
                                    Text(tone.displayName).tag(tone)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Button(action: { viewModel.saveCustomization() }) {
                            Text(NSLocalizedString("action.save", value: "Save", comment: ""))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "A8E6CF").opacity(colorScheme == .dark ? 0.75 : 0.85))
                                )
                        }
                        .padding(.top, 8)
                    }
                    .padding(18)
                }
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(theme.card)
                        .shadow(color: theme.shadow, radius: 12)
                )
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(theme.border, lineWidth: 0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .fontDesign(.rounded)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.subtext)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(theme.fieldBackground))
                            .overlay(Circle().stroke(theme.border, lineWidth: 0.7))
                    }
                }
            }
        }
    }
}

// MARK: - Custom Input Field

struct CustomInputField: View {
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundColor(theme.subtext.opacity(0.7))
        )
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundColor(theme.text)
        .keyboardType(keyboard)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.fieldBackground))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.border, lineWidth: 0.8))
    }
}

// MARK: - Preview

#Preview("Light") {
    CaptainScreen().preferredColorScheme(.light)
}

#Preview("Dark") {
    CaptainScreen().preferredColorScheme(.dark)
}
