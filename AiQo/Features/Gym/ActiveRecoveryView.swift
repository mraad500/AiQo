import SwiftUI
internal import Combine

struct ActiveRecoveryView: View {
    @ObservedObject var session: LiveWorkoutSession
    let peakHeartRate: Double
    let durationSeconds: Int
    let onComplete: (_ recovery1: Int, _ recovery2: Int) -> Void

    @State private var remainingSeconds: Int
    @State private var startDate: Date?
    @State private var recovery1: Int?
    @State private var didFinish = false
    @State private var hrAt30SecondsLeft: Double? = nil
    @State private var showRewardCaption: Bool = false

    @State private var avatarScale: CGFloat = 1.0
    @State private var breathingInstruction = "استنشق بعمق..."
    @State private var breathingTask: Task<Void, Never>?

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(
        session: LiveWorkoutSession,
        peakHeartRate: Double,
        durationSeconds: Int = 120,
        onComplete: @escaping (_ recovery1: Int, _ recovery2: Int) -> Void
    ) {
        self.session = session
        self.peakHeartRate = peakHeartRate
        self.durationSeconds = durationSeconds
        self.onComplete = onComplete
        _remainingSeconds = State(initialValue: durationSeconds)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.08, green: 0.11, blue: 0.17),
                    Color(red: 0.04, green: 0.06, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("ACTIVE RECOVERY")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.82))

                Text(formatCountdown(remainingSeconds))
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text("Live HR: \(Int(session.heartRate.rounded())) BPM")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer(minLength: 12)

                Image("Hammoudi5")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .scaleEffect(avatarScale)
                    .shadow(color: .white.opacity(0.12), radius: 24, x: 0, y: 14)

                Text(breathingInstruction)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                if showRewardCaption {
                    Text("مو القوة إنك تعلي النبض...\nالقوة إنك ترجع تسيطر عليه.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .animation(.easeInOut(duration: 1.0), value: showRewardCaption)
        }
        .interactiveDismissDisabled()
        .onAppear {
            startDate = Date()
            hrAt30SecondsLeft = nil
            showRewardCaption = false
            beginBreathingLoop()
        }
        .onDisappear {
            breathingTask?.cancel()
            breathingTask = nil
        }
        .onReceive(ticker) { _ in
            tickRecoveryTimer()
        }
    }

    private func tickRecoveryTimer() {
        guard !didFinish, let startDate else { return }

        let elapsed = Int(Date().timeIntervalSince(startDate))
        let nextRemaining = max(durationSeconds - elapsed, 0)
        let currentHR = session.heartRate

        if nextRemaining != remainingSeconds {
            remainingSeconds = nextRemaining
        }

        if nextRemaining == 30, hrAt30SecondsLeft == nil {
            hrAt30SecondsLeft = currentHR
        }

        if nextRemaining <= 15,
           let hrAt30SecondsLeft,
           currentHR <= hrAt30SecondsLeft - 6 {
            showRewardCaption = true
        }

        if elapsed >= 60, recovery1 == nil {
            recovery1 = calculateRecovery(using: currentHR)
        }

        if elapsed >= durationSeconds {
            didFinish = true
            let resolvedRecovery1 = recovery1 ?? calculateRecovery(using: currentHR)
            let recovery2 = calculateRecovery(using: currentHR)
            onComplete(resolvedRecovery1, recovery2)
        }
    }

    private func calculateRecovery(using heartRate: Double) -> Int {
        Int((peakHeartRate - heartRate).rounded())
    }

    private func beginBreathingLoop() {
        breathingTask?.cancel()
        breathingTask = Task { @MainActor in
            while !Task.isCancelled {
                breathingInstruction = "استنشق بعمق..."
                withAnimation(.easeInOut(duration: 4.0)) {
                    avatarScale = 1.15
                }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { break }

                breathingInstruction = "زفير ببطء..."
                withAnimation(.easeInOut(duration: 6.0)) {
                    avatarScale = 1.0
                }
                try? await Task.sleep(nanoseconds: 6_000_000_000)
            }
        }
    }

    private func formatCountdown(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
