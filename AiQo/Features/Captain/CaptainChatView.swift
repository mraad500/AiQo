import SwiftUI
import UIKit

struct CaptainChatView: View {
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @ObservedObject private var consentManager = AIDataConsentManager.shared
    @ObservedObject private var voiceService = CaptainVoiceService.shared
    /// Hybrid voice router — dispatches speaker-icon taps to either Apple TTS
    /// (default) or MiniMax (commit 2, consent-gated). Observed so the
    /// `enhancedVoiceActive` badge and accessibility label reflect live state.
    @ObservedObject private var voiceRouter = CaptainVoiceRouter.shared
    @ObservedObject private var voiceConsent = CaptainVoiceConsent.shared
    @State private var showAIPrivacySettings = false
    @State private var showHealthSources = false
    /// First speaker tap presents the cloud-voice consent sheet rather than
    /// silently falling back to Apple TTS — discoverability fix for the
    /// "I configured the MiniMax key but voice still uses Apple" case.
    @State private var showVoiceConsent = false

    private let bottomAnchorID = "captain-chat-bottom"

    /// v1.1 kill switch — Info.plist `AIQO_CHAT_V1_1_ENABLED`. When off, the
    /// new fixed header + persistent safety banner retract and the chat falls
    /// back to a scroll-embedded header like v1.0 so Apple Review can see the
    /// pre-v1.1 UX if we need to roll back without shipping a new binary.
    private var isChatV1_1Enabled: Bool { FeatureFlags.captainChatV1_1Enabled }

    var body: some View {
        VStack(spacing: 0) {
            if isChatV1_1Enabled {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                CaptainSafetyBanner()
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    messagesList
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.immediately)
                .safeAreaPadding(.bottom, 8)
                .onAppear {
                    scrollToBottom(using: proxy, animated: false)
                }
                .onChange(of: globalBrain.messages.count) {
                    scrollToBottom(using: proxy)
                }
                .onChange(of: globalBrain.isLoading) { _, thinking in
                    if thinking {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        }
                    } else {
                        scrollToBottom(using: proxy)
                    }
                }
                .onChange(of: globalBrain.currentWorkoutPlan != nil) {
                    scrollToBottom(using: proxy)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = voiceService.displayedToast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 96)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: voiceService.displayedToast)
        .navigationTitle(isChatV1_1Enabled ? "" : "Captain Hamoudi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isChatV1_1Enabled ? .hidden : .visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposerBar(isSending: globalBrain.isLoading) { text in
                globalBrain.sendMessage(text, context: .mainChat)
            }
        }
        .background(CaptainChatBackground())
        .fullScreenCover(isPresented: $globalBrain.showGratitudeSession) {
            GratitudeSessionView()
        }
        .sheet(isPresented: $globalBrain.showChatHistory) {
            ChatHistoryView()
                .environmentObject(globalBrain)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAIPrivacySettings) {
            NavigationStack {
                AIDataPrivacySettingsView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showHealthSources) {
            HealthSourcesView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $globalBrain.showPaywall) {
            PaywallView(source: .captainGate)
        }
        .sheet(isPresented: $showVoiceConsent) {
            VoiceConsentSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        // Reactive presentation — any speaker tap (this view OR any other
        // future entry point) that hits `consent_missing` will publish on
        // the router, and we surface the sheet here. Belt-and-suspenders
        // with the predictive guard above on `onSpeak`.
        .onChange(of: voiceRouter.needsConsent) { _, needsIt in
            guard needsIt else { return }
            showVoiceConsent = true
            voiceRouter.acknowledgeConsentRequest()
        }
        .onAppear {
            globalBrain.generateMorningSleepAnalysis()
        }
        .onDisappear {
            AppRootManager.shared.dismissCaptainChat()
        }
    }
}

private extension CaptainChatView {

    // MARK: - Header

