//
//  CaptainScreen.swift
//  AiQo - Captain Hamoudi Screen
//
//  SwiftUI Implementation + On-Device Captain Intelligence
//

import SwiftUI
import Combine
import RealityKit

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
    case readingMessage
    case thinkingOnDevice
    case shapingReply
    case typing

    var statusText: String? {
        switch self {
        case .idle:
            return nil
        case .readingMessage:
            return "الكابتن يقرأ رسالتك"
        case .thinkingOnDevice:
            return "الكابتن يشغّل Apple Intelligence"
        case .shapingReply:
            return "الكابتن يرتب الرد باللهجة العراقية"
        case .typing:
            return "الكابتن يكتب الرد"
        }
    }

    var detailText: String {
        switch self {
        case .idle:
            return "Captain ready"
        case .readingMessage:
            return "يلتقط طلبك مباشرة من غير ترجمة"
        case .thinkingOnDevice:
            return "المعالجة تصير محلياً على الجهاز"
        case .shapingReply:
            return "يصوغ جواب قصير وعملي بصوت حمّودي"
        case .typing:
            return "يصوغ الرد النهائي بصوت حمّودي"
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            return "sparkles"
        case .readingMessage:
            return "eye.fill"
        case .thinkingOnDevice:
            return "cpu.fill"
        case .shapingReply:
            return "character.bubble.fill"
        case .typing:
            return "ellipsis.bubble.fill"
        }
    }

    var accentColors: [Color] {
        switch self {
        case .idle:
            return [Color.white.opacity(0.18), Color.white.opacity(0.08)]
        case .readingMessage:
            return [Color(red: 0.68, green: 0.91, blue: 0.84), Color(red: 0.43, green: 0.80, blue: 0.72)]
        case .thinkingOnDevice:
            return [Color(red: 0.77, green: 0.86, blue: 1.00), Color(red: 0.53, green: 0.70, blue: 0.98)]
        case .shapingReply:
            return [Color(red: 0.72, green: 0.67, blue: 0.98), Color(red: 0.53, green: 0.59, blue: 0.97)]
        case .typing:
            return [Color(red: 0.88, green: 0.77, blue: 0.53), Color(red: 0.95, green: 0.89, blue: 0.73)]
        }
    }

    var pulseScale: CGFloat {
        switch self {
        case .idle:
            return 1
        case .readingMessage:
            return 1.24
        case .thinkingOnDevice:
            return 1.34
        case .shapingReply:
            return 1.5
        case .typing:
            return 1.18
        }
    }

    var rotationDuration: Double {
        switch self {
        case .idle:
            return 1
        case .readingMessage:
            return 5.4
        case .thinkingOnDevice:
            return 3.9
        case .shapingReply:
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
    var captainText: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.90)
    }
    var userText: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.72)
    }
    var chatBubbleText: Color { Color.black.opacity(colorScheme == .dark ? 0.82 : 0.86) }
    var spatialMint: Color { Color.mint.opacity(colorScheme == .dark ? 0.92 : 0.72) }

    var border: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var shadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08)
    }

    var accent: Color { Color(hex: "FFD700") }

    var captainBubble: Color {
        Color(
            uiColor: UIColor(named: "ChatAssistantBubble")
                ?? UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1)
        )
    }

    var userBubble: Color {
        Color(
            uiColor: UIColor(named: "ChatUserBubble")
                ?? UIColor(red: 0.75, green: 0.91, blue: 0.84, alpha: 1)
        )
    }

    var inputBackground: Color { card }
    var fieldBackground: Color { colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }
    var icon: Color { subtext }
}

// MARK: - Main Captain Screen

