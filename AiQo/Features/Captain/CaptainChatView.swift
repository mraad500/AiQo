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

    /// Hoisted from `ChatComposerBar` so the chat view can react to focus
    /// transitions — specifically to re-pin the scroll to the latest
    /// message when the keyboard rises. Without this, a new Captain reply
    /// arriving *while the user is typing* lands behind the keyboard
    /// because the scroll position still reflects the pre-keyboard layout.
    @FocusState private var inputFocused: Bool

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
                .scrollDismissesKeyboard(.interactively)
                .safeAreaPadding(.bottom, 8)
                .onAppear {
                    scrollToBottom(using: proxy, animated: false)
                }
                .onChange(of: globalBrain.messages.count) {
                    // One layout pass before scrolling so the just-appended
                    // message has a real frame to anchor against. Without
                    // the yield, the scroll fires against stale geometry
                    // and the new bubble lands behind the composer.
                    Task { @MainActor in
                        await Task.yield()
                        scrollToBottom(using: proxy)
                    }
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
                // Keyboard appears → re-pin the scroll to the bottom so
                // the most recent message stays visible above the rising
                // composer. The 0.32s delay matches the system keyboard
                // animation; scrolling earlier targets the pre-keyboard
                // safe-area inset and lands the message behind the keys.
                .onChange(of: inputFocused) { _, focused in
                    guard focused else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(320))
                        scrollToBottom(using: proxy)
                    }
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
            ChatComposerBar(
                isSending: globalBrain.isLoading,
                isFocused: $inputFocused
            ) { text in
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
                let isUser = message.isUser
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
                    enhancedVoiceActive: voiceRouter.activeProvider == .miniMax && voiceRouter.isSpeaking,
                    isVoicePlaying: voiceRouter.isSpeaking
                        && voiceRouter.speakingTextHash == message.text.trimmingCharacters(in: .whitespacesAndNewlines).hashValue
                )
                .id(message.id)
                .padding(.bottom, spacing(forIndex: index))
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .scale(scale: 0.94, anchor: isUser ? .bottomTrailing : .bottomLeading))
                            .combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    )
                )

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
                CaptainTypingRow(coachState: globalBrain.coachState)
                    .id("typing-indicator")
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.92, anchor: .bottomLeading))),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
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
                ForEach(Array(globalBrain.quickReplies.enumerated()), id: \.element) { index, reply in
                    QuickReplyChip(
                        text: reply,
                        index: index
                    ) {
                        HapticEngine.selection()
                        globalBrain.sendMessage(reply)
                    }
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
    /// True when the voice router is currently sounding THIS message.
    /// Drives the speaker → waveform morph and the mint border highlight on
    /// the bubble so the user can spot the active utterance at a glance.
    var isVoicePlaying: Bool = false

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
                    .overlay(
                        Circle()
                            .stroke(Color.aiqoMint.opacity(isVoicePlaying ? 0.85 : 0), lineWidth: 2)
                            .scaleEffect(isVoicePlaying ? 1.18 : 1.0)
                            .opacity(isVoicePlaying ? 0.9 : 0)
                            .animation(
                                isVoicePlaying
                                    ? .easeOut(duration: 1.2).repeatForever(autoreverses: false)
                                    : .easeOut(duration: 0.2),
                                value: isVoicePlaying
                            )
                    )

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
                                        Group {
                                            if isVoicePlaying {
                                                // Live waveform replaces the static speaker icon
                                                // while THIS message is the one being spoken.
                                                VoiceWaveform(color: Color.black.opacity(0.78))
                                                    .frame(width: 18, height: 14)
                                                    .transition(.scale.combined(with: .opacity))
                                            } else {
                                                Image(systemName: "speaker.wave.2")
                                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(Color.black.opacity(ttsDimmed ? 0.4 : 0.68))
                                                    .transition(.scale.combined(with: .opacity))
                                            }
                                        }
                                        .frame(width: 18, height: 14)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(ttsDimmed ? 0.18 : (isVoicePlaying ? 0.55 : 0.34)))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    isVoicePlaying ? Color.aiqoMint.opacity(0.85) : Color.clear,
                                                    lineWidth: 1.4
                                                )
                                        )
                                        .scaleEffect(isVoicePlaying ? 1.06 : 1)
                                        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isVoicePlaying)

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
                .scaleEffect(isVoicePlaying ? 1.014 : 1)
                .shadow(color: isVoicePlaying ? Color.aiqoMint.opacity(0.28) : .clear, radius: isVoicePlaying ? 14 : 0, x: 0, y: 4)
                .animation(.spring(response: 0.4, dampingFraction: 0.78), value: isVoicePlaying)

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

