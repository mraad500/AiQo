import Foundation
import Combine

/// Exposes phone reachability to the new SwiftUI views by mirroring the
/// authoritative `WatchConnectivityManager.shared` — the single `WCSession`
/// delegate on the watch. Reachability is delivered by the session delegate, so
/// this just forwards its published state instead of polling on a timer.
@MainActor
final class WatchConnectivityService: ObservableObject {
    @Published var isPhoneReachable = false

    private var cancellable: AnyCancellable?

    init() {
        let manager = WatchConnectivityManager.shared
        isPhoneReachable = manager.isPhoneReachable
        cancellable = manager.$isPhoneReachable
            .receive(on: RunLoop.main)
            .sink { [weak self] reachable in
                self?.isPhoneReachable = reachable
            }
    }
}