struct CaptainScreen: View {
    @EnvironmentObject private var viewModel: CaptainViewModel
    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }
    @State private var showHealthSources = false
    @Namespace private var avatarNamespace
    @State private var showGrowsSheet = false
    @AppStorage("captain.growsBanner.dismissedAtEpoch") private var growsBannerDismissedAtEpoch: Double = 0

    /// Free-tier "Captain grows with Max" teaser — shown only on the pre-chat
    /// meet-the-Captain screen (never interrupts an active chat), and snoozed for
    /// a cooldown after dismissal.
    private var shouldShowUpgradeBanner: Bool {
        viewModel.isFreeCaptain
            && !hasUserStartedChat
            && CaptainUpgradeNudge.shouldShow(dismissedAtEpoch: growsBannerDismissedAtEpoch)
    }

    /// Flips to true the moment the user sends their first message this session.
    /// Resets to false on `startNewChat()` and on cold launch (which calls `loadPersistedHistory()` → `startNewChat()`).
    private var hasUserStartedChat: Bool {
        viewModel.messages.contains(where: \.isUser)
    }

    private var isArabicUI: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    fileprivate var captainStatusSubtitle: String {
        if viewModel.isLoading {
            return isArabicUI ? "يفكر الحين" : "Thinking…"
        }
        return isArabicUI ? "متصل الآن" : "Online now"
    }

    var body: some View {
        ZStack {
            CaptainBackgroundView()

            if hasUserStartedChat {
                chatModeLayout
                    .transition(.opacity)
            } else {
                showcaseModeLayout
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: hasUserStartedChat)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 10) {
                topChrome
                CaptainSafetyBanner()
                    .padding(.horizontal, 16)

                if shouldShowUpgradeBanner {
                    CaptainUpgradeBanner(
                        isArabic: isArabicUI,
                        onOpen: { showGrowsSheet = true },
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                growsBannerDismissedAtEpoch = Date().timeIntervalSince1970
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.bottom, 4)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: shouldShowUpgradeBanner)
            .background {
                // Opaque layer behind the header + safety banner so the chat
                // can't bleed through when the user scrolls messages up.
                // Extends past the safe-area top so the status-bar gutter is
                // covered too. Adapts to light/dark via systemBackground.
                theme.background
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.border)
                            .frame(height: 0.5)
                    }
            }
        }
        .fontDesign(.rounded)
        .onTapGesture { hideKeyboard() }
        .aiqoProfileSheet(isPresented: $viewModel.showProfile)
        .sheet(isPresented: $viewModel.showCustomization) {
            CustomizationSheetView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $viewModel.showChatHistory) {
            ChatHistoryView()
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showHealthSources) {
            HealthSourcesView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView(source: .captainGate)
        }
        .sheet(isPresented: $showGrowsSheet) {
            CaptainGrowsSheet(isArabic: isArabicUI) {
                // Hand off to the paywall: close this sheet, then present it on the
                // next runloop (two sheets can't be presented simultaneously).
                showGrowsSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    viewModel.showPaywall = true
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .onAppear {
            viewModel.consumePendingCaptainNotificationIfAny()
            Task {
                await CaptainVoiceService.shared.preCacheVoices()
            }
        }
        .onReceive(CaptainNotificationHandler.shared.$pendingNotificationMessage) { _ in
            viewModel.consumePendingCaptainNotificationIfAny()
        }
        .sensoryFeedback(.selection, trigger: viewModel.feedbackTrigger)
    }

    /// Pre-chat: large avatar centered, chat lives in a compact box above it.
    /// This is what the user sees on cold launch and after `startNewChat()`.
    private var showcaseModeLayout: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    let layout = viewModel.layout(for: geometry.size.height)

                    VStack {
                        Spacer()

                        LivingCaptainAvatarView()
                            .frame(height: layout.avatarHeight)
                            .offset(y: layout.avatarOffset)
                            .matchedGeometryEffect(id: "captain-avatar", in: avatarNamespace)
                    }

                    VStack {
                        ChatContainerView(
                            messages: viewModel.messages,
                            isTyping: viewModel.isTyping,
                            coachState: viewModel.coachState,
                            scrollEnabled: layout.chatScrollEnabled,
                            workoutPlan: viewModel.currentWorkoutPlan,
                            onStartWorkoutTap: handleStartWorkoutTap,
                            streamingText: viewModel.streamingText,
                            hasStreamingBubble: viewModel.streamingMessageID != nil
                        )
                        .frame(height: layout.chatHeight)
                        .offset(y: layout.chatOffset)

                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: viewModel.messages.count)
            }

            CaptainInputView(
                isSending: viewModel.isSending,
                onSend: { text in viewModel.sendMessage(text) }
            )
            .padding(.bottom, 16)
        }
    }

    /// After first user message: full-screen chat, compact avatar pinned above
    /// the input bar on the leading (right in RTL) side — messages flow directly
    /// on the screen, not in a boxed container.
    private var chatModeLayout: some View {
        VStack(spacing: 0) {
            ChatContainerView(
                messages: viewModel.messages,
                isTyping: viewModel.isTyping,
                coachState: viewModel.coachState,
                scrollEnabled: true,
                workoutPlan: viewModel.currentWorkoutPlan,
                onStartWorkoutTap: handleStartWorkoutTap,
                streamingText: viewModel.streamingText,
                hasStreamingBubble: viewModel.streamingMessageID != nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)

            HStack(spacing: 10) {
                CaptainAvatarView(breathes: false)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                    .matchedGeometryEffect(id: "captain-avatar", in: avatarNamespace)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            .environment(\.layoutDirection, .leftToRight)

            CaptainInputView(
                isSending: viewModel.isSending,
                onSend: { text in viewModel.sendMessage(text) }
            )
            .padding(.bottom, 16)
        }
    }

    /// Tapped from the in-chat `WorkoutPlanCard`. v1 hops into the
    /// detailed Captain chat view (where the existing plan tooling lives);
    /// when the dedicated workout runner ships we'll route there instead.
    /// Lives on the screen instead of the card so the card stays reusable
    /// across surfaces (Captain main, future Club preview, etc.).
    private func handleStartWorkoutTap() {
        AppRootManager.shared.openCaptainChat()
    }

    private var topChrome: some View {
        AiQoScreenTopChrome(
            horizontalInset: 10,
            profileVerticalOffset: -2,
            onProfileTap: { viewModel.showProfile = true }
        ) {
            // Single horizontal row: action buttons lead, title center-trailing.
            // In RTL the buttons visually appear on the right of the title,
            // balancing the profile avatar pulled in by AiQoScreenTopChrome on
            // the opposite side.
            HStack(alignment: .center, spacing: 8) {
                chromeCircleButton(
                    systemImage: "clock.arrow.circlepath",
                    accessibilityLabel: NSLocalizedString("captain.history.button", value: "Chat history", comment: "")
                ) {
                    viewModel.showChatHistory = true
                }

                chromeCircleButton(
                    systemImage: "text.book.closed.fill",
                    accessibilityLabel: NSLocalizedString("health.sources.button", value: "Health sources", comment: "")
                ) {
                    showHealthSources = true
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(NSLocalizedString("screen.captain.title", value: "Captain Hamoudi", comment: ""))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                    Text(captainStatusSubtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.subtext)
                }
                .lineLimit(1)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func chromeCircleButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.subtext)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(theme.border, lineWidth: 0.7))
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Background View

struct CaptainBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        SIMD2<Float>(0.0, 0.0),
                        SIMD2<Float>(0.5, 0.08),
                        SIMD2<Float>(1.0, 0.0),
                        SIMD2<Float>(0.04, 0.58),
                        SIMD2<Float>(0.5, 0.52),
                        SIMD2<Float>(0.96, 0.48),
                        SIMD2<Float>(0.0, 1.0),
                        SIMD2<Float>(0.5, 0.94),
                        SIMD2<Float>(1.0, 1.0)
                    ],
                    colors: [
                        Color(hex: "F7FFF9").opacity(colorScheme == .dark ? 0.04 : 0.46),
                        Color(hex: "B7FFE5").opacity(colorScheme == .dark ? 0.10 : 0.34),
                        Color(hex: "F8F4E8").opacity(colorScheme == .dark ? 0.04 : 0.28),
                        Color(hex: "D6FFF1").opacity(colorScheme == .dark ? 0.06 : 0.22),
                        Color.clear,
                        Color(hex: "DCF7FF").opacity(colorScheme == .dark ? 0.08 : 0.22),
                        Color(hex: "F8FFF4").opacity(colorScheme == .dark ? 0.05 : 0.22),
                        Color(hex: "CFFBEA").opacity(colorScheme == .dark ? 0.05 : 0.18),
                        Color(hex: "FFF8EE").opacity(colorScheme == .dark ? 0.05 : 0.22)
                    ]
                )
                .blur(radius: 80)
                .opacity(colorScheme == .dark ? 0.85 : 1)
                .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.04 : 0.38),
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.16 : 0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(theme.spatialMint.opacity(colorScheme == .dark ? 0.12 : 0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -110, y: -240)
                .blendMode(.screen)

            Ellipse()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.18))
                .frame(width: 360, height: 220)
                .blur(radius: 90)
                .offset(x: 120, y: 120)
                .blendMode(.screen)
        }
    }
}

