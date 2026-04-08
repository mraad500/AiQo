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

    var body: some View {
        ZStack {
            CaptainBackgroundView()

            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        let layout = viewModel.layout(for: geometry.size.height)

                        VStack {
                            Spacer()

                            CaptainAvatar3DView()
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
        .safeAreaInset(edge: .top, spacing: 0) {
            topChrome
        }
        .fontDesign(.rounded)
        .onTapGesture { hideKeyboard() }
        .gesture(DragGesture().onChanged { _ in hideKeyboard() })
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

    private var topChrome: some View {
        AiQoScreenTopChrome(
            horizontalInset: 10,
            profileVerticalOffset: -3,
            onProfileTap: { viewModel.showProfile = true }
        ) {
            HStack {
                Text(NSLocalizedString("screen.captain.title", value: "Captain Hamoudi", comment: ""))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
                    .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)

                Spacer(minLength: 0)

                Button {
                    viewModel.showChatHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.subtext)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(theme.border, lineWidth: 0.7))
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
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
    private let thinkingIndicatorID = "captain-thinking-indicator"

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            ChatBubbleView(
                                text: message.content,
                                isUser: message.isUser,
                                maxBubbleWidth: geometry.size.width * 0.72
                            )
                            .id(message.id)
                        }

                        if isTyping {
                            HStack {
                                TypingIndicatorView(state: coachState)
                                Spacer()
                            }
                            .id(thinkingIndicatorID)
                            .padding(.top, 6)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 20)
                }
                .scrollDisabled(!scrollEnabled)
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    scrollToBottom(using: proxy, animated: false)
                }
                .onChange(of: messages.count) {
                    scrollToBottom(using: proxy)
                }
                .onChange(of: messages.last?.content) {
                    scrollToBottom(using: proxy)
                }
                .onChange(of: isTyping) {
                    scrollToBottom(using: proxy)
                }
            }
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        let targetID: AnyHashable? = isTyping ? AnyHashable(thinkingIndicatorID) : messages.last.map { AnyHashable($0.id) }
        guard let targetID else { return }

        guard animated else {
            proxy.scrollTo(targetID, anchor: .bottom)
            return
        }

        if #available(iOS 17.0, *) {
            withAnimation(.smooth(duration: 0.24)) {
                proxy.scrollTo(targetID, anchor: .bottom)
            }
        } else {
            withAnimation(.easeOut(duration: 0.24)) {
                proxy.scrollTo(targetID, anchor: .bottom)
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubbleView: View {
    let text: String
    let isUser: Bool
    let maxBubbleWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }
    private var canSpeakReply: Bool {
        !isUser && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 52) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 10) {
                Text(text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.chatBubbleText)
                    .lineSpacing(3)
                    .multilineTextAlignment(isUser ? .trailing : .leading)

                if canSpeakReply {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        Button {
                            Task {
                                await CaptainVoiceService.shared.speak(text: text)
                            }
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(7)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: maxBubbleWidth, alignment: isUser ? .trailing : .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUser ? theme.userBubble : theme.captainBubble)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill((isUser ? theme.userBubble : theme.captainBubble).opacity(colorScheme == .dark ? 0.10 : 0.20))
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(isUser ? "User message" : "Captain message")
            .accessibilityValue(text)

            if !isUser { Spacer(minLength: 52) }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    let state: CoachCognitiveState

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(theme.spatialMint.opacity(phase == index ? 0.98 : 0.30))
                        .frame(width: 5, height: 5)
                        .scaleEffect(phase == index ? 1.22 : 0.82)
                        .blur(radius: phase == index ? 0.2 : 0)
                        .blendMode(.screen)
                        .animation(.easeInOut(duration: 0.24), value: phase)
                }
            }

            Text(thinkingLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(theme.subtext.opacity(0.80))
                .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
        }
        .padding(.leading, 4)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }

    private var thinkingLabel: String {
        switch state {
        case .readingMessage:
            return "الكابتن يقرا..."
        default:
            return "الكابتن يفكر..."
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
                    .foregroundStyle(theme.subtext.opacity(0.75)),
                axis: .vertical
            )
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(theme.text)
            .lineLimit(1...4)
            .submitLabel(.send)
            .onSubmit(onSend)
            .padding(.leading, 18)
            .padding(.vertical, 16)

            Button(action: onSend) {
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
