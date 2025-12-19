import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        NSLog("✅ [Monitor] intervalDidStart: \(activity.rawValue)")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        NSLog("⏳ [Monitor] Threshold reached: \(event.rawValue)")

        let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID)
        guard let data = defaults?.data(forKey: AppGroupKeys.savedSelection) else {
            NSLog("❌ [Monitor] No SavedSelection")
            return
        }

        do {
            let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)

            // Apply Shield (هذا اللي يخلّي الدرع يظهر)
            store.shield.applications = selection.applicationTokens

            if selection.categoryTokens.isEmpty {
                store.shield.applicationCategories = nil
            } else {
                store.shield.applicationCategories = .specific(selection.categoryTokens)
            }

            store.shield.webDomains = selection.webDomainTokens

            NSLog("⛔️ [Monitor] Shield applied")
        } catch {
            NSLog("❌ [Monitor] decode failed: \(error.localizedDescription)")
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()
        NSLog("🔓 [Monitor] intervalDidEnd: cleared shields")
    }
}
