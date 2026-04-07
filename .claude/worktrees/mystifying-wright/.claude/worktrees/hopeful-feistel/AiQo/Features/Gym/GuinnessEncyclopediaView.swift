import SwiftUI

// MARK: - Model

struct GuinnessCard: Identifiable, Hashable {
    let id = UUID()
    let imageName: String
    let topic: String
}

// MARK: - Fixed Card Size (1176 x 621 px @3x) ✅

enum GuinnessCardSize {
    static let width: CGFloat  = 1176.0 / 3.0  // 392pt ✅
    static let height: CGFloat = 621.0 / 3.0   // 207pt ✅
}

// MARK: - Theme (Light/Dark)

struct GuinnessTheme {
    let colorScheme: ColorScheme

    var background: Color { Color(UIColor.systemBackground) }
    var card: Color { Color(UIColor.secondarySystemBackground) }
    var text: Color { Color.primary }
    var subtext: Color { Color(UIColor.secondaryLabel) }

    var border: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    var shadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.12)
    }

    var inputField: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)
    }

    var userBubble: Color {
        // User bubble stays warm but tuned for dark mode
        colorScheme == .dark ? Color.yellow.opacity(0.22) : Color.yellow.opacity(0.25)
    }

    var captainBubble: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    var sendButton: Color {
        colorScheme == .dark ? Color.yellow.opacity(0.85) : Color.yellow.opacity(0.9)
    }
}

// MARK: - Main Screen

struct GuinnessEncyclopediaView: View {

    private let cards: [GuinnessCard] = [
        .init(imageName: "Longest.Plank", topic: "أطول بلانك (Longest Plank)"),
        .init(imageName: "Fastest.mile", topic: "أسرع ميل (Fastest mile 1609m)"),
        .init(imageName: "push-ups", topic: "أكثر ضغط بساعة (Most push-ups in 1 hour)"),
        .init(imageName: "Fastest", topic: "أسرع 100 متر (Fastest 100m)")
    ]

    @Environment(\.colorScheme) private var colorScheme
    private var theme: GuinnessTheme { GuinnessTheme(colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    Text("GUINNESS RECORDS-AiQo")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.text)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    VStack(spacing: 16) {
                        ForEach(cards) { card in
                            NavigationLink(value: card) {
                                GuinnessGlassCard(
                                    imageName: card.imageName,
                                    width: GuinnessCardSize.width,
                                    height: GuinnessCardSize.height
                                )
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationDestination(for: GuinnessCard.self) { card in
                GuinnessChatView(card: card)
            }
        }
        .fontDesign(.rounded)
    }
}

// MARK: - Card (Image 100%)

struct GuinnessGlassCard: View {

    let imageName: String
    let width: CGFloat
    let height: CGFloat

    private let radius: CGFloat = 22
    private let stroke: CGFloat = 1

    @Environment(\.colorScheme) private var colorScheme
    private var theme: GuinnessTheme { GuinnessTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .scaleEffect(1.22)
                .offset(y: -12)
                .clipped()
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(theme.card)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(theme.border, lineWidth: stroke)
        )
        .shadow(color: theme.shadow, radius: 16, x: 0, y: 10)
    }
}

// MARK: - Guinness Chat Message

struct GuinnessChatMsg: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

// MARK: - Guinness Chat View

struct GuinnessChatView: View {

    let card: GuinnessCard

    @State private var messages: [GuinnessChatMsg] = []
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    private var theme: GuinnessTheme { GuinnessTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 14) {

                VStack(spacing: 10) {

                    Text("كابتن حمّودي")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(theme.text)

                    Image("Hammoudi5")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .shadow(color: theme.shadow.opacity(colorScheme == .dark ? 0.65 : 1.0), radius: 22, x: 0, y: 12)
                }
                .padding(.top, 18)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(messages) { msg in
                                GuinnessBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                    }
                    .onAppear {
                        if messages.isEmpty {
                            messages.append(GuinnessChatMsg(text: firstCoachMessage(for: card), isUser: false))
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        guard let last = messages.last else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(.rounded)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("اكتب رسالتك…", text: $inputText)
                .focused($isFocused)
                .foregroundColor(theme.text)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.inputField)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )

            Button { send() } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.sendButton)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""

        messages.append(GuinnessChatMsg(text: trimmed, isUser: true))

        let reply = coachReply(userText: trimmed, topic: card.topic)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            messages.append(GuinnessChatMsg(text: reply, isUser: false))
        }
    }

    private func firstCoachMessage(for card: GuinnessCard) -> String {
        switch card.imageName {
        case "Longest.Plank":
            return "هلا بطل 🦾 داخل على تحدّي (أطول بلانك). قولي رقمك الحالي بالبلانك ونسويلك خطة 7 أيام قوية بس بدون تهور."
        case "Fastest.mile":
            return "هلا بطل 🦾 داخل على تحدّي (أسرع ميل). قولي وقتك الحالي بالمشي/الركض وكم يوم تقدر تتمرن بالأسبوع، وأنا أرتب لك خطة."
        case "push-ups":
            return "هلا بطل 😄 داخل على تحدّي (أكثر ضغط بساعة). قولي كم عدة تسوي مرة وحدة، حتى أطلع لك تقسيم ذكي (جولات + راحات)."
        case "Fastest":
            return "هلا بطل 😄 داخل على تحدّي (أسرع 100 متر). قولي مستواك الحالي وهل تتمرن جيم لو مضمار، وأبني لك خطة سرعة."
        default:
            return "هلا بطل 😄 قولي هدفك ورقمك الحالي وأنا وياك خطوة بخطوة."
        }
    }

    private func coachReply(userText: String, topic: String) -> String {
        let t = userText.lowercased()

        if t.contains("خطة") || t.contains("برنامج") || t.contains("plan") {
            return "تمام ✅ على \(topic): قولي رقمك الحالي + كم يوم تقدر تلتزم، وأنا أسويلك خطة 7 أيام (قياس + تطور + راحة)."
        }

        if t.contains("صعب") || t.contains("مستحيل") || t.contains("ما اكدر") {
            return "لا تخاف… نخليها مستويات. اليوم 1% أحسن من أمس. قولي رقمك الحالي وخلي أرتّب لك خطوات بسيطة."
        }

        return "وصلتني ✅ قولي رقمك الحالي بالضبط بهالتحدّي، وأبني لك تحدّي أسبوع كامل."
    }
}

// MARK: - Guinness Bubble

struct GuinnessBubble: View {
    let message: GuinnessChatMsg

    @Environment(\.colorScheme) private var colorScheme
    private var theme: GuinnessTheme { GuinnessTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }

            Text(message.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(theme.text)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(message.isUser ? theme.userBubble : theme.captainBubble)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
                .frame(maxWidth: 320, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Preview

#Preview("Light") {
    GuinnessEncyclopediaView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    GuinnessEncyclopediaView()
        .preferredColorScheme(.dark)
}
