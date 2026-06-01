import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import os

/// App-side orchestration of the Kernel via `DeviceActivityCenter`. Owns the
/// monitoring schedules and delegates the actual shielding to
/// `KernelShieldController`. App-target only (extensions react to the schedules
/// this sets up). Phase 2: usage-threshold (SMART) + always-on (HARD); the
/// physical/steps unlock is Phase 3.
@MainActor
final class KernelScheduler {
    static let shared = KernelScheduler()

    private let center = DeviceActivityCenter()
    private let shield = KernelShieldController.shared
    private let store = KernelSharedStore.shared
    private let log = Logger(subsystem: "com.mraad500.aiqo.kernel", category: "Scheduler")

    private let protectionActivity = DeviceActivityName("aiqo.kernel.protection")
    private let unlockActivity = DeviceActivityName("aiqo.kernel.unlock")
    private let usageEventName = DeviceActivityEvent.Name("aiqo.kernel.usage")

    // MARK: - Public

    /// Turn protection ON in the given mode.
    /// - HARD: shield immediately + keep a daily monitoring schedule alive so the
    ///   monitor can re-shield after a temporary unlock.
    /// - SMART: start daily monitoring with a usage-threshold event on the chosen
    ///   apps; the shield applies when the threshold is reached.
    func enableProtection(mode: KernelProtectionMode) {
        store.enableProtection(mode: mode)
        switch mode {
        case .hard:
            shield.applyShield()
            startProtectionSchedule(events: [:])
        case .smart:
            if let event = makeUsageEvent() {
                startProtectionSchedule(events: [usageEventName: event])
            } else {
                log.notice("enableProtection(smart): no apps selected — monitoring without event")
                startProtectionSchedule(events: [:])
            }
        }
        KernelBioEngine.shared.start()   // observe steps/HR to gate + verify unlocks
        log.notice("enableProtection: mode=\(mode.rawValue, privacy: .public)")
    }

    /// Turn protection OFF: stop all monitoring and lift the shield.
    func disableProtection() {
        center.stopMonitoring()
        shield.clearShield()
        store.disableProtection()
        KernelBioEngine.shared.stop()
        log.notice("disableProtection: stopped monitoring + cleared shield")
    }

    /// Re-arm the active mode (e.g. after the SMART threshold or selection changes).
    func reapplyIfActive() {
        let s = store.load()
        guard s.isProtectionEnabled else { return }
        enableProtection(mode: s.mode)
    }

    /// Grant the earned access session after a real unlock (called by
    /// `KernelBioEngine`): lift the shield (via the store) and schedule a
    /// DeviceActivity interval that ends at expiry so the **monitor** re-shields
    /// even if the app is killed (re-shield layer b). Replaces the Phase-2
    /// temporary-unlock button.
    func grantSession(minutes: Double) {
        store.grantUnlock(minutes: minutes)
        scheduleUnlockExpiry(minutes: minutes)
        log.notice("grantSession: \(minutes, privacy: .public)m access window opened")
    }

    // MARK: - Private

    private func startProtectionSchedule(events: [DeviceActivityEvent.Name: DeviceActivityEvent]) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        do {
            try center.startMonitoring(protectionActivity, during: schedule, events: events)
        } catch {
            log.error("startMonitoring(protection) failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func scheduleUnlockExpiry(minutes: Double) {
        let now = Date()
        let end = now.addingTimeInterval(minutes * 60)
        let cal = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: cal.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        do {
            try center.startMonitoring(unlockActivity, during: schedule)
        } catch {
            log.error("startMonitoring(unlock) failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Build the SMART usage-threshold event from the persisted selection.
    /// Returns `nil` when nothing is selected (so we don't arm an empty event).
    private func makeUsageEvent() -> DeviceActivityEvent? {
        guard let data = store.selectionData,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return nil }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let webs = selection.webDomainTokens
        guard !(apps.isEmpty && categories.isEmpty && webs.isEmpty) else { return nil }
        // Escalating SMART threshold: the FIRST shield (count 0) uses the user's own
        // `usageThresholdMinutes` (untouched); from shield 1 on, the usage allowed
        // before the next shield shrinks per `KernelEscalation` (15 → 8 → 5 → 3 → 2,
        // floor 2). Re-applied whenever monitoring is (re)armed (enable / reapply).
        let shield = store.triggeredTodayCount()
        let minutes = shield <= 0
            ? max(1, store.load().usageThresholdMinutes)
            : KernelEscalation.usageMinutesBeforeNext(forShield: shield)
        return DeviceActivityEvent(
            applications: apps,
            categories: categories,
            webDomains: webs,
            threshold: DateComponents(minute: minutes)
        )
    }
}
