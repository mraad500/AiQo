import SwiftUI
internal import Combine

@MainActor
final class WorkoutSessionViewModel: ObservableObject {
    struct PrimaryControlConfiguration {
        let title: String
        let icon: String
        let backgroundColor: Color
        let foregroundColor: Color
        let shadowColor: Color
        let isEnabled: Bool
    }

    @Published private(set) var watchConnectionStatus: WatchConnectionStatus
    @Published private(set) var primaryControl: PrimaryControlConfiguration

    let session: LiveWorkoutSession

    private let watchConnectivityService: WatchConnectivityService
    private var cancellables = Set<AnyCancellable>()

    init(
        session: LiveWorkoutSession,
        watchConnectivityService: WatchConnectivityService? = nil
    ) {
        let resolvedWatchConnectivityService = watchConnectivityService ?? WatchConnectivityService()

        self.session = session
        self.watchConnectivityService = resolvedWatchConnectivityService

        let initialStatus = resolvedWatchConnectivityService.connectionStatus
        self.watchConnectionStatus = initialStatus
        self.primaryControl = Self.makePrimaryControl(
            session.phase,
            session.isControlPending,
            session.remoteConnectionState,
            initialStatus
        )

        bind()
    }

    func handlePrimaryControlTap() {
        guard primaryControl.isEnabled else { return }

        switch session.phase {
        case .idle:
            session.startFromPhone()
        case .running:
            session.pauseFromPhone()
        case .paused:
            session.resumeFromPhone()
        case .starting, .ending:
            break
        }
    }

    func refreshWatchConnectionStatus() {
        watchConnectivityService.refresh()
    }

    private func bind() {
        watchConnectivityService.$connectionStatus
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] status in
                self?.watchConnectionStatus = status
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            session.$phase.removeDuplicates(),
            session.$isControlPending.removeDuplicates(),
            session.$remoteConnectionState.removeDuplicates(),
            watchConnectivityService.$connectionStatus.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .map { phase, isControlPending, remoteConnectionState, watchConnectionStatus in
            Self.makePrimaryControl(
                phase,
                isControlPending,
                remoteConnectionState,
                watchConnectionStatus
            )
        }
        .sink { [weak self] configuration in
            self?.primaryControl = configuration
        }
        .store(in: &cancellables)
    }

    private static func makePrimaryControl(
        _ phase: LiveWorkoutSession.Phase,
        _ isControlPending: Bool,
        _ remoteConnectionState: WorkoutConnectionState,
        _ watchConnectionStatus: WatchConnectionStatus
    ) -> PrimaryControlConfiguration {
        let baseForegroundColor = Color.black
        let baseBackgroundColor = WorkoutTheme.pastelMint
        let baseShadowColor = WorkoutTheme.pastelMint.opacity(0.30)
        let disconnectedBackgroundColor = Color.gray.opacity(0.62)
        let disconnectedForegroundColor = Color.white.opacity(0.86)

        switch phase {
        case .idle:
            let isEnabled = !isControlPending && watchConnectionStatus == .connected
            return PrimaryControlConfiguration(
                title: "Start Workout",
                icon: "play.fill",
                backgroundColor: isEnabled ? baseBackgroundColor : disconnectedBackgroundColor,
                foregroundColor: isEnabled ? baseForegroundColor : disconnectedForegroundColor,
                shadowColor: isEnabled ? baseShadowColor : Color.black.opacity(0.18),
                isEnabled: isEnabled
            )

        case .running:
            let isEnabled = !isControlPending && remoteConnectionState != .disconnected && remoteConnectionState != .failed
            return PrimaryControlConfiguration(
                title: "Pause Workout",
                icon: "pause.fill",
                backgroundColor: baseBackgroundColor,
                foregroundColor: baseForegroundColor,
                shadowColor: baseShadowColor,
                isEnabled: isEnabled
            )

        case .paused:
            let isEnabled = !isControlPending && remoteConnectionState != .disconnected && remoteConnectionState != .failed
            return PrimaryControlConfiguration(
                title: "Resume",
                icon: "play.fill",
                backgroundColor: baseBackgroundColor,
                foregroundColor: baseForegroundColor,
                shadowColor: baseShadowColor,
                isEnabled: isEnabled
            )

        case .starting:
            return PrimaryControlConfiguration(
                title: "Connecting...",
                icon: "hourglass",
                backgroundColor: baseBackgroundColor,
                foregroundColor: baseForegroundColor,
                shadowColor: WorkoutTheme.pastelMint.opacity(0.24),
                isEnabled: false
            )

        case .ending:
            return PrimaryControlConfiguration(
                title: "Ending...",
                icon: "hourglass",
                backgroundColor: baseBackgroundColor,
                foregroundColor: baseForegroundColor,
                shadowColor: WorkoutTheme.pastelMint.opacity(0.24),
                isEnabled: false
            )
        }
    }
}