// MARK: - Header View

// MARK: - Chat Container View

struct ChatContainerView: View {
    let messages: [ChatMessage]
    var isTyping: Bool = false
    var coachState: CoachCognitiveState = .idle
    var scrollEnabled: Bool = false
    /// When non-nil, a premium `WorkoutPlanCard` renders inline below the
    /// last message. Owned by `CaptainViewModel.currentWorkoutPlan` — the
    /// card shows the day-by-day breakdown so the bubble can stay short.
    var workoutPlan: WorkoutPlan? = nil
    /// Tap target for the card's "Start workout" CTA. Hand back navigation
    /// to the host screen (e.g. push into the Club runner).
    var onStartWorkoutTap: (() -> Void)? = nil
    /// Active progressive-reveal stream. When the Captain's reply is being
    /// streamed out char-by-char, `streamingText` carries the running prefix
    /// and `streamingMessageID` is the row identity. The bubble is rendered
    /// in place of the (not-yet-committed) final row so the user sees the
    /// Captain "talking" instead of a silent gap between their message and
    /// the plan card. Owned by `CaptainViewModel`.
    var streamingText: String = ""
    var hasStreamingBubble: Bool = false
    private let thinkingIndicatorID = "captain-thinking-indicator"
    private let planCardID = "captain-workout-plan-card"
    private let streamingBubbleID = "captain-streaming-bubble"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        ChatBubbleView(
                            text: message.content,
                            isUser: message.isUser
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                    }

