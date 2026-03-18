import SwiftUI

struct GratitudeSessionView: View {
    private enum SessionTiming {
        static let duration: TimeInterval = 150
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("coach_language") private var coachLanguageRaw = ""

    @StateObject private var audioManager = GratitudeAudioManager()
    @State private var elapsedTime: TimeInterval = 0
    @State private var currentSentenceIndex = 0
    @State private var sessionTask: Task<Void, Never>?
    @State private var hasStartedSession = false
    @State private var hasCompletedSession = false

    private var sessionLanguage: GratitudeSessionLanguage {
        GratitudeSessionLanguage(
            coachLanguageRaw: coachLanguageRaw,
            fallback: AppSettingsStore.shared.appLanguage
        )
    }

    private var isLocked: Bool {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        return Date() >= noon
    }

    private var dailySentences: [String] {
        let bundles = gratitudeBundles(for: sessionLanguage)
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return bundles[dayIndex % bundles.count]
    }

    private var sentenceInterval: TimeInterval {
        let count = max(dailySentences.count, 1)
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

    private var currentSentence: String {
        guard hasStartedSession else {
            return localized(
                ar: "خل هالدقيقتين هاديات، واشكر ربك على يوم جديد وجسم بعده شايلك.",
                en: "Give these two minutes some stillness, and thank God for a new day and a body still carrying you."
            )
        }

        let safeIndex = min(max(currentSentenceIndex, 0), max(dailySentences.count - 1, 0))
        return dailySentences[safeIndex]
    }

    var body: some View {
        ZStack {
            sessionBackground

            VStack(spacing: 24) {
                topBar

                Spacer(minLength: 10)

                progressOrb

                Spacer(minLength: 10)

                footerPanel
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .statusBarHidden()
        .onDisappear(perform: stopSession)
    }

    private var sessionBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.14),
                    Color(red: 0.17, green: 0.29, blue: 0.32),
                    Color(red: 0.91, green: 0.83, blue: 0.69)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 84)
                .offset(x: -110, y: -240)

            Circle()
                .fill(Color(red: 0.78, green: 0.91, blue: 0.84).opacity(0.24))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: 130, y: 250)

            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(0.28)
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

                Text(localized(ar: "مسار صباحي يهدّي النفس", en: "A calm morning ritual"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 16)

            Text(remainingTimeText)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
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
                            Color.white.opacity(0.30),
                            Color(red: 0.79, green: 0.91, blue: 0.84),
                            Color(red: 0.94, green: 0.89, blue: 0.78)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.28), value: progress)

            Circle()
                .fill(.ultraThinMaterial.opacity(0.88))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .padding(26)

            VStack(spacing: 16) {
                Text(statusTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))

