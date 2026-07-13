import Foundation
import DeviceActivity
import FamilyControls
import os

/// Phase-1 Device Activity Monitor for the Kernel.
///
/// No scheduling or shielding is wired yet. The single override below exists to
/// PROVE that the `FamilyActivitySelection` the app persists into the App Group
/// is readable from this separate extension process: it decodes the shared
/// selection via `KernelSharedStore` and logs the chosen-token count. No apps
/// are blocked.
///
/// The class name must match `NSExtensionPrincipalClass` in Info.plist
/// (`KernelDeviceActivityMonitor.DeviceActivityMonitorExtension`).
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let log = Logger(
        subsystem: "com.mraad500.aiqo.DeviceActivityMonitor",
        category: "Kernel"
    )

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let count = decodedSelectionCount()
        log.log("Kernel: intervalDidStart — decoded selection token count = \(count, privacy: .public)")
    }

    /// SMART trigger: the chosen apps crossed the usage threshold. Phase 3
    /// doomscroll gate — only shield if the app wrote that the user is sedentary.
    /// If they're moving while using, this is NOT doomscrolling: leave it open.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard KernelSharedStore.shared.load().doomscrollSedentary else {
            log.log("Kernel: threshold \(event.rawValue, privacy: .public) reached but user is ACTIVE — not shielding")
            return
        }
        log.log("Kernel: threshold \(event.rawValue, privacy: .public) + sedentary — applying SMART shield")
        KernelShieldController.shared.applyShield()
        KernelSharedStore.shared.mutate { $0.sessionStart = Date() }
    }

    /// Re-shield layer (b): when a monitored interval ends (incl. the temporary
    /// unlock window), re-apply the shield if the unlock has expired.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log.log("Kernel: intervalDidEnd \(activity.rawValue, privacy: .public) — reshield check")
        KernelShieldController.shared.reshieldIfNeeded()
    }

    /// Decodes the `FamilyActivitySelection` the app stored in the shared App
    /// Group and returns the total number of chosen tokens (apps + categories +
    /// web domains). Returns `0` when nothing is stored yet.
    private func decodedSelectionCount() -> Int {
        guard let data = KernelSharedStore.shared.selectionData,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return 0 }
        return selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }
}
