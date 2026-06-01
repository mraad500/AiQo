import SwiftUI
import Combine

/// Intentional-friction confirmation for turning the Kernel OFF.
///
/// The point of the feature — and the subscription behind it — is to guard the
/// user's focus, so disabling must be a calm, deliberate act, not an impulse. The
/// off switch arms only after **30 seconds of CALM**: when an Apple Watch heart rate
/// is available the countdown advances only while the pulse is calm (≤ 80 bpm); with
/// no recent reading it's a plain 30-second pause.
///
/// APPLE COMPLIANCE: a self-imposed restriction must always stay removable, so we
/// never gate disabling on a physiological state the user might be unable to reach.
/// An absolute wall-clock cap (`absoluteCapSeconds`) arms the off switch regardless
/// of heart rate — calm is the *faster* path, never the *only* path. Heart rate is
/// read on-device (HealthKit) and never leaves it.
struct KernelDisableConfirmView: View {
    let onConfirmDisable: () -> Void
    @ObservedObject private var bio = KernelBioEngine.shared
    @Environment(\.dismiss) private var dismiss

    private let calmSeconds = 30          // seconds of calm the user must hold
    private let calmCeilingBPM = 80       // "calm" = at or below this (lower is fine)
    private let absoluteCapSeconds = 90   // Apple safeguard: arms regardless after this — never trapped

    @State private var calmRemaining = 30
    @State private var elapsedTotal = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isArabic: Bool { AppSettingsStore.shared.appLanguage == .arabic }

    /// Most-recent real heart-rate sample (≈ Apple Watch present), else nil → no gate.
    private var liveBPM: Int? { bio.latestBPM }
    private var hasHR: Bool { liveBPM != nil }
    /// No HR → don't gate on it; otherwise calm means at/under the ceiling.
    private var isCalm: Bool { (liveBPM ?? 0) <= calmCeilingBPM }
    private var canDisable: Bool { calmRemaining <= 0 || elapsedTotal >= absoluteCapSeconds }

    var body: some View {
        VStack(spacing: AiQoSpacing.lg) {
            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(AiQoColors.mintSoft.opacity(0.25), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(calmSeconds - calmRemaining) / CGFloat(calmSeconds))
                    .stroke(isCalm ? AiQoTheme.Colors.accent : Color.orange,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: calmRemaining)
                centerContent
            }
            .frame(width: 138, height: 138)

            Text(isArabic ? "راح تكسر التزامك اليوم" : "You're about to break today's commitment")
                .font(AiQoTheme.Typography.screenTitle)
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(reflection)
                .font(AiQoTheme.Typography.body)
                .foregroundStyle(AiQoTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AiQoSpacing.md)

            if let status = hrStatus {
                Text(status)
                    .font(AiQoTheme.Typography.caption)
                    .foregroundStyle(isCalm ? AiQoTheme.Colors.textSecondary : Color.orange)
                    .multilineTextAlignment(.center)
            }

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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await bio.refreshLiveHeartRate() }
        .onReceive(timer) { _ in tick() }
    }

    @ViewBuilder
    private var centerContent: some View {
        if canDisable {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36)).foregroundStyle(AiQoTheme.Colors.accent)
        } else if let bpm = liveBPM {
            VStack(spacing: 0) {
                Text("\(bpm)")
                    .font(.system(size: 40, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(isCalm ? AiQoTheme.Colors.textPrimary : Color.orange)
                Text(isArabic ? "نبضة" : "bpm")
                    .font(AiQoTheme.Typography.caption).foregroundStyle(AiQoTheme.Colors.textSecondary)
            }
        } else {
            Text("\(calmRemaining)")
                .font(.system(size: 42, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(AiQoTheme.Colors.textPrimary)
        }
    }

    private var reflection: String {
        isArabic
            ? "توقّف وتنفّس — هاي بالضبط اللحظة اللي النواة موجودة عشانها. خلّي عقلك يهدأ، وفكّر: تستاهل تكسر التزامك؟ كل الدروع راح تنفك."
            : "Stop and breathe — this is exactly the moment the Kernel exists for. Let your mind settle, and ask: is it worth breaking your commitment? Every shield will be lifted."
    }

    /// HR coaching line (only while gating and a reading exists).
    private var hrStatus: String? {
        guard hasHR, !canDisable else { return nil }
        if isCalm {
            return isArabic ? "نبضك هادي — ثبّته \(calmRemaining) ثانية بعد" : "Calm — hold it \(calmRemaining)s more"
        }
        return isArabic ? "هدّي نبضك (خلّيه ٨٠ أو أقل) حتى يكمل العدّاد" : "Calm your pulse (80 or below) to keep the timer going"
    }

    private var disableLabel: String {
        if canDisable {
            return isArabic ? "أطفئ الحماية وفُكّ الدروع" : "Turn off & lift the shields"
        }
        if hasHR, !isCalm {
            return isArabic ? "هدّي نبضك أول" : "Calm your pulse first"
        }
        return isArabic ? "تگدر تطفّي بعد \(calmRemaining) ثانية" : "Available in \(calmRemaining)s"
    }

    private func tick() {
        elapsedTotal += 1
        // The calm hold advances ONLY while calm (or when there's no HR to gate on).
        if calmRemaining > 0, isCalm { calmRemaining -= 1 }
        // Refresh the on-device HR sample every few seconds so the gate tracks reality.
        if elapsedTotal % 3 == 0 { Task { await bio.refreshLiveHeartRate() } }
    }
}