/// Smart typing indicator that reflects the Captain's current cognitive state.
/// Falls back to neutral "Captain is thinking" copy when the cognitive timeline
/// hasn't transitioned yet (e.g. very early in the request) so the bubble never
/// appears empty on screen.
private struct CaptainTypingRow: View {
    let coachState: CoachCognitiveState

    @State private var avatarPulse = false

    private var isArabic: Bool {
        AppSettingsStore.shared.appLanguage == .arabic
    }

    private var resolvedStatusText: String {
        if let live = coachState.statusText { return live }
        return isArabic ? "الكابتن يفكر…" : "Captain is thinking…"
    }

    private var resolvedSymbol: String {
        coachState == .idle ? "ellipsis.bubble.fill" : coachState.symbolName
    }

    private var ringColor: Color {
        coachState.accentColors.first ?? Color(hex: "5ECDB7")
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.55), lineWidth: 2)
                    .scaleEffect(avatarPulse ? 1.18 : 1.0)
                    .opacity(avatarPulse ? 0 : 0.85)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: avatarPulse
                    )
                CaptainChatAvatarView(size: 28)
            }
            .frame(width: 28, height: 28)

            HStack(spacing: 10) {
                Image(systemName: resolvedSymbol)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: coachState.accentColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.symbolEffect(.replace.byLayer))
                    .animation(.spring(response: 0.4, dampingFraction: 0.78), value: coachState)

                Text(resolvedStatusText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary.opacity(0.78))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .id(resolvedStatusText)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        TypingDot(
                            delay: Double(index) * 0.16,
                            color: ringColor
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: "F7EAD7").opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [ringColor.opacity(0.42), Color.white.opacity(0.72)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)

            Spacer(minLength: 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { avatarPulse = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resolvedStatusText)
    }
}

private struct TypingDot: View {
    let delay: Double
    var color: Color = Color(hex: "5ECDB7")

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
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
    /// Focus binding hoisted to `CaptainChatView` so the parent can react
    /// to keyboard show/hide and re-pin the scroll. The composer still
    /// owns the underlying `@FocusState`; the parent just observes it.
    var isFocused: FocusState<Bool>.Binding
    let onSend: (String) -> Void

    @State private var text: String = ""
    @State private var sendPressed = false

    private let charSoftLimit = 480

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(height: 8)

