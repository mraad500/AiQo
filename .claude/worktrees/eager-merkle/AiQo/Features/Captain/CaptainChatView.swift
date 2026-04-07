import SwiftUI
import UIKit

struct CaptainChatView: View {
    @EnvironmentObject private var globalBrain: CaptainViewModel
    @FocusState private var isInputFocused: Bool

    private let bottomAnchorID = "captain-chat-bottom"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 14) {
                        headerCard

                        ForEach(globalBrain.messages) { message in
                            ChatMessageRow(
                                message: message,
                                onAppearRead: message.isEphemeral && !message.isRead ? {
                                    globalBrain.markEphemeralMessageRead(messageID: message.id)
                                } : nil,
                                onSpeak: message.isUser ? nil : {
                                    Task {
                                        await CaptainVoiceService.shared.speak(text: message.text)
                                    }
                                },
                                onAccessoryTap: message.accessory == .morningGratitude ? {
                                    globalBrain.startMorningGratitudeSession()
                                } : nil
                            )
                            .id(message.id)
                        }

                        if let plan = globalBrain.currentWorkoutPlan {
                            WorkoutPlanReadyCard(plan: plan)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if globalBrain.isLoading {
                            CaptainTypingRow()
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Quick Reply Chips
                        if !globalBrain.quickReplies.isEmpty && !globalBrain.isTyping {
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
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: globalBrain.quickReplies)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    // CHANGED: horizontal padding from 14 to 16pt — messages flow directly on screen background, no container box
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
                    scrollToBottom(using: proxy)
                }
                .onChange(of: globalBrain.isLoading) {
                    scrollToBottom(using: proxy)
                }
                .onChange(of: globalBrain.currentWorkoutPlan != nil) {
                    scrollToBottom(using: proxy)
                }
                .onChange(of: isInputFocused) {
                    guard isInputFocused else { return }
                    scrollToBottom(using: proxy)
                }
            }
        }
        .navigationTitle("Captain Hamoudi")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerBar
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
        .onAppear {
            globalBrain.generateMorningSleepAnalysis()
        }
        .onDisappear {
            AppRootManager.shared.dismissCaptainChat()
        }
    }
}

private extension CaptainChatView {
    // CHANGED: Title HStack is now leading-aligned (shifts left on screen in RTL context)
    var headerCard: some View {
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
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
                    )
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.aiqoMint)
                    .frame(width: 8, height: 8)
                Text(globalBrain.isLoading ? "يفكر هسه" : "جاهز")
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
        // CHANGED: leading-aligned instead of centered, pushes title toward left side of screen
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    var composerBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(height: 8)

            HStack(alignment: .bottom, spacing: 12) {
                TextField("اكتب رسالتك للكابتن...", text: $globalBrain.inputText, axis: .vertical)
                    .focused($isInputFocused)
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
                    .onSubmit {
                        sendCurrentMessage()
                    }

                Button(action: sendCurrentMessage) {
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
                .disabled(trimmedInput.isEmpty || globalBrain.isLoading)
                .opacity(trimmedInput.isEmpty || globalBrain.isLoading ? 0.55 : 1)
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

    var trimmedInput: String {
        globalBrain.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func sendCurrentMessage() {
        let message = trimmedInput
        guard !message.isEmpty else { return }

        globalBrain.sendMessage(message, context: .mainChat)
        isInputFocused = false
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

private struct ChatMessageRow: View {
    let message: ChatMessage
    var onAppearRead: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onAccessoryTap: (() -> Void)?

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
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.black.opacity(0.68))
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.34))
                                        )
                                }
                                .buttonStyle(.plain)
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
    }
}

private struct TypingDot: View {
    let delay: Double

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color(hex: "B99973"))
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
        UIImage(named: "imageKitchenHamoudi")
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
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
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

#Preview {
    NavigationStack {
        CaptainChatView()
    }
    .environmentObject(CaptainViewModel())
}