                    // Progressive-reveal bubble. Rendered ABOVE the workout
                    // card so the Captain's voice arrives in the same visual
                    // position the finalized row will take (no jump on swap).
                    if hasStreamingBubble {
                        StreamingCaptainBubbleRow(text: streamingText)
                            .id(streamingBubbleID)
                            .padding(.top, 2)
                    }

                    if let workoutPlan {
                        WorkoutPlanCard(plan: workoutPlan, onStartTap: onStartWorkoutTap)
                            .id(planCardID)
                            .padding(.top, 4)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }

                    if isTyping && !hasStreamingBubble {
                        HStack {
                            TypingIndicatorView(state: coachState)
                            Spacer()
                        }
                        .id(thinkingIndicatorID)
                        .padding(.top, 6)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottomLeading)),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 4)
                .padding(.bottom, 20)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: messages.count)
                .animation(.easeInOut(duration: 0.22), value: isTyping)
                .animation(.spring(response: 0.4, dampingFraction: 0.84), value: workoutPlan != nil)
            }
            .scrollDisabled(!scrollEnabled)
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                scrollToBottom(using: proxy, animated: false)
            }
            .onChange(of: messages.count) {
                scrollToBottom(using: proxy)
            }
            .onChange(of: isTyping) {
                scrollToBottom(using: proxy)
            }
            .onChange(of: hasStreamingBubble) {
                scrollToBottom(using: proxy)
            }
            .onChange(of: streamingText) {
                // Pin the live bubble to the bottom as it grows char-by-char.
                // No animation on purpose — a spring per tick janks; an
                // instant scrollTo tracks it buttery-smooth.
                guard hasStreamingBubble else { return }
                proxy.scrollTo(streamingBubbleID, anchor: .bottom)
            }
            .onChange(of: workoutPlan != nil) { _, hasPlan in
                guard hasPlan else { return }
                withAnimation(.smooth(duration: 0.32)) {
                    proxy.scrollTo(planCardID, anchor: .bottom)
                }
            }
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        let targetID: AnyHashable? = {
            if hasStreamingBubble {
                return AnyHashable(streamingBubbleID)
            }
            if isTyping {
                return AnyHashable(thinkingIndicatorID)
            }
            if workoutPlan != nil {
                return AnyHashable(planCardID)
            }
            return messages.last.map { AnyHashable($0.id) }
        }()
        guard let targetID else { return }

        guard animated else {
            proxy.scrollTo(targetID, anchor: .bottom)
            return
        }

        withAnimation(.smooth(duration: 0.32)) {
            proxy.scrollTo(targetID, anchor: .bottom)
        }
    }
}

