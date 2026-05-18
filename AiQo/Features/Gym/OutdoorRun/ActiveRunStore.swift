//
//  ActiveRunStore.swift
//  AiQo
//
//  Holds the in-progress Outdoor Run so it outlives the screen. The run view
//  is a `fullScreenCover`; dismissing it used to deallocate the session +
//  GPS manager and stop the workout. By owning them here (app-lifetime
//  singleton) the run keeps tracking in the background while the user moves
//  around the app, and re-opening the run re-attaches to the same session.
//

import Combine
import Foundation

@MainActor
final class ActiveRunStore: ObservableObject {
    static let shared = ActiveRunStore()

    @Published private(set) var session: OutdoorRunSession?
    @Published private(set) var location: RunLocationManager?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // If the workout ends on the Apple Watch while the run screen is
        // minimized, finalize the run here — saving the route + summary —
        // so the user never has to reopen the phone screen to press Stop.
        PhoneConnectivityManager.shared.$currentWorkoutPhase
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.finalizeIfWatchEnded()
            }
            .store(in: &cancellables)
    }

    /// Finalizes an orphaned run: the workout already ended on the Watch but
    /// the phone session is still alive in the background (the user never
    /// reopened the screen to press Stop). Saves the route + summary so it
    /// shows up with its map in History. Idempotent and safe to call anytime —
    /// it no-ops unless the Watch workout is genuinely finished, so it never
    /// cuts a run the user is still doing short.
    func finalizeIfWatchEnded() {
        guard let session, let location,
              session.isActive, session.isWatchActive,
              PhoneConnectivityManager.shared.currentWorkoutPhase.isTerminal
        else { return }
        session.finish(
            routeCoordinates: location.routeCoordinates,
            elevationGainMeters: location.elevationGainMeters
        )
        location.endRun()
    }

    /// True while a run is genuinely in progress (running or paused).
    var hasActiveRun: Bool {
        session?.isActive ?? false
    }

    /// Re-attach to the existing run unless it's already finished. Reusing a
    /// not-yet-started (`.ready`) session too — not just `.running` — is what
    /// stops the wrapper's `.task` from swapping the session/GPS objects out
    /// from under a run that's about to start, which would drop the route.
    func attachOrStart(title: String) {
        if let session, session.phase != .finished {
            return
        }
        session = OutdoorRunSession(title: title)
        location = RunLocationManager()
    }

    /// Tear down once the run is finished/discarded so the next open is fresh.
    func clear() {
        location?.endRun()
        session = nil
        location = nil
    }
}
