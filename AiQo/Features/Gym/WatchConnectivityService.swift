import Foundation
import Combine

enum WatchConnectionStatus: Equatable {
    case checking
    case connected
    case disconnected
}

@MainActor
final class WatchConnectivityService: ObservableObject {
    @Published private(set) var connectionStatus: WatchConnectionStatus
    @Published private(set) var isWorkoutStartAllowed: Bool

    private let connectivityManager: PhoneConnectivityManager
    private let isPreview: Bool
    private var cancellables = Set<AnyCancellable>()

    init(connectivityManager: PhoneConnectivityManager? = nil) {
        self.connectivityManager = connectivityManager ?? .shared
        self.connectionStatus = .checking
        self.isWorkoutStartAllowed = false
        self.isPreview = false

        bind()
        refresh()
    }

    private init(previewStatus: WatchConnectionStatus) {
        self.connectivityManager = .shared
        self.connectionStatus = previewStatus
        self.isWorkoutStartAllowed = previewStatus == .connected
        self.isPreview = true
    }

    func refresh() {
        guard !isPreview else { return }
        connectivityManager.refreshWatchConnectivityState()
        updateConnectionStatus()
    }

    static func preview(_ status: WatchConnectionStatus) -> WatchConnectivityService {
        WatchConnectivityService(previewStatus: status)
    }

    private func bind() {
        Publishers.CombineLatest4(
            connectivityManager.$activationState.removeDuplicates(),
            connectivityManager.$isPaired.removeDuplicates(),
            connectivityManager.$isWatchAppInstalled.removeDuplicates(),
            connectivityManager.$isReachable.removeDuplicates()
        )
        .combineLatest(connectivityManager.$hasMirroredSession.removeDuplicates())
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _ in
            guard let self else { return }
            self.apply(self.connectivityManager.watchStartConnectionStatus)
        }
        .store(in: &cancellables)
    }

    private func updateConnectionStatus() {
        apply(connectivityManager.watchStartConnectionStatus)
    }

    private func apply(_ status: WatchConnectionStatus) {
        let isStartAllowed = status == .connected

        guard connectionStatus != status || isWorkoutStartAllowed != isStartAllowed else {
            return
        }

        connectionStatus = status
        isWorkoutStartAllowed = isStartAllowed
    }

}
