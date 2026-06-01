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
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isArabic: Bool { AppSettingsStore.shared.appLanguage == .arabic }
    private var measuredBPM: Int? { method == .camera ? pulse.bpm : (method == .watch ? watchBPM : nil) }
    private var isMeasuring: Bool {
        (method == .camera && pulse.isMeasuring) || (method == .watch && watchActive)
    }
    private var isCalm: Bool { (measuredBPM ?? 999) <= calmCeilingBPM }
    private var canDisable: Bool { (measuredBPM != nil && !isMeasuring && isCalm) || elapsedTotal >= absoluteCapSeconds }

    var body: some View {
        Group {
            if showCameraIntro { cameraIntro } else { mainFlow }
        }
        .padding(AiQoSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AiQoTheme.Colors.primaryBackground.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(timer) { _ in tick() }
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

            if let status = statusLine {
                Text(status).font(AiQoTheme.Typography.caption)
                    .foregroundStyle(statusColor).multilineTextAlignment(.center)
                    .padding(.horizontal, AiQoSpacing.sm)
            }

            methodControls

            Spacer(minLength: 0)
            commitAndDisableButtons
        }
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
                instructionRow("flashlight.on.fill", isArabic ? "الفلاش راح يشتغل — هذا طبيعي وضروري للقياس." : "The flash turns on — that's normal and needed.")
                instructionRow("hand.point.up.left.fill", isArabic ? "حُط طرف إصبعك يغطّي الكاميرا الخلفية والفلاش تماماً." : "Cover the back camera and flash fully with a fingertip.")
                instructionRow("hand.raised.fill", isArabic ? "ثبّت بدون حركة \(Int(pulse.windowSeconds)) ثانية." : "Hold still for \(Int(pulse.windowSeconds)) seconds.")
                instructionRow("lock.shield.fill", isArabic ? "كل القياس على جهازك — ولا صورة تنحفظ أو تنرسل." : "All on-device — no image is saved or sent.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AiQoSpacing.md)
            .glassEffect(.regular, in: .rect(cornerRadius: AiQoRadius.card))

            Spacer(minLength: 0)

            Button {
                showCameraIntro = false
                method = .camera
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
        if let bpm = measuredBPM, !isMeasuring {
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
        connectivity.launchWatchAppForWorkout(activityType: .mindAndBody, locationType: .unknown)
    }

    private func resetMeasurement() {
        pulse.stop()
        if watchActive { connectivity.endWorkoutOnWatch() }
        method = nil
        watchActive = false
        watchCountdown = nil
        watchBPM = nil
    }

    private func endEverything() {
        pulse.stop()
        if watchActive { connectivity.endWorkoutOnWatch() }
    }

    private func tick() {
        elapsedTotal += 1
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
            }
        }
    }
}
