import SwiftUI
import UIKit

struct DJCaptainChatView: View {
    @EnvironmentObject var captainBrain: CaptainViewModel
    @FocusState private var isComposerFocused: Bool
    @State private var draftText = ""

    private let bottomAnchorID = "dj-captain-chat-bottom"

    var body: some View {
        ZStack {
            DJCaptainChatBackground()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        headerCard

                        ForEach(captainBrain.messages) { message in
                            DJCaptainMessageRow(message: message)
                                .id(message.id)
                        }

                        if captainBrain.isLoading {
                            DJCaptainTypingRow()
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    scrollToBottom(using: proxy, animated: false)
                }
                .onChange(of: captainBrain.messages.count) { _, _ in
                    scrollToBottom(using: proxy)
                }
                .onChange(of: captainBrain.isLoading) { _, _ in
                    scrollToBottom(using: proxy)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerBar
        }
    }
}

private extension DJCaptainChatView {
    var headerCard: some View {
        HStack(spacing: 12) {
            DJCaptainAvatarView(size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("dj.title", comment: ""))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(headerStatusText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.76))
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(captainBrain.isLoading ? Color.aiqoBeige : Color.aiqoMint)
                    .frame(width: 8, height: 8)

                Text(captainBrain.isLoading ? NSLocalizedString("dj.thinking", comment: "") : NSLocalizedString("dj.ready", comment: ""))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.76))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
        }
        .padding(16)
        .background(headerBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    var headerStatusText: String {
        captainBrain.coachState.statusText ?? NSLocalizedString("dj.headerFallback", comment: "")
    }

    var headerBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.aiqoMint.opacity(0.18),
                        Color.aiqoBeige.opacity(0.14),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
    }

    var composerBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 10)

            HStack(alignment: .bottom, spacing: 12) {
                TextField(NSLocalizedString("dj.placeholder", comment: ""), text: $draftText, axis: .vertical)
                    .focused($isComposerFocused)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.send)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .onSubmit {
                        sendCurrentMessage()
                    }

                Button(action: sendCurrentMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.aiqoMint,
                                        Color.aiqoLemon
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.8))
                            .rotationEffect(.degrees(10))
                    }
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.aiqoMint.opacity(0.28), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .disabled(trimmedDraft.isEmpty || captainBrain.isLoading)
                .opacity(trimmedDraft.isEmpty || captainBrain.isLoading ? 0.56 : 1)
                .accessibilityLabel("أرسل الرسالة")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.14),
                    Color.black.opacity(0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    var trimmedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func sendCurrentMessage() {
        let text = trimmedDraft
        guard !text.isEmpty else { return }

        captainBrain.sendMessage(text, context: .myVibe)
        draftText = ""
        isComposerFocused = false
    }

    func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard animated else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            return
        }

        withAnimation(.easeOut(duration: 0.24)) {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct DJCaptainMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isUser {
                Spacer(minLength: 52)

                Text(message.text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(userBubbleBackground)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                    .frame(maxWidth: 420, alignment: .trailing)
            } else {
                DJCaptainAvatarView(size: 34)

                assistantContent
                .frame(maxWidth: 420, alignment: .leading)

                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var assistantContent: some View {
        if let recommendation = message.spotifyRecommendation {
            VStack(alignment: .leading, spacing: 14) {
                Text(message.text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .multilineTextAlignment(.leading)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color(hex: "BCE2C6").opacity(0.34),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                SpotifyVibeCard(
                    recommendation: recommendation,
                    presentation: .embedded
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding(16)
            .background(captainBubbleBackground)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        } else {
            Text(message.text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.96))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(captainBubbleBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        }
    }

    private var userBubbleBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "D6FFF3").opacity(0.94),
                        Color(hex: "DDE8FF").opacity(0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.52), lineWidth: 1)
            }
    }

    private var captainBubbleBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.aiqoBeige.opacity(0.18),
                        Color.aiqoMint.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}

private struct DJCaptainTypingRow: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            DJCaptainAvatarView(size: 34)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    DJCaptainTypingDot(delay: Double(index) * 0.18)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
            )

            Spacer(minLength: 52)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DJCaptainTypingDot: View {
    let delay: Double

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.aiqoBeige)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1 : 0.56)
            .opacity(isAnimating ? 1 : 0.34)
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

private struct DJCaptainAvatarView: View {
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
                Image(systemName: "music.mic")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.74))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.66), lineWidth: 1)
        }
    }
}

private struct DJCaptainChatBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "091117"),
                    Color(hex: "0E171F"),
                    Color(hex: "131F29")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.aiqoMint.opacity(0.22))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: -120, y: -220)

            Circle()
                .fill(Color.aiqoBeige.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 72)
                .offset(x: 140, y: -140)

            Circle()
                .fill(Color(hex: "B7C9FF").opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 92)
                .offset(x: 120, y: 220)
        }
    }
}

#Preview {
    DJCaptainChatView()
        .environmentObject(CaptainViewModel())
}
