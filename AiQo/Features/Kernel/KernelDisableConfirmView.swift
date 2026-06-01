import SwiftUI
import Combine
import HealthKit

/// Intentional-friction confirmation for turning the Kernel OFF.
///
/// The point of the feature — and the subscription behind it — is to guard the user's
/// focus, so disabling must be a calm, deliberate act, not an impulse. The user
/// MEASURES their pulse — via the **Apple Watch** (a brief workout session) or the
/// **back camera** (on-device PPG) — and the off switch arms once a CALM reading
/// (≤ 80 bpm) is taken.
///
/// APPLE COMPLIANCE: a self-imposed restriction must always stay removable, so we
/// never gate disabling on a physiological state the user might be unable to reach.
/// An absolute wall-clock cap (`absoluteCapSeconds`) arms the off switch regardless —
/// calm is the *intended* path, never the *only* path. Heart rate is computed
/// on-device and never leaves it; the camera asks for explicit in-app consent first.
struct KernelDisableConfirmView: View {
    let onConfirmDisable: () -> Void
    @StateObject private var pulse = CameraPulseMeasurer()
    @ObservedObject private var connectivity = PhoneConnectivityManager.shared
    @Environment(\.dismiss) private var dismiss

    private enum Method { case camera, watch }
    private let calmCeilingBPM = 80
    private let watchHoldSeconds = 20
    private let absoluteCapSeconds = 90   // Apple safeguard — never trapped

    @State private var method: Method?
    @State private var showCameraIntro = false
    @State private var watchActive = false
    @State private var watchCountdown: Int?
    @State private var watchBPM: Int?
    @State private var elapsedTotal = 0
    // Guaranteed-exit fallback: after two failed attempts (or the "I can't right now"
    // button), a breathing timer arms the off switch — friction stays, the door always opens.
    @State private var failedAttempts = 0
    @State private var countedThisMeasurement = false
    @State private var fallbackActive = false
    @State private var fallbackRemaining = 0
    @State private var fallbackComplete = false
    @State private var breatheIn = false
    private let fallbackSeconds = 75
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isArabic: Bool { AppSettingsStore.shared.appLanguage == .arabic }
    private var measuredBPM: Int? { method == .camera ? pulse.bpm : (method == .watch ? watchBPM : nil) }
    private var isMeasuring: Bool {
        (method == .camera && pulse.isMeasuring) || (method == .watch && watchActive)
    }
    private var isCalm: Bool { (measuredBPM ?? 999) <= calmCeilingBPM }
    private var canDisable: Bool {
        (measuredBPM != nil && !isMeasuring && isCalm) || fallbackComplete || elapsedTotal >= absoluteCapSeconds
    }

