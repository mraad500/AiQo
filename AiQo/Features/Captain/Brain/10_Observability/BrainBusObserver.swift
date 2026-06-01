import Foundation

/// The Observability layer's consumer of `BrainBus`.
///
/// `BrainBus` is the brain's decoupled signal seam, but a `publish(_:)` only
/// does anything if something subscribed — until this type registers, every
/// signal (including the user-taught directive lifecycle) is silently dropped.
/// This observer is that subscriber: it gives the "do X after every workout"
/// standing-directive promise a real audit trail — `diag` for Console and a
/// privacy-safe `CaptainMetricsCounter` so we can confirm on TestFlight that
/// standing orders actually fire.
///
/// Privacy contract: the metrics counter receives only event + reason codes.
/// Directive UUIDs go to the os.log Brain category only (never to metrics,
/// never user content) — consistent with `CaptainMetricsCounter`'s contract.
enum BrainBusObserver {

    /// Subscribe once at launch. Single call site (`AiQoApp.init`) so there is
    /// no double-registration; do not call from elsewhere.
    static func start() async {
        await BrainBus.shared.subscribe { event in
            switch event {
            case .directiveLearned(let id):
                diag.info("BrainBus: directive learned id=\(id)")
                Task { @MainActor in
                    CaptainMetricsCounter.shared.record(event: "directive", reason: "learned")
                }

            case .directiveFired(let id):
                diag.info("BrainBus: directive fired id=\(id)")
                Task { @MainActor in
                    CaptainMetricsCounter.shared.record(event: "directive", reason: "fired")
                }

            case .workoutCompleted:
                Task { @MainActor in
                    CaptainMetricsCounter.shared.record(event: "directive", reason: "workout_seen")
                }

            case .tierChanged:
                diag.info("BrainBus: tier changed")

            case .userMessageSent, .captainReplied,
                 .notificationDelivered, .memoryExtracted:
                // Reserved for future consumers; intentionally not counted yet
                // so the metrics namespace stays meaningful.
                break
            }
        }
        diag.info("BrainBusObserver registered")
    }
}
