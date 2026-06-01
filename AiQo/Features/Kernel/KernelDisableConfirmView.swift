import SwiftUI
import Combine

/// Intentional-friction confirmation for turning the Kernel OFF.
///
/// The point of the feature — and the subscription behind it — is to guard the user's
/// focus, so disabling must be a calm, deliberate act, not an impulse. The user
/// MEASURES their pulse (back-camera PPG, on-device) and the off switch arms once a
/// CALM reading (≤ 80 bpm) is taken.
///
/// APPLE COMPLIANCE: a self-imposed restriction must always stay removable, so we
/// never gate disabling on a physiological state the user might be unable to reach.
/// An absolute wall-clock cap (`absoluteCapSeconds`) arms the off switch regardless —
/// calm is the *intended* path, never the *only* path. Heart rate is computed on the
/// device from the camera and never leaves it.
struct KernelDisableConfirmView: View {
    let onConfirmDisable: () -> Void
    @StateObject private var pulse = CameraPulseMeasurer()
    @Environment(\.dismiss) private var dismiss

    private let calmCeilingBPM = 80
    private let absoluteCapSeconds = 90   // Apple safeguard — never trapped
    @State private var elapsedTotal = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isArabic: Bool { AppSettingsStore.shared.appLanguage == .arabic }
    private var measuredBPM: Int? { pulse.bpm }
    private var isCalm: Bool { (measuredBPM ?? 999) <= calmCeilingBPM }
    private var canDisable: Bool { (measuredBPM != nil && isCalm) || elapsedTotal >= absoluteCapSeconds }

    var body: some View {
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
                Text(status)
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(statusColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AiQoSpacing.sm)
            }

            measureButton

            Spacer(minLength: 0)

            VStack(spacing: AiQoSpacing.sm) {
                Button { dismiss() } label: {
                    Label(isArabic ? "لا، أكمّل التزامي 💪" : "No, keep my commitment 💪",
                          systemImage: "shield.lefthalf.filled")
                        .font(AiQoTheme.Typography.cta)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glassProminent)
                .tint(AiQoTheme.Colors.accent)

                Button(role: .destructive) {
                    onConfirmDisable()
                    dismiss()
                } label: {
                    Text(disableLabel)
                        .font(AiQoTheme.Typography.body)
                        .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
                }
                .buttonStyle(.glass)
                .tint(.red)
                .disabled(!canDisable)
            }
        }
        .padding(AiQoSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AiQoTheme.Colors.primaryBackground.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(timer) { _ in elapsedTotal += 1 }
        .onDisappear { pulse.stop() }
    }

    // MARK: - Ring

    private var measurementRing: some View {
        ZStack {
            Circle().stroke(AiQoColors.mintSoft.opacity(0.25), lineWidth: 9)
            Circle()
                .trim(from: 0, to: pulse.isMeasuring ? pulse.progress : (measuredBPM != nil ? 1 : 0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: pulse.progress)
            ringCenter
        }
    }

    private var ringColor: Color {
        if let bpm = measuredBPM { return bpm <= calmCeilingBPM ? AiQoTheme.Colors.accent : .orange }
        return AiQoTheme.Colors.accent
    }

    @ViewBuilder
    private var ringCenter: some View {
        if let bpm = measuredBPM {
            VStack(spacing: 0) {
                Text("\(bpm)")
                    .font(.system(size: 44, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(bpm <= calmCeilingBPM ? AiQoTheme.Colors.textPrimary : Color.orange)
                Text(isArabic ? "نبضة" : "bpm")
                    .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        } else if pulse.isMeasuring {
            Image(systemName: "heart.fill")
                .font(.system(size: 42)).foregroundStyle(.pink)
                .symbolEffect(.pulse)
        } else {
            Image(systemName: "heart.text.square")
                .font(.system(size: 42)).foregroundStyle(AiQoTheme.Colors.accent)
        }
    }

    // MARK: - Measure button + status

    private var measureButton: some View {
        Button { pulse.start() } label: {
            Label(measureLabel, systemImage: "camera.fill")
                .font(AiQoTheme.Typography.body)
                .frame(maxWidth: .infinity).padding(.vertical, AiQoSpacing.sm)
        }
        .buttonStyle(.glass)
        .tint(AiQoTheme.Colors.accent)
        .disabled(pulse.isMeasuring)
    }

    private var measureLabel: String {
        if pulse.isMeasuring { return isArabic ? "جاري القياس…" : "Measuring…" }
        if measuredBPM == nil { return isArabic ? "ابدأ قياس النبض بالكاميرا" : "Measure pulse with the camera" }
        return isArabic ? "أعد القياس" : "Measure again"
    }

    private var statusLine: String? {
        if pulse.permissionDenied {
            return isArabic ? "تحتاج إذن الكاميرا للقياس — أو انتظر العدّاد." : "Camera access needed to measure — or wait it out."
        }
        if pulse.isMeasuring {
            return pulse.fingerDetected
                ? (isArabic ? "ثبّت إصبعك… جاري القياس" : "Hold steady… measuring")
                : (isArabic ? "غطِّ الكاميرا الخلفية والفلاش بطرف إصبعك" : "Cover the back camera and flash with your fingertip")
        }
        if let bpm = measuredBPM {
            return bpm <= calmCeilingBPM
                ? (isArabic ? "نبضك هادي ✓ تگدر تطفّي" : "Calm ✓ you can turn off")
                : (isArabic ? "نبضك مرتفع (\(bpm)) — هدّي وأعد القياس" : "Pulse high (\(bpm)) — calm down and re-measure")
        }
        return isArabic ? "حُط طرف إصبعك على الكاميرا الخلفية واضغط ابدأ." : "Place a fingertip on the back camera and tap measure."
    }

    private var statusColor: Color {
        if let bpm = measuredBPM, bpm > calmCeilingBPM { return .orange }
        if pulse.permissionDenied { return .orange }
        return AiQoTheme.Colors.textSecondary
    }

    private var disableLabel: String {
        if canDisable { return isArabic ? "أطفئ الحماية وفُكّ الدروع" : "Turn off & lift the shields" }
        if let bpm = measuredBPM, bpm > calmCeilingBPM { return isArabic ? "هدّي نبضك أول" : "Calm your pulse first" }
        return isArabic ? "قِس نبضك الهادي أول" : "Measure a calm pulse first"
    }
}