    var body: some View {
        Group {
            if fallbackActive { breathingFallback }
            else if showCameraIntro { cameraIntro }
            else { mainFlow }
        }
        .padding(AiQoSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AiQoTheme.Colors.primaryBackground.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(timer) { _ in tick() }
        .onChange(of: pulse.isMeasuring) { wasMeasuring, nowMeasuring in
            // Count a finished CAMERA measurement as failed if it wasn't a clear, calm reading.
            if wasMeasuring, !nowMeasuring, method == .camera, pulse.progress >= 1, !countedThisMeasurement {
                countedThisMeasurement = true
                if !(pulse.bpm.map { $0 <= calmCeilingBPM } ?? false) { failedAttempts += 1 }
            }
        }
        .onDisappear { endEverything() }
    }

    // MARK: - Main flow

    private var mainFlow: some View {
        VStack(spacing: AiQoSpacing.md) {
            Spacer(minLength: 0)
            measurementRing.frame(width: 152, height: 152)

            Text(isArabic ? "راح تكسر التزامك اليوم" : "You're about to break today's commitment")
                .font(AiQoTheme.Typography.screenTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(isArabic
                 ? "توقّف وتنفّس — قِس نبضك للتأكد إنك هادي مو متسرّع. لو هادي، أفتحلك الإطفاء."
                 : "Stop and breathe — measure your pulse to prove you're calm, not impulsive. If calm, the off switch unlocks.")
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AiQoSpacing.md)

            Text(isArabic
                 ? "نبض الهدوء عادةً 60–80 نبضة بالدقيقة — لمن يوصل نبضك لهالمدى، AiQo يتأكد إنك مرتاح ومسترخي."
                 : "A calm pulse is usually 60–80 bpm — when yours settles into that range, AiQo confirms you're relaxed.")
                .font(AiQoTheme.Typography.caption)
                .foregroundStyle(AiQoTheme.Colors.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AiQoSpacing.md)

            if let status = statusLine {
                Text(status).font(AiQoTheme.Typography.caption)
                    .foregroundStyle(statusColor).multilineTextAlignment(.center)
                    .padding(.horizontal, AiQoSpacing.sm)
            }

            methodControls

            Button { startFallback() } label: {
                Text(isArabic ? "ما أكدر أهدّي هسة — خذ تهدئة بالتنفّس وتفتح بعدها" : "Can't calm down right now — take a breathing break, then it opens")
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(failedAttempts >= 2 ? AiQoTheme.Colors.accent : AiQoTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .padding(.top, AiQoSpacing.xs)

            Spacer(minLength: 0)
            commitAndDisableButtons
            disclaimerFootnote
        }
    }

    // MARK: - Breathing fallback (guaranteed door)

    /// A calm-down breathing timer reached via two failed attempts or the "I can't
    /// right now" button. When it finishes, the off switch is armed for sure — the
    /// friction stays, but the exit is always there (Apple: restrictions stay removable).
    private var breathingFallback: some View {
        VStack(spacing: AiQoSpacing.lg) {
            Spacer(minLength: 0)
            Text(isArabic ? "خذ تهدئة" : "Take a breath")
                .font(AiQoTheme.Typography.screenTitle).foregroundStyle(AiQoTheme.Colors.textPrimary)
            Circle()
                .fill(AiQoColors.mintSoft.opacity(0.6))
                .frame(width: breatheIn ? 200 : 120, height: breatheIn ? 200 : 120)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breatheIn)
                .overlay(
                    Text(breatheIn ? (isArabic ? "شهيق" : "in") : (isArabic ? "زفير" : "out"))
                        .font(AiQoTheme.Typography.cardTitle).foregroundStyle(AiQoTheme.Colors.textPrimary)
                )
            Text(isArabic ? "تنفّس بهدوء — \(fallbackRemaining) ثانية" : "Breathe slowly — \(fallbackRemaining)s")
                .font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textSecondary)
            Text(isArabic ? "بعدها يفتح الإطفاء مضموناً." : "The off switch unlocks right after.")
                .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.accent)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Label(isArabic ? "لا، أكمّل التزامي 💪" : "No, keep my commitment 💪", systemImage: "shield.lefthalf.filled")
                    .font(AiQoTheme.Typography.cta).frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glassProminent).tint(AiQoTheme.Colors.accent)
            disclaimerFootnote
        }
        .onAppear { breatheIn = true }
    }

    /// Non-medical disclaimer — this is a wellbeing calm-check, never a diagnosis.
    private var disclaimerFootnote: some View {
        Text(isArabic
             ? "فحص هدوء للرفاهية فقط — مو جهاز أو قياس طبي."
             : "A wellbeing calm-check only — not a medical device or measurement.")
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(AiQoTheme.Colors.textSecondary.opacity(0.8))
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var methodControls: some View {
        if method == nil {
            VStack(spacing: AiQoSpacing.sm) {
                Button { startWatch() } label: {
                    Label(isArabic ? "قياس بالساعة" : "Measure with Apple Watch", systemImage: "applewatch")
                        .font(AiQoTheme.Typography.body)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glass).tint(AiQoTheme.Colors.accent)
                .disabled(!connectivity.canStartWorkoutFromPhone)

                Button { showCameraIntro = true } label: {
                    Label(isArabic ? "قياس بالكاميرا" : "Measure with camera", systemImage: "camera.fill")
                        .font(AiQoTheme.Typography.body)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glass).tint(AiQoTheme.Colors.accent)

                if !connectivity.canStartWorkoutFromPhone {
                    Text(isArabic ? "القياس بالساعة يحتاج ساعة مقترنة" : "Watch measurement needs a paired Apple Watch")
                        .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            }
        } else {
            Button { resetMeasurement() } label: {
                Label(isArabic ? "أعد القياس" : "Measure again", systemImage: "arrow.clockwise")
                    .font(AiQoTheme.Typography.body)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glass).tint(AiQoTheme.Colors.accent)
            .disabled(isMeasuring)
        }
    }

    private var commitAndDisableButtons: some View {
        VStack(spacing: AiQoSpacing.sm) {
            Button { dismiss() } label: {
                Label(isArabic ? "لا، أكمّل التزامي 💪" : "No, keep my commitment 💪",
                      systemImage: "shield.lefthalf.filled")
                    .font(AiQoTheme.Typography.cta)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glassProminent).tint(AiQoTheme.Colors.accent)

            Button(role: .destructive) {
                onConfirmDisable(); dismiss()
            } label: {
                Text(disableLabel).font(AiQoTheme.Typography.body)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glass).tint(.red)
            .disabled(!canDisable)
        }
    }

    // MARK: - Camera consent + instructions

    private var cameraIntro: some View {
        VStack(spacing: AiQoSpacing.lg) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(AiQoColors.mintSoft.opacity(0.2)).frame(width: 132, height: 132)
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 52)).foregroundStyle(AiQoTheme.Colors.accent)
            }
            Text(isArabic ? "قياس النبض بالكاميرا" : "Measure pulse with the camera")
                .font(AiQoTheme.Typography.screenTitle).foregroundStyle(AiQoTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: AiQoSpacing.sm) {
                instructionRow("target", isArabic ? "الهدف: نبض هادي 60–80 نبضة — عشان AiQo يتأكد إنك مرتاح ومسترخي." : "Goal: a calm pulse of 60–80 bpm — so AiQo can confirm you're relaxed.")
                instructionRow("flashlight.on.fill", isArabic ? "الفلاش راح يشتغل — هذا طبيعي وضروري للقياس." : "The flash turns on — that's normal and needed.")
                instructionRow("hand.point.up.left.fill", isArabic ? "حُط طرف إصبعك يغطّي الكاميرا الخلفية والفلاش تماماً." : "Cover the back camera and flash fully with a fingertip.")
                instructionRow("hand.raised.fill", isArabic ? "ثبّت بدون حركة \(Int(pulse.windowSeconds)) ثانية." : "Hold still for \(Int(pulse.windowSeconds)) seconds.")
                instructionRow("lock.shield.fill", isArabic ? "كل القياس على جهازك — ولا صورة تنحفظ أو تنرسل." : "All on-device — no image is saved or sent.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AiQoSpacing.md)
            .glassEffect(.regular, in: .rect(cornerRadius: AiQoRadius.card))

            disclaimerFootnote

            Spacer(minLength: 0)

            Button {
                showCameraIntro = false
                method = .camera
                countedThisMeasurement = false
                pulse.start()
            } label: {
                Label(isArabic ? "موافق، ابدأ القياس" : "I agree — start measuring", systemImage: "camera.fill")
                    .font(AiQoTheme.Typography.cta)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glassProminent).tint(AiQoTheme.Colors.accent)

            Button { showCameraIntro = false } label: {
                Text(isArabic ? "رجوع" : "Back")
                    .font(AiQoTheme.Typography.body)
                    .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
            }
            .buttonStyle(.glass)
        }
    }

    private func instructionRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AiQoSpacing.sm) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(AiQoTheme.Colors.accent)
                .frame(width: 24)
            Text(text).font(AiQoTheme.Typography.body).foregroundStyle(AiQoTheme.Colors.textPrimary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Ring

    private var measurementRing: some View {
        ZStack {
            Circle().stroke(AiQoColors.mintSoft.opacity(0.25), lineWidth: 9)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: ringProgress)
            ringCenter
        }
    }

    private var ringProgress: Double {
        if fallbackComplete { return 1 }
        if let _ = measuredBPM, !isMeasuring { return 1 }
        if method == .camera { return pulse.progress }
        if method == .watch, let c = watchCountdown { return Double(watchHoldSeconds - c) / Double(watchHoldSeconds) }
        return 0
    }

    private var ringColor: Color {
        if let bpm = measuredBPM, !isMeasuring { return bpm <= calmCeilingBPM ? AiQoTheme.Colors.accent : .orange }
        return AiQoTheme.Colors.accent
    }

    @ViewBuilder
    private var ringCenter: some View {
        if fallbackComplete, measuredBPM == nil {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 46)).foregroundStyle(AiQoTheme.Colors.accent)
        } else if let bpm = measuredBPM, !isMeasuring {
            bpmLabel(bpm, color: bpm <= calmCeilingBPM ? AiQoTheme.Colors.textPrimary : .orange)
        } else if method == .watch, watchActive {
            if let c = watchCountdown {
                VStack(spacing: 0) {
                    Text("\(c)").font(.system(size: 40, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    Text(watchBPM.map { isArabic ? "\($0) نبضة" : "\($0) bpm" } ?? "")
                        .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
                }
            } else {
                Image(systemName: "applewatch")
                    .font(.system(size: 42)).foregroundStyle(AiQoTheme.Colors.accent).symbolEffect(.pulse)
            }
        } else if method == .camera, pulse.isMeasuring {
            if let bpm = pulse.bpm { bpmLabel(bpm, color: AiQoTheme.Colors.textPrimary) }
            else { Image(systemName: "heart.fill").font(.system(size: 42)).foregroundStyle(.pink).symbolEffect(.pulse) }
        } else {
            Image(systemName: "heart.text.square").font(.system(size: 42)).foregroundStyle(AiQoTheme.Colors.accent)
        }
    }

    private func bpmLabel(_ bpm: Int, color: Color) -> some View {
        VStack(spacing: 0) {
            Text("\(bpm)").font(.system(size: 44, design: .rounded).weight(.bold).monospacedDigit()).foregroundStyle(color)
            Text(isArabic ? "نبضة" : "bpm").font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
        }
    }

    // MARK: - Status + labels

    private var statusLine: String? {
        if fallbackComplete, measuredBPM == nil {
            return isArabic ? "ارتحت ✓ تگدر تطفّي" : "Calmer ✓ you can turn off"
        }
        if pulse.permissionDenied {
            return isArabic ? "تحتاج إذن الكاميرا — أو جرّب القياس بالساعة، أو انتظر العدّاد." : "Camera access needed — try the Watch, or wait it out."
        }
        if method == .watch, watchActive {
            return watchCountdown == nil
                ? (isArabic ? "افتح التمرين بالساعة وثبّت… ننتظر النبض" : "Open the workout on your Watch and hold still… waiting for heart rate")
                : (isArabic ? "نبضك يُقاس — ثبّت \(watchCountdown ?? 0) ثانية" : "Measuring — hold \(watchCountdown ?? 0)s")
        }
        if method == .camera, pulse.isMeasuring {
            return pulse.fingerDetected
                ? (isArabic ? "ثبّت إصبعك… جاري القياس" : "Hold steady… measuring")
                : (isArabic ? "غطِّ الكاميرا الخلفية والفلاش بطرف إصبعك" : "Cover the back camera and flash with your fingertip")
        }
        if let bpm = measuredBPM {
            return bpm <= calmCeilingBPM
                ? (isArabic ? "نبضك هادي ✓ تگدر تطفّي" : "Calm ✓ you can turn off")
                : (isArabic ? "نبضك مرتفع (\(bpm)) — هدّي وأعد القياس" : "Pulse high (\(bpm)) — calm down and re-measure")
        }
        if method == .camera, !pulse.isMeasuring, pulse.progress >= 1 {
            return isArabic
                ? "ما طلع قياس واضح — اضغط إصبعك أكثر على الكاميرا وثبّت، وأعد. أو استخدم الساعة (أدق)."
                : "No clear reading — press your finger more firmly, hold still, and re-measure. Or use the Watch (more accurate)."
        }
        return isArabic ? "اختر طريقة القياس عشان تتأكد إنك هادي." : "Choose how to measure that you're calm."
    }

    private var statusColor: Color {
        if let bpm = measuredBPM, bpm > calmCeilingBPM, !isMeasuring { return .orange }
        if pulse.permissionDenied { return .orange }
        return AiQoTheme.Colors.textSecondary
    }

    private var disableLabel: String {
        if canDisable { return isArabic ? "أطفئ الحماية وفُكّ الدروع" : "Turn off & lift the shields" }
        if let bpm = measuredBPM, bpm > calmCeilingBPM { return isArabic ? "هدّي نبضك أول" : "Calm your pulse first" }
        return isArabic ? "قِس نبضك الهادي أول" : "Measure a calm pulse first"
    }

    // MARK: - Actions

    private func startWatch() {
        guard connectivity.canStartWorkoutFromPhone else { return }
        method = .watch
        watchActive = true
        watchCountdown = nil
        watchBPM = nil
        countedThisMeasurement = false
        connectivity.launchWatchAppForWorkout(activityType: .mindAndBody, locationType: .unknown)
    }

    private func resetMeasurement() {
        pulse.stop()
        if watchActive { connectivity.endWorkoutOnWatch() }
        method = nil
        watchActive = false
        watchCountdown = nil
        watchBPM = nil
        countedThisMeasurement = false
    }

    private func endEverything() {
        pulse.stop()
        if watchActive { connectivity.endWorkoutOnWatch() }
    }

    private func tick() {
        elapsedTotal += 1
        if fallbackActive {
            if fallbackRemaining > 0 { fallbackRemaining -= 1 }
            if fallbackRemaining <= 0 { fallbackActive = false; fallbackComplete = true }
            return
        }
        guard method == .watch, watchActive else { return }
        let hr = Int(connectivity.currentHeartRate.rounded())
        guard hr > 0 else { return }            // wait for the Watch to report HR
        watchBPM = hr
        if watchCountdown == nil {
            watchCountdown = watchHoldSeconds   // HR appeared — start the 20s hold
        } else {
            watchCountdown! -= 1
            if watchCountdown! <= 0 {
                connectivity.endWorkoutOnWatch()   // auto-end the Watch workout
                watchActive = false
                if !countedThisMeasurement {
                    countedThisMeasurement = true
                    if !(watchBPM.map { $0 <= calmCeilingBPM } ?? false) { failedAttempts += 1 }
                }
            }
        }
    }

    private func startFallback() {
        pulse.stop()
        if watchActive { connectivity.endWorkoutOnWatch() }
        method = nil
        watchActive = false
        watchCountdown = nil
        fallbackActive = true
        fallbackRemaining = fallbackSeconds
    }
}