            HStack(alignment: .bottom, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    TextField(composerPlaceholder, text: $text, axis: .vertical)
                        .focused(isFocused)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .submitLabel(.send)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        .lineLimit(1...5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(isFocused.wrappedValue ? 0.74 : 0.56))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: isFocused.wrappedValue
                                            ? [Color.aiqoMint.opacity(0.85), Color(hex: "EBCF97").opacity(0.55)]
                                            : [Color.white.opacity(0.68), Color.white.opacity(0.68)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isFocused.wrappedValue ? 1.4 : 1
                                )
                        )
                        .shadow(
                            color: isFocused.wrappedValue ? Color.aiqoMint.opacity(0.22) : .clear,
                            radius: isFocused.wrappedValue ? 10 : 0,
                            y: 0
                        )
                        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isFocused.wrappedValue)
                        .onSubmit(send)

                    if charCount >= charSoftLimit - 80 {
                        Text("\(charCount)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(charCount > charSoftLimit ? Color.red.opacity(0.75) : AiQoTheme.Colors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.white.opacity(0.7))
                            )
                            .padding(.top, 6)
                            .padding(.trailing, 10)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeOut(duration: 0.18), value: charCount >= charSoftLimit - 80)

                sendButton
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

    /// Morphing send button:
    /// - Empty / disabled: dim, neutral
    /// - Has text + idle: gradient mint, paperplane
    /// - Sending: gradient mint, spinning progress ring
    private var sendButton: some View {
        Button {
            send()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDisabled
                                ? [Color.gray.opacity(0.18), Color.gray.opacity(0.10)]
                                : [
                                    AiQoTheme.Colors.ctaGradientLeading,
                                    AiQoTheme.Colors.ctaGradientTrailing
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if isSending {
                    SendSpinner(color: Color(hex: "113238"))
                        .transition(.opacity.combined(with: .scale))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "113238"))
                        .rotationEffect(.degrees(isFocused.wrappedValue && !trimmed.isEmpty ? 0 : 12))
                        .offset(x: isFocused.wrappedValue && !trimmed.isEmpty ? 1 : 0)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(width: 50, height: 50)
            .scaleEffect(sendPressed ? 0.9 : 1)
            .shadow(color: isDisabled ? .clear : Color.aiqoMint.opacity(0.32), radius: 14, x: 0, y: 7)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSending)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDisabled)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: sendPressed)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(sendAccessibilityLabel)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !sendPressed && !isDisabled { sendPressed = true }
                }
                .onEnded { _ in
                    sendPressed = false
                }
        )
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var charCount: Int { text.count }

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
        if isSending { return isArabic ? "جاري الإرسال" : "Sending" }
        return isArabic ? "إرسال الرسالة" : "Send message"
    }

    private func send() {
        let message = trimmed
        guard !message.isEmpty, !isSending else { return }
        HapticEngine.success()
        onSend(message)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            text = ""
        }
        isFocused.wrappedValue = false
    }
}

/// Indeterminate spinner used while a chat send is in flight. Avoids the iOS
/// stock `ProgressView` so the stroke colour blends with the send-button
/// gradient and the rotation speed matches the app's spring vocabulary.
private struct SendSpinner: View {
    let color: Color
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.92)
            .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            .frame(width: 18, height: 18)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

/// Tappable suggestion chip beneath the latest Captain message. Stagger-fades
/// in based on its index so a fresh batch of replies cascades in instead of
/// popping all at once. Press effect uses the shared `AiQoPressButtonStyle`
/// for haptic-feeling spring scale.
private struct QuickReplyChip: View {
    let text: String
    let index: Int
    let action: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        Button(action: action) {
            Text(text)
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
        .accessibilityLabel(text)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 8)
        .onAppear {
            withAnimation(
                .spring(response: 0.42, dampingFraction: 0.82)
                    .delay(Double(index) * 0.06)
            ) {
                hasAppeared = true
            }
        }
    }
}

/// Animated five-bar audio waveform — mirrors the active utterance while the
/// router is sounding a Captain message. Each bar oscillates on its own phase
/// so the rhythm reads as voice-like, not a metronome. Replaces the static
/// `speaker.wave.2` SF Symbol while playback is active.
private struct VoiceWaveform: View {
    let color: Color
    @State private var phase: CGFloat = 0

    private let bars = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<bars, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.2, height: barHeight(for: index, time: timeline.date.timeIntervalSinceReferenceDate))
                }
            }
            .frame(width: 18, height: 14)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let speed: Double = 4.6
        let phaseOffset = Double(index) * 0.7
        let raw = sin(time * speed + phaseOffset)
        let normalized = (raw + 1) / 2
        return 4 + CGFloat(normalized) * 8
    }
}

#Preview {
    NavigationStack {
        CaptainChatView()
    }
    .environmentObject(CaptainViewModel())
}