// MARK: - Chat Bubble

/// A compact, continuously-animating "now playing" equalizer shown on a
/// Captain bubble while its voice is being spoken — the premium affordance that
/// replaces a flat speaker glyph. Desynced bar periods give the organic bob of
/// a real audio meter. Reduce Motion is honored by the caller (it swaps in a
/// static filled speaker instead of mounting this view).
private struct VoiceEqualizerBars: View {
    var color: Color
    @State private var animating = false

    // (restHeight, peakHeight, period) per bar.
    private let bars: [(min: CGFloat, max: CGFloat, period: Double)] = [
        (4, 12, 0.52),
        (6, 15, 0.40),
        (3, 11, 0.64),
        (5, 13, 0.48)
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(bars.indices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: 2.5, height: animating ? bars[index].max : bars[index].min)
                    .animation(
                        .easeInOut(duration: bars[index].period).repeatForever(autoreverses: true),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
        .accessibilityHidden(true)
    }
}

struct ChatBubbleView: View {
    let text: String
    let isUser: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject private var voiceService = CaptainVoiceService.shared
    /// Hybrid voice router — the speaker tap routes `.premium` to this so
    /// MiniMax takes over when consent + feature flag + configuration allow.
    /// Observed for the mint-dot badge + accessibility label variant.
    @ObservedObject private var voiceRouter = CaptainVoiceRouter.shared
    /// Bumped on each speaker tap to retrigger the SF Symbol bounce.
    @State private var speakBounce = 0
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }
    private var canSpeakReply: Bool {
        !isUser && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var enhancedVoiceActive: Bool {
        voiceRouter.activeProvider == .miniMax && voiceRouter.isSpeaking
    }
    /// True only when THIS bubble's text is the one currently being spoken —
    /// scopes the live equalizer to the right row (router state is global).
    private var isThisBubbleSpeaking: Bool {
        voiceRouter.isSpeaking
            && voiceRouter.speakingText == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var speakerAccessibilityLabel: String {
        let arabic = AppSettingsStore.shared.appLanguage == .arabic
        if !voiceService.isTTSAvailable {
            return arabic ? "الصوت غير متاح" : "Audio unavailable"
        }
        if enhancedVoiceActive {
            return arabic ? "استمع بالصوت المحسّن" : "Play with enhanced voice"
        }
        return arabic ? "استمع بالصوت المحلي" : "Play with local voice"
    }

    // v1.1 brand tokens — Apple resubmission palette.
    private let mintFill = Color(red: 0.77, green: 0.94, blue: 0.86) // #C4F0DB
    private let sandFill = Color(red: 0.97, green: 0.84, blue: 0.64) // #F8D6A3
    private let ink      = Color(red: 0.059, green: 0.090, blue: 0.129) // #0F1721

    /// Cap on bubble width. Avoids `UIScreen.main` (deprecated in iOS 26) by
    /// keying off the size class instead — compact = phone, regular = iPad.
    private var maxBubbleWidth: CGFloat {
        sizeClass == .regular ? 520 : 300
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if isUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 6,
                topTrailingRadius: 18,
                style: .continuous
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 6,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18,
                style: .continuous
            )
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser { Spacer(minLength: 52) }

            VStack(alignment: isUser ? .leading : .trailing, spacing: 4) {
                Text.captainMessage(text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(ink)
                    .lineSpacing(3)
                    .multilineTextAlignment(isUser ? .leading : .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: maxBubbleWidth, alignment: isUser ? .leading : .trailing)
                    .background(
                        bubbleShape.fill(
                            LinearGradient(
                                colors: isUser
                                    ? [mintFill, mintFill.opacity(0.85)]
                                    : [sandFill, sandFill.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(isUser ? "User message" : "Captain message")
                    .accessibilityValue(text)

                if canSpeakReply {
                    Button {
                        // Free → Apple voice (Siri-like, on-device). Paid → MiniMax API voice.
                        HapticEngine.light()
                        speakBounce += 1
                        Task {
                            let isPaid = DevOverride.unlockAllFeatures || TierGate.shared.canAccess(.captainChat)
                            await CaptainVoiceRouter.shared.speak(text: text, tier: isPaid ? .premium : .realtime)
                        }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if isThisBubbleSpeaking, !UIAccessibility.isReduceMotionEnabled {
                                    // Live audio meter while this reply plays.
                                    VoiceEqualizerBars(color: ink.opacity(0.7))
                                } else {
                                    Image(systemName: isThisBubbleSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(ink.opacity(voiceService.isTTSAvailable ? 0.55 : 0.35))
                                        .symbolEffect(.bounce, value: speakBounce)
                                }
                            }
                            .frame(minWidth: 22, minHeight: 16)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            if enhancedVoiceActive {
                                Circle()
                                    .fill(AiQoColors.mintSoft)
                                    .frame(width: 4, height: 4)
                                    .offset(x: 1, y: 1)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(speakerAccessibilityLabel)
                }
            }

            if isUser { Spacer(minLength: 52) }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Streaming Captain Bubble

/// The live progressive-reveal row shown while the Captain's reply types out
/// in `CaptainScreen`. Mirrors `ChatBubbleView`'s assistant layout (right-
/// aligned in RTL, sand bubble, ink text) so when the reveal finishes and
/// the real row is appended, the swap is seamless — same text, same
/// position, no jump. Required because the parent screen hosts the workout
/// card inline; without an explicit streaming bubble, the Captain looks
/// mute between the user's message and the card while the text streams.
struct StreamingCaptainBubbleRow: View {
    let text: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let sandFill = Color(red: 0.97, green: 0.84, blue: 0.64) // #F8D6A3
    private let ink      = Color(red: 0.059, green: 0.090, blue: 0.129) // #0F1721

    private var maxBubbleWidth: CGFloat {
        sizeClass == .regular ? 520 : 300
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 6,
            bottomTrailingRadius: 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 52)

            HStack(alignment: .bottom, spacing: 3) {
                Text.captainMessage(text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(ink)
                    .lineSpacing(3)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                CaptainScreenStreamingCaret()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
            .background(
                bubbleShape.fill(
                    LinearGradient(
                        colors: [sandFill, sandFill.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Reveal caret for the streaming bubble. Named with the screen prefix so
/// it doesn't collide with the same-named primitive inside CaptainChatView.
private struct CaptainScreenStreamingCaret: View {
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color(hex: "5ECDB7"))
            .frame(width: 2, height: 16)
            .padding(.bottom, 2)
            .opacity(on ? 1 : 0.15)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
            .accessibilityHidden(true)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    let state: CoachCognitiveState

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    PulsingDot(tint: theme.spatialMint, delay: Double(index) * 0.18)
                }
            }

            Text(thinkingLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(theme.subtext.opacity(0.80))
                .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
        }
        .padding(.leading, 4)
    }

    private var thinkingLabel: String {
        let arabic = AppSettingsStore.shared.appLanguage == .arabic
        switch state {
        case .readingMessage:
            return arabic ? "الكابتن يقرا..." : "Captain is reading…"
        default:
            return arabic ? "الكابتن يفكر..." : "Captain is thinking…"
        }
    }
}

/// Cheap pulsing dot — single `@State` flip + CoreAnimation `.repeatForever`.
///
/// Replaces a `Timer.publish(...).autoconnect()` that used to be stored as an
/// instance property on `TypingIndicatorView`. Because SwiftUI reconstructs view
/// structs on every parent body pass, that pattern created a fresh timer (and
/// left stale ones live) on every `@Published` emission from the view model,
/// piling up 0.35 s main-thread ticks until the chat appeared frozen.
private struct PulsingDot: View {
    let tint: Color
    let delay: Double

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 5, height: 5)
            .scaleEffect(isPulsing ? 1.22 : 0.82)
            .opacity(isPulsing ? 0.98 : 0.30)
            .animation(
                .easeInOut(duration: 0.48)
                    .repeatForever()
                    .delay(delay),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
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
            let sinVal: Double = sin(primaryAngle)
            let pulseDouble: Double = 0.92 + (((sinVal + 1) * 0.5) * Double(state.pulseScale - 0.92))
            let pulse: CGFloat = CGFloat(pulseDouble)
            let cosVal: Double = cos(primaryAngle * 0.8)
            let haloDouble: Double = 1.04 + (((cosVal + 1) * 0.5) * 0.18)
            let haloScale: CGFloat = CGFloat(haloDouble)
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
                    .foregroundStyle(theme.subtext.opacity(0.8))

                Text(state.statusText ?? "الكابتن حاضر")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)

                Text(state.detailText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.subtext)
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

/// The Captain's outfit reflects tier — the SAME grown Hamoudi for everyone,
/// only the look changes: free wears the plain fit (`Hammoudi4`), paid (Max+)
/// wears the premium fit (`Hammoudi5`) and gets the living aura treatment
/// (`LivingCaptainAvatarView`). One fixed adult character protects the brand.
/// `DevOverride` unlocks the paid look.
enum CaptainAvatarAsset {
    static var current: String {
        (DevOverride.unlockAllFeatures || TierGate.shared.canAccess(.captainChat))
            ? "Hammoudi5"
            : "Hammoudi4"
    }
}

struct CaptainAvatarView: View {
    var breathes: Bool = true

    /// Re-render the moment entitlement changes so the Captain visibly "grows"
    /// right when the user subscribes (free `Hammoudi4` → paid `Hammoudi5`).
    @ObservedObject private var entitlements = EntitlementStore.shared
    @State private var breathingOffset: CGFloat = 0

    var body: some View {
        let _ = entitlements
        Image(CaptainAvatarAsset.current)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .offset(y: breathes ? breathingOffset : 0)
            .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
            .onAppear {
                guard breathes else { return }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathingOffset = -8
                }
            }
    }
}

// MARK: - Input View

/// Input bar with **local** text state.
///
/// Key perf fix: previously bound its `TextField` to `$viewModel.inputText`, a
/// `@Published` on `CaptainViewModel`. Every keystroke published the whole VM,
/// forcing `CaptainScreen` (GeometryReader + layout math + chat container) to
/// re-evaluate per character — that's what pinned CPU at 50% while typing.
/// Holding the text locally keeps each keystroke inside this subview.
struct CaptainInputView: View {
    var isSending: Bool
    var onSend: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $text,
                prompt: Text(NSLocalizedString("captain.input.prompt", value: "شنو هدفك اليوم؟", comment: ""))
                    .foregroundStyle(theme.subtext.opacity(0.75)),
                axis: .vertical
            )
            .focused($isFocused)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(theme.text)
            .lineLimit(1...4)
            .submitLabel(.send)
            .onSubmit(send)
            .padding(.leading, 18)
            .padding(.vertical, 16)

            Button(action: send) {
                ZStack {
                    Circle()
                        .fill(canSend ? theme.spatialMint.opacity(0.20) : Color.white.opacity(0.05))
                        .background(.ultraThinMaterial, in: Circle())

                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(canSend ? theme.spatialMint : theme.subtext.opacity(0.50))
                }
                .frame(width: 42, height: 42)
                .shadow(
                    color: theme.spatialMint.opacity(canSend ? 0.28 : 0),
                    radius: 14,
                    x: 0,
                    y: 8
                )
                .scaleEffect(isSending ? 0.94 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isSending)
            }
            .disabled(!canSend)
            .padding(.trailing, 8)
        }
        .frame(minHeight: 58)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.38), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 20, x: 0, y: 12)
        .padding(.horizontal, 22)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        text = ""
        isFocused = false
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
                                .foregroundStyle(theme.text)

                            Text(NSLocalizedString("captain.customize.subtitle", value: "Add your info to personalize the captain.", comment: ""))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.subtext)
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
                                .foregroundStyle(theme.subtext)

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
                                .foregroundStyle(.black)
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
                            .foregroundStyle(theme.subtext)
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
            prompt: Text(placeholder).foregroundStyle(theme.subtext.opacity(0.7))
        )
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundStyle(theme.text)
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
    CaptainScreen()
        .environmentObject(CaptainViewModel())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    CaptainScreen()
        .environmentObject(CaptainViewModel())
        .preferredColorScheme(.dark)
}
