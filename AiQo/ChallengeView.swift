import SwiftUI
import UIKit
import ManagedSettings
internal import Combine

extension ManagedSettingsStore.Name {
    static let daily = ManagedSettingsStore.Name("daily")
}

// =========================
// File: AiQo/Views/ChallengeView.swift
// Demo-only for recording (NO real measuring)
// + Keyboard: Captain comes to front when keyboard opens
// =========================

struct ChallengeView: View {

    // MARK: - Fast Recording Goals
    private let stepsGoal: Int = 30
    private let calmMinBPM: Int = 72
    private let calmMaxBPM: Int = 88
    private let calmHoldSecondsGoal: Int = 5

    // MARK: - State
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyboard = KeyboardObserver()

    @State private var reasonText: String = ""
    @State private var isReasonSent: Bool = false

    // Live values (demo)
    @State private var stepsProgress: Int = 0
    @State private var currentBPM: Int = 78
    @State private var calmHoldSeconds: Int = 0

    // Running flags
    @State private var isStepsRunning: Bool = false
    @State private var isHeartRunning: Bool = false

    // Timers
    @State private var demoStepsTimer: Timer? = nil
    @State private var demoBpmTimer: Timer? = nil
    @State private var holdTimer: Timer? = nil

    @FocusState private var isReasonFocused: Bool

