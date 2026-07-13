import Foundation
import Combine
import FamilyControls

/// Thin wrapper around `AuthorizationCenter` for the individual (self) Family
/// Controls authorization the Kernel needs. No behavior beyond requesting and
/// reporting status — the Kernel applies no shields in Phase 1.
@MainActor
final class FamilyControlsAuthorizationService: ObservableObject {
    static let shared = FamilyControlsAuthorizationService()

    private let center = AuthorizationCenter.shared
    private var cancellable: AnyCancellable?

    @Published private(set) var status: AuthorizationStatus

    init() {
        self.status = AuthorizationCenter.shared.authorizationStatus
        // OBSERVE the framework's published status. Family Controls resolves the
        // persisted `.individual` approval slightly AFTER launch, so reading it once
        // (in init / onAppear) can catch a stale `.notDetermined` and wrongly
        // re-prompt for access on every relaunch even though the user already
        // granted it. Mirroring the published value keeps `status` correct once the
        // real (persisted) value loads.
        cancellable = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newStatus in self?.status = newStatus }
    }

    var isAuthorized: Bool { status == .approved }

    /// Request individual (self) authorization. Throws on failure / denial;
    /// always refreshes the published status afterward.
    func requestAuthorization() async throws {
        defer { refresh() }
        try await center.requestAuthorization(for: .individual)
    }

    /// Re-read the current authorization status (e.g. on `onAppear`).
    func refresh() {
        status = center.authorizationStatus
    }
}