    private var isArabicUI: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    var headerBar: some View {
        HStack(spacing: 10) {
            Button {
                globalBrain.showChatHistory = true
            } label: {
                headerIcon("clock.arrow.circlepath")
            }
            .accessibilityLabel(isArabicUI ? "سجل المحادثات" : "Chat history")

            Button {
                showHealthSources = true
            } label: {
                headerIcon("book.closed")
            }
            .accessibilityLabel(isArabicUI ? "الدليل" : "Health sources")

            Spacer()

            VStack(spacing: 2) {
                Text(isArabicUI ? "كابتن حمودي" : "Captain Hamoudi")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                Text(statusSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }

            Spacer()

            CaptainChatAvatarView(size: 36)
                .accessibilityLabel(isArabicUI ? "صورة كابتن حمودي" : "Captain Hamoudi avatar")
        }
        .frame(height: 56)
        .accessibilityElement(children: .contain)
    }

    private var statusSubtitle: String {
        if globalBrain.isLoading {
            return isArabicUI ? "يفكر الحين" : "Thinking…"
        }
        return isArabicUI ? "متصل الآن" : "Online now"
    }

    private var legacyStatusText: String {
        if globalBrain.isLoading {
            return isArabicUI ? "يفكر هسه" : "Thinking"
        }
        return isArabicUI ? "جاهز" : "Ready"
    }

    private func headerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(AiQoTheme.Colors.textSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    /// v1.0 scroll-embedded header. Surfaced only when the v1.1 kill switch is
    /// off so the old UX can return without shipping a new binary.
    var legacyHeaderCard: some View {
        HStack(spacing: 12) {
            CaptainChatAvatarView(size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Captain Hamoudi")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)

                Text("مدربك العراقي الذكي للتمارين اليومية")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }

            Spacer()

            Button {
                globalBrain.showChatHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.aiqoMint)
                    .frame(width: 8, height: 8)
                Text(legacyStatusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.22))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    // MARK: - Messages list

    @ViewBuilder
    var messagesList: some View {
        LazyVStack(spacing: 0) {
            if !isChatV1_1Enabled {
                legacyHeaderCard
                    .padding(.bottom, 14)
                HealthComplianceCard(compact: true)
                    .padding(.bottom, 14)
            }

            if consentManager.isInOfflineOnlyMode {
                CaptainOfflineModeBanner {
                    showAIPrivacySettings = true
                }
                .padding(.bottom, 12)
            }

            ForEach(Array(globalBrain.messages.enumerated()), id: \.element.id) { index, message in
                ChatMessageRow(
                    message: message,
                    onAppearRead: message.isEphemeral && !message.isRead ? {
                        globalBrain.markEphemeralMessageRead(messageID: message.id)
                    } : nil,
                    onSpeak: message.isUser ? nil : {
                        // Cloud voice requires a one-time user consent. If
                        // it has not been granted yet, surface the sheet
                        // here instead of letting the router silently fall
                        // back to Apple TTS — the user pressed the speaker
                        // because they want voice, hiding the gate behind
                        // Settings makes that intent unreachable.
                        if FeatureFlags.captainVoiceCloudEnabled,
                           !voiceConsent.isGranted {
                            showVoiceConsent = true
                            return
                        }
                        Task {
                            await CaptainVoiceRouter.shared.speak(text: message.text, tier: .premium)
                        }
                    },
                    onAccessoryTap: message.accessory == .morningGratitude ? {
                        globalBrain.startMorningGratitudeSession()
                    } : nil,
                    ttsDimmed: !voiceService.isTTSAvailable,
                    enhancedVoiceActive: voiceRouter.activeProvider == .miniMax && voiceRouter.isSpeaking
                )
                .id(message.id)
                .padding(.bottom, spacing(forIndex: index))

                if !message.isUser, let spotifyRec = message.spotifyRecommendation {
                    VibeMiniBubble(
                        vibeName: spotifyRec.vibeName,
                        description: spotifyRec.description
                    ) {
                        SpotifyVibeManager.shared.playVibe(
                            uri: spotifyRec.spotifyURI,
                            vibeTitle: spotifyRec.vibeName
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.leading, 38)
                    .padding(.bottom, 12)
                }
            }

            if let plan = globalBrain.currentWorkoutPlan {
                WorkoutPlanReadyCard(plan: plan)
                    .padding(.top, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if globalBrain.isLoading {
                CaptainTypingRow()
                    .id("typing-indicator")
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }

            if !globalBrain.quickReplies.isEmpty && !globalBrain.isTyping {
                quickReplyRow
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: globalBrain.quickReplies)
            }

            Color.clear
                .frame(height: 1)
                .id(bottomAnchorID)
        }
    }

    private func spacing(forIndex index: Int) -> CGFloat {
        let messages = globalBrain.messages
        guard index < messages.count - 1 else { return 8 }
        let sameRole = messages[index].isUser == messages[index + 1].isUser
        return sameRole ? 6 : 18
    }

    var quickReplyRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(globalBrain.quickReplies, id: \.self) { reply in
                    Button {
                        HapticEngine.light()
                        globalBrain.sendMessage(reply)
                    } label: {
                        Text(reply)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "EBCF97"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "EBCF97").opacity(0.15))
                                    .overlay(Capsule().stroke(Color(hex: "EBCF97").opacity(0.3), lineWidth: 1))
                            )
                    }
                    .buttonStyle(AiQoPressButtonStyle())
                    .accessibilityLabel(reply)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        let scrollAction = {
            if let lastMessageID = globalBrain.messages.last?.id {
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }

        guard animated else {
            scrollAction()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollAction()
        }
    }
}

private struct CaptainOfflineModeBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AuthFlowTheme.sand)
                .frame(width: 22, height: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("captain.offlineBanner.title", comment: ""))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("captain.offlineBanner.body", comment: ""))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onOpenSettings) {
                HStack(spacing: 4) {
                    Text(NSLocalizedString("captain.offlineBanner.action", comment: ""))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(AuthFlowTheme.sand)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("captain-offline-banner-settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AuthFlowTheme.sand.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AuthFlowTheme.sand, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    var onAppearRead: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onAccessoryTap: (() -> Void)?
    var ttsDimmed: Bool = false
    /// True when the `CaptainVoiceRouter` is currently routing through the
    /// MiniMax cloud provider. Drives the subtle mint badge on the speaker
    /// icon and the "enhanced voice" accessibility label variant.
    var enhancedVoiceActive: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isUser {
                Spacer(minLength: 26)

                MessageBubble(isUser: true, timestamp: message.timestamp) {
                    Text(message.text)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.trailing)
                }
            } else {
                CaptainChatAvatarView(size: 28)

                MessageBubble(isUser: false, timestamp: message.timestamp) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(message.text)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.leading)

                        if let accessory = message.accessory,
                           let onAccessoryTap {
                            Button(action: onAccessoryTap) {
                                Text(accessory.buttonTitle)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.white.opacity(0.34))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if let onSpeak, !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack {
                                Spacer(minLength: 0)

                                Button(action: onSpeak) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(systemName: "speaker.wave.2")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.black.opacity(ttsDimmed ? 0.4 : 0.68))
                                            .padding(8)
                                            .background(
                                                Circle()
                                                    .fill(Color.white.opacity(ttsDimmed ? 0.18 : 0.34))
                                            )
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
                                .accessibilityLabel(speakerAccessibilityLabel(
                                    ttsDimmed: ttsDimmed,
                                    enhancedVoiceActive: enhancedVoiceActive
                                ))
                            }
                        }
                    }
                }

                Spacer(minLength: 26)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .onAppear {
            onAppearRead?()
        }
    }

    private func speakerAccessibilityLabel(ttsDimmed: Bool, enhancedVoiceActive: Bool) -> String {
        let arabic = AppSettingsStore.shared.appLanguage == .arabic
        if ttsDimmed {
            return arabic ? "الصوت غير متاح" : "Audio unavailable"
        }
        if enhancedVoiceActive {
            return arabic ? "استمع بالصوت المحسّن" : "Play with enhanced voice"
        }
        return arabic ? "استمع بالصوت المحلي" : "Play with local voice"
    }
}