    // MARK: - Store
    private let store = ManagedSettingsStore()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                AiQoBrand.bg
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissKeyboard() }

                // ✅ Chat Card (خلف الكابتن لما الكيبورد يفتح)
                VStack(spacing: 10) {

                    HStack {
                        backButton
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    VStack(spacing: 10) {
                        stepsCardCompact
                        heartCardCompact
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        chatBoxBottomRight
                            .frame(width: min(geo.size.width * 0.58, 340))
                            .zIndex(keyboard.isVisible ? 1 : 3) // ✅ يصير خلف
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 45)

                    HStack { bottomBackButton }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(2)

                // ✅ Captain (للواجهة لما الكيبورد يفتح)
                Image("Hammoudi5")
                    .resizable()
                    .scaledToFit()
                    .frame(height: geo.size.height * (keyboard.isVisible ? 0.56 : 0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .position(
                        x: (geo.size.width * 0.44),
                        y: (geo.size.height - (geo.size.height * (keyboard.isVisible ? 0.56 : 0.65)) / 2 - 8)
                    )
                    .offset(y: keyboard.isVisible ? -geo.size.height * 0.18 : 0) // ✅ يطلع لفوك
                    .zIndex(keyboard.isVisible ? 4 : 1) // ✅ يصير قدّام
                    .allowsHitTesting(false)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .transaction { tx in
                tx.disablesAnimations = true
                tx.animation = nil
            }
            .animation(nil, value: stepsProgress)
            .animation(nil, value: currentBPM)
            .animation(nil, value: calmHoldSeconds)
            .animation(.spring(), value: isReasonSent)
            .onDisappear { stopAll() }
        }
    }

    // MARK: - Buttons
    private var backButton: some View {
        Button {
            stopAll()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.backward")
                Text("Back")
            }
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var bottomBackButton: some View {
        Button {
            stopAll()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.backward")
                Text("Back")
                    .font(.system(size: 17, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Cards (ONE TAP)
    private var stepsCardCompact: some View {
        CompactGlassCard(tint: AiQoBrand.mint) {
            HStack(spacing: 12) {
                CircleIcon(systemName: "figure.walk", tint: AiQoBrand.mintStrong, size: 40, iconSize: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Steps")
                        .font(.system(size: 14, weight: .semibold))

                    Text("\(stepsProgress) / \(stepsGoal) Steps")
                        .font(.system(size: 20, weight: .heavy))

                    Text(stepsStatusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(stepsStatusColor)
                }

                Spacer()

                Image(systemName: stepsStatusIcon)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(stepsStatusColor)
            }
        }
        .onTapGesture { toggleStepsOneTap() }
    }

    private var heartCardCompact: some View {
        CompactGlassCard(tint: AiQoBrand.sand) {
            HStack(spacing: 12) {
                CircleIcon(systemName: "heart.fill", tint: AiQoBrand.red, size: 40, iconSize: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Heart")
                        .font(.system(size: 14, weight: .semibold))

                    Text("\(currentBPM) BPM")
                        .font(.system(size: 20, weight: .heavy))

                    Text("Hold: \(calmHoldSeconds)/\(calmHoldSecondsGoal) sec")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(heartHintText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: heartStatusIcon)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(heartStatusColor)
            }
        }
        .onTapGesture { toggleHeartOneTap() }
    }

    // MARK: - Chat
    private var chatBoxBottomRight: some View {
        CompactGlassCard(tint: AiQoBrand.lemon) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Why disable protection?")
                    .font(.system(size: 16, weight: .heavy))

                HStack(spacing: 8) {
                    TextField("Type reason here...", text: $reasonText)
                        .focused($isReasonFocused)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .disabled(isReasonSent)

                    Button {
                        if !reasonText.trimmingCharacters(in: .whitespaces).isEmpty {
                            withAnimation {
                                isReasonSent = true
                                dismissKeyboard()
                            }
                        }
                    } label: {
                        Image(systemName: isReasonSent ? "checkmark.circle.fill" : "paperplane.fill")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(isReasonSent ? .green : .white)
                            .padding(8)
                    }
                    .disabled(reasonText.isEmpty || isReasonSent)
                }
                .background(Color.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

                Button {
                    if isUnlocked {
                        disableProtection()
                        stopAll()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                        Text(lockButtonTitle)
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white.opacity(isUnlocked ? 1 : 0.6))
                    .background(isUnlocked ? Color.black.opacity(0.75) : Color.gray.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!isUnlocked)
            }
        }
    }

    // MARK: - Disable Protection
    private func disableProtection() {
        let defaultStore = ManagedSettingsStore()
        defaultStore.shield.applications = nil
        defaultStore.shield.applicationCategories = nil
        defaultStore.shield.webDomains = nil

        let dailyStore = ManagedSettingsStore(named: .daily)
        dailyStore.shield.applications = nil
        dailyStore.shield.applicationCategories = nil
        dailyStore.shield.webDomains = nil

        defaultStore.dateAndTime.requireAutomaticDateAndTime = false
        dailyStore.dateAndTime.requireAutomaticDateAndTime = false
    }

    // MARK: - Unlock logic
    private var isUnlocked: Bool {
        let stepsOK = stepsProgress >= stepsGoal
        let calmOK = calmHoldSeconds >= calmHoldSecondsGoal
        return stepsOK && calmOK && isReasonSent
    }

    private var lockButtonTitle: String {
        isUnlocked ? "Unlock Protection" : "Complete Challenges"
    }

    // MARK: - One Tap Control
    private func toggleStepsOneTap() {
        if stepsProgress >= stepsGoal { return }
        isStepsRunning ? stopSteps() : startStepsDemoFast()
    }

    private func toggleHeartOneTap() {
        if calmHoldSeconds >= calmHoldSecondsGoal { return }
        isHeartRunning ? stopHeart() : startHeartDemoFast()
    }

    // MARK: - Steps DEMO (FAST)
    private func startStepsDemoFast() {
        dismissKeyboard()
        stepsProgress = 0
        isStepsRunning = true

        demoStepsTimer?.invalidate()
        demoStepsTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isStepsRunning else { return }
            let burst = Int.random(in: 3...7)
            stepsProgress = min(stepsProgress + burst, stepsGoal)
            if stepsProgress >= stepsGoal { stopSteps() }
        }
        demoStepsTimer?.tolerance = 0.02
    }

    private func stopSteps() {
        isStepsRunning = false
        demoStepsTimer?.invalidate()
        demoStepsTimer = nil
    }

    // MARK: - Heart DEMO (GUARANTEED)
    private func startHeartDemoFast() {
        dismissKeyboard()
        calmHoldSeconds = 0
        isHeartRunning = true

        currentBPM = Int.random(in: calmMinBPM...calmMaxBPM)
        demoBpmTimer?.invalidate()
        demoBpmTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
            guard isHeartRunning else { return }
            let delta = Int.random(in: -2...2)
            currentBPM = max(calmMinBPM, min(calmMaxBPM, currentBPM + delta))
        }
        demoBpmTimer?.tolerance = 0.1

        startHoldTimerFast()
    }

    private func startHoldTimerFast() {
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            guard isHeartRunning else { return }
            calmHoldSeconds = min(calmHoldSeconds + 1, calmHoldSecondsGoal)
            if calmHoldSeconds >= calmHoldSecondsGoal {
                stopHeart()
            }
        }
        holdTimer?.tolerance = 0.12
    }

    private func stopHeart() {
        isHeartRunning = false
        holdTimer?.invalidate()
        holdTimer = nil
        demoBpmTimer?.invalidate()
        demoBpmTimer = nil
    }

    private func stopAll() {
        stopSteps()
        stopHeart()
    }

    // MARK: - Status helpers
    private var stepsStatusText: String {
        if stepsProgress >= stepsGoal { return "Completed" }
        if isStepsRunning { return "Running..." }
        return "Tap to run"
    }

    private var stepsStatusIcon: String {
        if stepsProgress >= stepsGoal { return "checkmark.seal.fill" }
        return isStepsRunning ? "bolt.fill" : "hand.tap.fill"
    }

    private var stepsStatusColor: Color {
        if stepsProgress >= stepsGoal { return .green }
        return isStepsRunning ? AiQoBrand.mintStrong : .secondary
    }

    private var heartStatusIcon: String {
        if calmHoldSeconds >= calmHoldSecondsGoal { return "checkmark.seal.fill" }
        return isHeartRunning ? "waveform.path.ecg" : "hand.tap.fill"
    }

    private var heartStatusColor: Color {
        if calmHoldSeconds >= calmHoldSecondsGoal { return .green }
        return isHeartRunning ? AiQoBrand.red : .secondary
    }

    private var heartHintText: String {
        if calmHoldSeconds >= calmHoldSecondsGoal { return "Completed" }
        if isHeartRunning { return "Hold for a few seconds..." }
        return "Tap to run"
    }

    private func dismissKeyboard() {
        isReasonFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Keyboard Observer
final class KeyboardObserver: ObservableObject {
    @Published var isVisible: Bool = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }

        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.isVisible = v }
            .store(in: &cancellables)
    }
}

// MARK: - Glass UI
private struct CompactGlassCard<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack { content }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.12))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

private struct CircleIcon: View {
    let systemName: String
    let tint: Color
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.16))
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

private enum AiQoBrand {
    static let bg = Color.black.opacity(0.06)

    static let mint  = Color(red: 0.77, green: 0.94, blue: 0.86)
    static let sand  = Color(red: 0.97, green: 0.84, blue: 0.64)
    static let lemon = Color(red: 1.00, green: 0.93, blue: 0.72)

    static let mintStrong = Color(red: 0.15, green: 0.55, blue: 0.45)
    static let red = Color.red
}

#Preview {
    ChallengeView()
}
