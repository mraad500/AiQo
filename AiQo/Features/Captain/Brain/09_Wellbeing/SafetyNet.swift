import Foundation

/// Records recent wellbeing signals and decides whether the app should
/// intervene on the current turn.
actor SafetyNet {
    static let shared = SafetyNet()

    private var recentSignals: [CrisisDetector.Signal] = []
    private let signalBufferLimit: Int

    init(signalBufferLimit: Int = 50) {
        self.signalBufferLimit = max(1, signalBufferLimit)
    }

    func record(_ signal: CrisisDetector.Signal) {
        recentSignals.append(signal)
        if recentSignals.count > signalBufferLimit {
            recentSignals.removeFirst(recentSignals.count - signalBufferLimit)
        }

        Task { @MainActor in
            diag.info(
                "SafetyNet: recorded severity=\(signal.severity.rawValue) source=\(signal.source.rawValue) context=\(signal.context)"
            )
        }
    }

    func shouldIntervene(
        for latest: CrisisDetector.Signal,
        language: AppLanguage
    ) -> InterventionPolicy.Decision {
        InterventionPolicy.decide(
            signal: latest,
            recentHistory: recentSignals,
            language: language
        )
    }

    func signalCount(
        in window: TimeInterval,
        minimumSeverity: CrisisDetector.Signal.Severity = .noConcern
    ) -> Int {
        let cutoff = Date().addingTimeInterval(-window)
        return recentSignals.filter {
            $0.detectedAt > cutoff && $0.severity >= minimumSeverity
        }.count
    }

    func clearBuffer() {
        recentSignals.removeAll()
    }
}
