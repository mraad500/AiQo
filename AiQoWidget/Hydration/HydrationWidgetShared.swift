import Foundation

/// Contract shared between the main app and the hydration widget.
/// All keys live in the `group.aiqo` App Group.
///
/// Single-writer per key:
/// - `consumedML`, `goalML`, `lastUpdated`, `tapCounterSeen` are written only by the app.
/// - `tapCounter` is written only by the widget (AddWaterIntent).
///
/// The widget displays `consumedML + (tapCounter - tapCounterSeen) * tapIncrementML`,
/// so the UI never regresses even if the app's last committed total hasn't caught up
/// with a sequence of widget taps yet.
enum HydrationWidgetShared {
    static let suiteName = "group.aiqo"
    static let widgetKind = "AiQoHydrationWidget"
    static let tapIncrementML: Int = 250

    enum Keys {
        // App writes:
        static let consumedML = "aiqo_water_ml"
        static let goalML = "aiqo_water_goal_ml"
        static let lastUpdated = "aiqo_water_last_updated"
        static let tapCounterSeen = "aiqo_water_tap_counter_seen"
        // Widget writes:
        static let tapCounter = "aiqo_water_tap_counter"
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
