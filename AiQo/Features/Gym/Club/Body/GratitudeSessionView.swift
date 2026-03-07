import SwiftUI

struct GratitudeSessionView: View {
    private enum SessionTiming {
        static let duration: TimeInterval = 120
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("coach_language") private var coachLanguageRaw = ""

    @StateObject private var audioManager = GratitudeAudioManager()
    @State private var elapsedTime: TimeInterval = 0
    @State private var currentSentenceIndex = 0
    @State private var sessionTask: Task<Void, Never>?
    @State private var hasStartedSession = false
    @State private var hasCompletedSession = false

    private let isTesting = true

    private var sessionLanguage: GratitudeSessionLanguage {
        GratitudeSessionLanguage(
            coachLanguageRaw: coachLanguageRaw,
            fallback: AppSettingsStore.shared.appLanguage
        )
    }

    private var activeSentences: [String] {
        switch sessionLanguage {
        case .arabic:
            return [
                "خذ نفسًا عميقًا... واحمد الله على نعمة الصحة.",
                "تذكر نعم الله التي تحيط بك اليوم.",
                "كل خطوة تمشيها هي نعمة من الخالق.",
                "في هذا الصباح لديك فرصة جديدة لتبدأ بقلب أخف.",
                "اشكر جسدك لأنه حملك حتى هذه اللحظة.",
                "دع الامتنان يسبق كل فكرة، ودع الهدوء يقودك.",
                "ابدأ يومك برضا، وثقة، وحمد صادق."
            ]
        case .english:
            return [
                "Take a deep breath, and thank God for the gift of health.",
                "Notice the blessings surrounding you today.",
                "Every step you take is a gift from your Creator.",
                "This morning gives you a fresh chance to begin with a lighter heart.",
                "Thank your body for carrying you to this moment.",
                "Let gratitude move before every thought, and let calm lead you.",
                "Start your day with contentment, trust, and honest thanks."
            ]
        }
    }

    private var sentenceInterval: TimeInterval {
        let count = max(activeSentences.count, 1)
        return SessionTiming.duration / Double(count)
    }

    private var progress: CGFloat {
        CGFloat(min(max(elapsedTime / SessionTiming.duration, 0), 1))
    }

    private var remainingTimeText: String {
        let remaining = max(Int(SessionTiming.duration - elapsedTime.rounded(.down)), 0)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var isPastNoon: Bool {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        return Date() >= noon
    }

    private var isLocked: Bool {
        isPastNoon && !isTesting
    }

    private var isShowingTestingBypass: Bool {
        isPastNoon && isTesting
    }

    private var currentSentence: String {
        let safeIndex = min(max(currentSentenceIndex, 0), max(activeSentences.count - 1, 0))
        return activeSentences[safeIndex]
    }

    var body: some View {
        ZStack {
            sessionBackground

            VStack(spacing: 24) {
                topBar

                Spacer(minLength: 12)

                progressOrb

                Spacer(minLength: 12)

                footerStatus
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 28)

            if isLocked {
                lockedOverlay
            }
        }
        .statusBarHidden()
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: stopSession)
    }