private struct CaptainTypingRow: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            CaptainChatAvatarView(size: 28)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    TypingDot(delay: Double(index) * 0.18)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: "F7EAD7").opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)

            Spacer(minLength: 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            AppSettingsStore.shared.appLanguage == .arabic ? "الكابتن يكتب" : "Captain is typing"
        )
    }
}

private struct TypingDot: View {
    let delay: Double

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color(hex: "5ECDB7"))
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1 : 0.55)
            .opacity(isAnimating ? 1 : 0.35)
            .offset(y: isAnimating ? -3 : 3)
            .animation(
                .easeInOut(duration: 0.7)
                    .repeatForever()
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

private struct WorkoutPlanReadyCard: View {
    let plan: WorkoutPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFF2B5"),
                                    Color(hex: "CFF7EC")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "57411D"))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("🎯 خطة التمرين جاهزة")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)

                    Text(plan.displayTitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                }

                Spacer()
            }

            if !plan.exercisePreview.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(Array(plan.exercisePreview.enumerated()), id: \.offset) { _, exercise in
                        Text(exercise)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.48))
                            )
                    }
                }
            }

            Text(plan.displayOverview)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.aiqoMint.opacity(0.34),
                                    Color.aiqoLemon.opacity(0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}

private struct CaptainChatAvatarView: View {
    let size: CGFloat

