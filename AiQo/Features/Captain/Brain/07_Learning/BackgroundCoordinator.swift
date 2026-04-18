import Foundation
import BackgroundTasks

/// Coordinates the nightly consolidation BGTask that runs:
///   1. `EmotionalMiner.mine(since:)` over the last 24h of episodes
///   2. `BehavioralObserver.mineAndNominate()` to surface ProceduralPattern candidates
///
/// Registration must happen once at app launch (before `application:didFinishLaunching`
/// returns), and is a no-op unless `FeatureFlags.memoryV4Enabled` is true.
final class BackgroundCoordinator {
    static let shared = BackgroundCoordinator()

    static let nightlyTaskID = "aiqo.brain.nightly"

    private var didRegister = false

    private init() {}

    /// Registers the nightly task with `BGTaskScheduler`. Safe to call more than once —
    /// second calls are no-ops.
    func registerTasks() {
        guard !didRegister else { return }
        didRegister = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.nightlyTaskID,
            using: nil
        ) { task in
            Task.detached(priority: .utility) {
                guard let refreshTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                await Self.shared.handleNightlyTask(refreshTask)
            }
        }
        diag.info("BackgroundCoordinator: registered \(Self.nightlyTaskID)")
    }

    /// Submits a `BGAppRefreshTaskRequest` earliest-begin for the next 3am local time.
    /// Call after `registerTasks()` and also at the end of each nightly run.
    func scheduleNextNightly() {
        let request = BGAppRefreshTaskRequest(identifier: Self.nightlyTaskID)
        request.earliestBeginDate = Self.next3am(after: Date())

        do {
            try BGTaskScheduler.shared.submit(request)
            diag.info("BackgroundCoordinator: scheduled next nightly for \(request.earliestBeginDate?.description ?? "nil")")
        } catch {
            diag.error("BackgroundCoordinator: schedule failed", error: error)
        }
    }

    // MARK: - Task Execution

    private func handleNightlyTask(_ task: BGAppRefreshTask) async {
        let started = Date()
        diag.info("BackgroundCoordinator: nightly task started")

        task.expirationHandler = {
            diag.error("BackgroundCoordinator: nightly task expired before completion")
        }

        let since = started.addingTimeInterval(-86_400)

        async let minedCount = EmotionalMiner.shared.mine(since: since)
        async let nominatedCount = BehavioralObserver.shared.mineAndNominate()

        let (emotions, patterns) = await (minedCount, nominatedCount)
        diag.info("BackgroundCoordinator: nightly complete emotions=\(emotions) patterns=\(patterns)")

        scheduleNextNightly()
        task.setTaskCompleted(success: true)
    }

    // MARK: - Helpers

    static func next3am(after now: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 3
        components.minute = 0
        components.second = 0
        let today3am = calendar.date(from: components) ?? now
        if today3am > now { return today3am }
        return calendar.date(byAdding: .day, value: 1, to: today3am) ?? now.addingTimeInterval(86_400)
    }
}