    private var sessionBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.11, blue: 0.16),
                    Color(red: 0.18, green: 0.33, blue: 0.34),
                    Color(red: 0.84, green: 0.78, blue: 0.67)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -120, y: -220)

            Circle()
                .fill(Color(red: 0.79, green: 0.91, blue: 0.84).opacity(0.2))
                .frame(width: 320, height: 320)
                .blur(radius: 96)
                .offset(x: 140, y: 240)

            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(0.35)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer(minLength: 16)

            VStack(spacing: 6) {
                Text(localized(ar: "جلسة الامتنان", en: "Gratitude Session"))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(localized(ar: "إعادة ضبط الأنا", en: "Reset the ego"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 16)

            Text(remainingTimeText)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .contentTransition(.numericText())
        }
    }

    private var progressOrb: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 16)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            Color(red: 0.79, green: 0.91, blue: 0.84),
                            Color(red: 0.94, green: 0.89, blue: 0.78)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)

            Circle()
                .fill(.ultraThinMaterial.opacity(0.88))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .padding(26)

            VStack(spacing: 16) {
                Text(hasCompletedSession ? localized(ar: "اكتملت الجلسة", en: "Session Complete") : localized(ar: "صفاء", en: "Serenity"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))

                Text(currentSentence)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(8)
                    .padding(.horizontal, 10)
                    .id(currentSentenceIndex)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: currentSentenceIndex)

                if hasCompletedSession {
                    Text(localized(ar: "احمل هذا الهدوء معك لبداية يومك.", en: "Carry this calm with you into the rest of your day."))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 42)
        }
        .frame(maxWidth: 430, maxHeight: 430)
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.14), radius: 30, y: 16)
    }

    private var footerStatus: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isPastNoon ? "lock.circle" : "sun.haze.circle")
                    .font(.system(size: 16, weight: .semibold))

                Text(lockStatusText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())

            if isShowingTestingBypass {
                Text(localized(ar: "وضع الاختبار مفعّل حاليًا، لذلك الجلسة تعمل بعد 12:00 ظهرًا رغم ظهور القفل.", en: "Testing bypass is enabled, so the session still runs after 12:00 PM even though the lock is visible."))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .transition(.opacity)
            }
        }
    }

    private var lockedOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)

                Text(localized(ar: "جلسة الامتنان تُقفل بعد 12:00 ظهرًا", en: "Gratitude Session locks after 12:00 PM"))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(localized(ar: "أوقف وضع الاختبار لتفعيل هذا القفل منطقيًا.", en: "Disable testing mode when you want this lock to be enforced."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))

                Button(action: dismiss.callAsFunction) {
                    Text(localized(ar: "إغلاق", en: "Close"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(28)
            .frame(maxWidth: 380)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private var lockStatusText: String {
        if isShowingTestingBypass {
            return localized(ar: "القفل ظاهر بعد 12:00 ظهرًا، لكن تجاوزه مفعّل للاختبار.", en: "The noon lock is visible, but bypassed for testing.")
        }

        if isPastNoon {
            return localized(ar: "الجلسة مغلقة بعد 12:00 ظهرًا.", en: "The session is locked after 12:00 PM.")
        }

        return localized(ar: "الجلسة متاحة حتى 12:00 ظهرًا.", en: "The session stays open until 12:00 PM.")
    }

    private func handleOnAppear() {
        guard !hasStartedSession else { return }
        hasStartedSession = true

        if isLocked {
            return
        }

        startSession()
    }

    private func startSession() {
        let sentences = activeSentences
        guard !sentences.isEmpty else { return }

        sessionTask?.cancel()
        elapsedTime = 0
        currentSentenceIndex = 0
        hasCompletedSession = false

        audioManager.startSessionAudio()
        audioManager.speak(sentences[0], language: sessionLanguage)

        sessionTask = Task { @MainActor in
            let startDate = Date()

            while !Task.isCancelled {
                let elapsed = min(Date().timeIntervalSince(startDate), SessionTiming.duration)
                elapsedTime = elapsed

                let nextIndex = min(
                    Int(elapsed / sentenceInterval),
                    max(sentences.count - 1, 0)
                )

                if nextIndex != currentSentenceIndex {
                    withAnimation(.easeInOut(duration: 0.9)) {
                        currentSentenceIndex = nextIndex
                    }
                    audioManager.speak(sentences[nextIndex], language: sessionLanguage)
                }

                if elapsed >= SessionTiming.duration {
                    break
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            hasCompletedSession = true
            audioManager.stopAll()
            sessionTask = nil
        }
    }

    private func stopSession() {
        sessionTask?.cancel()
        sessionTask = nil
        audioManager.stopAll()
    }

    private func localized(ar: String, en: String) -> String {
        sessionLanguage == .english ? en : ar
    }
}

#Preview {
    GratitudeSessionView()
}