    private var captainImage: UIImage? {
        UIImage(named: "Hammoudi5")
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFF0D8"),
                            Color(hex: "D8F8ED")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let captainImage {
                Image(uiImage: captainImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color(hex: "4D3B28"))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(red: 0.718, green: 0.898, blue: 0.824).opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
}

private struct CaptainChatBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AiQoTheme.Colors.primaryBackground,
                    Color(hex: "EFF8F5"),
                    Color(hex: "FFF6EC")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.aiqoMint.opacity(colorScheme == .dark ? 0.16 : 0.28))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -120, y: -240)

            Circle()
                .fill(Color.aiqoBeige.opacity(colorScheme == .dark ? 0.14 : 0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 150, y: -180)

            Circle()
                .fill(Color(hex: "DCEBFF").opacity(colorScheme == .dark ? 0.12 : 0.24))
                .frame(width: 240, height: 240)
                .blur(radius: 72)
                .offset(x: 120, y: 220)
        }
    }
}

private extension WorkoutPlan {
    var displayTitle: String {
        title.isEmpty ? "خطة مخصصة من الكابتن" : title
    }

    var displayOverview: String {
        if exercises.isEmpty {
            return "رتبلك الكابتن خطة بداية. افتح شاشة الخطة وابدأ أول تمرين."
        }

        return exercises
            .prefix(3)
            .map(\.displaySummary)
            .joined(separator: " • ")
    }

    var exercisePreview: [String] {
        Array(exercises.prefix(4).map(\.displaySummary))
    }
}

private extension Exercise {
    var displaySummary: String {
        "\(name) • \(sets)x\(repsOrDuration)"
    }
}

/// Input composer bar with **local** text state.
///
/// Key perf fix: the TextField used to bind to `$globalBrain.inputText`, which is
/// `@Published`. Every keystroke re-published the whole `CaptainViewModel`, forcing
/// `CaptainChatView` and every `ChatMessageRow` inside it to re-evaluate — that's
/// why opening the keyboard pinned one core at 50% and sending spiked to 100%.
/// Holding the text and focus state locally keeps each keystroke inside this
/// subview; the only time anything escapes to the VM is when the user taps send.
private struct ChatComposerBar: View {
    let isSending: Bool
    let onSend: (String) -> Void

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(height: 8)

            HStack(alignment: .bottom, spacing: 12) {
                TextField(composerPlaceholder, text: $text, axis: .vertical)
                    .focused($isFocused)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.send)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.56))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.68), lineWidth: 1)
                    )
                    .onSubmit(send)

                Button(action: send) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AiQoTheme.Colors.ctaGradientLeading,
                                        AiQoTheme.Colors.ctaGradientTrailing
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "113238"))
                            .rotationEffect(.degrees(12))
                    }
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 7)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.55 : 1)
                .accessibilityLabel(sendAccessibilityLabel)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: -6)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(UIColor.systemGroupedBackground).opacity(0.78),
                    Color(UIColor.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDisabled: Bool {
        trimmed.isEmpty || isSending
    }

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var composerPlaceholder: String {
        isArabic ? "اكتب رسالتك للكابتن..." : "Write your message to the captain…"
    }

    private var sendAccessibilityLabel: String {
        isArabic ? "إرسال الرسالة" : "Send message"
    }

    private func send() {
        let message = trimmed
        guard !message.isEmpty else { return }
        onSend(message)
        text = ""
        isFocused = false
    }
}

#Preview {
    NavigationStack {
        CaptainChatView()
    }
    .environmentObject(CaptainViewModel())
}
