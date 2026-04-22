import AppIntents
import WidgetKit

/// Interactive widget button action: logs +0.25 L by incrementing the
/// monotonic tap counter in the shared App Group. The main app drains this
/// counter into HealthKit on next activation (see HydrationService).
///
/// Why not write directly to HealthKit here: the widget extension does not
/// hold HealthKit entitlement and shouldn't. Monotonic counter + single-writer
/// per key is race-free and avoids any widget→app desync.
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log water"
    static var description = IntentDescription("Log 0.25 L of water from the widget.")

    /// Makes the button feel instant — WidgetKit dispatches the intent on the
    /// extension's main thread and reloads synchronously after `perform()`.
    static var isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let defaults = HydrationWidgetShared.sharedDefaults else {
            return .result()
        }

        // Atomic increment within the widget process. The widget is the only
        // writer for `tapCounter`, so no cross-process race is possible.
        let current = defaults.integer(forKey: HydrationWidgetShared.Keys.tapCounter)
        defaults.set(current + 1, forKey: HydrationWidgetShared.Keys.tapCounter)

        // Ask WidgetKit to re-render. Reads the new counter and reflects it
        // via the committed-plus-pending display formula.
        WidgetCenter.shared.reloadTimelines(
            ofKind: HydrationWidgetShared.widgetKind
        )

        return .result()
    }
}
