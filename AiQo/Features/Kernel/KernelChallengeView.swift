import SwiftUI
import Combine
import UIKit
import HealthKit

/// The in-app challenge / unlock screen. Live HealthKit-derived data is allowed
/// HERE (never inside the shield). Presented by the Kernel hub (`KernelView`)
/// when a chosen app is locked; auto-dismisses on unlock with a celebration that
/// matches the app's level-up moments. All challenge logic lives here — the hub
/// holds none of it. Uses the existing DesignSystem (AiQoTheme / AiQoColors).
struct KernelChallengeView: View {
    @ObservedObject var model: KernelViewModel
    @ObservedObject private var bio = KernelBioEngine.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCelebration = false
    @State private var celebrationLine = ""
    @State private var nextHint = ""

    private var language: AppLanguage { AppSettingsStore.shared.appLanguage }
    private var isAr: Bool { language == .arabic }

    var body: some View {
        ZStack {
            AiQoTheme.Colors.primaryBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: AiQoSpacing.lg) {
                    // Past shield 5 the "enough for today" card IS the headline — drop
                    // the generic "charge up" header so it doesn't compete with it.
                    if !isEnoughForToday { titleHeader }
                    challengeSection
                }
                .padding(AiQoSpacing.lg)
                .frame(maxWidth: .infinity)
            }
            if showCelebration { celebrationOverlay }
            closeButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { model.refreshChallenge() }
        .onChange(of: model.isLocked) { wasLocked, isLocked in
            if wasLocked && !isLocked { celebrateUnlock() }
        }
    }

    /// Close the challenge and go back (does NOT unlock — the apps stay shielded;
    /// the user just chose to step away). Top-leading (top-right in RTL).
    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .frame(width: 38, height: 38)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .padding(AiQoSpacing.md)
        .accessibilityLabel("رجوع")
    }

    private var titleHeader: some View {
        VStack(spacing: AiQoSpacing.sm) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 30, design: .rounded))
                .foregroundStyle(AiQoTheme.Colors.accent)
            Text("اشحن نواتك")
                .font(AiQoTheme.Typography.screenTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
            Text("تحرّك شوي وتنفتح — جسمك هو المفتاح.")
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AiQoSpacing.md)
    }

    /// True when we're at the gentle "enough for today" tier (shield ≥ 5).
    private var isEnoughForToday: Bool {
        if case .enoughForToday = model.challengeState { return true }
        return false
    }

    @ViewBuilder
    private var challengeSection: some View {
        switch model.challengeState {
        case .preparing:
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.lg)
        case let .challenge(challenge, _):
            challengeCard(challenge)
        case let .enoughForToday(challenge, _):
            enoughForTodayCard(challenge)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func challengeCard(_ challenge: UnlockChallenge) -> some View {
        VStack(spacing: AiQoSpacing.lg) {
            switch challenge.kind {
            case .steps:
                // Shields 1–4: the Captain is a live in-app trainer (photo + bubble +
                // start → running clock + real live steps/HR + spoken encouragement).
                CaptainTrainerSession(model: model, bio: bio, challenge: challenge)
            case let .breathing(seconds):
                BreathingChallengeView(seconds: seconds) { model.completeActiveChallenge() }
            case let .calmHeartRate(maxBPM, holdSeconds):
                CalmHeartChallengeView(maxBPM: maxBPM, holdSeconds: holdSeconds,
                                       liveBPM: bio.latestBPM) { model.completeActiveChallenge() }
            }
            // Spend path hidden once the energy cost is OFF (shield > 5 → physical only).
            if challenge.coinPrice > 0 {
                spendButton(price: challenge.coinPrice)
            }
        }
        .kernelCard()
    }

    private func spendButton(price: Int) -> some View {
        let canAfford = model.coinBalance >= price
        return VStack(spacing: AiQoSpacing.xs) {
            Button {
                _ = model.spendToUnlock()
            } label: {
                Label("افتح بـ \(price) طاقة", systemImage: "bolt.circle")
                    .font(AiQoTheme.Typography.cta)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glass)
            .tint(AiQoColors.sandSoft)
            .disabled(!canAfford)

            if !canAfford {
                Text("ما عندك طاقة كافية — تحرّك تكسبها.")
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        }
    }

    /// Shield ≥ 5: the gentle "enough for today" message LEADS as the main card; the
    /// (hard) escalation challenge stays available beneath it as a small secondary
    /// option — opening is never removed (not a jail). Past shield 5 the energy/spend
    /// path is gone, so only real physical effort opens it. Replaces the old fixed
    /// daily-limit / once-a-day 500-step emergency card.
    private func enoughForTodayCard(_ challenge: UnlockChallenge) -> some View {
        VStack(spacing: AiQoSpacing.lg) {
            // The CAPTAIN himself leads the "enough for today" moment — big photo.
            VStack(spacing: AiQoSpacing.sm) {
                Image("Hammoudi5").resizable().scaledToFit()
                    .frame(height: 132)
                Text(KernelCaptainBridge.enoughForTodayLead(language: language))
                    .font(AiQoTheme.Typography.sectionTitle)
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            // The hard challenge stays available beneath — small, headerless trainer.
            VStack(spacing: AiQoSpacing.sm) {
                Text(isAr ? "بس إذا لازم — امشِ \(challenge.stepTarget) خطوة:"
                          : "Only if you must — walk \(challenge.stepTarget) steps:")
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CaptainTrainerSession(model: model, bio: bio, challenge: challenge, showHeader: false)
                if challenge.coinPrice > 0 {
                    spendButton(price: challenge.coinPrice)
                }
            }
            .opacity(0.95)
        }
        .kernelCard()
    }

    /// The one-moment celebration: the Captain congratulates (big photo + line) and
    /// gives an honest "next is harder" heads-up read live from `KernelEscalation`,
    /// then the screen auto-dismisses. Silent — no voice (text + haptic only).
    private func celebrateUnlock() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        celebrationLine = KernelCaptainBridge.celebrationLine(language: language)
        let nextShield = KernelSharedStore.shared.triggeredTodayCount() + 1
        nextHint = KernelEscalation.isEnoughForToday(shield: nextShield)
            ? KernelCaptainBridge.enoughForTodayLead(language: language)
            : KernelCaptainBridge.nextShieldHint(
                nextSteps: KernelEscalation.baseSteps(forShield: nextShield), language: language)
        withAnimation { showCelebration = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { dismiss() }
    }

    private var celebrationOverlay: some View {
        VStack(spacing: AiQoSpacing.md) {
            Image("Hammoudi5").resizable().scaledToFit()
                .frame(height: 132)
            Text(celebrationLine.isEmpty ? (isAr ? "انفتح! نواتك اتشحنت 🔋" : "Open! kernel charged 🔋") : celebrationLine)
                .font(AiQoTheme.Typography.cardTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            if !nextHint.isEmpty {
                Text(nextHint)
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AiQoSpacing.lg)
        .frame(maxWidth: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: AiQoRadius.ctaContainer))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Live Captain trainer

/// The Captain as a live in-app coach: his photo + a speech bubble, an explicit
/// "start" button, then a running clock with REAL live steps (+ heart rate when a
/// recent sample exists) and milestone encouragement spoken through on-device Apple
/// TTS (`.realtime` → ZERO cloud in the loop). Completion is verified by the engine
/// (real steps-since-block), which unlocks + grants energy exactly as before.
private struct CaptainTrainerSession: View {
    @ObservedObject var model: KernelViewModel
    @ObservedObject var bio: KernelBioEngine
    /// Live phone↔watch link — used to start a REAL mirrored workout session and
    /// read the watch's live heart rate. Carries no voice/coaching of its own.
    @ObservedObject private var connectivity = PhoneConnectivityManager.shared
    let challenge: UnlockChallenge
    var showHeader: Bool = true

    @State private var started = false
    @State private var startedWorkout = false
    @State private var elapsed = 0
    @State private var lastMilestone = -1
    @State private var bubble = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var language: AppLanguage { AppSettingsStore.shared.appLanguage }
    private var isAr: Bool { language == .arabic }
    private var target: Int { challenge.stepTarget }

    /// Live heart rate — preferring the real watch-workout stream, then a recent
    /// phone sample, else nil (honest "unavailable" — never a fabricated number).
    private var liveBPM: Int? {
        if connectivity.currentHeartRate > 0 { return Int(connectivity.currentHeartRate.rounded()) }
        return bio.latestBPM
    }
    private var hrFromWatch: Bool { connectivity.currentHeartRate > 0 }

    var body: some View {
        VStack(spacing: AiQoSpacing.md) {
            captainHeader
            if started { liveSession } else { startCard }
        }
        .onAppear {
            if bubble.isEmpty { bubble = KernelCaptainBridge.introLine(target: target, language: language) }
        }
        .onReceive(timer) { _ in
            guard started else { return }
            Task { await onTick() }
        }
        .onDisappear {
            bio.stopLiveSteps()
            endWorkoutIfNeeded()
        }
    }

    /// BIG Captain photo (the trainer is "in the room" with you) + his current
    /// message bubble. Photo omitted when `showHeader == false` (embedded under the
    /// "enough for today" lead, which shows its own big photo).
    private var captainHeader: some View {
        VStack(spacing: AiQoSpacing.sm) {
            if showHeader {
                // Full figure — NOT clipped to a circle (which cut off his head).
                Image("Hammoudi5").resizable().scaledToFit()
                    .frame(height: 168).frame(maxWidth: .infinity)
            }
            Text(bubble)
                .font(showHeader ? AiQoTheme.Typography.cardTitle : AiQoTheme.Typography.caption)
                .foregroundStyle(showHeader ? AiQoTheme.Colors.textPrimary : AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AiQoSpacing.md).padding(.vertical, AiQoSpacing.sm)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: AiQoRadius.control))
        }
    }

    private var startCard: some View {
        VStack(spacing: AiQoSpacing.md) {
            StepRingChallengeView(walked: bio.stepsSinceBlock, target: target)
            Button { startSession() } label: {
                Label(isAr ? "ابدأ التحدي" : "Start the challenge", systemImage: "figure.walk")
                    .font(AiQoTheme.Typography.cta)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glassProminent)
            .tint(AiQoTheme.Colors.accent)
        }
    }

    private var liveSession: some View {
        VStack(spacing: AiQoSpacing.md) {
            Text(clockString)
                .font(.system(size: 30, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
            StepRingChallengeView(walked: bio.stepsSinceBlock, target: target)
            heartRateRow
        }
    }

    /// Honest heart-rate row — live from the Watch workout when present, else a
    /// recent phone sample, else a truthful "unavailable". Never a fabricated number.
    private var heartRateRow: some View {
        HStack(spacing: AiQoSpacing.sm) {
            Image(systemName: "heart.fill").foregroundStyle(.pink)
            if let bpm = liveBPM {
                Text(isAr ? "\(bpm) نبضة" : "\(bpm) bpm")
                    .font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textPrimary)
                if hrFromWatch {
                    Text(isAr ? "· مباشر من الساعة" : "· live from Watch")
                        .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            } else {
                Text(isAr ? "النبض غير متوفر — الخطوات تكفي" : "Heart rate unavailable — steps are enough")
                    .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        }
    }

    private var clockString: String { String(format: "%02d:%02d", elapsed / 60, elapsed % 60) }

    private func startSession() {
        started = true
        elapsed = 0
        lastMilestone = KernelCaptainBridge.Milestone.start.rawValue
        bubble = KernelCaptainBridge.encouragement(.start, language: language)   // text only — no voice
        bio.startLiveSteps()   // real-time CMPedometer steps + auto-unlock at target
        // Also start a REAL workout session on the paired Apple Watch (live HR streamed
        // back + logged to Health). No watch → the challenge still runs phone-only, so
        // the step/unlock path is unaffected.
        if connectivity.canStartWorkoutFromPhone {
            connectivity.launchWatchAppForWorkout(activityType: .walking, locationType: .unknown)
            startedWorkout = true
        }
        Task { await bio.refreshLiveHeartRate() }
    }

    @MainActor
    private func onTick() async {
        elapsed += 1
        // Steps stream in real time from CMPedometer (startLiveSteps) — here we only
        // advance the clock, refresh phone HR when there's no Watch stream, and the bubble.
        if elapsed % 4 == 0, !hrFromWatch { await bio.refreshLiveHeartRate() }
        updateMilestoneBubble()
    }

    /// Advance the Captain's message at step milestones. TEXT ONLY — no TTS (voice
    /// is removed from the challenge/workout per design).
    private func updateMilestoneBubble() {
        guard target > 0 else { return }
        let pct = Double(bio.stepsSinceBlock) / Double(target)
        let milestone: KernelCaptainBridge.Milestone =
            pct >= 0.9 ? .almost : pct >= 0.75 ? .threeQuarter : pct >= 0.5 ? .half : pct >= 0.25 ? .quarter : .start
        guard milestone.rawValue > lastMilestone else { return }
        lastMilestone = milestone.rawValue
        bubble = KernelCaptainBridge.encouragement(milestone, language: language)
    }

    /// End the mirrored Watch workout when leaving the trainer (challenge completed
    /// or the user stepped away) so it never runs orphaned.
    private func endWorkoutIfNeeded() {
        guard startedWorkout else { return }
        startedWorkout = false
        connectivity.endWorkoutOnWatch()
    }
}

// MARK: - Step ring

private struct StepRingChallengeView: View {
    let walked: Int
    let target: Int
    private var progress: Double { target <= 0 ? 1 : min(1, Double(walked) / Double(target)) }

    var body: some View {
        VStack(spacing: AiQoSpacing.md) {
            ZStack {
                Circle().stroke(AiQoColors.mintSoft.opacity(0.25), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [AiQoTheme.Colors.accent, AiQoColors.sandSoft], center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                VStack(spacing: 2) {
                    Text("\(walked)")
                        .font(.system(size: 38, design: .rounded).weight(.bold))
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    Text("/ \(target) خطوة")
                        .font(AiQoTheme.Typography.caption)
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            }
            .frame(width: 200, height: 200)
            Text("امشِ لتفتح — يكتمل تلقائياً لمن توصل.")
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Breathing (guided timer)

private struct BreathingChallengeView: View {
    let seconds: Int
    let onComplete: () -> Void
    @State private var remaining: Int
    @State private var inhale = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(seconds: Int, onComplete: @escaping () -> Void) {
        self.seconds = seconds
        self.onComplete = onComplete
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(spacing: AiQoSpacing.md) {
            Circle()
                .fill(AiQoColors.mintSoft.opacity(0.6))
                .frame(width: inhale ? 180 : 110, height: inhale ? 180 : 110)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: inhale)
                .overlay(Text(inhale ? "شهيق" : "زفير").font(AiQoTheme.Typography.cardTitle))
            Text("تنفّس بهدوء — \(remaining) ثانية")
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
        }
        .onAppear { inhale = true }
        .onReceive(timer) { _ in
            guard remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 { onComplete() }
        }
    }
}

// MARK: - Calm heart rate (Apple Watch)

private struct CalmHeartChallengeView: View {
    let maxBPM: Int
    let holdSeconds: Int
    let liveBPM: Int?
    let onComplete: () -> Void
    @State private var hold: Int
    @State private var running = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(maxBPM: Int, holdSeconds: Int, liveBPM: Int?, onComplete: @escaping () -> Void) {
        self.maxBPM = maxBPM
        self.holdSeconds = holdSeconds
        self.liveBPM = liveBPM
        self.onComplete = onComplete
        _hold = State(initialValue: holdSeconds)
    }

    var body: some View {
        VStack(spacing: AiQoSpacing.md) {
            Image(systemName: "heart.fill").font(.system(size: 40)).foregroundStyle(.pink)
            if let bpm = liveBPM {
                Text("\(bpm) نبضة")
                    .font(.system(size: 30, design: .rounded).weight(.bold))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                Text("خلّي نبضك تحت \(maxBPM) لـ \(hold) ثانية")
                    .font(AiQoTheme.Typography.body)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                if !running {
                    Button("ابدأ الفحص") { running = true }
                        .font(AiQoTheme.Typography.cta)
                        .buttonStyle(.borderedProminent).tint(AiQoTheme.Colors.accent)
                }
            } else {
                Text("فحص النبض يحتاج Apple Watch.")
                    .font(AiQoTheme.Typography.body)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                Text("تگدر تمشي أو تصرف طاقتك بدالها.")
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        }
        .onReceive(timer) { _ in
            guard running, let bpm = liveBPM else { return }
            if bpm <= maxBPM {
                hold -= 1
                if hold <= 0 { onComplete() }
            } else {
                hold = holdSeconds
            }
        }
    }
}

// MARK: - Local card helper (uses existing material + radius tokens; not a new token)

private extension View {
    func kernelCard() -> some View {
        self.padding(AiQoSpacing.lg)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: AiQoRadius.card))
    }
}