                Text(currentSentence)
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .lineSpacing(8)
                    .padding(.horizontal, 10)
                    .id(currentSentenceIndex)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.9), value: currentSentenceIndex)

                Text(subtitleText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 40)
        }
        .frame(maxWidth: 430, maxHeight: 430)
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.14), radius: 30, y: 16)
    }

    private var footerPanel: some View {
        VStack(spacing: 14) {
            if isLocked {
                lockedCard
            } else {
                HStack(spacing: 10) {
                    Image(systemName: hasCompletedSession ? "checkmark.circle.fill" : "sun.haze.circle")
                        .font(.system(size: 16, weight: .semibold))

                    Text(
                        localized(
                            ar: hasCompletedSession ? "تمام بطل.. خذ هالهدوء وكمل يومك." : "الجلسة مفتوحة لحد 12:00 ظهرًا.",
                            en: hasCompletedSession ? "Good. Carry this calm into the rest of your day." : "This session stays open until 12:00 PM."
                        )
                    )
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.84))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Button(action: startSession) {
                Text(startButtonTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "F4E6C3"),
                                        Color(hex: "CFECDD")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(isLocked || hasStartedSession)
            .opacity(isLocked || hasStartedSession ? 0.45 : 1)
        }
    }

    private var lockedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)

            Text("جلسة الامتنان الصباحية انتهى وقتها. نلتقي باجر الصبح يا ذيب حتى نبدأ يومنا صح")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var statusTitle: String {
        if isLocked {
            return localized(ar: "مقفلة اليوم", en: "Locked Today")
        }

        if hasCompletedSession {
            return localized(ar: "اكتملت الجلسة", en: "Session Complete")
        }

        if hasStartedSession {
            return localized(ar: "صفاء", en: "Serenity")
        }

        return localized(ar: "جاهزة إلك", en: "Ready For You")
    }

    private var subtitleText: String {
        if isLocked {
            return localized(
                ar: "هذا المسار الصباحي ينتهي ظهرًا حتى يبقى مرتبط ببداية اليوم.",
                en: "This ritual closes at noon so it stays anchored to the morning."
            )
        }

        if hasCompletedSession {
            return localized(
                ar: "خذ نفسك الأخير بهدوء، وامشِ على يومك بخفة.",
                en: "Take one final slow breath and carry that softness into the day."
            )
        }

        if hasStartedSession {
            return localized(
                ar: "خلك ويّا الصوت والجملة، والباقي يهدأ وحده.",
                en: "Stay with the sound and the sentence, and let the rest settle."
            )
        }

        return localized(
            ar: "ابدأ الجلسة حتى يشتغل الصوت والموسيقى وتتحرك جُمل الامتنان بهدوء.",
            en: "Start the session to fade through today's gratitude lines with voice and ambient sound."
        )
    }

    private var startButtonTitle: String {
        if hasCompletedSession {
            return localized(ar: "تمت الجلسة", en: "Session Complete")
        }

        if hasStartedSession {
            return localized(ar: "الجلسة شغالة", en: "Session In Progress")
        }

        return localized(ar: "ابدأ جلسة الامتنان", en: "Start Gratitude Session")
    }

    private func startSession() {
        guard !isLocked else { return }
        guard !hasStartedSession else { return }
        guard !dailySentences.isEmpty else { return }

        sessionTask?.cancel()
        elapsedTime = 0
        currentSentenceIndex = 0
        hasStartedSession = true
        hasCompletedSession = false

        audioManager.startSessionAudio()
        audioManager.speak(dailySentences[0], language: sessionLanguage)

        sessionTask = Task { @MainActor in
            let startDate = Date()

            while !Task.isCancelled {
                let elapsed = min(Date().timeIntervalSince(startDate), SessionTiming.duration)
                elapsedTime = elapsed

                let nextIndex = min(
                    Int(elapsed / sentenceInterval),
                    max(dailySentences.count - 1, 0)
                )

                if nextIndex != currentSentenceIndex {
                    withAnimation(.easeInOut(duration: 0.9)) {
                        currentSentenceIndex = nextIndex
                    }
                    audioManager.speak(dailySentences[nextIndex], language: sessionLanguage)
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

    private func gratitudeBundles(for language: GratitudeSessionLanguage) -> [[String]] {
        switch language {
        case .arabic:
            return [
                [
                    "أشكر ربك على هالبدن اللي بعده يشيلك من أول خطوة.",
                    "أشكر الصبح لأن رجعلك فرصة جديدة حتى ترتب يومك بهدوء.",
                    "أشكر النفس اللي دا يدخل ويطلع بدون ما تطلب منه شي.",
                    "أشكر قلبك لأن بعدها يدق ويذكرك إنك حاضر بهاللحظة.",
                    "أشكر الطريق البسيط اللي قدامك، لأن مو كل يوم لازم يكون صاخب حتى يكون مهم.",
                    "أشكر الناس الزينين اللي يمرون بخاطرك حتى لو مو يمك هسه."
                ],
                [
                    "احمد الله على الراحة اللي وصلتلك ولو بشكل بسيط هالليلة.",
                    "اذكر نعمة الوعي، لأنك دا تبدي يومك وأنت منتبه لنفسك.",
                    "أشكر عيونك اللي شايفة الصبح، ويدك اللي تكدر تبني بيها يوم جديد.",
                    "أشكر كل تعب علّمك شلون ترجع أهدأ وأوضح.",
                    "أشكر جسمك على كل إشارة ديعطيها إلك حتى تتعامل وياه بلطف.",
                    "أشكر اللحظة لأن بيها مجال ترجع ترتب نيتك من جديد."
                ],
                [
                    "أشكر الله على السعة حتى لو يومك مزدحم، لأن بداخلك بعده مكان للهدوء.",
                    "أشكر الخطوات الصغيرة، لأن هي اللي تشيلك للنهاية مو القفزات.",
                    "أشكر كل شيء بسيط يثبتك: المي، الهواء، الضوء، والسكينة.",
                    "أشكر عقلك لأن دا يتعلم يخفف الضجيج شوي شوي.",
                    "أشكر رزقك الموجود هسه، حتى لو بعدك دا تبني أكثر.",
                    "أشكر هالدقيقتين لأنهن رجعن جسمك وروحك لنفس الخط."
                ]
            ]
        case .english:
            return [
                [
                    "Thank God for the body still carrying you through the first steps of the day.",
                    "Thank the morning for handing you another chance to begin with more softness.",
                    "Thank your breath for returning again and again without asking anything back.",
                    "Thank your heart for still keeping rhythm while you learn to slow down.",
                    "Thank the simple road ahead, because a quiet day can still be a meaningful one.",
                    "Thank the good people who cross your mind, even if they are not beside you right now."
                ],
                [
                    "Be grateful for whatever rest reached you last night, even if it came in fragments.",
                    "Be grateful for awareness, because you are starting this day awake to yourself.",
                    "Thank your eyes for seeing this morning, and your hands for shaping a new day.",
                    "Thank every hard season that taught you how to return with more calm.",
                    "Thank your body for every signal it sends when you choose to listen gently.",
                    "Thank this moment because it gives you room to reset your intention."
                ],
                [
                    "Thank God for the space inside you, even when the outside world feels crowded.",
                    "Thank the small steps, because they carry the day more honestly than big bursts.",
                    "Thank the basics that steady you: water, air, light, and stillness.",
                    "Thank your mind for learning, little by little, how to loosen its noise.",
                    "Thank what is already in your hands before asking for what comes next.",
                    "Thank these two quiet minutes for bringing your body and spirit back into one line."
                ]
            ]
        }
    }
}

#Preview {
    GratitudeSessionView()
}
